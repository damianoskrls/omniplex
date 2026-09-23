// ============================================================
// FILE: src/routes/tenant.routes.js
// All Master Admin tenant management endpoints
// ============================================================

const express  = require('express');
const multer   = require('multer');
const path     = require('path');
const fs       = require('fs');
const bcrypt   = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const db       = require('../db');
const { authenticate, requireMasterAdmin } = require('../middleware/auth');

const router = express.Router();

const { r2Multer } = require('../lib/r2_upload');

const ALLOWED_IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml'];

const uploadLogo = r2Multer({
  keyFn: (req, file) => {
    const extMap = { 'image/png': '.png', 'image/jpeg': '.jpg', 'image/webp': '.webp', 'image/svg+xml': '.svg' };
    const ext = extMap[file.mimetype] || '.png';
    return `uploads/${req.params.id}/logo/logo${ext}`;
  },
  allowedMimes: ALLOWED_IMAGE_TYPES,
  maxSizeMb: 5,
});

const uploadIcon = r2Multer({
  keyFn: (req, file) => {
    const extMap = { 'image/png': '.png', 'image/jpeg': '.jpg', 'image/webp': '.webp', 'image/svg+xml': '.svg' };
    const ext = extMap[file.mimetype] || '.png';
    return `uploads/${req.params.id}/logo/icon${ext}`;
  },
  allowedMimes: ALLOWED_IMAGE_TYPES,
  maxSizeMb: 2,
});

const upload = uploadLogo;

// ── Helper: default labels per business type ─────────────────
function getDefaultLabels(type) {
  const map = {
    gym: {
      book_cta: 'Book a Class', staff_noun: 'Trainer',
      service_noun: 'Class', appointment_noun: 'Session',
      home_hero: 'Train harder. Live better.', loyalty_label: 'Fitness Points',
    },
    barbershop: {
      book_cta: 'Book a Barber', staff_noun: 'Barber',
      service_noun: 'Cut', appointment_noun: 'Appointment',
      home_hero: 'Look sharp. Feel sharp.', loyalty_label: 'Loyalty Points',
    },
    salon: {
      book_cta: 'Book a Stylist', staff_noun: 'Stylist',
      service_noun: 'Treatment', appointment_noun: 'Appointment',
      home_hero: 'Beauty, redefined.', loyalty_label: 'Beauty Points',
    },
    spa: {
      book_cta: 'Book a Treatment', staff_noun: 'Therapist',
      service_noun: 'Treatment', appointment_noun: 'Reservation',
      home_hero: 'Your sanctuary awaits.', loyalty_label: 'Wellness Points',
    },
  };
  return JSON.stringify(map[type] || map.salon);
}

// ── Helper: default feature flags per plan ───────────────────
function getDefaultFlags(plan) {
  return {
    feature_online_booking:      1,
    feature_loyalty_points:      plan !== 'starter' ? 1 : 0,
    feature_memberships:         plan === 'enterprise' ? 1 : 0,
    feature_pos_integration:     plan === 'enterprise' ? 1 : 0,
    feature_multi_location:      plan === 'enterprise' ? 1 : 0,
    feature_waitlist:            plan !== 'starter' ? 1 : 0,
    feature_video_consultations: 0,
    feature_marketplace:         0,
    feature_online_payments:     0,
  };
}

