// ============================================================
// FILE: src/routes/business.routes.js
// Staff, Services, Bookings, Users endpoints (per tenant)
// ============================================================

const express = require('express');
const { v4: uuidv4 } = require('uuid');
const db      = require('../db');
const { authenticate, requireMasterAdmin } = require('../middleware/auth');
const { getAtRiskMembers, sendAtRiskMessages } = require('../lib/at_risk');
const { generateMonthlyReport, computeMonthData } = require('../lib/monthly_report');
const { getWaitlistConfig } = require('../lib/waitlist');

const router = express.Router();

// ── STAFF ────────────────────────────────────────────────────

// GET /api/business/:bizId/staff  (public — mobile app reads this)
router.get('/:bizId/staff', async (req, res) => {
  try {
    const [rows] = await db.query(
      'SELECT * FROM staff WHERE business_id = ? ORDER BY full_name',
      [req.params.bizId]
    );
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/business/:bizId/staff
router.post('/:bizId/staff', authenticate, requireMasterAdmin, async (req, res) => {
  const { full_name, role, bio, color_hex } = req.body;
  if (!full_name || !role) {
    return res.status(400).json({ error: 'full_name and role are required' });
  }
  try {
    const id = uuidv4();
    await db.query(
      'INSERT INTO staff (id, business_id, full_name, role, bio, color_hex) VALUES (?, ?, ?, ?, ?, ?)',
      [id, req.params.bizId, full_name, role, bio || null, color_hex || '#607D8B']
    );
    return res.status(201).json({ id });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// PATCH /api/business/:bizId/staff/:staffId
router.patch('/:bizId/staff/:staffId', authenticate, requireMasterAdmin, async (req, res) => {
  const { full_name, role, bio, color_hex, is_active } = req.body;
  try {
    await db.query(
      `UPDATE staff SET
        full_name  = COALESCE(?, full_name),
        role       = COALESCE(?, role),
        bio        = COALESCE(?, bio),
        color_hex  = COALESCE(?, color_hex),
        is_active  = COALESCE(?, is_active)
      WHERE id = ? AND business_id = ?`,
      [full_name, role, bio, color_hex, is_active, req.params.staffId, req.params.bizId]
    );
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// DELETE /api/business/:bizId/staff/:staffId
router.delete('/:bizId/staff/:staffId', authenticate, requireMasterAdmin, async (req, res) => {
  try {
    await db.query(
      'DELETE FROM staff WHERE id = ? AND business_id = ?',
      [req.params.staffId, req.params.bizId]
    );
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ── SERVICES ─────────────────────────────────────────────────

// GET /api/business/:bizId/services  (public — mobile app reads this)
router.get('/:bizId/services', async (req, res) => {
  try {
    const [rows] = await db.query(
      'SELECT * FROM services WHERE business_id = ? ORDER BY category, name',
      [req.params.bizId]
    );
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/business/:bizId/services
router.post('/:bizId/services', authenticate, requireMasterAdmin, async (req, res) => {
  const { name, description, duration_mins, price_cents, category } = req.body;
  if (!name || !duration_mins || price_cents === undefined) {
    return res.status(400).json({ error: 'name, duration_mins, and price_cents are required' });
  }
  try {
    const id = uuidv4();
    await db.query(
      'INSERT INTO services (id, business_id, name, description, duration_mins, price_cents, category) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [id, req.params.bizId, name, description || null, duration_mins, price_cents, category || null]
    );
    return res.status(201).json({ id });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// PATCH /api/business/:bizId/services/:serviceId
router.patch('/:bizId/services/:serviceId', authenticate, requireMasterAdmin, async (req, res) => {
  const { name, description, duration_mins, price_cents, category, is_active } = req.body;
  try {
    await db.query(
      `UPDATE services SET
        name          = COALESCE(?, name),
        description   = COALESCE(?, description),
        duration_mins = COALESCE(?, duration_mins),
        price_cents   = COALESCE(?, price_cents),
        category      = COALESCE(?, category),
        is_active     = COALESCE(?, is_active)
      WHERE id = ? AND business_id = ?`,
      [name, description, duration_mins, price_cents, category, is_active,
       req.params.serviceId, req.params.bizId]
    );
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ── BOOKINGS ─────────────────────────────────────────────────

// GET /api/business/:bizId/bookings
router.get('/:bizId/bookings', async (req, res) => {
  try {
    let query = `
      SELECT
        bk.*,
        u.full_name  AS user_name,
        u.phone      AS user_phone,
        s.full_name  AS staff_name,
        sv.name      AS service_name,
        sv.price_cents
      FROM bookings bk
      LEFT JOIN users    u  ON u.id  = bk.user_id
      LEFT JOIN staff    s  ON s.id  = bk.staff_id
      LEFT JOIN services sv ON sv.id = bk.service_id
      WHERE bk.business_id = ?
    `;
    const params = [req.params.bizId];

    if (req.query.date) {
      query += ' AND DATE(bk.starts_at) = ?';
      params.push(req.query.date);
    }
    if (req.query.status) {
      query += ' AND bk.status = ?';
      params.push(req.query.status);
    }

    query += ' ORDER BY bk.starts_at ASC';

    const [rows] = await db.query(query, params);
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// PATCH /api/business/:bizId/bookings/:bookingId/status
router.patch('/:bizId/bookings/:bookingId/status', authenticate, async (req, res) => {
  const { status } = req.body;
  const valid = ['pending','confirmed','in_progress','completed','cancelled','no_show'];
  if (!valid.includes(status)) {
    return res.status(400).json({ error: `status must be one of: ${valid.join(', ')}` });
  }
  try {
    await db.query(
      'UPDATE bookings SET status = ? WHERE id = ? AND business_id = ?',
      [status, req.params.bookingId, req.params.bizId]
    );
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ── USERS ─────────────────────────────────────────────────────

// GET /api/business/:bizId/users
router.get('/:bizId/users', async (req, res) => {
  try {
    const [rows] = await db.query(
      'SELECT id, full_name, email, phone, loyalty_points, created_at FROM users WHERE business_id = ? ORDER BY full_name',
      [req.params.bizId]
    );
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ── DASHBOARD STATS ───────────────────────────────────────────

// GET /api/business/:bizId/stats
router.get('/:bizId/stats', async (req, res) => {
  try {
    const [[bookings]] = await db.query(
      'SELECT COUNT(*) AS total FROM bookings WHERE business_id = ?',
      [req.params.bizId]
    );
    const [[today]] = await db.query(
      'SELECT COUNT(*) AS total FROM bookings WHERE business_id = ? AND DATE(starts_at) = CURDATE()',
      [req.params.bizId]
    );
    const [[revenue]] = await db.query(
      "SELECT COALESCE(SUM(amount_cents), 0) AS total FROM payments WHERE business_id = ? AND status = 'paid'",
      [req.params.bizId]
    );
    const [[users]] = await db.query(
      'SELECT COUNT(*) AS total FROM users WHERE business_id = ?',
      [req.params.bizId]
    );

    return res.json({
      total_bookings:  bookings.total,
      todays_bookings: today.total,
      total_revenue_cents: revenue.total,
      total_users:     users.total,
    });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// ANALYTICS — revenue, expenses, trial conversions
// GET /api/business/:bizId/analytics?year=2026&month=9
// ============================================================
router.get('/:bizId/analytics', authenticate, async (req, res) => {
  // Allow master admin or the business's own admin
  if (req.user.role !== 'master_admin' && req.user.businessId !== req.params.bizId) {
    return res.status(403).json({ error: 'Access denied' });
  }
  const bizId = req.params.bizId;
  const now   = new Date();

  let start, end, prevStart, prevEnd;
  let year  = parseInt(req.query.year  || now.getFullYear(), 10);
  let month = parseInt(req.query.month || now.getMonth() + 1, 10);
  let prevYear  = month === 1 ? year - 1 : year;
  let prevMonth = month === 1 ? 12 : month - 1;

  if (req.query.from_date && req.query.to_date) {
    // Custom date range
    start = req.query.from_date;
    end   = req.query.to_date;
    const sd = new Date(start);
    year = sd.getFullYear(); month = sd.getMonth() + 1;
    prevYear = month === 1 ? year - 1 : year;
    prevMonth = month === 1 ? 12 : month - 1;
    const ms = new Date(end) - new Date(start) + 86400000;
    const prevEndDate = new Date(new Date(start) - 86400000);
    const prevStartDate = new Date(prevEndDate - ms + 86400000);
    const fmt = d => d.toISOString().slice(0, 10);
    prevStart = fmt(prevStartDate);
    prevEnd   = fmt(prevEndDate);
  } else {
    // Month/year mode
    start = `${year}-${String(month).padStart(2,'0')}-01`;
    const endDay = new Date(year, month, 0).getDate();
    end   = `${year}-${String(month).padStart(2,'0')}-${String(endDay).padStart(2,'0')}`;
    prevStart = `${prevYear}-${String(prevMonth).padStart(2,'0')}-01`;
    const prevEndDay = new Date(prevYear, prevMonth, 0).getDate();
    prevEnd   = `${prevYear}-${String(prevMonth).padStart(2,'0')}-${String(prevEndDay).padStart(2,'0')}`;
  }

  const range = (s, e) => [`${s} 00:00:00`, `${e} 23:59:59`];

  try {
    // Revenue (paid payments — use payment_date for month bucketing)
    const [[rev]] = await db.query(
      `SELECT COALESCE(SUM(COALESCE(paid_amount_cents, amount_cents)),0) AS total FROM payments
       WHERE business_id=? AND status='paid' AND DATE(COALESCE(payment_date, created_at)) BETWEEN ? AND ?`,
      [bizId, start, end]);
    const [[revPrev]] = await db.query(
      `SELECT COALESCE(SUM(COALESCE(paid_amount_cents, amount_cents)),0) AS total FROM payments
       WHERE business_id=? AND status='paid' AND DATE(COALESCE(payment_date, created_at)) BETWEEN ? AND ?`,
      [bizId, prevStart, prevEnd]);

    // Expenses (from business_expenses table)
    const [[exp]] = await db.query(
      `SELECT COALESCE(SUM(amount_cents),0) AS total FROM business_expenses
       WHERE business_id=? AND year=? AND month=?`,
      [bizId, year, month]);
    const [[expPrev]] = await db.query(
      `SELECT COALESCE(SUM(amount_cents),0) AS total FROM business_expenses
       WHERE business_id=? AND year=? AND month=?`,
      [bizId, prevYear, prevMonth]);

    // Expenses by category
    const [expByCategory] = await db.query(
      `SELECT category, COALESCE(SUM(amount_cents),0) AS total
       FROM business_expenses WHERE business_id=? AND year=? AND month=?
       GROUP BY category ORDER BY total DESC`,
      [bizId, year, month]);

    // Trial bookings
    const [[trials]] = await db.query(
      `SELECT COUNT(*) AS total FROM bookings
       WHERE business_id=? AND is_trial=1 AND starts_at BETWEEN ? AND ?`,
      [bizId, ...range(start, end)]);
    const [[trialsPrev]] = await db.query(
      `SELECT COUNT(*) AS total FROM bookings
       WHERE business_id=? AND is_trial=1 AND starts_at BETWEEN ? AND ?`,
      [bizId, ...range(prevStart, prevEnd)]);

    // Trial conversions (had a trial then got a membership/payment afterwards)
    const [[conversions]] = await db.query(
      `SELECT COUNT(DISTINCT b.user_id) AS total
       FROM bookings b
       JOIN user_memberships m ON m.user_id = b.user_id AND m.business_id = b.business_id
       WHERE b.business_id=? AND b.is_trial=1
         AND b.starts_at BETWEEN ? AND ?
         AND m.valid_from >= b.starts_at`,
      [bizId, ...range(start, end)]);

    // Revenue by service — count completed bookings per service
    const [revByService] = await db.query(
      `SELECT sv.name AS service_name, COUNT(*) AS bookings_count,
              COALESCE(SUM(p.paid_amount_cents), SUM(p.amount_cents), 0) AS revenue_cents
       FROM bookings b
       JOIN services sv ON sv.id = b.service_id
       LEFT JOIN payments p ON p.user_id = b.user_id AND p.business_id = b.business_id
         AND p.status = 'paid'
         AND DATE(p.created_at) BETWEEN ? AND ?
       WHERE b.business_id=? AND b.starts_at BETWEEN ? AND ?
         AND b.status IN ('completed','confirmed')
       GROUP BY b.service_id, sv.name
       ORDER BY bookings_count DESC
       LIMIT 10`,
      [start, end, bizId, ...range(start, end)]);

    // New members this month (users registered to this business)
    const [[newMembers]] = await db.query(
      `SELECT COUNT(*) AS total FROM users
       WHERE business_id=? AND created_at BETWEEN ? AND ?`,
      [bizId, ...range(start, end)]);
    const [[newMembersPrev]] = await db.query(
      `SELECT COUNT(*) AS total FROM users
       WHERE business_id=? AND created_at BETWEEN ? AND ?`,
      [bizId, ...range(prevStart, prevEnd)]);

    // Total completed bookings
    const [[completed]] = await db.query(
      `SELECT COUNT(*) AS total FROM bookings
       WHERE business_id=? AND status='completed' AND starts_at BETWEEN ? AND ?`,
      [bizId, ...range(start, end)]);
    const [[completedPrev]] = await db.query(
      `SELECT COUNT(*) AS total FROM bookings
       WHERE business_id=? AND status='completed' AND starts_at BETWEEN ? AND ?`,
      [bizId, ...range(prevStart, prevEnd)]);

    const c2e = (cents) => Math.round((cents || 0) / 100); // cents → euros
    return res.json({
      period: { year, month, start, end },
      revenue:     { current: c2e(rev.total),                    previous: c2e(revPrev.total) },
      expenses:    { current: c2e(exp.total),                    previous: c2e(expPrev.total) },
      profit:      { current: c2e(rev.total - exp.total),        previous: c2e(revPrev.total - expPrev.total) },
      trials:      trials.total,
      conversions: conversions.total,
      conversion_rate: trials.total > 0 ? Math.round((conversions.total / trials.total) * 100) : 0,
      completed:   { current: completed.total,  previous: completedPrev.total },
      new_members: { current: newMembers.total, previous: newMembersPrev.total },
      revenue_by_service: revByService.map(r => ({ service_name: r.service_name, revenue: c2e(r.revenue_cents), bookings: r.bookings_count })),
      expenses_by_category: expByCategory.map(r => ({ category: r.category, total: c2e(r.total) })),
    });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// AT-RISK MEMBERS
// ============================================================

// GET /api/business/:bizId/at-risk?days=14
router.get('/:bizId/at-risk', authenticate, async (req, res) => {
  const days = parseInt(req.query.days, 10) || 14;
  const conn = await db.getConnection();
  try {
    const members = await getAtRiskMembers(conn, req.params.bizId, days);
    return res.json({ members, days });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// POST /api/business/:bizId/at-risk/message
// Body: { user_ids: [...], template?: '...' }
router.post('/:bizId/at-risk/message', authenticate, async (req, res) => {
  const { user_ids, template } = req.body;
  if (!user_ids?.length) return res.status(400).json({ error: 'Απαιτείται user_ids' });

  const conn = await db.getConnection();
  try {
    // Use provided template or fall back to stored one
    let tmpl = template;
    if (!tmpl) {
      const [[cfg]] = await conn.query(
        'SELECT at_risk_template FROM business_configs WHERE business_id = ?',
        [req.params.bizId],
      );
      tmpl = cfg?.at_risk_template;
    }
    if (!tmpl) return res.status(400).json({ error: 'Δεν υπάρχει template μηνύματος' });

    const result = await sendAtRiskMessages(conn, req.params.bizId, user_ids, tmpl);
    return res.json(result);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// GET /api/business/:bizId/at-risk/config
router.get('/:bizId/at-risk/config', authenticate, async (req, res) => {
  try {
    const [[row]] = await db.query(
      'SELECT at_risk_days, at_risk_template FROM business_configs WHERE business_id = ?',
      [req.params.bizId],
    );
    return res.json(row || { at_risk_days: 14, at_risk_template: '' });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// PATCH /api/business/:bizId/at-risk/config
// Body: { at_risk_days?, at_risk_template? }
router.patch('/:bizId/at-risk/config', authenticate, async (req, res) => {
  const { at_risk_days, at_risk_template } = req.body;
  const updates = {};
  if (at_risk_days !== undefined)    updates.at_risk_days    = parseInt(at_risk_days, 10);
  if (at_risk_template !== undefined) updates.at_risk_template = at_risk_template;
  if (!Object.keys(updates).length) return res.status(400).json({ error: 'Τίποτα να ενημερωθεί' });

  try {
    const sets = Object.keys(updates).map(k => `${k} = ?`).join(', ');
    await db.query(
      `UPDATE business_configs SET ${sets} WHERE business_id = ?`,
      [...Object.values(updates), req.params.bizId],
    );
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// MONTHLY VALUE REPORT
// ============================================================

// GET /api/business/:bizId/report/monthly?year=2026&month=8
router.get('/:bizId/report/monthly', authenticate, async (req, res) => {
  const now   = new Date();
  const year  = parseInt(req.query.year,  10) || now.getFullYear();
  const month = parseInt(req.query.month, 10) || now.getMonth() || 12; // default = prev month

  const conn = await db.getConnection();
  try {
    // Try stored report first (table may not exist on older deployments)
    let stored = null;
    try {
      const [[row]] = await conn.query(`
        SELECT data FROM monthly_reports
        WHERE business_id = ? AND report_month = ?
      `, [req.params.bizId, `${year}-${String(month).padStart(2,'0')}-01`]);
      stored = row;
    } catch { /* monthly_reports table missing — skip */ }

    if (stored) {
      try { return res.json(JSON.parse(stored.data)); } catch { /* bad JSON, recompute */ }
    }

    // Generate on-the-fly
    const data = await computeMonthData(conn, req.params.bizId, year, month);
    return res.json(data);
  } catch (err) {
    console.error('[monthly report]', err);
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// POST /api/business/:bizId/report/monthly/generate — manual trigger
router.post('/:bizId/report/monthly/generate', authenticate, async (req, res) => {
  const now   = new Date();
  const year  = parseInt(req.body.year,  10) || now.getFullYear();
  const month = parseInt(req.body.month, 10) || (now.getMonth() || 12);

  const conn = await db.getConnection();
  try {
    const data = await generateMonthlyReport(conn, req.params.bizId, year, month);
    return res.json(data);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// ============================================================
// WAITLIST CONFIG (admin)
// ============================================================

// GET /api/business/:bizId/waitlist-config
router.get('/:bizId/waitlist-config', authenticate, async (req, res) => {
  const conn = await db.getConnection();
  try {
    const cfg = await getWaitlistConfig(conn, req.params.bizId);
    return res.json(cfg);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// PATCH /api/business/:bizId/waitlist-config
router.patch('/:bizId/waitlist-config', authenticate, async (req, res) => {
  const allowed = ['waitlist_mode', 'waitlist_offer_minutes', 'waitlist_cutoff_hours', 'waitlist_sms'];
  const updates = {};
  for (const key of allowed) {
    if (req.body[key] !== undefined) updates[key] = req.body[key];
  }
  if (!Object.keys(updates).length) return res.status(400).json({ error: 'Τίποτα να ενημερωθεί' });

  try {
    const sets = Object.keys(updates).map(k => `${k} = ?`).join(', ');
    await db.query(
      `UPDATE business_configs SET ${sets} WHERE business_id = ?`,
      [...Object.values(updates), req.params.bizId],
    );
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// TRAINER FEES
// ============================================================

// GET /api/business/:bizId/trainer-fees
router.get('/:bizId/trainer-fees', authenticate, async (req, res) => {
  const conn = await db.getConnection();
  try {
    const [rows] = await conn.query(`
      SELECT s.id AS staff_id, s.full_name,
             tf.monthly_gross, tf.monthly_net,
             tf.fee_per_class,
             tf.notes
      FROM staff s
      LEFT JOIN trainer_fees tf ON tf.staff_id = s.id AND tf.business_id = ?
      WHERE s.business_id = ? AND s.is_active = 1
      ORDER BY s.full_name
    `, [req.params.bizId, req.params.bizId]);
    return res.json({ fees: rows });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// PUT /api/business/:bizId/trainer-fees/:staffId
router.put('/:bizId/trainer-fees/:staffId', authenticate, async (req, res) => {
  const { monthly_gross, monthly_net, fee_per_class, notes } = req.body;
  try {
    await db.query(`
      INSERT INTO trainer_fees (id, business_id, staff_id, monthly_gross, monthly_net, fee_per_class, notes)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        monthly_gross = VALUES(monthly_gross),
        monthly_net   = VALUES(monthly_net),
        fee_per_class = VALUES(fee_per_class),
        notes         = VALUES(notes)
    `, [
      uuidv4(), req.params.bizId, req.params.staffId,
      monthly_gross ?? null, monthly_net ?? null, fee_per_class ?? null, notes ?? null,
    ]);
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// GET /api/business/:bizId/trainer-fees/report?year=2026&month=8
router.get('/:bizId/trainer-fees/report', authenticate, async (req, res) => {
  const now   = new Date();
  const year  = parseInt(req.query.year,  10) || now.getFullYear();
  const month = parseInt(req.query.month, 10) || (now.getMonth() + 1);
  const start = `${year}-${String(month).padStart(2,'0')}-01`;
  const end   = new Date(year, month, 0).toISOString().slice(0, 10);

  const conn = await db.getConnection();
  try {
    const [rows] = await conn.query(`
      SELECT
        s.id AS staff_id,
        s.full_name AS staff_name,
        tf.fee_per_class,
        tf.fee_per_head,
        COUNT(DISTINCT b.id) AS classes_taught,
        SUM(participant_counts.cnt) AS total_participants,
        ROUND(
          COALESCE(tf.fee_per_class, 0) * COUNT(DISTINCT b.id)
          + COALESCE(tf.fee_per_head, 0) * COALESCE(SUM(participant_counts.cnt), 0)
        , 2) AS total_fee
      FROM staff s
      JOIN trainer_fees tf ON tf.staff_id = s.id AND tf.business_id = ?
      LEFT JOIN bookings b
        ON b.staff_id = s.id AND b.business_id = ?
        AND b.starts_at BETWEEN ? AND ?
        AND b.status IN ('confirmed','completed','attended')
      LEFT JOIN (
        SELECT staff_id, DATE(starts_at) AS day, TIME(starts_at) AS t,
               COUNT(*) AS cnt
        FROM bookings
        WHERE business_id = ? AND starts_at BETWEEN ? AND ?
          AND status IN ('confirmed','completed','attended')
        GROUP BY staff_id, day, t
      ) participant_counts
        ON participant_counts.staff_id = s.id
      WHERE s.business_id = ?
      GROUP BY s.id, s.full_name, tf.fee_per_class, tf.fee_per_head
      ORDER BY s.full_name
    `, [
      req.params.bizId, req.params.bizId,
      start, end + ' 23:59:59',
      req.params.bizId, start, end + ' 23:59:59',
      req.params.bizId,
    ]);

    return res.json({ year, month, fees: rows });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// ============================================================
// STAFF SALARY PAYMENTS (payroll tracking)
// ============================================================

// GET /api/business/:bizId/salary-payments?year=2026&month=9
// Returns all staff with their salary config + whether paid this month
router.get('/:bizId/salary-payments', authenticate, async (req, res) => {
  const now   = new Date();
  const year  = parseInt(req.query.year,  10) || now.getFullYear();
  const month = parseInt(req.query.month, 10) || (now.getMonth() + 1);
  try {
    const [rows] = await db.query(`
      SELECT
        s.id AS staff_id, s.full_name,
        tf.monthly_gross, tf.monthly_net, tf.fee_per_class, tf.notes AS fee_notes,
        p.id AS payment_id, p.amount_cents AS paid_amount_cents, p.paid_at, p.notes AS payment_notes
      FROM staff s
      LEFT JOIN trainer_fees tf ON tf.staff_id = s.id AND tf.business_id = ?
      LEFT JOIN staff_salary_payments p
        ON p.staff_id = s.id AND p.business_id = ? AND p.year = ? AND p.month = ?
      WHERE s.business_id = ? AND s.is_active = 1
      ORDER BY s.full_name
    `, [req.params.bizId, req.params.bizId, year, month, req.params.bizId]);
    return res.json({ year, month, staff: rows });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/business/:bizId/salary-payments — mark as paid
router.post('/:bizId/salary-payments', authenticate, async (req, res) => {
  const { staff_id, year, month, amount_cents, notes } = req.body;
  if (!staff_id || !year || !month || amount_cents == null)
    return res.status(400).json({ error: 'staff_id, year, month, amount_cents required' });
  const id = uuidv4();
  try {
    await db.query(`
      INSERT INTO staff_salary_payments (id, business_id, staff_id, year, month, amount_cents, notes)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE amount_cents = VALUES(amount_cents), notes = VALUES(notes), paid_at = NOW()
    `, [id, req.params.bizId, staff_id, year, month, amount_cents, notes || null]);
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// DELETE /api/business/:bizId/salary-payments/:paymentId — undo payment
router.delete('/:bizId/salary-payments/:paymentId', authenticate, async (req, res) => {
  try {
    await db.query(`DELETE FROM staff_salary_payments WHERE id = ? AND business_id = ?`,
      [req.params.paymentId, req.params.bizId]);
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// GET /api/business/:bizId/salary-payments/summary?year=2026
// Annual overview: paid vs outstanding per month
router.get('/:bizId/salary-payments/summary', authenticate, async (req, res) => {
  const now  = new Date();
  const year = parseInt(req.query.year, 10) || now.getFullYear();
  try {
    const [paid] = await db.query(`
      SELECT month, SUM(amount_cents) AS paid_cents, COUNT(*) AS staff_count
      FROM staff_salary_payments
      WHERE business_id = ? AND year = ?
      GROUP BY month
    `, [req.params.bizId, year]);

    const [owed] = await db.query(`
      SELECT COALESCE(SUM(monthly_net), 0) AS total_net_cents
      FROM trainer_fees
      WHERE business_id = ?
    `, [req.params.bizId]);

    return res.json({ year, paid, monthly_total_owed_cents: owed[0]?.total_net_cents || 0 });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// RECURRING EXPENSES (παγια)
// ============================================================

// GET /api/business/:bizId/recurring-expenses
router.get('/:bizId/recurring-expenses', authenticate, async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT * FROM business_recurring_expenses WHERE business_id = ? ORDER BY due_day, category`,
      [req.params.bizId]
    );
    return res.json({ recurring: rows });
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

// POST /api/business/:bizId/recurring-expenses
router.post('/:bizId/recurring-expenses', authenticate, async (req, res) => {
  const { category, description, amount_cents, due_day, notes } = req.body;
  if (!description || !amount_cents) return res.status(400).json({ error: 'description and amount_cents required' });
  const id = uuidv4();
  try {
    await db.query(
      `INSERT INTO business_recurring_expenses (id, business_id, category, description, amount_cents, due_day, notes)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [id, req.params.bizId, category || 'Άλλο', description, amount_cents, due_day || 1, notes || null]
    );
    return res.status(201).json({ id });
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

// PUT /api/business/:bizId/recurring-expenses/:expId
router.put('/:bizId/recurring-expenses/:expId', authenticate, async (req, res) => {
  const { category, description, amount_cents, due_day, is_active, notes } = req.body;
  try {
    await db.query(
      `UPDATE business_recurring_expenses SET category=?, description=?, amount_cents=?, due_day=?, is_active=?, notes=?
       WHERE id=? AND business_id=?`,
      [category, description, amount_cents, due_day, is_active ? 1 : 0, notes || null, req.params.expId, req.params.bizId]
    );
    return res.json({ ok: true });
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

// DELETE /api/business/:bizId/recurring-expenses/:expId
router.delete('/:bizId/recurring-expenses/:expId', authenticate, async (req, res) => {
  try {
    await db.query(`DELETE FROM business_recurring_expenses WHERE id=? AND business_id=?`,
      [req.params.expId, req.params.bizId]);
    return res.json({ ok: true });
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

// GET /api/business/:bizId/recurring-expenses/month?year=2026&month=9
router.get('/:bizId/recurring-expenses/month', authenticate, async (req, res) => {
  const now   = new Date();
  const year  = parseInt(req.query.year,  10) || now.getFullYear();
  const month = parseInt(req.query.month, 10) || (now.getMonth() + 1);
  try {
    const [rows] = await db.query(`
      SELECT r.*, p.id AS payment_id, p.paid_at, p.notes AS payment_notes
      FROM business_recurring_expenses r
      LEFT JOIN business_recurring_payments p
        ON p.recurring_expense_id = r.id AND p.year = ? AND p.month = ?
      WHERE r.business_id = ? AND r.is_active = 1
      ORDER BY r.due_day, r.category
    `, [year, month, req.params.bizId]);
    return res.json({ year, month, items: rows });
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

// POST /api/business/:bizId/recurring-expenses/:expId/pay
router.post('/:bizId/recurring-expenses/:expId/pay', authenticate, async (req, res) => {
  const { year, month, notes } = req.body;
  const id = uuidv4();
  try {
    await db.query(`
      INSERT INTO business_recurring_payments (id, business_id, recurring_expense_id, year, month, paid_at, notes)
      VALUES (?, ?, ?, ?, ?, NOW(), ?)
      ON DUPLICATE KEY UPDATE paid_at = NOW(), notes = VALUES(notes)
    `, [id, req.params.bizId, req.params.expId, year, month, notes || null]);
    return res.json({ ok: true });
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

// DELETE /api/business/:bizId/recurring-expenses/:expId/pay?year=2026&month=9
router.delete('/:bizId/recurring-expenses/:expId/pay', authenticate, async (req, res) => {
  const { year, month } = req.query;
  try {
    await db.query(`DELETE FROM business_recurring_payments WHERE recurring_expense_id=? AND business_id=? AND year=? AND month=?`,
      [req.params.expId, req.params.bizId, year, month]);
    return res.json({ ok: true });
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

// ============================================================
// BUSINESS EXPENSES (one-time, manual)
// ============================================================

// GET /api/business/:bizId/expenses?year=2026&month=9
router.get('/:bizId/expenses', authenticate, async (req, res) => {
  const now   = new Date();
  const year  = parseInt(req.query.year,  10) || now.getFullYear();
  const month = parseInt(req.query.month, 10) || (now.getMonth() + 1);
  try {
    const [rows] = await db.query(
      `SELECT * FROM business_expenses WHERE business_id = ? AND year = ? AND month = ? ORDER BY category, description`,
      [req.params.bizId, year, month]
    );
    return res.json({ year, month, expenses: rows });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/business/:bizId/expenses
router.post('/:bizId/expenses', authenticate, async (req, res) => {
  const { year, month, category, description, amount_cents } = req.body;
  if (!description || !amount_cents) return res.status(400).json({ error: 'description and amount_cents required' });
  const id = uuidv4();
  try {
    await db.query(
      `INSERT INTO business_expenses (id, business_id, year, month, category, description, amount_cents)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [id, req.params.bizId, year, month, category || 'Άλλο', description, amount_cents]
    );
    return res.status(201).json({ id });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// PUT /api/business/:bizId/expenses/:expId
router.put('/:bizId/expenses/:expId', authenticate, async (req, res) => {
  const { category, description, amount_cents } = req.body;
  try {
    await db.query(
      `UPDATE business_expenses SET category=?, description=?, amount_cents=? WHERE id=? AND business_id=?`,
      [category, description, amount_cents, req.params.expId, req.params.bizId]
    );
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// DELETE /api/business/:bizId/expenses/:expId
router.delete('/:bizId/expenses/:expId', authenticate, async (req, res) => {
  try {
    await db.query(`DELETE FROM business_expenses WHERE id=? AND business_id=?`, [req.params.expId, req.params.bizId]);
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

module.exports = router;
