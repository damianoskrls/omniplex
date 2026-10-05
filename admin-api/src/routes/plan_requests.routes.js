const express = require('express');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const db = require('../db');
const { loadPlanForBusiness, grantPlanMembership } = require('../lib/member_plan_purchase');
const { createOneBooking } = require('../lib/create_booking');
const { createUserNotification } = require('../lib/user_notifications');

const router = express.Router();

function requireAdmin(req, res, next) {
  try {
    const payload = jwt.verify((req.headers.authorization || '').replace('Bearer ', ''), process.env.JWT_SECRET);
    if (payload.role !== 'client_admin' && payload.role !== 'owner' && payload.role !== 'admin') {
      return res.status(403).json({ error: 'Forbidden' });
    }
    req.bizId = payload.businessId;
    if (payload.locationId) req.query.location_id = payload.locationId;
    next();
  } catch {
    return res.status(401).json({ error: 'Unauthorized' });
  }
}

router.get('/', requireAdmin, async (req, res) => {
  try {
    const params = [req.bizId];
    let locationSql = '';
    if (req.query.location_id) {
      locationSql = ' AND r.location_id = ?';
      params.push(req.query.location_id);
    }
    const [rows] = await db.query(
      `SELECT r.id, r.kind, r.status, r.created_at, r.resolved_at, r.user_id, r.plan_id, r.service_id,
              r.trial_date, r.trial_time, r.location_id,
              u.full_name, u.phone, bp.name AS plan_name, bp.price_cents, s.name AS service_name,
              loc.name AS location_name
       FROM plan_purchase_requests r
       JOIN users u ON u.id = (r.user_id COLLATE utf8mb4_unicode_ci)
       JOIN business_plans bp ON bp.id = (r.plan_id COLLATE utf8mb4_unicode_ci)
       LEFT JOIN services s ON s.id = (r.service_id COLLATE utf8mb4_unicode_ci)
       LEFT JOIN locations loc ON loc.id = (r.location_id COLLATE utf8mb4_unicode_ci)
       WHERE r.business_id = ?${locationSql}
       ORDER BY (r.status COLLATE utf8mb4_unicode_ci) = (_utf8mb4'pending' COLLATE utf8mb4_unicode_ci) DESC, r.created_at DESC
       LIMIT 100`,
      params,
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/:id/reject', requireAdmin, async (req, res) => {
  try {
    const [[row]] = await db.query(
      `SELECT r.*, bp.name AS plan_name FROM plan_purchase_requests r
       JOIN business_plans bp ON bp.id = (r.plan_id COLLATE utf8mb4_unicode_ci)
       WHERE r.id = ? AND r.business_id = ? AND (r.status COLLATE utf8mb4_unicode_ci) = (_utf8mb4'pending' COLLATE utf8mb4_unicode_ci)`,
      [req.params.id, req.bizId],
    );
    if (!row) return res.status(404).json({ error: 'Το αίτημα δεν βρέθηκε' });
    await db.query(
      `UPDATE plan_purchase_requests SET status = 'rejected', resolved_at = NOW() WHERE id = ?`,
      [row.id],
    );
    await createUserNotification(db, {
      businessId: req.bizId,
      userId: row.user_id,
      type: 'plan_request',
      title: 'Το αίτημα δεν έγινε δεκτό',
      body: `Το γυμναστήριο δεν αποδέχτηκε το αίτημα για ${row.plan_name}.`,
      payload: { request_id: row.id },
    }).catch(() => {});
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/:id/accept', requireAdmin, async (req, res) => {
  const conn = await db.getConnection();
  try {
    const [[row]] = await conn.query(
      `SELECT * FROM plan_purchase_requests WHERE id = ? AND business_id = ? AND (status COLLATE utf8mb4_unicode_ci) = (_utf8mb4'pending' COLLATE utf8mb4_unicode_ci)`,
      [req.params.id, req.bizId],
    );
    if (!row) return res.status(404).json({ error: 'Το αίτημα δεν βρέθηκε' });
    const plan = await loadPlanForBusiness(conn, req.bizId, row.plan_id);
    if (!plan) return res.status(404).json({ error: 'Το πακέτο δεν βρέθηκε' });

    await conn.beginTransaction();
    let locationId = req.body?.location_id || row.location_id || null;
    if (locationId) {
      const [[loc]] = await conn.query(
        'SELECT id FROM locations WHERE id = ? AND business_id = ? AND is_active = 1',
        [locationId, req.bizId],
      );
      if (!loc) {
        await conn.rollback();
        return res.status(400).json({ error: 'Το κατάστημα δεν βρέθηκε' });
      }
      locationId = loc.id;
    } else if (row.kind === 'trial') {
      const [stores] = await conn.query(
        'SELECT id FROM locations WHERE business_id = ? AND is_active = 1',
        [req.bizId],
      );
      if (stores.length > 1) {
        await conn.rollback();
        return res.status(400).json({ error: 'Διάλεξε κατάστημα' });
      }
      locationId = stores[0]?.id || null;
    }

    if (row.kind === 'trial') {
      const trial_date = req.body?.trial_date || row.trial_date;
      const trial_time = req.body?.trial_time || row.trial_time;
      if (!trial_date || !trial_time) {
        await conn.rollback();
        return res.status(400).json({ error: 'Βάλε ημερομηνία και ώρα δοκιμαστικού' });
      }
      const serviceId = row.service_id || plan.service_ids?.[0] || null;
      const booking = await createOneBooking(conn, {
        bizId: req.bizId,
        userId: row.user_id,
        service_id: serviceId,
        date: trial_date,
        time: trial_time,
        location_id: locationId,
        use_credit: false,
        is_trial: true,
        source: 'admin',
      });
      const [[svc]] = serviceId
        ? await conn.query('SELECT name, category FROM services WHERE id = ?', [serviceId])
        : [[]];
      await conn.query(
        `INSERT INTO user_memberships
          (id, user_id, business_id, plan_id, service_id, service_category,
           total_sessions, used_sessions, valid_from, valid_until, notes,
           membership_status, trial_booking_id)
         VALUES (?, ?, ?, ?, ?, ?, 0, 0, ?, ?, ?, 'trial', ?)`,
        [
          uuidv4(), row.user_id, req.bizId, plan.id, serviceId, svc?.category || null,
          trial_date, trial_date,
          `Δοκιμαστικό${svc?.name ? ` — ${svc.name}` : ''} (${trial_date} ${trial_time})`,
          booking.id,
        ],
      );
      await createUserNotification(conn, {
        businessId: req.bizId,
        userId: row.user_id,
        type: 'plan_request',
        title: 'Το δοκιμαστικό έγινε δεκτό',
        body: `${plan.name} · ${trial_date} ${trial_time}`,
        payload: { request_id: row.id },
      }).catch(() => {});
    } else {
      await grantPlanMembership(conn, {
        bizId: req.bizId,
        userId: row.user_id,
        plan,
        paid: false,
        locationId: row.location_id || null,
      });
      await createUserNotification(conn, {
        businessId: req.bizId,
        userId: row.user_id,
        type: 'plan_request',
        title: 'Το πακέτο εγκρίθηκε',
        body: `${plan.name} προστέθηκε. Η πληρωμή εκκρεμεί στο γυμναστήριο.`,
        payload: { request_id: row.id },
      }).catch(() => {});
    }
    await conn.query(
      `UPDATE plan_purchase_requests SET status = 'accepted', resolved_at = NOW(), location_id = COALESCE(?, location_id) WHERE id = ?`,
      [locationId, row.id],
    );
    await conn.commit();
    res.json({
      ok: true,
      message: row.kind === 'trial'
        ? 'Το δοκιμαστικό προγραμματίστηκε'
        : 'Το πακέτο προστέθηκε. Η πληρωμή μένει εκκρεμής στην καρτέλα του πελάτη.',
    });
  } catch (err) {
    try { await conn.rollback(); } catch (_) {}
    res.status(err.status || 400).json({ error: err.message });
  } finally {
    conn.release();
  }
});

module.exports = router;