// ============================================================
// GET /api/tenants — List all tenants
// ============================================================
router.get('/', authenticate, requireMasterAdmin, async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT
        b.id, b.slug, b.name, b.business_type, b.is_active, b.plan, b.created_at,
        c.app_name, c.primary_color, c.secondary_color, c.logo_url,
        c.feature_online_booking, c.feature_loyalty_points, c.feature_memberships
      FROM businesses b
      LEFT JOIN business_configs c ON c.business_id = b.id
      ORDER BY b.created_at DESC
    `);
    return res.json(rows);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
});

// ============================================================
// GET /api/tenants/search?q= — Public business search (no auth)
// ============================================================
router.get('/search', async (req, res) => {
  const q = (req.query.q || '').trim();
  if (q.length < 2) return res.json([]);
  try {
    const [rows] = await db.query(`
      SELECT b.slug, b.name, b.business_type,
             c.app_name, c.primary_color, c.logo_url
      FROM businesses b
      LEFT JOIN business_configs c ON c.business_id = b.id
      WHERE b.is_active = 1
        AND (b.name LIKE ? OR b.slug LIKE ? OR c.app_name LIKE ?)
      ORDER BY b.name ASC
      LIMIT 20
    `, [`%${q}%`, `%${q}%`, `%${q}%`]);
    return res.json(rows.map(r => ({
      slug:          r.slug,
      name:          r.name,
      app_name:      r.app_name || r.name,
      business_type: r.business_type,
      primary_color: r.primary_color || '#6200EE',
      logo_url:      r.logo_url || null,
    })));
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

// ============================================================
// GET /api/tenants/:id — Full config for one tenant
// ============================================================
router.get('/:id', authenticate, requireMasterAdmin, async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT b.*, c.*
      FROM businesses b
      LEFT JOIN business_configs c ON c.business_id = b.id
      WHERE b.id = ?
    `, [req.params.id]);

    if (!rows.length) return res.status(404).json({ error: 'Tenant not found' });

    const row = rows[0];
    // Parse label_overrides JSON string → object
    if (row.label_overrides && typeof row.label_overrides === 'string') {
      try { row.label_overrides = JSON.parse(row.label_overrides); } catch (_) {}
    }

    return res.json(row);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
});

// ============================================================
// GET /api/tenants/:id/build-config — Called by build script
// ============================================================
router.get('/:id/build-config', authenticate, async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT b.*, c.*
      FROM businesses b
      LEFT JOIN business_configs c ON c.business_id = b.id
      WHERE (b.id = ? OR b.slug = ?) AND b.is_active = 1
    `, [req.params.id, req.params.id]);

    if (!rows.length) return res.status(404).json({ error: 'Tenant not found or inactive' });

    const row = rows[0];
    if (row.label_overrides && typeof row.label_overrides === 'string') {
      try { row.label_overrides = JSON.parse(row.label_overrides); } catch (_) {}
    }

    return res.json(row);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
});

// ============================================================
// GET /api/tenants/public/:slug — Public config for Flutter
// No auth required — returns only safe public fields
// ============================================================
router.get('/public/:slug', async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT
        b.id AS business_id, b.slug, b.name, b.business_type, b.is_active,
        c.app_name, c.bundle_id, c.android_package,
        c.primary_color, c.secondary_color, c.accent_color,
        c.background_color, c.surface_color, c.font_family,
        c.logo_url, c.icon_url, c.label_overrides,
        c.feature_online_booking, c.feature_loyalty_points,
        c.feature_memberships, c.feature_nutrition,
        c.feature_waitlist, c.feature_marketplace,
        c.feature_online_payments
      FROM businesses b
      LEFT JOIN business_configs c ON c.business_id = b.id
      WHERE b.slug = ? AND b.is_active = 1
      LIMIT 1
    `, [req.params.slug]);

    if (!rows.length) return res.status(404).json({ error: 'Business not found' });

    const r = rows[0];
    if (r.label_overrides && typeof r.label_overrides === 'string') {
      try { r.label_overrides = JSON.parse(r.label_overrides); } catch (_) {}
    }

    return res.json({
      business_id:             r.business_id,
      slug:                    r.slug,
      app_name:                r.app_name || r.name,
      bundle_id:               r.bundle_id || `com.ergonhub.${r.slug}`,
      android_package:         r.android_package || `com.ergonhub.${r.slug}`,
      primary_color:           r.primary_color   || '#6200EE',
      secondary_color:         r.secondary_color || '#03DAC6',
      accent_color:            r.accent_color    || '#FF6D00',
      background_color:        r.background_color || '#0D0D0D',
      surface_color:           r.surface_color   || '#1A1A2E',
      font_family:             r.font_family     || 'Inter',
      logo_url:                r.logo_url        || null,
      icon_url:                r.icon_url        || null,
      business_type:           r.business_type,
      label_overrides:         r.label_overrides || {},
      feature_online_booking:  !!r.feature_online_booking,
      feature_loyalty_points:  !!r.feature_loyalty_points,
      feature_memberships:     !!r.feature_memberships,
      feature_nutrition:       !!r.feature_nutrition,
      feature_waitlist:        !!r.feature_waitlist,
      feature_marketplace:     !!r.feature_marketplace,
      feature_online_payments: !!r.feature_online_payments,
    });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// POST /api/tenants — Create new tenant
