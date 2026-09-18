const db = require('../db');
const { sendSms } = require('./sms');
const { sendEmail } = require('./email');
const crypto = require('crypto');

async function runReminders() {
  try {
    // Get all businesses with reminder settings
    const [businesses] = await db.query(
      'SELECT business_id, reminder_settings FROM business_configs WHERE reminder_settings IS NOT NULL'
    );

    for (const biz of businesses) {
      let settings;
      try { settings = JSON.parse(biz.reminder_settings); } catch { continue; }
      const bizId = biz.business_id;

      await runBookingReminders(bizId, settings.booking_reminder);
      await runMembershipExpiryReminders(bizId, settings.membership_expiry);
      await runInactiveClientReminders(bizId, settings.inactive_client);
    }
  } catch (err) {
    console.error('[ReminderWorker] Error:', err.message);
  }
}

async function runBookingReminders(bizId, cfg) {
  if (!cfg?.enabled) return;
  const hours = cfg.hours_before || 24;
  try {
    // Find bookings in the next `hours` window not yet reminded
    const [bookings] = await db.query(
      `SELECT b.id, b.start_time, u.id AS user_id, u.full_name, u.phone, u.email
       FROM bookings b
       JOIN users u ON u.id = b.user_id
       WHERE b.business_id = ?
         AND b.status IN ('confirmed', 'pending')
         AND b.start_time BETWEEN NOW() AND DATE_ADD(NOW(), INTERVAL ? HOUR)
         AND NOT EXISTS (
           SELECT 1 FROM sent_reminders sr
           WHERE sr.business_id=? AND sr.type='booking_reminder' AND sr.ref_id=b.id
         )`,
      [bizId, hours, bizId]
    );

    for (const b of bookings) {
      const timeStr = new Date(b.start_time).toLocaleTimeString('el-GR', { hour: '2-digit', minute: '2-digit' });
      const msg = (cfg.message || '').replace('{time}', timeStr).replace('{name}', b.full_name);
      let status = 'sent';
      try {
        if (cfg.channel === 'sms' && b.phone) {
          await sendSms(b.phone, msg);
        } else if (cfg.channel === 'email' && b.email) {
          await sendEmail(b.email, b.full_name, 'Υπενθύμιση κράτησης', msg);
        }
      } catch { status = 'error'; }

      await db.query(
        'INSERT IGNORE INTO sent_reminders (id, business_id, user_id, type, channel, ref_id, status, sent_at) VALUES (?,?,?,?,?,?,?,NOW())',
        [crypto.randomUUID(), bizId, b.user_id, 'booking_reminder', cfg.channel, b.id, status]
      );
    }
  } catch (err) { console.error('[ReminderWorker] booking_reminder error:', err.message); }
}

async function runMembershipExpiryReminders(bizId, cfg) {
  if (!cfg?.enabled) return;
  const days = cfg.days_before || 3;
  try {
    const [members] = await db.query(
      `SELECT m.id, m.end_date, u.id AS user_id, u.full_name, u.phone, u.email
       FROM user_memberships m
       JOIN users u ON u.id = m.user_id
       WHERE m.business_id = ?
         AND m.membership_status = 'active'
         AND m.end_date BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL ? DAY)
         AND NOT EXISTS (
           SELECT 1 FROM sent_reminders sr
           WHERE sr.business_id=? AND sr.type='membership_expiry' AND sr.ref_id=m.id
         )`,
      [bizId, days, bizId]
    );

    for (const m of members) {
      const daysLeft = Math.ceil((new Date(m.end_date) - new Date()) / 86400000);
      const msg = (cfg.message || '').replace('{days}', daysLeft).replace('{name}', m.full_name);
      let status = 'sent';
      try {
        if (cfg.channel === 'sms' && m.phone) {
          await sendSms(m.phone, msg);
        } else if (cfg.channel === 'email' && m.email) {
          await sendEmail(m.email, m.full_name, 'Λήξη πακέτου', msg);
        }
      } catch { status = 'error'; }

      await db.query(
        'INSERT IGNORE INTO sent_reminders (id, business_id, user_id, type, channel, ref_id, status, sent_at) VALUES (?,?,?,?,?,?,?,NOW())',
        [crypto.randomUUID(), bizId, m.user_id, 'membership_expiry', cfg.channel, m.id, status]
      );
    }
  } catch (err) { console.error('[ReminderWorker] membership_expiry error:', err.message); }
}

async function runInactiveClientReminders(bizId, cfg) {
  if (!cfg?.enabled) return;
  const days = cfg.days_inactive || 30;
  try {
    // Clients who haven't had a booking in `days` days and haven't been reminded this month
    const [clients] = await db.query(
      `SELECT u.id AS user_id, u.full_name, u.phone, u.email,
              MAX(b.start_time) AS last_booking
       FROM users u
       LEFT JOIN bookings b ON b.user_id = u.id AND b.business_id = u.business_id
                              AND b.status IN ('confirmed','completed')
       WHERE u.business_id = ?
         AND u.account_status = 'active'
         AND u.deleted_at IS NULL
         AND NOT EXISTS (
           SELECT 1 FROM sent_reminders sr
           WHERE sr.business_id=? AND sr.type='inactive_client' AND sr.user_id=u.id
             AND sr.sent_at > DATE_SUB(NOW(), INTERVAL 30 DAY)
         )
       GROUP BY u.id, u.full_name, u.phone, u.email
       HAVING last_booking IS NULL OR last_booking < DATE_SUB(NOW(), INTERVAL ? DAY)
       LIMIT 50`,
      [bizId, bizId, days]
    );

    for (const c of clients) {
      const msg = (cfg.message || '').replace('{days}', days).replace('{name}', c.full_name);
      let status = 'sent';
      try {
        if (cfg.channel === 'sms' && c.phone) {
          await sendSms(c.phone, msg);
        } else if (cfg.channel === 'email' && c.email) {
          await sendEmail(c.email, c.full_name, 'Σας λείψαμε!', msg);
        }
      } catch { status = 'error'; }

      await db.query(
        'INSERT IGNORE INTO sent_reminders (id, business_id, user_id, type, channel, ref_id, status, sent_at) VALUES (?,?,?,?,?,?,?,NOW())',
        [crypto.randomUUID(), bizId, c.user_id, 'inactive_client', cfg.channel, c.user_id, status]
      );
    }
  } catch (err) { console.error('[ReminderWorker] inactive_client error:', err.message); }
}

function startReminderWorker() {
  console.log(' Reminder worker started (runs every 15 min)');
  setInterval(runReminders, 15 * 60 * 1000);
  // Run once on startup after a short delay
  setTimeout(runReminders, 30000);
}

module.exports = { startReminderWorker };
