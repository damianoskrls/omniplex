const express = require('express');
const router = express.Router();
const db = require('../db');
const { v4: uuidv4 } = require('uuid');
const jwt = require('jsonwebtoken');
const { sendEmail } = require('../lib/email');
const { sendSms } = require('../lib/sms');

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

/** Build recipients query based on filter */
async function getRecipients(bizId, filterType, filterValue) {
  let q = `
    SELECT DISTINCT u.id, u.full_name, u.email, u.phone
    FROM users u
  `;
  const params = [bizId];

  switch (filterType) {
    case 'all':
      q += ' WHERE u.business_id = ? AND u.deleted_at IS NULL AND u.account_status = "active"';
      break;

    case 'active_members':
      q += `
        JOIN user_memberships m ON m.user_id = u.id AND m.business_id = u.business_id
                                AND m.membership_status = 'active'
        WHERE u.business_id = ? AND u.deleted_at IS NULL
      `;
      break;

    case 'service':
      q += `
        JOIN user_memberships m ON m.user_id = u.id AND m.business_id = u.business_id
                                AND m.service_id = ? AND m.membership_status = 'active'
        WHERE u.business_id = ? AND u.deleted_at IS NULL
      `;
      params.unshift(filterValue); // service_id first
      break;

    case 'at_risk':
      q += `
        WHERE u.business_id = ? AND u.deleted_at IS NULL AND u.account_status = 'active'
          AND u.id NOT IN (
            SELECT DISTINCT b.user_id FROM bookings b
            WHERE b.business_id = ? AND b.starts_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
              AND b.user_id IS NOT NULL
          )
      `;
      params.push(bizId);
      break;

    case 'no_active_package':
      q += `
        LEFT JOIN user_memberships m ON m.user_id = u.id AND m.business_id = u.business_id
                                     AND m.membership_status = 'active'
        WHERE u.business_id = ? AND u.deleted_at IS NULL AND m.id IS NULL
      `;
      break;

    default:
      q += ' WHERE u.business_id = ? AND u.deleted_at IS NULL AND u.account_status = "active"';
  }

  const [rows] = await db.query(q, params);
  return rows;
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
  const { filter_type = 'all', filter_value, channel = 'sms' } = req.query;
  try {
    const all = await getRecipients(bizId, filter_type, filter_value);
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
  const { channel, subject, body, filter_type = 'all', filter_value } = req.body;
  if (!channel || !body) return res.status(400).json({ error: 'channel and body required' });
  if (channel === 'email' && !subject) return res.status(400).json({ error: 'subject required for email' });

  const id = uuidv4();
  try {
    const recipients = await getRecipients(bizId, filter_type, filter_value);
    const eligible = channel === 'email'
      ? recipients.filter(r => r.email)
      : recipients.filter(r => r.phone);

    await db.query(
      'INSERT INTO bulk_campaigns (id, business_id, channel, subject, body, filter_type, filter_value, recipient_count, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, "sending")',
      [id, bizId, channel, subject || null, body, filter_type, filter_value || null, eligible.length]
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