// ============================================================
router.post('/', authenticate, requireMasterAdmin, async (req, res) => {
  const {
    name, slug, business_type, owner_email, plan = 'starter',
    app_name, bundle_id,
    primary_color = '#6200EE', secondary_color = '#03DAC6',
    accent_color = '#FF6D00', admin_password,
  } = req.body;

  // Basic validation
  if (!name || !slug || !business_type || !owner_email || !app_name || !bundle_id) {
    return res.status(400).json({ error: 'Missing required fields: name, slug, business_type, owner_email, app_name, bundle_id' });
  }

  const bizId    = uuidv4();
  const configId = uuidv4();
  const flags    = getDefaultFlags(plan);
  const labels   = getDefaultLabels(business_type);

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    await conn.query(`
      INSERT INTO businesses (id, slug, name, business_type, owner_email, plan)
      VALUES (?, ?, ?, ?, ?, ?)
    `, [bizId, slug, name, business_type, owner_email, plan]);

    await conn.query(`
      INSERT INTO business_configs (
        id, business_id,
        primary_color, secondary_color, accent_color,
        app_name, bundle_id, android_package,
        label_overrides,
        feature_online_booking, feature_loyalty_points, feature_memberships,
        feature_pos_integration, feature_multi_location, feature_waitlist,
        feature_video_consultations, feature_marketplace, feature_online_payments
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [
      configId, bizId,
      primary_color, secondary_color, accent_color,
      app_name, bundle_id, bundle_id,
      labels,
      flags.feature_online_booking,
      flags.feature_loyalty_points,
      flags.feature_memberships,
      flags.feature_pos_integration,
      flags.feature_multi_location,
      flags.feature_waitlist,
      flags.feature_video_consultations,
      flags.feature_marketplace,
      flags.feature_online_payments,
    ]);

    // Store admin password if provided
    if (admin_password) {
      const hash = await bcrypt.hash(admin_password, 10);
      await conn.query(
        'INSERT INTO client_admin_passwords (business_id, password_hash) VALUES (?, ?) ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash)',
        [bizId, hash],
      );
    }

    await conn.commit();
    return res.status(201).json({ id: bizId, slug, message: 'Tenant created successfully' });
  } catch (err) {
    await conn.rollback();
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'Slug or bundle_id already exists' });
    }
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  } finally {
    conn.release();
  }
});

// ============================================================
// POST /api/tenants/:id/admin-password — Set/reset business admin password
// ============================================================
router.post('/:id/admin-password', authenticate, requireMasterAdmin, async (req, res) => {
  const { password } = req.body;
  if (!password || password.length < 6) return res.status(400).json({ error: 'Ο κωδικός πρέπει να έχει τουλάχιστον 6 χαρακτήρες' });
  try {
    const hash = await bcrypt.hash(password, 10);
    await db.query(
      'INSERT INTO client_admin_passwords (business_id, password_hash) VALUES (?, ?) ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash)',
      [req.params.id, hash],
    );
    return res.json({ ok: true });
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

// PATCH /api/tenants/:id — Update basic business info
// ============================================================
router.patch('/:id', authenticate, requireMasterAdmin, async (req, res) => {
  const { name, owner_email, plan, business_type } = req.body;
  const updates = {};
  if (name)          updates.name = name;
  if (owner_email)   updates.owner_email = owner_email;
  if (plan)          updates.plan = plan;
  if (business_type) updates.business_type = business_type;
  if (!Object.keys(updates).length) return res.status(400).json({ error: 'Nothing to update' });
  const sets = Object.keys(updates).map(k => `${k} = ?`).join(', ');
  try {
    await db.query(`UPDATE businesses SET ${sets} WHERE id = ?`, [...Object.values(updates), req.params.id]);
    return res.json({ ok: true });
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

// PATCH /api/tenants/:id/config — Update branding or flags
// ============================================================
router.patch('/:id/config', authenticate, requireMasterAdmin, async (req, res) => {
  try {
    const allowed = [
      'primary_color', 'secondary_color', 'accent_color',
      'background_color', 'surface_color', 'font_family',
      'app_name', 'bundle_id', 'version_name',
      'owner_name', 'owner_phone', 'gym_address', 'gym_phone', 'gym_email',
      'feature_online_booking', 'feature_loyalty_points', 'feature_memberships',
      'feature_pos_integration', 'feature_multi_location', 'feature_waitlist',
      'feature_video_consultations', 'feature_custom_module_id',
      'feature_nutrition', 'feature_online_payments', 'feature_marketplace',
      'firebase_project_id',
    ];

    // Only update fields that were sent and are in the allowed list
    const updates = {};
    for (const key of allowed) {
      if (req.body[key] !== undefined) updates[key] = req.body[key];
    }

    // label_overrides: merge with existing JSON, don't replace
    if (req.body.label_overrides !== undefined) {
      const [rows] = await db.query(
        'SELECT label_overrides FROM business_configs WHERE business_id = ?',
        [req.params.id]
      );
      let existing = rows[0]?.label_overrides || {};
      if (typeof existing === 'string') {
        try { existing = JSON.parse(existing); } catch (_) { existing = {}; }
      }
      updates.label_overrides = JSON.stringify({
        ...existing,
        ...req.body.label_overrides,
      });
    }

    if (!Object.keys(updates).length) {
      return res.status(400).json({ error: 'No valid fields to update' });
    }

    const setClauses = Object.keys(updates).map(k => `\`${k}\` = ?`).join(', ');
    const values     = [...Object.values(updates), req.params.id];

    await db.query(
      `UPDATE business_configs SET ${setClauses} WHERE business_id = ?`,
      values
    );

    return res.json({ ok: true });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
});

