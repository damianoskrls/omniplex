const db = require('../db');
const { createUserNotification } = require('./user_notifications');
const { createAdminNotification } = require('./notifications');
const { resolveTips, firstNameFromFull } = require('./tips');
const { membershipCredits } = require('./membership_sessions');
const { parseDateTimeParts } = require('./datetime');
const { paymentBalance } = require('./payments');
const { processExpiredWaitlistOffers } = require('./waitlist');
const { processAtRiskReturns } = require('./at_risk');
const { processMonthlyReports } = require('./monthly_report');

async function getBusinessNotificationSettings(conn, businessId) {
  const [[row]] = await conn.query(
    `SELECT booking_reminder_24h, booking_reminder_1h,
            auto_payment_reminders, payment_reminder_days
     FROM business_configs WHERE business_id = ?`,
    [businessId]
  );
  return {
    booking_reminder_24h: row?.booking_reminder_24h !== 0,
    booking_reminder_1h: row?.booking_reminder_1h !== 0,
    auto_payment_reminders: !!row?.auto_payment_reminders,
    payment_reminder_days: row?.payment_reminder_days ?? 3,
  };
}

async function processDayBeforeReminders(conn) {
  const [bookings] = await conn.query(`
    SELECT b.id, b.user_id, b.business_id, b.starts_at,
           sv.name AS service_name, sss.label
    FROM bookings b
    JOIN services sv ON sv.id = b.service_id
    JOIN business_configs bc ON bc.business_id = b.business_id
    LEFT JOIN service_slot_schedules sss ON sss.service_id = b.service_id
      AND sss.business_id = b.business_id
      AND sss.weekday = WEEKDAY(b.starts_at)
      AND sss.start_time = TIME(b.starts_at)
      AND sss.is_active = 1
    WHERE b.status IN ('confirmed', 'pending')
      AND b.day_before_notified = 0
      AND bc.booking_reminder_24h = 1
      AND b.starts_at BETWEEN DATE_ADD(NOW(), INTERVAL 23 HOUR)
                          AND DATE_ADD(NOW(), INTERVAL 25 HOUR)
  `);

  for (const b of bookings) {
    const { date: dateStr, time: timeStr } = parseDateTimeParts(b.starts_at);
    const label = b.label || b.service_name;
    await createUserNotification(conn, {
      businessId: b.business_id,
      userId: b.user_id,
      bookingId: b.id,
      type: 'booking_reminder_24h',
      title: `Αύριο — ${label}`,
      body: `Έχεις προπόνηση ${dateStr} στις ${timeStr}.`,
      payload: { action: 'open_booking', booking_id: b.id },
    });
    await conn.query('UPDATE bookings SET day_before_notified = 1 WHERE id = ?', [b.id]);
  }
}

async function processHourBeforeReminders(conn) {
  const [bookings] = await conn.query(`
    SELECT b.id, b.user_id, b.business_id, b.starts_at, b.ends_at, b.membership_id,
           u.full_name AS user_name,
           sv.name AS service_name,
           sss.label, sss.room_name, sss.icon_key,
           sss.preparation_tips, sss.post_workout_tips,
           m.total_sessions, m.used_sessions, m.membership_status
    FROM bookings b
    JOIN users u ON u.id = b.user_id
    JOIN services sv ON sv.id = b.service_id
    JOIN business_configs bc ON bc.business_id = b.business_id
    LEFT JOIN service_slot_schedules sss ON sss.service_id = b.service_id
      AND sss.business_id = b.business_id
      AND sss.weekday = WEEKDAY(b.starts_at)
      AND sss.start_time = TIME(b.starts_at)
      AND sss.is_active = 1
    LEFT JOIN user_memberships m ON m.id = b.membership_id
    WHERE b.status IN ('confirmed', 'pending')
      AND b.prep_notified = 0
      AND bc.booking_reminder_1h = 1
      AND b.starts_at BETWEEN DATE_ADD(NOW(), INTERVAL 50 MINUTE)
                          AND DATE_ADD(NOW(), INTERVAL 70 MINUTE)
      AND b.starts_at > NOW()
  `);

  for (const b of bookings) {
    const tips = resolveTips(b, b.icon_key);
    const prepPreview = tips.preparation_tips.slice(0, 3).join(' · ');
    const { time: timeStr } = parseDateTimeParts(b.starts_at);
    const label = b.label || b.service_name;
    const firstName = firstNameFromFull(b.user_name);

    let sessionsLine = '';
    if (b.membership_id) {
      const credits = membershipCredits(b);
      if (b.membership_status === 'trial') {
        sessionsLine = 'Δοκιμαστικό μάθημα';
      } else if (!credits.isUnlimited && credits.remaining > 0) {
        const rem = credits.remaining;
        sessionsLine = rem === 1
          ? 'Απομένει 1 συνεδρία'
          : `Απομένουν ${rem} συνεδρίες`;
      }
    }

    const bodyParts = [prepPreview || 'Πετσέτα, νερό & ελαφρό γεύμα'];
    if (sessionsLine) bodyParts.push(sessionsLine);

    await createUserNotification(conn, {
      businessId: b.business_id,
      userId: b.user_id,
      bookingId: b.id,
      type: 'prep_reminder',
      title: `${firstName}, σε 1 ώρα — ${label} στις ${timeStr}`,
      body: bodyParts.join(' · '),
      payload: { action: 'open_booking', booking_id: b.id },
      sendPush: true,
    });
    await conn.query('UPDATE bookings SET prep_notified = 1 WHERE id = ?', [b.id]);
  }
}

