'use strict';

const { v4: uuidv4 } = require('uuid');
const { createUserNotification } = require('./user_notifications');
const { sendSms } = require('./sms');

const RETURN_WINDOW_DAYS = 14;

async function getAtRiskMembers(conn, bizId, days) {
  const [rows] = await conn.query(`
    SELECT
      u.id AS user_id,
      u.full_name,
      u.phone,
      u.email,
      MAX(COALESCE(b.starts_at, ci.checked_in_at)) AS last_activity,
      COUNT(DISTINCT b.id) AS total_bookings_90d
    FROM users u
    JOIN user_memberships m ON m.user_id = u.id AND m.business_id = ? AND m.membership_status = 'active'
    LEFT JOIN bookings b
      ON b.user_id = u.id AND b.business_id = ?
      AND b.status IN ('confirmed', 'completed', 'attended')
      AND b.starts_at >= DATE_SUB(NOW(), INTERVAL 90 DAY)
    LEFT JOIN qr_checkins ci
      ON ci.user_id = u.id AND ci.business_id = ?
      AND ci.checked_in_at >= DATE_SUB(NOW(), INTERVAL 90 DAY)
    WHERE u.deleted_at IS NULL
    GROUP BY u.id, u.full_name, u.phone, u.email
    HAVING last_activity IS NULL
        OR last_activity < DATE_SUB(NOW(), INTERVAL ? DAY)
    ORDER BY last_activity ASC
  `, [bizId, bizId, bizId, days]);

  // Compute usual frequency: bookings_90d / 13 weeks → per-week
  return rows.map(r => ({
    ...r,
    usual_per_week: r.total_bookings_90d > 0
      ? (r.total_bookings_90d / 13).toFixed(1)
      : null,
    days_inactive: r.last_activity
      ? Math.floor((Date.now() - new Date(r.last_activity).getTime()) / 86400000)
      : null,
  }));
}

async function sendAtRiskMessages(conn, bizId, userIds, template) {
  if (!template || !userIds?.length) return { sent: 0 };

  const [users] = await conn.query(`
    SELECT id, full_name, phone FROM users WHERE id IN (?) AND deleted_at IS NULL
  `, [userIds]);

  let sent = 0;
  for (const user of users) {
    const firstName = user.full_name.split(' ')[0];
    const personalised = template
      .replace(/\{name\}/gi, firstName)
      .replace(/\{full_name\}/gi, user.full_name);

    await createUserNotification(conn, {
      businessId: bizId,
      userId: user.id,
      type: 'at_risk_outreach',
      title: 'Σε σκεφτόμαστε!',
      body: personalised,
      payload: { action: 'open_home' },
      sendPush: true,
    });

    await conn.query(`
      INSERT INTO at_risk_outreach (id, business_id, user_id, template_snapshot)
      VALUES (?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE sent_at = NOW(), template_snapshot = VALUES(template_snapshot), returned_at = NULL
    `, [uuidv4(), bizId, user.id, personalised]);

    sent++;
  }

  return { sent };
}

// Worker: check if at-risk members have returned (booked or checked in since outreach)
async function processAtRiskReturns(conn) {
  const [pending] = await conn.query(`
    SELECT ar.id, ar.user_id, ar.business_id, ar.sent_at
    FROM at_risk_outreach ar
    WHERE ar.returned_at IS NULL
      AND ar.sent_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
  `, [RETURN_WINDOW_DAYS]);

  for (const r of pending) {
    const [[activity]] = await conn.query(`
      SELECT 1
      FROM (
        SELECT starts_at AS activity_at FROM bookings
        WHERE user_id = ? AND business_id = ?
          AND starts_at > ? AND status IN ('confirmed','completed','attended')
        UNION ALL
        SELECT checked_in_at FROM qr_checkins
        WHERE user_id = ? AND business_id = ?
          AND checked_in_at > ?
      ) t
      LIMIT 1
    `, [r.user_id, r.business_id, r.sent_at,
        r.user_id, r.business_id, r.sent_at]);

    if (activity) {
      await conn.query(
        `UPDATE at_risk_outreach SET returned_at = NOW() WHERE id = ?`,
        [r.id],
      );
    }
  }
}

module.exports = { getAtRiskMembers, sendAtRiskMessages, processAtRiskReturns };