// ============================================================
// POST /api/tenants/:id/logo — Upload logo image (PNG/JPG/WEBP/SVG)
// ============================================================
router.post('/:id/logo', authenticate, requireMasterAdmin, (req, res, next) => {
  uploadLogo.single('logo')(req, res, (err) => {
    if (err) {
      console.error('[logo upload]', err.message);
      return res.status(500).json({ error: err.message || 'Upload failed' });
    }
    next();
  });
}, async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
    const logoUrl = req.file.publicUrl;
    await db.query('UPDATE business_configs SET logo_url = ? WHERE business_id = ?', [logoUrl, req.params.id]);
    return res.json({ logo_url: logoUrl });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message || 'Server error' });
  }
});

// ============================================================
// POST /api/tenants/:id/icon — Upload square app icon (PNG/JPG/WEBP/SVG)
// ============================================================
router.post('/:id/icon', authenticate, requireMasterAdmin, (req, res, next) => {
  uploadIcon.single('icon')(req, res, (err) => {
    if (err) {
      console.error('[icon upload]', err.message);
      return res.status(500).json({ error: err.message || 'Upload failed' });
    }
    next();
  });
}, async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
    const iconUrl = req.file.publicUrl;
    await db.query('UPDATE business_configs SET icon_url = ? WHERE business_id = ?', [iconUrl, req.params.id]);
    return res.json({ icon_url: iconUrl });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message || 'Server error' });
  }
});

