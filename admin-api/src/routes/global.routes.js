// ============================================================
// FILE: src/routes/global.routes.js
// Global (cross-gym) user auth + discovery + multi-gym dashboard
// ============================================================

const express = require('express');
const bcrypt  = require('bcryptjs');
const jwt     = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const db      = require('../db');
const { phoneDigitsLike, phoneDigitsEq } = require('../lib/phone_sql');

const router = express.Router();

// ── Middleware ───────────────────────────────────────────────
function requireGlobal(req, res, next) {
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'No token' });
  try {
    const d = jwt.verify(token, process.env.JWT_SECRET);
    if (d.role !== 'global_user') return res.status(403).json({ error: 'Global token required' });
    req.globalUser = d;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

function makeGlobalToken(user) {
  return jwt.sign(
    { globalUserId: user.id, email: user.email, fullName: user.full_name, role: 'global_user' },
    process.env.JWT_SECRET,
    { expiresIn: '30d' },
  );
}

// ── Helpers ──────────────────────────────────────────────────
async function getGymsForGlobalUser(globalUserId) {
  const [rows] = await db.query(`
    SELECT u.id AS user_id, u.business_id, u.full_name, u.status,
           b.slug, b.name, b.business_type,
           c.app_name, c.primary_color, c.logo_url
    FROM users u
    JOIN businesses b ON b.id = u.business_id
    LEFT JOIN business_configs c ON c.business_id = b.id
    WHERE u.global_user_id = ? AND b.is_active = 1 AND u.deleted_at IS NULL
    ORDER BY b.name ASC
  `, [globalUserId]);
  return rows.map(r => ({
    user_id:       r.user_id,
    business_id:   r.business_id,
    business_name: r.name,
    app_name:      r.app_name || r.name,
    slug:          r.slug,
    business_type: r.business_type,
    primary_color: r.primary_color || '#B8F55E',
    logo_url:      r.logo_url || null,
    user_status:   r.status,
  }));
}

// ============================================================
// POST /api/global/auth/register
// Body: { full_name, email, password, phone? }
// ============================================================
router.post('/auth/register', async (req, res) => {
  const { full_name, email, password, phone } = req.body;
  if (!full_name || !email || !password)
    return res.status(400).json({ error: 'Απαιτούνται: ονοματεπώνυμο, email, κωδικός' });
  if (password.length < 6)
    return res.status(400).json({ error: 'Ο κωδικός πρέπει να έχει τουλάχιστον 6 χαρακτήρες' });

  try {
    const [existing] = await db.query('SELECT id FROM global_users WHERE email = ?', [email.toLowerCase()]);
    if (existing.length) return res.status(409).json({ error: 'Υπάρχει ήδη λογαριασμός με αυτό το email' });

    const hash = await bcrypt.hash(password, 10);
    const id   = uuidv4();
    await db.query(
      'INSERT INTO global_users (id, email, password_hash, full_name, phone) VALUES (?, ?, ?, ?, ?)',
      [id, email.toLowerCase(), hash, full_name.trim(), phone || null],
    );

    const user = { id, email: email.toLowerCase(), full_name: full_name.trim() };
    return res.json({ token: makeGlobalToken(user), user });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// POST /api/global/auth/login
// Body: { email, password }
// ============================================================
router.post('/auth/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) return res.status(400).json({ error: 'Email και κωδικός απαιτούνται' });

  try {
    const [rows] = await db.query('SELECT * FROM global_users WHERE email = ?', [email.toLowerCase()]);
    if (!rows.length) return res.status(401).json({ error: 'Λάθος email ή κωδικός' });

    const user = rows[0];
    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) return res.status(401).json({ error: 'Λάθος email ή κωδικός' });

    const gyms = await getGymsForGlobalUser(user.id);
    return res.json({
      token: makeGlobalToken(user),
      user:  { id: user.id, email: user.email, full_name: user.full_name },
      gyms,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// GET /api/global/me  (auth)
// ============================================================
router.get('/me', requireGlobal, async (req, res) => {
  try {
    const [rows] = await db.query('SELECT id, email, full_name, phone FROM global_users WHERE id = ?', [req.globalUser.globalUserId]);
    if (!rows.length) return res.status(404).json({ error: 'User not found' });
    const gyms = await getGymsForGlobalUser(req.globalUser.globalUserId);
    return res.json({ user: rows[0], gyms });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// GET /api/global/me/dashboard  (auth)
// Upcoming bookings across all gyms
// ============================================================
router.get('/me/dashboard', requireGlobal, async (req, res) => {
  try {
    const gyms = await getGymsForGlobalUser(req.globalUser.globalUserId);
    if (!gyms.length) return res.json({ gyms: [], upcoming_bookings: [] });

    const userIds = gyms.map(g => g.user_id);

    // Upcoming bookings for all gym accounts
    const [bookings] = await db.query(`
      SELECT b.id, b.booking_date, b.booking_time, b.status,
             s.name AS service_name, s.duration_mins,
             st.full_name AS staff_name,
             biz.id AS business_id, biz.name AS business_name,
             bc.app_name, bc.primary_color, bc.logo_url
      FROM bookings b
      JOIN services s ON s.id = b.service_id
      LEFT JOIN staff st ON st.id = b.staff_id
      JOIN businesses biz ON biz.id = b.business_id
      LEFT JOIN business_configs bc ON bc.business_id = b.business_id
      WHERE b.user_id IN (?)
        AND b.booking_date >= CURDATE()
        AND b.status IN ('pending','confirmed')
      ORDER BY b.booking_date ASC, b.booking_time ASC
      LIMIT 20
    `, [userIds]);

    return res.json({ gyms, upcoming_bookings: bookings });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// POST /api/global/gym-token  (auth)
// Exchange global token for a per-gym JWT
// Body: { business_id }
// ============================================================
router.post('/gym-token', requireGlobal, async (req, res) => {
  const { business_id } = req.body;
  if (!business_id) return res.status(400).json({ error: 'business_id required' });

  try {
    const [rows] = await db.query(
      `SELECT u.id, u.business_id, u.email, u.full_name, u.status, u.phone
       FROM users u
       WHERE u.global_user_id = ? AND u.business_id = ? AND u.deleted_at IS NULL`,
      [req.globalUser.globalUserId, business_id],
    );
    if (!rows.length) return res.status(404).json({ error: 'Δεν είσαι μέλος αυτού του γυμναστηρίου' });

    const u = rows[0];
    if (u.status === 'pending') return res.status(403).json({ error: 'Ο λογαριασμός σου εκκρεμεί έγκριση' });

    const token = jwt.sign(
      { userId: u.id, businessId: u.business_id, email: u.email, fullName: u.full_name, role: 'customer', globalUserId: req.globalUser.globalUserId },
      process.env.JWT_SECRET,
      { expiresIn: '7d' },
    );
    return res.json({ token });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// POST /api/global/link-gym  (auth)
// Link an existing gym account (by phone+PIN) to this global user
// Body: { business_id, phone, pin }
// ============================================================
router.post('/link-gym', requireGlobal, async (req, res) => {
  const { business_id, phone, pin } = req.body;
  if (!business_id || !phone || !pin) return res.status(400).json({ error: 'business_id, phone, pin required' });

  try {
    const normalizedPhone = String(phone).replace(/[\s\-().]/g, '');
    const [rows] = await db.query(
      'SELECT id, pin_hash, status FROM users WHERE business_id = ? AND phone = ? AND deleted_at IS NULL',
      [business_id, normalizedPhone],
    );
    if (!rows.length) return res.status(404).json({ error: 'Δεν βρέθηκε λογαριασμός με αυτό το κινητό' });

    const u = rows[0];
    const valid = await bcrypt.compare(String(pin), u.pin_hash || '');
    if (!valid) return res.status(401).json({ error: 'Λάθος PIN' });

    // Check not already linked to another global user
    const [linked] = await db.query('SELECT global_user_id FROM users WHERE id = ?', [u.id]);
    if (linked[0]?.global_user_id && linked[0].global_user_id !== req.globalUser.globalUserId) {
      return res.status(409).json({ error: 'Αυτός ο λογαριασμός είναι ήδη συνδεδεμένος με άλλο global account' });
    }

    await db.query('UPDATE users SET global_user_id = ? WHERE id = ?', [req.globalUser.globalUserId, u.id]);
    return res.json({ success: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// GET /api/global/discovery/gyms
// Public gym search with filters: ?q=&service=pilates&city=athens
// ============================================================
router.get('/discovery/gyms', async (req, res) => {
  const { q = '', service = '', city = '' } = req.query;

  // Require is_discoverable only for pure browse (no query, no service filter)
  const requireDiscoverable = !q.trim() && !service.trim() && !city.trim();
  const conditions = requireDiscoverable
    ? ['b.is_active = 1', 'b.is_discoverable = 1']
    : ['b.is_active = 1'];
  const params = [];

  if (q.trim().length >= 2) {
    conditions.push('(b.name LIKE ? OR b.slug LIKE ? OR c.app_name LIKE ?)');
    params.push(`%${q.trim()}%`, `%${q.trim()}%`, `%${q.trim()}%`);
  }
  if (city.trim()) {
    conditions.push('b.city LIKE ?');
    params.push(`%${city.trim()}%`);
  }

  try {
    let sql;
    if (service.trim()) {
      sql = `
        SELECT DISTINCT b.id, b.slug, b.name, b.business_type, b.city, b.description,
               c.app_name, c.primary_color, c.logo_url
        FROM businesses b
        LEFT JOIN business_configs c ON c.business_id = b.id
        JOIN services s ON s.business_id = b.id AND s.is_active = 1 AND s.name LIKE ?
        WHERE ${conditions.join(' AND ')}
        ORDER BY b.name ASC
        LIMIT 30
      `;
      params.unshift(`%${service.trim()}%`);
    } else {
      sql = `
        SELECT b.id, b.slug, b.name, b.business_type, b.city, b.description,
               c.app_name, c.primary_color, c.logo_url
        FROM businesses b
        LEFT JOIN business_configs c ON c.business_id = b.id
        WHERE ${conditions.join(' AND ')}
        ORDER BY b.name ASC
        LIMIT 30
      `;
    }

    const [rows] = await db.query(sql, params);

    // For each gym, also return what services it offers
    const bizIds = rows.map(r => r.id);
    let serviceMap = {};
    if (bizIds.length) {
      const [svcRows] = await db.query(
        `SELECT business_id, name FROM services WHERE business_id IN (?) AND is_active = 1 ORDER BY name ASC`,
        [bizIds],
      );
      for (const s of svcRows) {
        if (!serviceMap[s.business_id]) serviceMap[s.business_id] = [];
        serviceMap[s.business_id].push(s.name);
      }
    }

    return res.json(rows.map(r => ({
      business_id:   r.id,
      slug:          r.slug,
      name:          r.name,
      app_name:      r.app_name || r.name,
      business_type: r.business_type,
      city:          r.city || null,
      description:   r.description || null,
      primary_color: r.primary_color || '#B8F55E',
      logo_url:      r.logo_url || null,
      services:      serviceMap[r.id] || [],
    })));
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// GET /api/global/discovery/gyms/:slug  — public gym profile
// ============================================================
router.get('/discovery/gyms/:slug', async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT b.id, b.slug, b.name, b.business_type, b.city, b.description, b.latitude, b.longitude,
             c.app_name, c.primary_color, c.secondary_color, c.logo_url, c.feature_online_payments
      FROM businesses b
      LEFT JOIN business_configs c ON c.business_id = b.id
      WHERE b.slug = ? AND b.is_active = 1
    `, [req.params.slug]);
    if (!rows.length) return res.status(404).json({ error: 'Gym not found' });

    const biz = rows[0];
    const [services] = await db.query(
      `SELECT id, name, duration_mins, category, description, drop_in_price_cents
       FROM services WHERE business_id = ? AND is_active = 1 ORDER BY name ASC`,
      [biz.id],
    );

    return res.json({
      business_id:       biz.id,
      slug:              biz.slug,
      name:              biz.name,
      app_name:          biz.app_name || biz.name,
      business_type:     biz.business_type,
      city:              biz.city || null,
      description:       biz.description || null,
      latitude:          biz.latitude,
      longitude:         biz.longitude,
      primary_color:     biz.primary_color || '#B8F55E',
      secondary_color:   biz.secondary_color || null,
      logo_url:          biz.logo_url || null,
      online_payments:   !!biz.feature_online_payments,
      services,
    });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// POST /api/global/auth/register  (updated: accepts gym_ids for join requests)
// replaces the earlier handler — added gym_ids processing
// ============================================================
// NOTE: the earlier /auth/register handler above handles creation.
// This extra route handles POST-registration gym linking after creation:
// POST /api/global/join-requests  (auth)
// Body: { business_id }
// Creates a join request or auto-links if matching phone/email exists
// ============================================================
router.post('/join-requests', requireGlobal, async (req, res) => {
  const { business_id } = req.body;
  if (!business_id) return res.status(400).json({ error: 'business_id required' });

  const { globalUserId, email, fullName } = req.globalUser;

  try {
    // Get user details
    const [guRows] = await db.query('SELECT phone, full_name FROM global_users WHERE id = ?', [globalUserId]);
    if (!guRows.length) return res.status(404).json({ error: 'Global user not found' });
    const phone = guRows[0].phone;
    const name  = guRows[0].full_name || fullName;

    // Check business exists
    const [bizRows] = await db.query('SELECT id, name FROM businesses WHERE id = ? AND is_active = 1', [business_id]);
    if (!bizRows.length) return res.status(404).json({ error: 'Gym not found' });

    // Check if already linked
    const [linked] = await db.query(
      'SELECT id FROM users WHERE global_user_id = ? AND business_id = ? AND deleted_at IS NULL',
      [globalUserId, business_id],
    );
    if (linked.length) return res.status(409).json({ error: 'already_linked', message: 'Είσαι ήδη μέλος αυτού του γυμναστηρίου' });

    // Try auto-link: find user in this gym with same email or phone
    let matchQuery = null;
    if (email) {
      const [r] = await db.query(
        `SELECT id, global_user_id FROM users WHERE business_id = ? AND email = CONVERT(? USING utf8mb4) COLLATE utf8mb4_unicode_ci AND deleted_at IS NULL`,
        [business_id, email.toLowerCase()],
      );
      if (r.length) matchQuery = r[0];
    }
    if (!matchQuery && phone) {
      const normalizedPhone = phone.replace(/[\s\-().]/g, '');
      const [r] = await db.query(
        `SELECT id, global_user_id FROM users
         WHERE business_id = ?
           AND ${phoneDigitsEq('phone')}
           AND deleted_at IS NULL`,
        [business_id, normalizedPhone.replace(/\D/g, '')],
      );
      if (r.length) matchQuery = r[0];
    }

    if (matchQuery) {
      if (matchQuery.global_user_id && matchQuery.global_user_id !== globalUserId) {
        return res.status(409).json({ error: 'already_linked_other', message: 'Αυτός ο λογαριασμός είναι συνδεδεμένος με άλλο global account' });
      }
      // Auto-link!
      await db.query('UPDATE users SET global_user_id = ? WHERE id = ?', [globalUserId, matchQuery.id]);
      return res.json({ status: 'linked', message: 'Ο λογαριασμός συνδέθηκε αυτόματα' });
    }

    // No match — check for duplicate pending request
    const [existing] = await db.query(
      'SELECT id, status FROM gym_join_requests WHERE global_user_id = ? AND business_id = ?',
      [globalUserId, business_id],
    );
    if (existing.length) {
      if (existing[0].status === 'pending') return res.json({ status: 'pending', message: 'Το αίτημά σου εκκρεμεί' });
      if (existing[0].status === 'approved') return res.json({ status: 'approved' });
      // rejected — allow re-request
      await db.query('UPDATE gym_join_requests SET status = ? WHERE id = ?', ['pending', existing[0].id]);
      return res.json({ status: 'pending', message: 'Το αίτημά σου εστάλη ξανά' });
    }

    // Create join request
    const reqId = uuidv4();
    await db.query(
      'INSERT INTO gym_join_requests (id, global_user_id, business_id, full_name, email, phone) VALUES (?, ?, ?, ?, ?, ?)',
      [reqId, globalUserId, business_id, name, email || '', phone || null],
    );

    // Notify admin
    try {
      const { createAdminNotification } = require('../lib/notifications');
      await createAdminNotification(db, {
        businessId: business_id,
        type:  'join_request',
        title: 'Αίτημα εγγραφής',
        body:  `${name} ζητά να γίνει μέλος του γυμναστηρίου.`,
        payload: { join_request_id: reqId, global_user_id: globalUserId, full_name: name, email: email || '', phone: phone || '' },
      });
    } catch (_) {}

    return res.json({ status: 'pending', message: 'Το αίτημά σου στάλθηκε. Ο διαχειριστής θα σε ειδοποιήσει.' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// GET /api/global/join-requests  (auth)
// My pending/resolved join requests
// ============================================================
router.get('/join-requests', requireGlobal, async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT jr.id, jr.business_id, jr.status, jr.created_at, jr.admin_note,
             b.name AS business_name, bc.app_name, bc.logo_url, bc.primary_color
      FROM gym_join_requests jr
      JOIN businesses b ON b.id = (jr.business_id COLLATE utf8mb4_unicode_ci)
      LEFT JOIN business_configs bc ON bc.business_id = (jr.business_id COLLATE utf8mb4_unicode_ci)
      WHERE (jr.global_user_id COLLATE utf8mb4_unicode_ci) = ?
      ORDER BY jr.created_at DESC
    `, [req.globalUser.globalUserId]);
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// DELETE /api/global/join-requests/:id  (auth)
// Cancel a pending join request
// ============================================================
router.delete('/join-requests/:id', requireGlobal, async (req, res) => {
  try {
    const [result] = await db.query(
      `DELETE FROM gym_join_requests WHERE id = ? AND global_user_id = ? AND status = 'pending'`,
      [req.params.id, req.globalUser.globalUserId],
    );
    if (result.affectedRows === 0) return res.status(404).json({ error: 'Not found or already processed' });
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// POST /api/global/staff/login  — staff multi-gym login
// Body: { email, password }
// Returns global staff token + list of gyms where user works
// ============================================================
router.post('/staff/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) return res.status(400).json({ error: 'Email και κωδικός απαιτούνται' });

  try {
    // Find all staff records with this email that have a password
    const [rows] = await db.query(`
      SELECT s.id AS staff_id, s.business_id, s.full_name, s.role, s.avatar_url,
             p.password_hash,
             b.slug, b.name AS business_name, b.business_type,
             bc.app_name, bc.primary_color, bc.logo_url
      FROM staff s
      JOIN businesses b ON b.id = s.business_id AND b.is_active = 1
      LEFT JOIN business_configs bc ON bc.business_id = s.business_id
      LEFT JOIN staff_passwords p ON p.staff_id = s.id
      WHERE s.portal_email = ? AND s.is_active = 1
    `, [email.toLowerCase()]);

    if (!rows.length) return res.status(401).json({ error: 'Δεν βρέθηκε λογαριασμός προσωπικού' });

    // Verify password against first found record that has a hash
    const withHash = rows.find(r => r.password_hash);
    if (!withHash) return res.status(401).json({ error: 'Δεν έχει οριστεί κωδικός. Επικοινώνησε με τον διαχειριστή.' });
    const valid = await bcrypt.compare(password, withHash.password_hash);
    if (!valid) return res.status(401).json({ error: 'Λάθος κωδικός' });

    const gyms = rows.map(r => ({
      staff_id:      r.staff_id,
      business_id:   r.business_id,
      business_name: r.business_name,
      app_name:      r.app_name || r.business_name,
      slug:          r.slug,
      business_type: r.business_type,
      role:          r.role,
      primary_color: r.primary_color || '#B8F55E',
      logo_url:      r.logo_url || null,
      avatar_url:    r.avatar_url || null,
    }));

    const token = jwt.sign(
      { email: email.toLowerCase(), fullName: withHash.full_name, role: 'global_staff',
        primaryStaffId: withHash.staff_id, primaryBusinessId: withHash.business_id },
      process.env.JWT_SECRET,
      { expiresIn: '30d' },
    );

    return res.json({ token, gyms, full_name: withHash.full_name });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// POST /api/global/staff/gym-token  — get per-gym trainer JWT
// Body: { staff_id, business_id }
// ============================================================
router.post('/staff/gym-token', async (req, res) => {
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'No token' });
  try {
    const d = jwt.verify(token, process.env.JWT_SECRET);
    if (d.role !== 'global_staff') return res.status(403).json({ error: 'Staff token required' });

    const { staff_id, business_id } = req.body;
    if (!staff_id || !business_id) return res.status(400).json({ error: 'staff_id and business_id required' });

    const [rows] = await db.query(
      `SELECT s.id, s.business_id, s.full_name, s.role, s.avatar_url, s.color_hex, s.bio
       FROM staff s WHERE s.id = ? AND s.business_id = ? AND s.is_active = 1`,
      [staff_id, business_id],
    );
    if (!rows.length) return res.status(404).json({ error: 'Staff record not found' });

    const s = rows[0];
    const gymToken = jwt.sign(
      { businessId: s.business_id, email: d.email, role: 'trainer',
        name: s.full_name, staffId: s.id },
      process.env.JWT_SECRET,
      { expiresIn: '7d' },
    );
    return res.json({ token: gymToken });
  } catch (err) {
    return res.status(401).json({ error: 'Invalid token' });
  }
});

// ============================================================
// GET /api/global/discovery/gyms/:slug/packages  — public packages
// ============================================================
router.get('/discovery/gyms/:slug/packages', async (req, res) => {
  try {
    const [[biz]] = await db.query('SELECT id FROM businesses WHERE slug = ? AND is_active = 1', [req.params.slug]);
    if (!biz) return res.status(404).json({ error: 'Gym not found' });

    const [plans] = await db.query(`
      SELECT bp.id, bp.name, bp.sessions, bp.price_cents, bp.billing_period, bp.plan_type, bp.sort_order,
             GROUP_CONCAT(DISTINCT s.name ORDER BY s.name SEPARATOR ', ') AS service_name
      FROM business_plans bp
      LEFT JOIN plan_service_items psi ON psi.plan_id = bp.id
      LEFT JOIN services s ON s.id = psi.service_id
      WHERE bp.business_id = ? AND bp.is_active = 1 AND bp.plan_type != 'nutrition'
      GROUP BY bp.id
      ORDER BY bp.sort_order ASC, bp.price_cents ASC
    `, [biz.id]);
    return res.json(plans);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// GET /api/global/discovery/gyms/:slug/opening-hours  (public)
// ============================================================
router.get('/discovery/gyms/:slug/opening-hours', async (req, res) => {
  try {
    const [[biz]] = await db.query('SELECT id FROM businesses WHERE slug = ? AND is_active = 1', [req.params.slug]);
    if (!biz) return res.status(404).json({ error: 'Gym not found' });

    const [rows] = await db.query(
      'SELECT day_of_week, open_time, close_time, is_closed FROM opening_hours WHERE business_id = ? ORDER BY day_of_week ASC',
      [biz.id],
    );
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// POST /api/global/auth/login-phone
// Body: { phone, pin }  — PIN = last 4 digits of phone
// Also auto-links existing per-gym users who don't have a global account yet
// ============================================================
router.post('/auth/login-phone', async (req, res) => {
  const { phone, pin } = req.body;
  if (!phone || !pin) return res.status(400).json({ error: 'Απαιτούνται τηλέφωνο και PIN' });

  const digits = phone.replace(/\D/g, '');
  if (pin !== digits.slice(-4)) return res.status(401).json({ error: 'Λάθος PIN' });

  // Normalise to last 9 digits for fuzzy match (handles +30 prefix etc)
  const last9 = digits.slice(-9);

  try {
    // 1. Try global_users first
    const [guRows] = await db.query(
      `SELECT * FROM global_users
       WHERE ${phoneDigitsLike('phone')}`,
      [`%${last9}`],
    );

    if (guRows.length) {
      const user = guRows[0];
      const gyms = await getGymsForGlobalUser(user.id);
      return res.json({
        token: makeGlobalToken(user),
        user:  { id: user.id, email: user.email, full_name: user.full_name },
        gyms,
      });
    }

    // 2. Fall back: look in per-gym users table
    const [gymUsers] = await db.query(
      `SELECT u.*, b.slug, b.name AS biz_name, c.app_name, c.primary_color, c.logo_url
       FROM users u
       JOIN businesses b ON b.id = u.business_id
       LEFT JOIN business_configs c ON c.business_id = b.id
       WHERE ${phoneDigitsLike('u.phone')}
         AND u.deleted_at IS NULL AND b.is_active = 1`,
      [`%${last9}`],
    );

    if (!gymUsers.length) {
      return res.status(401).json({ error: 'Δεν βρέθηκε λογαριασμός με αυτό το τηλέφωνο' });
    }

    // Create global_user and link all matching gym accounts
    const firstUser = gymUsers[0];
    const newId = uuidv4();
    await db.query(
      `INSERT INTO global_users (id, email, full_name, phone) VALUES (?,?,?,?)
       ON DUPLICATE KEY UPDATE id=id`,
      [newId, firstUser.email || '', firstUser.full_name || '', firstUser.phone || ''],
    );

    // Re-fetch (in case ON DUPLICATE KEY triggered)
    const [[createdGU]] = await db.query('SELECT * FROM global_users WHERE id = ?', [newId]);
    const globalUserId = createdGU ? createdGU.id : newId;

    // Link all gym users to this global account
    const userIds = [...new Set(gymUsers.map(u => u.id))];
    for (const uid of userIds) {
      await db.query(
        'UPDATE users SET global_user_id = ? WHERE id = ? AND global_user_id IS NULL',
        [globalUserId, uid],
      );
    }

    const user = createdGU || { id: globalUserId, email: firstUser.email || '', full_name: firstUser.full_name || '' };
    const gyms = await getGymsForGlobalUser(globalUserId);
    return res.json({
      token: makeGlobalToken(user),
      user:  { id: user.id, email: user.email, full_name: user.full_name },
      gyms,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// POST /api/global/purchase/:slug/intent
// Public (or optional auth) — create Stripe PaymentIntent for package
// Body: { plan_id, user_info?: { full_name, email, phone, password } }
// ============================================================
router.post('/purchase/:slug/intent', async (req, res) => {
  const { plan_id, user_info } = req.body;
  if (!plan_id) return res.status(400).json({ error: 'Απαιτείται plan_id' });

  const conn = await db.getConnection();
  try {
    // Get gym + plan
    const [[biz]] = await conn.query(
      `SELECT b.id, b.name, c.app_name FROM businesses b
       LEFT JOIN business_configs c ON c.business_id = b.id
       WHERE b.slug = ? AND b.is_active = 1`,
      [req.params.slug],
    );
    if (!biz) return res.status(404).json({ error: 'Γυμναστήριο δεν βρέθηκε' });

    const [[plan]] = await conn.query(
      `SELECT p.*, s.name AS service_name FROM service_plans p
       JOIN services s ON s.id = p.service_id
       WHERE p.id = ? AND s.business_id = ? AND p.is_active = 1`,
      [plan_id, biz.id],
    );
    if (!plan) return res.status(404).json({ error: 'Πακέτο δεν βρέθηκε' });

    // Get Stripe config for this gym
    const [[provRow]] = await conn.query(
      `SELECT * FROM payment_providers WHERE business_id = ? AND is_active = 1 LIMIT 1`,
      [biz.id],
    );
    if (!provRow) return res.status(400).json({ error: 'Οι online πληρωμές δεν είναι διαθέσιμες για αυτό το γυμναστήριο' });

    const cfg = typeof provRow.config === 'string' ? JSON.parse(provRow.config) : (provRow.config || {});
    const stripe = require('stripe')(cfg.secret_key);

    const intent = await stripe.paymentIntents.create({
      amount:   plan.price_cents,
      currency: 'eur',
      metadata: {
        slug:    req.params.slug,
        plan_id: plan.id,
        biz_id:  biz.id,
        full_name: user_info?.full_name || '',
        email:     user_info?.email    || '',
        phone:     user_info?.phone    || '',
        password:  user_info?.password || '',
        type: 'global_package_purchase',
      },
      automatic_payment_methods: { enabled: true },
    });

    return res.json({
      client_secret:   intent.client_secret,
      intent_id:       intent.id,
      publishable_key: cfg.publishable_key,
      amount_cents:    plan.price_cents,
      plan_name:       plan.name,
      gym_name:        biz.app_name || biz.name,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// ============================================================
// POST /api/global/purchase/:slug/confirm
// After client-side payment success — create membership
// Body: { intent_id, user_info: { full_name, email, phone, password }, plan_id }
// ============================================================
router.post('/purchase/:slug/confirm', async (req, res) => {
  const { intent_id, user_info, plan_id } = req.body;
  if (!intent_id || !plan_id || !user_info?.phone)
    return res.status(400).json({ error: 'Απαιτούνται intent_id, plan_id, user_info.phone' });

  const conn = await db.getConnection();
  try {
    // Verify gym
    const [[biz]] = await conn.query(
      `SELECT b.id, b.name FROM businesses b WHERE b.slug = ? AND b.is_active = 1`,
      [req.params.slug],
    );
    if (!biz) return res.status(404).json({ error: 'Γυμναστήριο δεν βρέθηκε' });

    // Verify payment with Stripe
    const [[provRow]] = await conn.query(
      `SELECT * FROM payment_providers WHERE business_id = ? AND is_active = 1 LIMIT 1`,
      [biz.id],
    );
    const cfg = typeof provRow?.config === 'string' ? JSON.parse(provRow.config) : (provRow?.config || {});
    const stripe = require('stripe')(cfg.secret_key);
    const intent = await stripe.paymentIntents.retrieve(intent_id);
    if (intent.status !== 'succeeded') {
      return res.status(402).json({ error: 'Η πληρωμή δεν ολοκληρώθηκε' });
    }

    // Get plan
    const [[plan]] = await conn.query(
      `SELECT p.*, s.name AS service_name, s.id AS service_id FROM service_plans p
       JOIN services s ON s.id = p.service_id
       WHERE p.id = ? AND s.business_id = ?`,
      [plan_id, biz.id],
    );
    if (!plan) return res.status(404).json({ error: 'Πακέτο δεν βρέθηκε' });

    // Find or create global_user
    let globalUser;
    const phone = user_info.phone.trim();
    const [existingGU] = await conn.query(
      'SELECT * FROM global_users WHERE phone = ? OR email = ?',
      [phone, (user_info.email || '').toLowerCase()],
    );
    if (existingGU.length) {
      globalUser = existingGU[0];
    } else {
      const hash = user_info.password ? await require('bcryptjs').hash(user_info.password, 10) : null;
      const guId = require('uuid').v4();
      await conn.query(
        'INSERT INTO global_users (id, email, password_hash, full_name, phone) VALUES (?,?,?,?,?)',
        [guId, (user_info.email || '').toLowerCase(), hash, user_info.full_name || '', phone],
      );
      globalUser = { id: guId, email: user_info.email || '', full_name: user_info.full_name || '' };
    }

    // Find or create gym user
    let gymUserId;
    const [existingUser] = await conn.query(
      'SELECT id FROM users WHERE business_id = ? AND phone = ? AND deleted_at IS NULL',
      [biz.id, phone],
    );
    if (existingUser.length) {
      gymUserId = existingUser[0].id;
      // Link global user if not linked
      await conn.query(
        'UPDATE users SET global_user_id = ? WHERE id = ? AND global_user_id IS NULL',
        [globalUser.id, gymUserId],
      );
    } else {
      gymUserId = require('uuid').v4();
      await conn.query(
        `INSERT INTO users (id, business_id, global_user_id, full_name, email, phone, role, status, created_at)
         VALUES (?,?,?,?,?,?,'customer','active',NOW())`,
        [gymUserId, biz.id, globalUser.id, user_info.full_name || '', user_info.email || '', phone],
      );
    }

    // Create membership
    const membershipId = require('uuid').v4();
    const expiresAt = plan.validity_days
      ? new Date(Date.now() + plan.validity_days * 86400000).toISOString().slice(0, 10)
      : null;
    await conn.query(
      `INSERT INTO user_memberships
        (id, business_id, user_id, plan_id, service_id, total_sessions, used_sessions, expires_at, purchase_date, provider_intent_id)
       VALUES (?,?,?,?,?,?,0,?,NOW(),?)`,
      [membershipId, biz.id, gymUserId, plan.id, plan.service_id,
       plan.sessions_included ?? 9999, expiresAt, intent_id],
    );

    // Approve/upsert join request
    const [existJR] = await conn.query(
      'SELECT id FROM gym_join_requests WHERE global_user_id = ? AND business_id = ?',
      [globalUser.id, biz.id],
    );
    if (existJR.length) {
      await conn.query(
        "UPDATE gym_join_requests SET status='approved', resolved_at=NOW() WHERE id=?",
        [existJR[0].id],
      );
    } else {
      await conn.query(
        `INSERT INTO gym_join_requests (id, global_user_id, business_id, status, resolved_at)
         VALUES (?,?,?,'approved',NOW())`,
        [require('uuid').v4(), globalUser.id, biz.id],
      );
    }

    const gyms = await getGymsForGlobalUser(globalUser.id);
    const token = jwt.sign(
      { globalUserId: globalUser.id, email: globalUser.email, fullName: globalUser.full_name, role: 'global_user' },
      process.env.JWT_SECRET,
      { expiresIn: '30d' },
    );

    return res.json({
      ok: true,
      token,
      user: { id: globalUser.id, email: globalUser.email, full_name: globalUser.full_name },
      gyms,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

module.exports = router;