async function processPostWorkoutReminders(conn) {
  const [bookings] = await conn.query(`
    SELECT b.id, b.user_id, b.business_id, b.starts_at, b.ends_at,
           sv.name AS service_name,
           sss.label, sss.icon_key
    FROM bookings b
    JOIN services sv ON sv.id = b.service_id
    LEFT JOIN service_slot_schedules sss ON sss.service_id = b.service_id
      AND sss.business_id = b.business_id
      AND sss.weekday = WEEKDAY(b.starts_at)
      AND sss.start_time = TIME(b.starts_at)
      AND sss.is_active = 1
    WHERE b.status IN ('confirmed', 'pending', 'in_progress')
      AND b.attendance_confirmed = 0
      AND b.post_notified = 0
      AND b.ends_at <= NOW()
      AND b.ends_at >= DATE_SUB(NOW(), INTERVAL 3 HOUR)
  `);

  for (const b of bookings) {
    const label = b.label || b.service_name;
    await createUserNotification(conn, {
      businessId: b.business_id,
      userId: b.user_id,
      bookingId: b.id,
      type: 'workout_complete',
      title: `Τέλος προπόνησης — ${label}`,
      body: 'Επιβεβαίωσε την παρουσία σου, σχολίασε και κοινοποίησε τη φωτογραφία σου!',
      payload: { action: 'workout_complete', booking_id: b.id },
      sendPush: true,
    });
    await conn.query('UPDATE bookings SET post_notified = 1 WHERE id = ?', [b.id]);
  }
}

async function processMissedCheckinReminders(conn) {
  const [bookings] = await conn.query(`
    SELECT b.id, b.user_id, b.business_id, b.starts_at, b.ends_at,
           sv.name AS service_name,
           sss.label
    FROM bookings b
    JOIN services sv ON sv.id = b.service_id
    LEFT JOIN service_slot_schedules sss ON sss.service_id = b.service_id
      AND sss.business_id = b.business_id
      AND sss.weekday = WEEKDAY(b.starts_at)
      AND sss.start_time = TIME(b.starts_at)
      AND sss.is_active = 1
    WHERE b.status IN ('confirmed', 'pending', 'in_progress')
      AND b.attendance_confirmed = 0
      AND b.ends_at <= DATE_SUB(NOW(), INTERVAL 10 MINUTE)
      AND b.ends_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
  `);

  for (const b of bookings) {
    const [[sent]] = await conn.query(`
      SELECT id FROM user_notifications
      WHERE user_id = ? AND type = 'checkin_reminder' AND booking_id = ?
      LIMIT 1
    `, [b.user_id, b.id]);
    if (sent) continue;

    const label = b.label || b.service_name;
    await createUserNotification(conn, {
      businessId: b.business_id,
      userId: b.user_id,
      bookingId: b.id,
      type: 'checkin_reminder',
      title: `Ξέχασες το check-in; — ${label}`,
      body: 'Επιβεβαίωσε την παρουσία σου από τις Κρατήσεις ή σκάναρε το QR στο γυμναστήριο.',
      payload: { action: 'workout_complete', booking_id: b.id },
      sendPush: true,
    });
  }
}