// ============================================================
// POST /api/tenants/:id/toggle-active — Enable / disable tenant
// ============================================================
router.post('/:id/toggle-active', authenticate, requireMasterAdmin, async (req, res) => {
  try {
    await db.query(
      'UPDATE businesses SET is_active = NOT is_active WHERE id = ?',
      [req.params.id]
    );

    const [rows] = await db.query(
      'SELECT id, is_active FROM businesses WHERE id = ?',
      [req.params.id]
    );

    return res.json({ id: rows[0].id, is_active: !!rows[0].is_active });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
});

// ============================================================
// DELETE /api/tenants/:id — Delete tenant + all data
// ============================================================
router.delete('/:id', authenticate, requireMasterAdmin, async (req, res) => {
  try {
    await db.query('DELETE FROM businesses WHERE id = ?', [req.params.id]);
    return res.json({ ok: true, message: 'Tenant deleted' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
});

// ============================================================
// GET /api/tenants/:id/subscription — Get billing model
// PUT /api/tenants/:id/subscription — Create or update billing model
// ============================================================
router.get('/:id/subscription', authenticate, requireMasterAdmin, async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM tenant_subscriptions WHERE business_id = ?', [req.params.id]);
    return res.json(rows[0] || null);
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

router.put('/:id/subscription', authenticate, requireMasterAdmin, async (req, res) => {
  const {
    billing_model = 'monthly_fee', monthly_fee = 0, annual_fee = 0,
    revenue_share_pct = 0, per_booking_fee = 0, billing_cycle = 'monthly',
    status = 'active', trial_ends_at, current_period_start, current_period_end,
    next_renewal_at, setup_fee = 0, payment_method, contract_start, contract_end, notes,
  } = req.body;

  try {
    const [existing] = await db.query('SELECT id FROM tenant_subscriptions WHERE business_id = ?', [req.params.id]);
    if (existing.length) {
      await db.query(`UPDATE tenant_subscriptions SET
        billing_model=?, monthly_fee=?, annual_fee=?, revenue_share_pct=?, per_booking_fee=?,
        billing_cycle=?, status=?, trial_ends_at=?, current_period_start=?, current_period_end=?,
        next_renewal_at=?, setup_fee=?, payment_method=?, contract_start=?, contract_end=?, notes=?
        WHERE business_id=?`,
        [billing_model, monthly_fee, annual_fee, revenue_share_pct, per_booking_fee,
         billing_cycle, status, trial_ends_at||null, current_period_start||null, current_period_end||null,
         next_renewal_at||null, setup_fee, payment_method||null, contract_start||null, contract_end||null,
         notes||null, req.params.id]);
    } else {
      await db.query(`INSERT INTO tenant_subscriptions
        (id, business_id, billing_model, monthly_fee, annual_fee, revenue_share_pct, per_booking_fee,
         billing_cycle, status, trial_ends_at, current_period_start, current_period_end,
         next_renewal_at, setup_fee, payment_method, contract_start, contract_end, notes)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
        [uuidv4(), req.params.id, billing_model, monthly_fee, annual_fee, revenue_share_pct, per_booking_fee,
         billing_cycle, status, trial_ends_at||null, current_period_start||null, current_period_end||null,
         next_renewal_at||null, setup_fee, payment_method||null, contract_start||null, contract_end||null,
         notes||null]);
    }
    const [rows] = await db.query('SELECT * FROM tenant_subscriptions WHERE business_id = ?', [req.params.id]);
    return res.json(rows[0]);
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

// ============================================================
// GET  /api/tenants/:id/invoices — List invoices
// POST /api/tenants/:id/invoices — Create invoice
// PATCH /api/tenants/:id/invoices/:invId — Update (mark paid etc)
// ============================================================
router.get('/:id/invoices', authenticate, requireMasterAdmin, async (req, res) => {
  try {
    const [rows] = await db.query(
      'SELECT * FROM tenant_invoices WHERE business_id = ? ORDER BY created_at DESC',
      [req.params.id]
    );
    return res.json(rows);
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

router.post('/:id/invoices', authenticate, requireMasterAdmin, async (req, res) => {
  const {
    amount, currency = 'EUR', status = 'pending',
    period_start, period_end, due_date, description, notes,
  } = req.body;
  if (!amount || !due_date) return res.status(400).json({ error: 'amount and due_date required' });

  // Auto-generate invoice number: INV-{year}-{seq}
  try {
    const year = new Date().getFullYear();
    const [seq] = await db.query(
      "SELECT COUNT(*) AS cnt FROM tenant_invoices WHERE YEAR(created_at) = ?", [year]
    );
    const num = String(seq[0].cnt + 1).padStart(4, '0');
    const invoice_number = `INV-${year}-${num}`;

    const id = uuidv4();
    await db.query(`INSERT INTO tenant_invoices
      (id, business_id, invoice_number, amount, currency, status, period_start, period_end, due_date, description, notes)
      VALUES (?,?,?,?,?,?,?,?,?,?,?)`,
      [id, req.params.id, invoice_number, amount, currency, status,
       period_start||null, period_end||null, due_date, description||null, notes||null]);

    const [rows] = await db.query('SELECT * FROM tenant_invoices WHERE id = ?', [id]);
    return res.status(201).json(rows[0]);
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

router.patch('/:id/invoices/:invId', authenticate, requireMasterAdmin, async (req, res) => {
  const allowed = ['status', 'paid_at', 'due_date', 'amount', 'notes', 'description'];
  const updates = {};
  for (const k of allowed) {
    if (req.body[k] !== undefined) updates[k] = req.body[k];
  }
  if (req.body.status === 'paid' && !updates.paid_at) {
    updates.paid_at = new Date().toISOString().slice(0, 19).replace('T', ' ');
  }
  if (!Object.keys(updates).length) return res.status(400).json({ error: 'Nothing to update' });
  const sets = Object.keys(updates).map(k => `${k} = ?`).join(', ');
  try {
    await db.query(`UPDATE tenant_invoices SET ${sets} WHERE id = ? AND business_id = ?`,
      [...Object.values(updates), req.params.invId, req.params.id]);
    const [rows] = await db.query('SELECT * FROM tenant_invoices WHERE id = ?', [req.params.invId]);
    return res.json(rows[0]);
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

// ============================================================
// GET /api/tenants/:id/stats — Per-tenant usage stats
// ============================================================
router.get('/:id/stats', authenticate, requireMasterAdmin, async (req, res) => {
  const bizId = req.params.id;
  try {
    const [[users]]    = await db.query("SELECT COUNT(*) AS cnt FROM users WHERE business_id = ?", [bizId]);
    const [[active30]] = await db.query(`
      SELECT COUNT(DISTINCT user_id) AS cnt FROM bookings
      WHERE business_id = ? AND start_time >= DATE_SUB(NOW(), INTERVAL 30 DAY)`, [bizId]);
    const [[bkTotal]]  = await db.query("SELECT COUNT(*) AS cnt FROM bookings WHERE business_id = ?", [bizId]);
    const [[bk30]]     = await db.query(`
      SELECT COUNT(*) AS cnt FROM bookings
      WHERE business_id = ? AND start_time >= DATE_SUB(NOW(), INTERVAL 30 DAY)`, [bizId]);
    const [[rev30]]    = await db.query(`
      SELECT COALESCE(SUM(amount_cents),0) AS total FROM payments
      WHERE business_id = ? AND status = 'paid' AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)`, [bizId]);
    const [[revTotal]] = await db.query(`
      SELECT COALESCE(SUM(amount_cents),0) AS total FROM payments
      WHERE business_id = ? AND status = 'paid'`, [bizId]);
    const [[products]] = await db.query("SELECT COUNT(*) AS cnt FROM products WHERE business_id = ?", [bizId]);
    const [[orders30]] = await db.query(`
      SELECT COUNT(*) AS cnt FROM orders
      WHERE business_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)`, [bizId]);
    const [[members]]  = await db.query(`
      SELECT COUNT(*) AS cnt FROM user_memberships
      WHERE business_id = ? AND status = 'active'`, [bizId]);

    // Bookings by month (last 6 months)
    const [monthly] = await db.query(`
      SELECT DATE_FORMAT(start_time,'%Y-%m') AS month, COUNT(*) AS bookings
      FROM bookings WHERE business_id = ?
        AND start_time >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
      GROUP BY month ORDER BY month ASC`, [bizId]);

    return res.json({
      users:         Number(users.cnt),
      active_users_30d: Number(active30.cnt),
      bookings_total: Number(bkTotal.cnt),
      bookings_30d:  Number(bk30.cnt),
      revenue_30d:   Number(rev30.total) / 100,
      revenue_total: Number(revTotal.total) / 100,
      products:      Number(products.cnt),
      orders_30d:    Number(orders30.cnt),
      active_members: Number(members.cnt),
      monthly_bookings: monthly,
    });
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

// ============================================================
// GET /api/tenants/dashboard/overview — Aggregate super-admin stats
// ============================================================
router.get('/dashboard/overview', authenticate, requireMasterAdmin, async (req, res) => {
  try {
    const [[total]]   = await db.query("SELECT COUNT(*) AS cnt FROM businesses");
    const [[active]]  = await db.query("SELECT COUNT(*) AS cnt FROM businesses WHERE is_active = 1");
    const [[trial]]   = await db.query("SELECT COUNT(*) AS cnt FROM tenant_subscriptions WHERE status = 'trial'");
    const [[mrr]]     = await db.query(`
      SELECT COALESCE(SUM(monthly_fee),0) AS total FROM tenant_subscriptions
      WHERE status = 'active' AND billing_cycle = 'monthly'`);
    const [[arrAnnual]] = await db.query(`
      SELECT COALESCE(SUM(annual_fee/12),0) AS total FROM tenant_subscriptions
      WHERE status = 'active' AND billing_cycle = 'annual'`);
    const [[overdue]] = await db.query(`
      SELECT COUNT(*) AS cnt FROM tenant_invoices WHERE status = 'overdue'`);
    const [[pendingInv]] = await db.query(`
      SELECT COUNT(*) AS cnt, COALESCE(SUM(amount),0) AS total
      FROM tenant_invoices WHERE status IN ('pending','overdue')`);
    const [[paidThisMonth]] = await db.query(`
      SELECT COALESCE(SUM(amount),0) AS total FROM tenant_invoices
      WHERE status='paid' AND MONTH(paid_at)=MONTH(NOW()) AND YEAR(paid_at)=YEAR(NOW())`);

    // Monthly collected revenue — last 6 months
    const [monthlyRevenue] = await db.query(`
      SELECT DATE_FORMAT(paid_at, '%Y-%m') AS month,
             COALESCE(SUM(amount), 0) AS collected
      FROM tenant_invoices
      WHERE status = 'paid'
        AND paid_at >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
      GROUP BY DATE_FORMAT(paid_at, '%Y-%m')
      ORDER BY month ASC`);

    // Per-tenant summary with oldest pending invoice date
    const [tenants] = await db.query(`
      SELECT b.id, b.name, b.slug, b.business_type, b.plan, b.is_active, b.created_at,
        c.logo_url, c.primary_color,
        ts.status AS sub_status, ts.billing_model, ts.monthly_fee, ts.annual_fee,
        ts.next_renewal_at, ts.billing_cycle, ts.trial_ends_at,
        (SELECT COUNT(*) FROM users u WHERE u.business_id = b.id) AS user_count,
        (SELECT COUNT(*) FROM bookings bk WHERE bk.business_id = b.id
          AND bk.starts_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)) AS bookings_30d,
        (SELECT COALESCE(SUM(amount),0) FROM tenant_invoices ti
          WHERE ti.business_id = b.id AND ti.status IN ('pending','overdue')) AS outstanding,
        (SELECT MIN(due_date) FROM tenant_invoices ti
          WHERE ti.business_id = b.id AND ti.status IN ('pending','overdue')) AS oldest_due_date,
        (SELECT COUNT(*) FROM tenant_invoices ti
          WHERE ti.business_id = b.id AND ti.status = 'overdue') AS overdue_count
      FROM businesses b
      LEFT JOIN business_configs c ON c.business_id = b.id
      LEFT JOIN tenant_subscriptions ts ON ts.business_id = b.id
      ORDER BY b.created_at DESC`);

    const mrrTotal = Number(mrr.total) + Number(arrAnnual.total);

    return res.json({
      totals: {
        tenants:              Number(total.cnt),
        active:               Number(active.cnt),
        trial:                Number(trial.cnt),
        mrr:                  Math.round(mrrTotal * 100) / 100,
        overdue_invoices:     Number(overdue.cnt),
        pending_amount:       Number(pendingInv.total),
        collected_this_month: Number(paidThisMonth.total),
      },
      monthly_revenue: monthlyRevenue,
      tenants,
    });
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

// ── Global Users (OmniPlex app users) ─────────────────────────

// List all global users with search + pagination
router.get('/global-users', authenticate, requireMasterAdmin, async (req, res) => {
  try {
    const page  = Math.max(1, parseInt(req.query.page)  || 1);
    const limit = Math.min(100, parseInt(req.query.limit) || 50);
    const q     = (req.query.q || '').trim();
    const offset = (page - 1) * limit;

    let where = '';
    const params = [];
    if (q) {
      where = `WHERE (gu.email LIKE ? OR gu.full_name LIKE ? OR gu.phone LIKE ?)`;
      const like = `%${q}%`;
      params.push(like, like, like);
    }

    const [[{ total }]] = await db.query(
      `SELECT COUNT(*) AS total FROM global_users gu ${where}`,
      params,
    );

    const [rows] = await db.query(
      `SELECT gu.id, gu.email, gu.full_name, gu.phone, gu.created_at,
              COUNT(DISTINCT gjr.business_id) AS linked_gyms_count
       FROM global_users gu
       LEFT JOIN gym_join_requests gjr ON gjr.global_user_id = gu.id AND gjr.status = 'approved'
       ${where}
       GROUP BY gu.id
       ORDER BY gu.created_at DESC
       LIMIT ? OFFSET ?`,
      [...params, limit, offset],
    );

    return res.json({ total, page, limit, rows });
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

// Get single global user details
router.get('/global-users/:id', authenticate, requireMasterAdmin, async (req, res) => {
  try {
    const [[user]] = await db.query(
      `SELECT id, email, full_name, phone, created_at FROM global_users WHERE id = ?`,
      [req.params.id],
    );
    if (!user) return res.status(404).json({ error: 'Not found' });

    const [gyms] = await db.query(
      `SELECT gjr.id, gjr.status, gjr.created_at AS requested_at, gjr.updated_at AS updated_at,
              b.id AS business_id, b.name AS business_name, b.slug, b.business_type
       FROM gym_join_requests gjr
       JOIN businesses b ON b.id = gjr.business_id
       WHERE gjr.global_user_id = ?
       ORDER BY gjr.created_at DESC`,
      [req.params.id],
    );

    return res.json({ user, gyms });
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

// Update global user (email, full_name, phone, password)
router.put('/global-users/:id', authenticate, requireMasterAdmin, async (req, res) => {
  try {
    const { email, full_name, phone, password } = req.body;
    const sets = [];
    const vals = [];

    if (email)     { sets.push('email = ?');     vals.push(email.toLowerCase().trim()); }
    if (full_name) { sets.push('full_name = ?');  vals.push(full_name.trim()); }
    if (phone !== undefined) { sets.push('phone = ?'); vals.push(phone || null); }
    if (password)  {
      const hash = await bcrypt.hash(password, 12);
      sets.push('password_hash = ?');
      vals.push(hash);
    }

    if (!sets.length) return res.status(400).json({ error: 'Nothing to update' });

    vals.push(req.params.id);
    await db.query(`UPDATE global_users SET ${sets.join(', ')} WHERE id = ?`, vals);
    return res.json({ ok: true });
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

// Delete global user
router.delete('/global-users/:id', authenticate, requireMasterAdmin, async (req, res) => {
  try {
    await db.query('DELETE FROM gym_join_requests WHERE global_user_id = ?', [req.params.id]);
    await db.query('UPDATE users SET global_user_id = NULL WHERE global_user_id = ?', [req.params.id]);
    const [result] = await db.query('DELETE FROM global_users WHERE id = ?', [req.params.id]);
    if (result.affectedRows === 0) return res.status(404).json({ error: 'Not found' });
    return res.json({ ok: true });
  } catch (err) { return res.status(500).json({ error: err.message }); }
});

module.exports = router;
