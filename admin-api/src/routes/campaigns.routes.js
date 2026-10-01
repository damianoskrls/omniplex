const express = require('express');
const router = express.Router();
const db = require('../db');
const { v4: uuidv4 } = require('uuid');
const jwt = require('jsonwebtoken');
const { sendEmail } = require('../lib/email');
const { sendSms } = require('../lib/sms');
const { resolveAudience, normalizeAudienceInput } = require('../lib/audience');

function requireClientAdmin(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth) return res.status(401).json({ error: 'Unauthorized' });
  try {
    const payload = jwt.verify(auth.replace('Bearer ', ''), process.env.JWT_SECRET);
    if (payload.role !== 'client_admin') return res.status(403).json({ error: 'Forbidden' });
    req.admin = payload;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

async function getRecipients(bizId, input) {
  return resolveAudience(db, bizId, input);
}

// ── GET /campaigns — list ───────────────────────────────────────────────────
router.get('/', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  try {
    const [rows] = await db.query(
      'SELECT * FROM bulk_campaigns WHERE business_id = ? ORDER BY created_at DESC LIMIT 100',
      [bizId]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── GET /campaigns/preview — count recipients ──────────────────────────────
router.get('/preview', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { channel = 'sms' } = req.query;
  try {
    const all = await getRecipients(bizId, req.query);
    const eligible = channel === 'email'
      ? all.filter(r => r.email)
      : all.filter(r => r.phone);
    res.json({ total: all.length, eligible: eligible.length });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── POST /campaigns — send ─────────────────────────────────────────────────
router.post('/', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { channel, subject, body } = req.body;
  if (!channel || !body) return res.status(400).json({ error: 'channel and body required' });
  if (channel === 'email' && !subject) return res.status(400).json({ error: 'subject required for email' });
  if (channel !== 'email' && !process.env.BREVO_API_KEY) {
    return res.status(400).json({ error: 'Τα SMS δεν είναι ρυθμισμένα στον server (λείπει το κλειδί αποστολής).' });
  }

  const target = normalizeAudienceInput(req.body);
  const filterType = target.audience === 'staff' ? 'staff' : (target.clientScope || 'all');
  const filterValue = JSON.stringify({
    location_id: target.locationId,
    service_id: target.serviceId,
    staff_kind: target.staffKind,
  }).slice(0, 255);

  const id = uuidv4();
  try {
    const recipients = await getRecipients(bizId, req.body);
    const eligible = channel === 'email'
      ? recipients.filter(r => r.email)
      : recipients.filter(r => r.phone);

    await db.query(
      'INSERT INTO bulk_campaigns (id, business_id, channel, subject, body, filter_type, filter_value, recipient_count, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, "sending")',
      [id, bizId, channel, subject || null, body, filterType, filterValue, eligible.length]
    );

    // Respond immediately, send in background
    res.json({ id, recipient_count: eligible.length, status: 'sending' });

    // Send messages asynchronously
    let sent = 0;
    for (const r of eligible) {
      try {
        if (channel === 'email') {
          await sendEmail({ to: r.email, toName: r.full_name, subject, htmlContent: body.replace(/\n/g, '<br>') });
        } else {
          const msg = `${r.full_name ? r.full_name + ', ' : ''}${body}`;
          await sendSms(r.phone, msg);
        }
        sent++;
        // Small delay to avoid rate limits
        await new Promise(resolve => setTimeout(resolve, 80));
      } catch (e) {
        console.error(`[Campaign ${id}] Failed to send to ${r.id}:`, e.message);
      }
    }

    await db.query(
      'UPDATE bulk_campaigns SET sent_count = ?, status = "done" WHERE id = ?',
      [sent, id]
    );
  } catch (err) {
    await db.query('UPDATE bulk_campaigns SET status = "failed" WHERE id = ?', [id]).catch(() => {});
    console.error('[Campaign]', err.message);
  }
});

module.exports = router;
