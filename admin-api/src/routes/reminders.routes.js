const express = require('express');
const router = express.Router();
const db = require('../db');

function requireAdmin(req, res, next) {
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  const jwt = require('jsonwebtoken');
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    if (payload.role !== 'owner' && payload.role !== 'admin') return res.status(403).json({ error: 'Forbidden' });
    req.bizId = payload.business_id || payload.bizId;
    next();
  } catch { return res.status(401).json({ error: 'Unauthorized' }); }
}

// Get reminder settings for this business
router.get('/settings', requireAdmin, async (req, res) => {
  try {
    const [rows] = await db.query(
      'SELECT reminder_settings FROM business_configs WHERE business_id=?',
      [req.bizId]
    );
    const raw = rows[0]?.reminder_settings;
    const settings = raw ? JSON.parse(raw) : getDefaults();
    res.json(settings);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Save reminder settings
router.put('/settings', requireAdmin, async (req, res) => {
  try {
    const settings = req.body;
    await db.query(
      'UPDATE business_configs SET reminder_settings=? WHERE business_id=?',
      [JSON.stringify(settings), req.bizId]
    );
    res.json({ ok: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// List recently sent reminders (last 100)
router.get('/log', requireAdmin, async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT sr.id, sr.type, sr.channel, sr.sent_at, sr.status,
              u.full_name, u.phone, u.email
       FROM sent_reminders sr
       LEFT JOIN users u ON u.id = sr.user_id
       WHERE sr.business_id=?
       ORDER BY sr.sent_at DESC LIMIT 100`,
      [req.bizId]
    );
    res.json(rows);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

function getDefaults() {
  return {
    booking_reminder: { enabled: false, channel: 'sms', hours_before: 24, message: 'Υπενθύμιση: έχετε κράτηση αύριο στις {time}. Σας περιμένουμε!' },
    membership_expiry: { enabled: false, channel: 'sms', days_before: 3, message: 'Το πακέτο σας λήγει σε {days} ημέρες. Επικοινωνήστε μαζί μας για ανανέωση!' },
    inactive_client:  { enabled: false, channel: 'sms', days_inactive: 30, message: 'Σας λείψαμε! Δεν σας έχουμε δει εδώ και {days} ημέρες. Κλείστε μια κράτηση σήμερα.' },
  };
}

module.exports = router;
