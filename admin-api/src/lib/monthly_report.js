'use strict';

const { v4: uuidv4 } = require('uuid');

// Returns YYYY-MM-01 string for a given year/month
function monthStart(year, month) {
  return `${year}-${String(month).padStart(2, '0')}-01`;
}

function monthEnd(year, month) {
  const d = new Date(year, month, 0); // last day of month
  return `${year}-${String(month).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

async function computeMonthData(conn, bizId, year, month) {
  const start = monthStart(year, month);
  const end   = monthEnd(year, month);

  const prevMonth = month === 1 ? 12 : month - 1;
  const prevYear  = month === 1 ? year - 1 : year;
  const prevStart = monthStart(prevYear, prevMonth);
  const prevEnd   = monthEnd(prevYear, prevMonth);

  const [[cfg]] = await conn.query(`
    SELECT minutes_per_booking, at_risk_days
    FROM business_configs WHERE business_id = ?
  `, [bizId]);
  const minutesPerBooking = cfg?.minutes_per_booking ?? 5;

  // ── Waitlist fills ──────────────────────────────────────────────────────
  const [[wl]] = await conn.query(`
    SELECT COUNT(*) AS cnt FROM waitlist_promotions
    WHERE business_id = ? AND booking_id IS NOT NULL
      AND promoted_at BETWEEN ? AND ?
  `, [bizId, start, end + ' 23:59:59']);
  const [[wlPrev]] = await conn.query(`
    SELECT COUNT(*) AS cnt FROM waitlist_promotions
    WHERE business_id = ? AND booking_id IS NOT NULL
      AND promoted_at BETWEEN ? AND ?
  `, [bizId, prevStart, prevEnd + ' 23:59:59']);

  // ── App bookings ────────────────────────────────────────────────────────
  const [[bk]] = await conn.query(`
    SELECT COUNT(*) AS cnt FROM bookings
    WHERE business_id = ? AND source = 'app'
      AND starts_at BETWEEN ? AND ?
  `, [bizId, start, end + ' 23:59:59']);
  const [[bkPrev]] = await conn.query(`
    SELECT COUNT(*) AS cnt FROM bookings
    WHERE business_id = ? AND source = 'app'
      AND starts_at BETWEEN ? AND ?
  `, [bizId, prevStart, prevEnd + ' 23:59:59']);

  // ── Check-ins ───────────────────────────────────────────────────────────
  const [[ci]] = await conn.query(`
    SELECT COUNT(*) AS cnt FROM bookings
    WHERE business_id = ? AND attendance_confirmed = 1
      AND starts_at BETWEEN ? AND ?
  `, [bizId, start, end + ' 23:59:59']);
  const [[ciPrev]] = await conn.query(`
    SELECT COUNT(*) AS cnt FROM bookings
    WHERE business_id = ? AND attendance_confirmed = 1
      AND starts_at BETWEEN ? AND ?
  `, [bizId, prevStart, prevEnd + ' 23:59:59']);

  // ── Active members (had at least 1 booking in period) ──────────────────
  const [[am]] = await conn.query(`
    SELECT COUNT(DISTINCT user_id) AS cnt FROM bookings
    WHERE business_id = ? AND status IN ('confirmed','completed','attended')
      AND starts_at BETWEEN ? AND ?
  `, [bizId, start, end + ' 23:59:59']);
  const [[amPrev]] = await conn.query(`
    SELECT COUNT(DISTINCT user_id) AS cnt FROM bookings
    WHERE business_id = ? AND status IN ('confirmed','completed','attended')
      AND starts_at BETWEEN ? AND ?
  `, [bizId, prevStart, prevEnd + ' 23:59:59']);

  // ── Payment reminders sent & renewals that followed ────────────────────
  const [[pr]] = await conn.query(`
    SELECT COUNT(*) AS cnt FROM user_notifications
    WHERE business_id = ? AND type IN ('payment_reminder_auto','membership_expired')
      AND created_at BETWEEN ? AND ?
  `, [bizId, start, end + ' 23:59:59']);

  const [[prRenewed]] = await conn.query(`
    SELECT COUNT(*) AS cnt
    FROM user_notifications n
    JOIN user_memberships m
      ON m.user_id = n.user_id AND m.business_id = n.business_id
      AND m.valid_from > DATE(n.created_at)
      AND m.valid_from <= DATE(DATE_ADD(n.created_at, INTERVAL 14 DAY))
    WHERE n.business_id = ? AND n.type IN ('payment_reminder_auto','membership_expired')
      AND n.created_at BETWEEN ? AND ?
  `, [bizId, start, end + ' 23:59:59']);

  // ── At-risk members who returned ───────────────────────────────────────
  const [[ar]] = await conn.query(`
    SELECT COUNT(*) AS cnt FROM at_risk_outreach
    WHERE business_id = ? AND returned_at IS NOT NULL
      AND returned_at BETWEEN ? AND ?
  `, [bizId, start, end + ' 23:59:59']);
  const [[arPrev]] = await conn.query(`
    SELECT COUNT(*) AS cnt FROM at_risk_outreach
    WHERE business_id = ? AND returned_at IS NOT NULL
      AND returned_at BETWEEN ? AND ?
  `, [bizId, prevStart, prevEnd + ' 23:59:59']);

  // ── Avg session price estimate from payments in last 90d ───────────────
  const [[avgPrice]] = await conn.query(`
    SELECT AVG(amount_cents) AS avg_cents
    FROM payments
    WHERE business_id = ? AND status = 'paid'
      AND created_at >= DATE_SUB(?, INTERVAL 90 DAY)
  `, [bizId, start]);
  const avgSessionCents = avgPrice?.avg_cents || 0;

  // ── Value estimate ──────────────────────────────────────────────────────
  const waitlistValueCents    = Math.round(wl.cnt * avgSessionCents);
  const receptionSavedMinutes = bk.cnt * minutesPerBooking;
  const receptionSavedEur     = Math.round((receptionSavedMinutes / 60) * 1200); // €12/hr

  return {
    period:               { year, month, start, end },
    active_members:       { value: am.cnt,  prev: amPrev.cnt  },
    check_ins:            { value: ci.cnt,  prev: ciPrev.cnt  },
    app_bookings:         { value: bk.cnt,  prev: bkPrev.cnt  },
    waitlist_fills:       { value: wl.cnt,  prev: wlPrev.cnt  },
    at_risk_returned:     { value: ar.cnt,  prev: arPrev.cnt  },
    payment_reminders_sent:   pr.cnt,
    payment_reminder_renewals: prRenewed.cnt,
    reception_saved_minutes: receptionSavedMinutes,
    reception_saved_eur_estimate: receptionSavedEur,
    waitlist_value_eur_estimate: Math.round(waitlistValueCents / 100),
    avg_session_eur_estimate: avgSessionCents ? Math.round(avgSessionCents / 100 * 10) / 10 : null,
    minutes_per_booking: minutesPerBooking,
  };
}

async function generateMonthlyReport(conn, bizId, year, month) {
  const data = await computeMonthData(conn, bizId, year, month);
  const reportMonth = monthStart(year, month);

  await conn.query(`
    INSERT INTO monthly_reports (id, business_id, report_month, data)
    VALUES (?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE data = VALUES(data), created_at = CURRENT_TIMESTAMP
  `, [uuidv4(), bizId, reportMonth, JSON.stringify(data)]);

  return data;
}

// Called by notification_worker on the 1st of every month
async function processMonthlyReports(conn) {
  const now = new Date();
  if (now.getDate() !== 1) return;  // Only run on 1st

  // Report covers previous month
  const reportDate  = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const year  = reportDate.getFullYear();
  const month = reportDate.getMonth() + 1;

  // Check we haven't already generated this report today
  const reportMonth = monthStart(year, month);
  const [[exists]] = await conn.query(`
    SELECT 1 FROM monthly_reports
    WHERE report_month = ?
      AND created_at >= CURDATE()
    LIMIT 1
  `, [reportMonth]);
  if (exists) return;

  const [businesses] = await conn.query('SELECT id FROM businesses');
  for (const biz of businesses) {
    try {
      await generateMonthlyReport(conn, biz.id, year, month);
    } catch (err) {
      console.error(`[monthly_report] ${biz.id}:`, err.message);
    }
  }
}

module.exports = { generateMonthlyReport, processMonthlyReports, computeMonthData };