async function processAutoPaymentReminders(conn) {
  const [businesses] = await conn.query(`
    SELECT business_id, payment_reminder_days
    FROM business_configs
    WHERE auto_payment_reminders = 1
  `);

  for (const biz of businesses) {
    const days = biz.payment_reminder_days ?? 3;
    const [payments] = await conn.query(`
      SELECT p.id, p.user_id, p.business_id, p.description, p.amount_cents,
             p.paid_amount_cents, p.due_date, p.period_end, p.payment_date,
             u.full_name AS user_name
      FROM payments p
      JOIN users u ON u.id = p.user_id
      WHERE p.business_id = ?
        AND p.user_id IS NOT NULL
        AND p.status IN ('pending', 'partial', 'overdue')
        AND COALESCE(p.due_date, p.period_end) IS NOT NULL
        AND DATE(COALESCE(p.due_date, p.period_end)) >= CURDATE()
        AND DATE(COALESCE(p.due_date, p.period_end)) <= DATE_ADD(CURDATE(), INTERVAL ? DAY)
    `, [biz.business_id, days]);

    for (const p of payments) {
      const [[sent]] = await conn.query(`
        SELECT id FROM user_notifications
        WHERE user_id = ? AND type = 'payment_reminder_auto'
          AND JSON_UNQUOTE(JSON_EXTRACT(payload, '$.payment_id')) = ?
          AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        LIMIT 1
      `, [p.user_id, p.id]);
      if (sent) continue;

      const balance = paymentBalance(p.amount_cents, p.paid_amount_cents || 0);
      const due = (p.due_date || p.period_end || '').toString().slice(0, 10);
      const title = 'Υπενθύμιση πληρωμής';
      const body = balance > 0
        ? `Οφείλετε €${(balance / 100).toFixed(2)} έως ${due}. ${p.description || ''}`.trim()
        : `Η περίοδος ${p.description || 'συνδρομής'} λήγει στις ${due}.`;

      await createUserNotification(conn, {
        businessId: p.business_id,
        userId: p.user_id,
        type: 'payment_reminder_auto',
        title,
        body,
        payload: { payment_id: p.id, due_date: due, auto: true },
      });
    }

    const [memberships] = await conn.query(`
      SELECT m.id AS membership_id, m.user_id, m.business_id, m.valid_until,
             s.name AS service_name, u.full_name AS user_name
      FROM user_memberships m
      JOIN users u ON u.id = m.user_id
      LEFT JOIN services s ON s.id = m.service_id
      WHERE m.business_id = ?
        AND m.membership_status = 'active'
        AND m.valid_until >= CURDATE()
        AND m.valid_until <= DATE_ADD(CURDATE(), INTERVAL ? DAY)
    `, [biz.business_id, days]);

    for (const m of memberships) {
      const [[sent]] = await conn.query(`
        SELECT id FROM user_notifications
        WHERE user_id = ? AND type = 'payment_reminder_auto'
          AND JSON_UNQUOTE(JSON_EXTRACT(payload, '$.membership_id')) = ?
          AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        LIMIT 1
      `, [m.user_id, m.membership_id]);
      if (sent) continue;

      const dueRaw = m.valid_until;
      const due = dueRaw instanceof Date
        ? dueRaw.toISOString().slice(0, 10)
        : String(dueRaw).slice(0, 10);
      await createUserNotification(conn, {
        businessId: m.business_id,
        userId: m.user_id,
        type: 'payment_reminder_auto',
        title: 'Λήγει σύντομα το πακέτο σου',
        body: `${m.service_name || 'Συνδρομή'} λήγει στις ${due}. Επικοινώνησε με το γυμναστήριο.`,
        payload: { membership_id: m.membership_id, due_date: due, auto: true },
      });
    }

    const [[graceCfg]] = await conn.query(
      'SELECT grace_period_days FROM business_configs WHERE business_id = ?',
      [biz.business_id],
    );
    const graceDays = graceCfg?.grace_period_days ?? 15;

    const [expiredToday] = await conn.query(`
      SELECT m.id AS membership_id, m.user_id, m.business_id, m.valid_until,
             s.name AS service_name, u.full_name AS user_name
      FROM user_memberships m
      JOIN users u ON u.id = m.user_id
      LEFT JOIN services s ON s.id = m.service_id
      WHERE m.business_id = ?
        AND m.membership_status = 'active'
        AND DATE(m.valid_until) = CURDATE()
    `, [biz.business_id]);

    for (const m of expiredToday) {
      const [[sentUser]] = await conn.query(`
        SELECT id FROM user_notifications
        WHERE user_id = ? AND type = 'membership_expired'
          AND JSON_UNQUOTE(JSON_EXTRACT(payload, '$.membership_id')) = ?
          AND created_at >= DATE_SUB(NOW(), INTERVAL 3 DAY)
        LIMIT 1
      `, [m.user_id, m.membership_id]);
      if (!sentUser) {
        const due = String(m.valid_until).slice(0, 10);
        await createUserNotification(conn, {
          businessId: m.business_id,
          userId: m.user_id,
          type: 'membership_expired',
          title: 'Έληξε η συνδρομή σου',
          body: `${m.service_name || 'Συνδρομή'} έληξε στις ${due}. Ανένεωσε εντός ${graceDays} ημερών για να συνεχίσεις.`,
          payload: { membership_id: m.membership_id, due_date: due, grace_days: graceDays },
          sendPush: true,
        });
      }

      const [[sentAdmin]] = await conn.query(`
        SELECT id FROM admin_notifications
        WHERE business_id = ? AND type = 'membership_expired_admin'
          AND JSON_UNQUOTE(JSON_EXTRACT(payload, '$.membership_id')) = ?
          AND created_at >= DATE_SUB(NOW(), INTERVAL 3 DAY)
        LIMIT 1
      `, [m.business_id, m.membership_id]);
      if (!sentAdmin) {
        await createAdminNotification(conn, {
          businessId: m.business_id,
          type: 'membership_expired_admin',
          title: 'Λήξη συνδρομής πελάτη',
          body: `${m.user_name} — ${m.service_name || 'Συνδρομή'} έληξε σήμερα. Ανανέωση / πληρωμή.`,
          payload: { membership_id: m.membership_id, user_id: m.user_id },
        });
      }
    }

    const [inGrace] = await conn.query(`
      SELECT m.id AS membership_id, m.user_id, m.business_id, m.valid_until,
             s.name AS service_name, u.full_name AS user_name
      FROM user_memberships m
      JOIN users u ON u.id = m.user_id
      LEFT JOIN services s ON s.id = m.service_id
      WHERE m.business_id = ?
        AND m.membership_status = 'active'
        AND m.valid_until < CURDATE()
        AND DATE_ADD(m.valid_until, INTERVAL ? DAY) >= CURDATE()
    `, [biz.business_id, graceDays]);

    for (const m of inGrace) {
      const [[sent]] = await conn.query(`
        SELECT id FROM user_notifications
        WHERE user_id = ? AND type = 'membership_grace'
          AND JSON_UNQUOTE(JSON_EXTRACT(payload, '$.membership_id')) = ?
          AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        LIMIT 1
      `, [m.user_id, m.membership_id]);
      if (sent) continue;

      const graceEnd = new Date(`${String(m.valid_until).slice(0, 10)}T12:00:00`);
      graceEnd.setDate(graceEnd.getDate() + graceDays);
      const graceEndStr = graceEnd.toISOString().slice(0, 10);

      await createUserNotification(conn, {
        businessId: m.business_id,
        userId: m.user_id,
        type: 'membership_grace',
        title: 'Η συνδρομή σου έληξε',
        body: `${m.service_name || 'Συνδρομή'} — ανανέωσε έως ${graceEndStr} αλλιώς δεν θα μπορείς να κλείνεις θέσεις.`,
        payload: { membership_id: m.membership_id, grace_until: graceEndStr },
        sendPush: true,
      });
    }
  }
}

async function processBookingNotifications() {
  const conn = await db.getConnection();
  try {
    await processDayBeforeReminders(conn);
    await processHourBeforeReminders(conn);
    await processPostWorkoutReminders(conn);
    await processMissedCheckinReminders(conn);
    await processAutoPaymentReminders(conn);
    await processExpiredWaitlistOffers(conn);
    await processAtRiskReturns(conn);
    await processMonthlyReports(conn);
  } catch (err) {
    console.error('[notification_worker]', err.message);
  } finally {
    conn.release();
  }
}

function startNotificationWorker(intervalMs = 60000) {
  processBookingNotifications();
  setInterval(processBookingNotifications, intervalMs);
  console.log(' Notification worker started (every 60s)');
}

module.exports = {
  processBookingNotifications,
  startNotificationWorker,
  getBusinessNotificationSettings,
};
