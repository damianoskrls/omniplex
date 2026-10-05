// ============================================================
// FILE: src/routes/global.routes.js
// Global (cross-gym) user auth + discovery + multi-gym dashboard
// ============================================================

const express = require('express');
const bcrypt  = require('bcryptjs');
const jwt     = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const db      = require('../db');
const { phoneDigitsLike, phoneLast10Eq } = require('../lib/phone_sql');
const { parseOpeningHours } = require('../lib/slots');

const HOUR_DAYS = ['Δευ', 'Τρί', 'Τετ', 'Πέμ', 'Παρ', 'Σαβ', 'Κυρ'];

function describeHours(raw) {
  const hours = parseOpeningHours(raw);
  if (!hours || typeof hours !== 'object' || Array.isArray(hours)) return null;
  const days = [];
  for (let d = 0; d < 7; d++) {
    const day = hours[d] ?? hours[String(d)];
    if (!day || typeof day !== 'object') continue;
    const closed = !!day.closed;
    const open = String(day.open || '').slice(0, 5);
    const close = String(day.close || '').slice(0, 5);
    if (!closed && (!open || !close)) continue;
    days.push({
      day_index: d,
      day: HOUR_DAYS[d],
      open: closed ? null : open,
      close: closed ? null : close,
      closed,
    });
  }
  if (!days.length) return null;
  const groups = [];
  for (const day of days) {
    const key = day.closed ? 'closed' : `${day.open}-${day.close}`;
    const last = groups[groups.length - 1];
    if (last && last.key === key && last.end === day.day_index - 1) {
      last.end = day.day_index;
    } else {
      groups.push({ start: day.day_index, end: day.day_index, key, closed: day.closed, open: day.open, close: day.close });
    }
  }
  const summary = groups.map((group) => {
    const label = group.start === group.end
      ? HOUR_DAYS[group.start]
      : `${HOUR_DAYS[group.start]}–${HOUR_DAYS[group.end]}`;
    return group.closed ? `${label} κλειστά` : `${label} ${group.open}–${group.close}`;
  }).join(' · ');
  return { days, summary };
}

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
const autoLinkAt = new Map();

async function locationsForMember(dbConn, { bizIds, memberIds, staffIds }) {
  if (!bizIds.length) return [];
  const clauses = [];
  const params = [bizIds];
  const add = (sql, ids) => {
    if (!ids.length) return;
    clauses.push(sql);
    params.push(ids);
  };
  add(`EXISTS (SELECT 1 FROM user_locations ul WHERE ul.location_id = l.id AND ul.user_id IN (?))`, memberIds);
  add(`(
    (SELECT COUNT(*) FROM locations lx WHERE lx.business_id = l.business_id AND lx.is_active = 1) = 1
    AND EXISTS (
      SELECT 1 FROM users u
      WHERE u.id IN (?) AND u.business_id = l.business_id AND u.deleted_at IS NULL
        AND NOT EXISTS (SELECT 1 FROM user_locations ul WHERE ul.user_id = u.id)
    )
  )`, memberIds);
  add(`EXISTS (SELECT 1 FROM staff_locations sl WHERE sl.location_id = l.id AND sl.staff_id IN (?))`, staffIds);
  add(`(
    (SELECT COUNT(*) FROM locations lx WHERE lx.business_id = l.business_id AND lx.is_active = 1) = 1
    AND EXISTS (
      SELECT 1 FROM staff s
      WHERE s.id IN (?) AND s.business_id = l.business_id AND s.is_active = 1
        AND NOT EXISTS (SELECT 1 FROM staff_locations sl WHERE sl.staff_id = s.id)
    )
  )`, staffIds);
  if (!clauses.length) return [];
  const [rows] = await dbConn.query(
    `SELECT DISTINCT l.id, l.business_id, l.name
     FROM locations l
     WHERE l.is_active = 1 AND l.business_id IN (?)
       AND (${clauses.join(' OR ')})
     ORDER BY l.name`,
    params,
  );
  return rows;
}

async function getGymsForGlobalUser(globalUserId) {
  const [[gu]] = await db.query('SELECT phone, email FROM global_users WHERE id = ?', [globalUserId]);
  const lastLink = autoLinkAt.get(globalUserId) || 0;
  if (gu && Date.now() - lastLink > 120000) {
    autoLinkAt.set(globalUserId, Date.now());
    try { await autoLinkGlobalUser(globalUserId, gu.phone, gu.email); }
    catch (err) {
      autoLinkAt.delete(globalUserId);
      console.warn('auto-link skipped:', err.message);
    }
  }

  const [memberRows] = await db.query(`
    SELECT u.id AS user_id, u.business_id, u.full_name, u.account_status AS status,
           b.slug, b.name, b.business_type,
           c.app_name, c.primary_color, c.logo_url,
           'member' AS user_type, NULL AS staff_id
    FROM users u
    JOIN businesses b ON b.id = u.business_id
    LEFT JOIN business_configs c ON c.business_id = b.id
    WHERE u.global_user_id = ? AND b.is_active = 1 AND u.deleted_at IS NULL
  `, [globalUserId]);

  const [staffRows] = await db.query(`
    SELECT s.id AS user_id, s.business_id, s.full_name, 'active' AS status,
           b.slug, b.name, b.business_type,
           c.app_name, c.primary_color, c.logo_url,
           'staff' AS user_type, s.id AS staff_id, s.role AS staff_role,
           COALESCE(s.is_nutritionist, 0) AS is_nutritionist
    FROM staff s
    JOIN businesses b ON b.id = s.business_id AND b.is_active = 1
    LEFT JOIN business_configs c ON c.business_id = s.business_id
    WHERE s.global_user_id = ? AND s.is_active = 1
  `, [globalUserId]);

  const staffExpanded = staffRows.flatMap(expandStaffGyms);
  const seen = new Set();
  const all = [...memberRows, ...staffExpanded].filter(r => {
    const key = `${r.business_id}:${r.user_type}:${r.staff_kind || ''}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  }).sort((a, b) => a.name.localeCompare(b.name));

  const memberIds = [...new Set(all.filter((r) => r.user_type === 'member').map((r) => r.user_id))];
  const staffIds = [...new Set(all.filter((r) => r.user_type === 'staff').map((r) => r.staff_id || r.user_id))];
  const bizIds = [...new Set(all.map((r) => r.business_id).filter(Boolean))];
  const places = await locationsForMember(db, { bizIds, memberIds, staffIds });
  const placesByBiz = {};
  for (const place of places) {
    if (!placesByBiz[place.business_id]) placesByBiz[place.business_id] = [];
    placesByBiz[place.business_id].push({ id: place.id, name: place.name });
  }

  return all.map(r => ({
    user_id:       r.user_id,
    business_id:   r.business_id,
    business_name: r.name,
    app_name:      r.app_name || r.name,
    slug:          r.slug,
    business_type: r.business_type,
    primary_color: r.primary_color || '#B8F55E',
    logo_url:      r.logo_url || null,
    user_status:   r.status,
    user_type:     r.user_type,
    staff_id:      r.staff_id || null,
    staff_kind:    r.user_type === 'staff' ? (r.staff_kind || staffKindFromRow(r)) : null,
    locations:     placesByBiz[r.business_id] || [],
  }));
}

function staffKindsFromRow(row) {
  const role = String(row.staff_role || row.role || row.specialty || '').trim();
  const nutrition = Number(row.is_nutritionist) === 1 || /διατροφ|nutri/i.test(role);
  const physio = /φυσιο|physio/i.test(role);
  const genericTrainer = /^(trainer|γυμναστής|γυμναστης)$/i.test(role);
  const kinds = [];
  if (nutrition) kinds.push('nutritionist');
  if (physio) kinds.push('physiotherapist');
  // "Trainer" is the default staff title. It must not cover a nutritionist.
  if (/trainer|γυμναστ|coach|personal/i.test(role) && !(nutrition && genericTrainer)) {
    kinds.push('trainer');
  }
  if (!kinds.length) kinds.push('trainer');
  return kinds;
}

function staffKindFromRow(row) {
  return staffKindsFromRow(row)[0];
}

function expandStaffGyms(row) {
  return staffKindsFromRow(row).map((kind) => ({ ...row, staff_kind: kind }));
}

function staffKindLabel(specialty) {
  const kind = staffKindFromRow({ specialty });
  if (kind === 'nutritionist') return 'διατροφολόγος';
  if (kind === 'physiotherapist') return 'φυσιοθεραπευτής';
  return 'trainer';
}

// ── Debug: outbound IP (temporary) ──────────────────────────
router.get('/debug/ip', async (req, res) => {
  try {
    const r = await fetch('https://api.ipify.org?format=json');
    const data = await r.json();
    return res.json({ outbound_ip: data.ip });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

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

    db.query('UPDATE global_users SET last_login = NOW() WHERE id = ?', [user.id]).catch(() => {});
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

// DELETE /api/global/me — the signed-in person erases their OmniPlex account.
router.delete('/me', requireGlobal, async (req, res) => {
  const id = req.globalUser.globalUserId;
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const [[account]] = await conn.query(
      'SELECT id, phone FROM global_users WHERE id = ? FOR UPDATE',
      [id],
    );
    if (!account) {
      await conn.rollback();
      return res.status(404).json({ error: 'Ο λογαριασμός δεν βρέθηκε' });
    }

    const [members] = await conn.query(
      'SELECT id FROM users WHERE global_user_id = ?',
      [id],
    );
    const memberIds = members.map((row) => row.id).filter(Boolean);

    if (memberIds.length) {
      await conn.query(
        `UPDATE bookings
         SET status = 'cancelled'
         WHERE user_id IN (?)
           AND starts_at > NOW()
           AND status IN ('confirmed', 'pending', 'in_progress')`,
        [memberIds],
      );
      await conn.query(
        `UPDATE waitlist_entries
         SET status = 'cancelled'
         WHERE user_id IN (?) AND status IN ('waiting', 'offered')`,
        [memberIds],
      );
      await conn.query(
        `UPDATE dropin_bookings
         SET status = 'cancelled', guest_name = NULL, guest_email = NULL, guest_phone = NULL
         WHERE user_id IN (?)
           AND status IN ('pending', 'confirmed')
           AND booking_date >= CURDATE()`,
        [memberIds],
      );
      await conn.query(
        `UPDATE users
         SET global_user_id = NULL,
             full_name = 'Διαγραμμένος λογαριασμός',
             email = NULL,
             phone = NULL,
             notes = NULL,
             date_of_birth = NULL,
             weight_kg = NULL,
             deleted_at = NOW()
         WHERE id IN (?)`,
        [memberIds],
      );
    }

    await conn.query('UPDATE staff SET global_user_id = NULL WHERE global_user_id = ?', [id]);
    await conn.query('DELETE FROM gym_join_requests WHERE global_user_id = ?', [id]);
    await conn.query('DELETE FROM global_user_notifications WHERE global_user_id = ?', [id]);
    await conn.query('DELETE FROM global_device_tokens WHERE global_user_id = ?', [id]);
    if (account.phone) {
      await conn.query('DELETE FROM global_otps WHERE phone = ?', [account.phone]);
    }
    await conn.query('DELETE FROM global_users WHERE id = ?', [id]);
    await conn.commit();
    return res.json({ ok: true });
  } catch (err) {
    await conn.rollback();
    console.error('[delete account]', err.message);
    return res.status(500).json({ error: 'Η διαγραφή δεν ολοκληρώθηκε. Δοκίμασε ξανά.' });
  } finally {
    conn.release();
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

    const memberIds = gyms.filter(g => g.user_type !== 'staff').map(g => g.user_id).filter(Boolean);
    const staffIds = gyms.filter(g => g.user_type === 'staff').map(g => g.staff_id || g.user_id).filter(Boolean);

    const selectSql = `
      SELECT b.id,
             DATE_FORMAT(b.starts_at, '%Y-%m-%d') AS booking_date,
             DATE_FORMAT(b.starts_at, '%H:%i:%s') AS booking_time,
             b.status,
             s.name AS service_name, s.duration_mins, s.image_url AS service_image_url,
             st.full_name AS staff_name,
             u.full_name AS client_name,
             biz.id AS business_id, biz.name AS business_name,
             b.location_id, loc.name AS location_name,
             COALESCE(bc.app_name, biz.name) AS app_name, bc.primary_color, bc.logo_url`;
    const fromSql = `
      FROM bookings b
      JOIN services s ON s.id = b.service_id
      LEFT JOIN staff st ON st.id = b.staff_id
      LEFT JOIN users u ON u.id = b.user_id
      JOIN businesses biz ON biz.id = b.business_id
      LEFT JOIN locations loc ON loc.id = b.location_id
      LEFT JOIN business_configs bc ON bc.business_id = b.business_id`;
    const windowSql = `
        AND b.starts_at >= DATE_SUB(CURDATE(), INTERVAL 60 DAY)
        AND b.status IN ('pending','confirmed')`;

    const parts = [];
    const params = [];
    if (memberIds.length) {
      parts.push(`${selectSql}, 'member' AS role ${fromSql}
        WHERE b.user_id IN (?) ${windowSql}`);
      params.push(memberIds);
    }
    if (staffIds.length) {
      parts.push(`${selectSql}, 'staff' AS role ${fromSql}
        WHERE b.staff_id IN (?) ${windowSql}`);
      params.push(staffIds);
    }
    if (memberIds.length) {
      const [[gu]] = await db.query(
        'SELECT phone FROM global_users WHERE id = ?',
        [req.globalUser.globalUserId],
      );
      const digits = String(gu?.phone || '').replace(/\D/g, '');
      const phoneMatch = digits.length >= 10 ? `OR ${phoneLast10Eq('db.guest_phone')}` : '';
      parts.push(`
        SELECT db.id,
               DATE_FORMAT(db.booking_date, '%Y-%m-%d') AS booking_date,
               DATE_FORMAT(db.booking_time, '%H:%i:%s') AS booking_time,
               db.status,
               COALESCE(s.name, db.service_name) AS service_name,
               CAST(COALESCE(s.duration_mins, 60) AS UNSIGNED) AS duration_mins,
               s.image_url AS service_image_url,
               db.staff_name,
               COALESCE(u.full_name, db.guest_name) AS client_name,
               biz.id AS business_id, biz.name AS business_name,
               NULL AS location_id, NULL AS location_name,
               COALESCE(bc.app_name, biz.name) AS app_name, bc.primary_color, bc.logo_url,
               'member' AS role
        FROM dropin_bookings db
        LEFT JOIN services s ON s.id = db.service_id
        LEFT JOIN users u ON u.id = db.user_id
        JOIN businesses biz ON biz.id = db.business_id
        LEFT JOIN business_configs bc ON bc.business_id = db.business_id
        WHERE (db.user_id IN (?) ${phoneMatch})
          AND db.booking_date >= DATE_SUB(CURDATE(), INTERVAL 60 DAY)
          AND db.status IN ('pending','confirmed')
          AND db.payment_status IN ('paid','pending')
          AND (db.booking_id IS NULL OR NOT EXISTS (
            SELECT 1 FROM bookings b WHERE b.id = db.booking_id
          ))`);
      params.push(memberIds);
      if (digits.length >= 10) params.push(digits);
    }
    if (!parts.length) return res.json({ gyms, upcoming_bookings: [] });

    const [bookings] = await db.query(
      `${parts.join(' UNION ALL ')} ORDER BY booking_date ASC, booking_time ASC LIMIT 300`,
      params,
    );

    const bizIds = [...new Set(gyms.map((g) => g.business_id).filter(Boolean))];
    const locations = await locationsForMember(db, { bizIds, memberIds, staffIds });

    let memberships = [];
    if (memberIds.length) {
      const [rows] = await db.query(
        `SELECT um.user_id, um.business_id,
                COALESCE(bp.name, um.notes, 'Πακέτο') AS plan_name,
                um.total_sessions, um.used_sessions, um.valid_until
         FROM user_memberships um
         LEFT JOIN business_plans bp ON bp.id = um.plan_id
         WHERE um.user_id IN (?)
           AND (um.valid_until IS NULL OR um.valid_until >= CURDATE())
           AND (um.membership_status IS NULL OR um.membership_status IN ('active', 'trial'))
         ORDER BY um.valid_from DESC`,
        [memberIds],
      );
      memberships = rows;
    }
    return res.json({ gyms, upcoming_bookings: bookings, locations, memberships });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
});

router.get('/me/documents', requireGlobal, async (req, res) => {
  try {
    const gyms = await getGymsForGlobalUser(req.globalUser.globalUserId);
    const userIds = [...new Set(gyms.map((g) => g.user_id).filter(Boolean))];
    if (!userIds.length) return res.json([]);
    const [rows] = await db.query(
      `SELECT g.id, g.user_id, g.business_id, g.kind, g.title, g.program_name, g.full_name,
              g.signed_at, g.expires_at, g.created_at, g.body_snapshot,
              COALESCE(bc.app_name, b.name) AS gym_name
       FROM gdpr_consents g
       JOIN businesses b ON b.id = g.business_id
       LEFT JOIN business_configs bc ON bc.business_id = g.business_id
       WHERE g.user_id IN (?)
       ORDER BY g.signed_at IS NULL DESC, g.created_at DESC
       LIMIT 50`,
      [userIds],
    ).catch(() => [[]]);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/me/documents/:id', requireGlobal, async (req, res) => {
  try {
    const gyms = await getGymsForGlobalUser(req.globalUser.globalUserId);
    const userIds = [...new Set(gyms.map((g) => g.user_id).filter(Boolean))];
    if (!userIds.length) return res.status(404).json({ error: 'Δεν βρέθηκε' });
    const [[row]] = await db.query(
      `SELECT g.*, COALESCE(bc.app_name, b.name) AS gym_name, bc.gdpr_text
       FROM gdpr_consents g
       JOIN businesses b ON b.id = g.business_id
       LEFT JOIN business_configs bc ON bc.business_id = g.business_id
       WHERE g.id = ? AND g.user_id IN (?)`,
      [req.params.id, userIds],
    );
    if (!row) return res.status(404).json({ error: 'Δεν βρέθηκε' });
    res.json({
      id: row.id,
      kind: row.kind || 'gdpr',
      title: row.title,
      program_name: row.program_name,
      full_name: row.full_name,
      gym_name: row.gym_name,
      signed_at: row.signed_at,
      body: row.body_snapshot || row.gdpr_text || '',
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/me/documents/:id/sign', requireGlobal, async (req, res) => {
  const { signature_data } = req.body || {};
  if (!signature_data) return res.status(400).json({ error: 'Signature required' });
  try {
    const gyms = await getGymsForGlobalUser(req.globalUser.globalUserId);
    const userIds = [...new Set(gyms.map((g) => g.user_id).filter(Boolean))];
    if (!userIds.length) return res.status(404).json({ error: 'Δεν βρέθηκε' });
    const [[row]] = await db.query(
      'SELECT id, signed_at, expires_at FROM gdpr_consents WHERE id = ? AND user_id IN (?)',
      [req.params.id, userIds],
    );
    if (!row) return res.status(404).json({ error: 'Δεν βρέθηκε' });
    if (new Date(row.expires_at) < new Date()) return res.status(410).json({ error: 'Το έγγραφο έχει λήξει' });
    if (row.signed_at) return res.json({ ok: true, already_signed: true });
    const ip = req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.socket.remoteAddress;
    await db.query(
      'UPDATE gdpr_consents SET signed_at = NOW(), signature_data = ?, ip_address = ? WHERE id = ?',
      [signature_data, ip, row.id],
    );
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/me/notifications', requireGlobal, async (req, res) => {
  try {
    const gyms = await getGymsForGlobalUser(req.globalUser.globalUserId);
    const userIds = [...new Set(gyms.map((g) => g.user_id).filter(Boolean))];
    const [rows] = userIds.length
      ? await db.query(
        `SELECT n.id, n.type, n.title, n.body, n.payload, n.is_read, n.created_at, n.business_id,
                COALESCE(bc.app_name, biz.name) AS gym_name
         FROM user_notifications n
         JOIN businesses biz ON (biz.id COLLATE utf8mb4_unicode_ci) = (n.business_id COLLATE utf8mb4_unicode_ci)
         LEFT JOIN business_configs bc ON (bc.business_id COLLATE utf8mb4_unicode_ci) = (n.business_id COLLATE utf8mb4_unicode_ci)
         WHERE (n.user_id COLLATE utf8mb4_unicode_ci) IN (?)
         ORDER BY n.created_at DESC
         LIMIT 80`,
        [userIds],
      )
      : [[]];
    const [platform] = await db.query(
      `SELECT id, type, title, body, is_read, created_at, NULL AS business_id, 'OmniPlex' AS gym_name
       FROM global_user_notifications
       WHERE global_user_id = ?
       ORDER BY created_at DESC
       LIMIT 40`,
      [req.globalUser.globalUserId],
    ).catch(() => [[]]);
    const notifications = [...rows, ...(platform || [])]
      .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
      .slice(0, 80);
    return res.json({
      notifications,
      unread_count: notifications.filter((row) => !row.is_read).length,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
});

router.patch('/me/notifications/:id/read', requireGlobal, async (req, res) => {
  try {
    const gyms = await getGymsForGlobalUser(req.globalUser.globalUserId);
    const userIds = [...new Set(gyms.map((g) => g.user_id).filter(Boolean))];
    if (userIds.length) {
      await db.query(
        'UPDATE user_notifications SET is_read = 1 WHERE id = ? AND user_id IN (?)',
        [req.params.id, userIds],
      );
    }
    await db.query(
      'UPDATE global_user_notifications SET is_read = 1 WHERE id = ? AND global_user_id = ?',
      [req.params.id, req.globalUser.globalUserId],
    ).catch(() => {});
    return res.json({ ok: true });
  } catch (err) {
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
      `SELECT u.id, u.business_id, u.email, u.full_name,
              COALESCE(u.account_status, 'active') AS status, u.phone
       FROM users u
       WHERE u.global_user_id = ? AND u.business_id = ? AND u.deleted_at IS NULL`,
      [req.globalUser.globalUserId, business_id],
    );
    if (!rows.length) return res.status(404).json({ error: 'Δεν είσαι μέλος αυτού του γυμναστηρίου' });

    const u = rows[0];
    if (u.status !== 'active') {
      const msg = u.status === 'pending'
        ? 'Ο λογαριασμός σου εκκρεμεί έγκριση'
        : 'Ο λογαριασμός δεν είναι ενεργός';
      return res.status(403).json({ error: msg, account_status: u.status });
    }

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
  const lat = parseFloat(req.query.lat);
  const lng = parseFloat(req.query.lng);
  const hasLocation = !isNaN(lat) && !isNaN(lng);

  // A typed name can still find a gym. Filters and nearby only list gyms that opted in.
  const requireDiscoverable = q.trim().length < 2;
  const conditions = ['b.is_active = 1'];
  const params = [];
  if (requireDiscoverable) {
    conditions.push('((l.id IS NULL AND b.is_discoverable = 1) OR (l.id IS NOT NULL AND l.is_discoverable = 1))');
  }

  if (q.trim().length >= 2) {
    const like = `%${q.trim()}%`;
    conditions.push(`(b.name LIKE ? OR b.slug LIKE ? OR c.app_name LIKE ?
      OR l.name LIKE ? OR l.city LIKE ? OR l.area LIKE ? OR l.address LIKE ? OR l.program_tags LIKE ?
      OR b.city LIKE ? OR b.area LIKE ? OR b.address LIKE ? OR b.program_tags LIKE ?)`);
    params.push(like, like, like, like, like, like, like, like, like, like, like, like);
  }
  if (city.trim()) {
    conditions.push('(l.city LIKE ? OR (l.id IS NULL AND b.city LIKE ?))');
    params.push(`%${city.trim()}%`, `%${city.trim()}%`);
  }

  const placeLat = 'IF(l.id IS NULL, b.latitude, l.latitude)';
  const placeLng = 'IF(l.id IS NULL, b.longitude, l.longitude)';
  const distanceExpr = hasLocation
    ? `(6371 * 2 * ASIN(SQRT(
         POWER(SIN((RADIANS(${placeLat}) - RADIANS(?)) / 2), 2) +
         COS(RADIANS(?)) * COS(RADIANS(${placeLat})) *
         POWER(SIN((RADIANS(${placeLng}) - RADIANS(?)) / 2), 2)
       )))`
    : 'NULL';

  const tagAliases = {
    δύναμη: ['Δύναμη', 'Strength'],
    strength: ['Δύναμη', 'Strength'],
    κολύμβηση: ['Κολύμβηση', 'Swimming'],
    swimming: ['Κολύμβηση', 'Swimming'],
  };
  const programs = String(service).split(',').map((s) => s.trim()).filter(Boolean);
  if (programs.length) {
    const ors = [];
    for (const program of programs) {
      const names = tagAliases[program.toLowerCase()] || [program];
      for (const name of names) {
        ors.push(`(l.program_tags LIKE ? OR (l.id IS NULL AND b.program_tags LIKE ?) OR EXISTS (
          SELECT 1 FROM services sv
          LEFT JOIN service_locations sl ON sl.service_id = sv.id
          WHERE sv.business_id = b.id AND sv.is_active = 1 AND sv.name LIKE ?
            AND (l.id IS NULL OR sl.location_id = l.id OR sl.location_id IS NULL)
        ))`);
        params.push(`%${name}%`, `%${name}%`, `%${name}%`);
      }
    }
    conditions.push(`(${ors.join(' OR ')})`);
  }
  const amenities = String(req.query.amenities || '').split(',').map((s) => s.trim()).filter(Boolean);
  for (const amenity of amenities) {
    conditions.push('(l.amenity_tags LIKE ? OR (l.id IS NULL AND b.amenity_tags LIKE ?))');
    params.push(`%${amenity}%`, `%${amenity}%`);
  }

  try {
    const distParams = hasLocation ? [lat, lat, lng] : [];
    const sql = `
        SELECT b.id, b.slug, b.name, b.business_type,
               IF(l.id IS NULL, b.city, l.city) AS city,
               IF(l.id IS NULL, b.area, l.area) AS area,
               IF(l.id IS NULL, b.address, l.address) AS address,
               IF(l.id IS NULL, b.description, l.description) AS description,
               ${placeLat} AS latitude,
               ${placeLng} AS longitude,
               l.id AS location_id, l.name AS location_name, l.opening_hours,
               c.app_name, c.primary_color, c.logo_url,
               COALESCE(
                 (SELECT url FROM gym_photos gp WHERE gp.business_id = b.id AND gp.location_id <=> l.id ORDER BY gp.is_cover DESC, gp.display_order ASC, gp.created_at ASC LIMIT 1),
                 (SELECT url FROM gym_photos gp WHERE gp.business_id = b.id AND gp.location_id IS NULL ORDER BY gp.is_cover DESC, gp.display_order ASC, gp.created_at ASC LIMIT 1)
               ) AS cover_url,
               (IF(l.id IS NULL, b.accepts_drop_in, l.accepts_drop_in) = 1
                 OR EXISTS (
                   SELECT 1 FROM dropin_offers dof
                   WHERE dof.business_id = b.id AND dof.is_active = 1
                     AND (l.id IS NULL OR dof.location_id = l.id)
                 )
               ) AS has_drop_in,
               ${distanceExpr} AS distance_km
        FROM businesses b
        LEFT JOIN locations l ON l.business_id = b.id AND l.is_active = 1
        LEFT JOIN business_configs c ON c.business_id = b.id
        WHERE ${conditions.join(' AND ')}
        ORDER BY ${hasLocation ? 'distance_km IS NULL ASC, distance_km ASC' : 'b.name ASC, l.name ASC'}
        LIMIT 80
      `;

    const [rows] = await db.query(sql, [...distParams, ...params]);

    const bizIds = [...new Set(rows.map((r) => r.id))];
    const servicesByLoc = {};
    const servicesByBiz = {};
    if (bizIds.length) {
      const [svcRows] = await db.query(
        `SELECT sv.business_id, sv.name, sl.location_id
         FROM services sv
         LEFT JOIN service_locations sl ON sl.service_id = sv.id
         WHERE sv.business_id IN (?) AND sv.is_active = 1
         ORDER BY sv.name ASC`,
        [bizIds],
      );
      for (const s of svcRows) {
        if (!servicesByBiz[s.business_id]) servicesByBiz[s.business_id] = [];
        if (!servicesByBiz[s.business_id].includes(s.name)) servicesByBiz[s.business_id].push(s.name);
        if (s.location_id) {
          if (!servicesByLoc[s.location_id]) servicesByLoc[s.location_id] = [];
          if (!servicesByLoc[s.location_id].includes(s.name)) servicesByLoc[s.location_id].push(s.name);
        }
      }
    }

    const maxDistance = parseFloat(req.query.max_distance);
    const limited = rows.filter((r) => {
      if (Number.isNaN(maxDistance)) return true;
      const km = r.distance_km == null ? null : Number(r.distance_km);
      return km != null && km <= maxDistance;
    }).slice(0, 30);

    return res.json(limited.map((r) => {
      const brand = r.app_name || r.name;
      const described = describeHours(r.opening_hours);
      return {
        business_id:   r.id,
        slug:          r.slug,
        location_id:   r.location_id || null,
        location_name: r.location_name || null,
        name:          r.name,
        app_name:      r.location_name ? `${brand} · ${r.location_name}` : brand,
        business_type: r.business_type,
        city:          r.city || null,
        area:          r.area || null,
        address:       r.address || null,
        description:   r.description || null,
        primary_color: r.primary_color || '#B8F55E',
        logo_url:      r.logo_url || null,
        cover_url:     r.cover_url || null,
        services:      (r.location_id && servicesByLoc[r.location_id]?.length)
          ? servicesByLoc[r.location_id]
          : (servicesByBiz[r.id] || []),
        hours:         described?.summary ? [{ name: null, summary: described.summary }] : [],
        latitude:      r.latitude  != null ? parseFloat(r.latitude)  : null,
        longitude:     r.longitude != null ? parseFloat(r.longitude) : null,
        distance_km:   r.distance_km != null ? parseFloat(Number(r.distance_km).toFixed(1)) : null,
        has_drop_in:   !!r.has_drop_in,
      };
    }));
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
      SELECT b.id, b.slug, b.name, b.business_type, b.city, b.area, b.address, b.description, b.latitude, b.longitude,
             b.accepts_drop_in, b.drop_in_price_cents,
             c.app_name, c.primary_color, c.secondary_color, c.logo_url, c.feature_online_payments
      FROM businesses b
      LEFT JOIN business_configs c ON c.business_id = b.id
      WHERE b.slug = ? AND b.is_active = 1
    `, [req.params.slug]);
    if (!rows.length) return res.status(404).json({ error: 'Gym not found' });

    const biz = rows[0];
    const locationId = String(req.query.location_id || '').trim() || null;
    let place = null;
    if (locationId) {
      const [[loc]] = await db.query(
        `SELECT id, name, city, address, area, latitude, longitude, description, phone, accepts_drop_in, opening_hours
         FROM locations WHERE id = ? AND business_id = ? AND is_active = 1`,
        [locationId, biz.id],
      );
      if (!loc) return res.status(404).json({ error: 'Το κατάστημα δεν βρέθηκε' });
      place = loc;
    }
    const [services] = await db.query(
      `SELECT s.id, s.name, s.duration_mins, s.category, s.description, s.image_url, s.drop_in_price_cents
       FROM services s
       WHERE s.business_id = ? AND s.is_active = 1
         AND (? IS NULL
           OR EXISTS (SELECT 1 FROM service_locations sl WHERE sl.service_id = s.id AND sl.location_id = ?)
           OR NOT EXISTS (SELECT 1 FROM service_locations sl WHERE sl.service_id = s.id))
       ORDER BY s.name ASC`,
      [biz.id, locationId, locationId],
    );
    const [photoRows] = await db.query(
      `SELECT id, url, is_cover, location_id FROM gym_photos
       WHERE business_id = ?
         AND (? IS NULL OR location_id = ? OR location_id IS NULL)
       ORDER BY is_cover DESC, display_order, created_at`,
      [biz.id, locationId, locationId],
    );
    const ownPhotos = locationId ? photoRows.filter((p) => p.location_id === locationId) : photoRows;
    const photos = (ownPhotos.length ? ownPhotos : photoRows).map(({ location_id, ...p }) => p);
    const [gymTrainers] = await db.query(
      `SELECT id, name, specialty, photo_url FROM gym_trainers
       WHERE business_id = ?
         AND (? IS NULL OR location_id = ? OR location_id IS NULL)
       ORDER BY display_order, created_at`,
      [biz.id, locationId, locationId],
    );
    const [staffTrainers] = await db.query(
      `SELECT st.id, st.full_name AS name, COALESCE(st.discovery_specialty, st.role) AS specialty, st.avatar_url AS photo_url
       FROM staff st
       WHERE st.business_id = ? AND st.show_in_discovery = 1
         AND (? IS NULL
           OR EXISTS (SELECT 1 FROM staff_locations sl WHERE sl.staff_id = st.id AND sl.location_id = ?)
           OR NOT EXISTS (SELECT 1 FROM staff_locations sl WHERE sl.staff_id = st.id))
       ORDER BY st.full_name`,
      [biz.id, locationId, locationId],
    );
    const trainers = [...staffTrainers, ...gymTrainers];
    let locations = [];
    try {
      const [locRows] = await db.query(
        `SELECT id, name, city, address, accepts_drop_in, opening_hours
         FROM locations WHERE business_id = ? AND is_active = 1
         ORDER BY sort_order, name`,
        [biz.id],
      );
      let businessHours = null;
      try {
        const [[cfg]] = await db.query(
          'SELECT opening_hours FROM business_configs WHERE business_id = ?',
          [biz.id],
        );
        businessHours = describeHours(cfg?.opening_hours);
      } catch (_) {}
      const visibleRows = locationId ? locRows.filter((l) => l.id === locationId) : locRows;
      locations = visibleRows.map((l) => {
        const described = describeHours(l.opening_hours) || businessHours;
        return {
          id: l.id,
          name: l.name,
          city: l.city,
          address: l.address,
          accepts_drop_in: !!l.accepts_drop_in,
          hours: described?.days || [],
          hours_summary: described?.summary || null,
        };
      });
      if (!locations.length && businessHours) {
        locations = [{
          id: null,
          name: biz.app_name || biz.name,
          city: biz.city || null,
          address: biz.address || null,
          accepts_drop_in: !!biz.accepts_drop_in,
          hours: businessHours.days,
          hours_summary: businessHours.summary,
        }];
      }
    } catch (_) {}
    const [plans] = await db.query(
      `SELECT bp.id, COALESCE(bp.discovery_name, bp.name) AS name, bp.price_cents, bp.sale_price_cents, bp.image_url, bp.sessions, bp.duration_mins, bp.billing_period
       FROM business_plans bp
       WHERE bp.business_id = ? AND bp.is_active = 1 AND bp.show_in_discovery = 1 AND bp.plan_type = 'service'
         AND (? IS NULL
           OR NOT EXISTS (SELECT 1 FROM plan_service_items psi WHERE psi.plan_id = bp.id)
           OR EXISTS (
             SELECT 1 FROM plan_service_items psi
             JOIN service_locations sl ON sl.service_id = psi.service_id
             WHERE psi.plan_id = bp.id AND sl.location_id = ?
           ))
         AND (? IS NULL
           OR NOT EXISTS (SELECT 1 FROM plan_locations pl WHERE pl.plan_id = bp.id)
           OR EXISTS (SELECT 1 FROM plan_locations pl WHERE pl.plan_id = bp.id AND pl.location_id = ?))
       ORDER BY bp.sort_order, bp.price_cents`,
      [biz.id, locationId, locationId, locationId, locationId],
    );
    const [schedule] = await db.query(
      `SELECT sss.id, sss.weekday AS day_of_week, sss.start_time,
              COALESCE(sss.label, s.name) AS class_name,
              st.full_name AS trainer_name,
              sss.icon_key AS color,
              sss.subtitle AS equipment,
              sss.max_capacity, sss.image_url
       FROM service_slot_schedules sss
       JOIN services s ON s.id = sss.service_id
       LEFT JOIN staff st ON st.id = sss.staff_id
       WHERE sss.business_id = ? AND sss.is_active = 1
         AND (? IS NULL
           OR sss.location_id = ?
           OR (sss.location_id IS NULL AND NOT EXISTS (
             SELECT 1 FROM service_slot_schedules owned
             WHERE owned.business_id = sss.business_id AND owned.location_id = ? AND owned.is_active = 1
           )))
       ORDER BY sss.weekday, sss.start_time`,
      [biz.id, locationId, locationId, locationId],
    );

    let dropinServices = [];
    try {
      const [offerRows] = await db.query(
        `SELECT s.id, s.name, s.duration_mins, o.price_cents AS drop_in_price_cents,
                o.location_id, l.name AS location_name
         FROM dropin_offers o
         JOIN services s ON s.id = o.service_id
         LEFT JOIN locations l ON l.id = o.location_id
         WHERE o.business_id = ? AND o.is_active = 1 AND s.is_active = 1
           AND (? IS NULL OR o.location_id = ?)
         ORDER BY s.name`,
        [biz.id, locationId, locationId],
      );
      dropinServices = offerRows;
      if (!dropinServices.length) {
        const [priced] = await db.query(
          `SELECT id, name, duration_mins, drop_in_price_cents, NULL AS location_id, NULL AS location_name
           FROM services
           WHERE business_id = ? AND is_active = 1 AND drop_in_price_cents > 0
           ORDER BY name`,
          [biz.id],
        );
        dropinServices = priced;
      }
    } catch (_) {}
    const coverPhoto = photos.find(p => p.is_cover) || photos[0] || null;
    const dropInOn = place
      ? (!!place.accepts_drop_in || dropinServices.length > 0)
      : (!!biz.accepts_drop_in || locations.some((l) => l.accepts_drop_in) || dropinServices.length > 0);
    const brand = biz.app_name || biz.name;
    return res.json({
      business_id:       biz.id,
      slug:              biz.slug,
      location_id:       place?.id || null,
      location_name:     place?.name || null,
      name:              biz.name,
      app_name:          place ? `${brand} · ${place.name}` : brand,
      business_type:     biz.business_type,
      city:              place ? (place.city || null) : (biz.city || null),
      area:              place ? (place.area || null) : (biz.area || null),
      address:           place ? (place.address || null) : (biz.address || null),
      description:       place ? (place.description || null) : (biz.description || null),
      phone:             place?.phone || null,
      latitude:          place ? place.latitude : biz.latitude,
      longitude:         place ? place.longitude : biz.longitude,
      primary_color:     biz.primary_color || '#B8F55E',
      secondary_color:   biz.secondary_color || null,
      logo_url:          biz.logo_url || null,
      cover_url:         coverPhoto?.url || null,
      online_payments:   !!biz.feature_online_payments,
      accepts_drop_in:       dropInOn,
      drop_in_price_cents:   biz.drop_in_price_cents || 0,
      dropin_services:       dropinServices,
      photos,
      trainers,
      schedule,
      services,
      plans,
      locations,
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
function placeholderName(name) {
  const value = String(name || '').trim();
  return !value || /^Χρήστης\s+\d+$/.test(value);
}

async function claimExistingGym(globalUserId, businessId) {
  const [[gu]] = await db.query(
    'SELECT id, phone, email, full_name FROM global_users WHERE id = ?',
    [globalUserId],
  );
  if (!gu) return null;
  const digits = String(gu.phone || '').replace(/\D/g, '');
  if (digits.length < 10) return null;

  const [members] = await db.query(
    `SELECT id, full_name, email, phone FROM users
     WHERE business_id = ? AND deleted_at IS NULL
       AND (global_user_id IS NULL OR global_user_id = ?)
       AND ${phoneLast10Eq('phone')}`,
    [businessId, globalUserId, digits],
  );
  const [staffRows] = await db.query(
    `SELECT id, full_name, phone FROM staff
     WHERE business_id = ? AND is_active = 1
       AND (global_user_id IS NULL OR global_user_id = ?)
       AND ${phoneLast10Eq('phone')}`,
    [businessId, globalUserId, digits],
  );
  if (!members.length && !staffRows.length) return null;

  for (const member of members) {
    await db.query(
      'UPDATE users SET global_user_id = ? WHERE id = ?',
      [globalUserId, member.id],
    );
  }
  for (const staff of staffRows) {
    await db.query(
      'UPDATE staff SET global_user_id = ? WHERE id = ?',
      [globalUserId, staff.id],
    );
  }

  await copyStoredProfile(globalUserId);
  await db.query(
    `UPDATE gym_join_requests SET status = 'approved'
     WHERE global_user_id = ? AND business_id = ? AND status = 'pending'`,
    [globalUserId, businessId],
  );

  const [[user]] = await db.query(
    'SELECT id, email, full_name, phone FROM global_users WHERE id = ?',
    [globalUserId],
  );
  const gyms = await getGymsForGlobalUser(globalUserId);
  return { status: 'linked', user, gyms, message: 'Το γυμναστήριο προστέθηκε με τα στοιχεία που έχει ήδη ο διαχειριστής.' };
}

// POST /api/global/gyms/claim  (auth)
// If this phone already exists as a client or staff member, link it now.
router.post('/gyms/claim', requireGlobal, async (req, res) => {
  const businessId = req.body?.business_id;
  if (!businessId) return res.status(400).json({ error: 'business_id required' });
  try {
    const claimed = await claimExistingGym(req.globalUser.globalUserId, businessId);
    if (!claimed) return res.json({ status: 'not_found' });
    return res.json(claimed);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/global/join-requests  (auth)
// Body: { business_id }
// Creates a join request, or links an existing admin-created record.
// ============================================================
router.post('/join-requests', requireGlobal, async (req, res) => {
  const { business_id, role = 'member', location_id, full_name: formName, phone: formPhone, email: formEmail, date_of_birth, specialty } = req.body;
  if (!business_id) return res.status(400).json({ error: 'business_id required' });

  const { globalUserId, email: tokenEmail, fullName } = req.globalUser;

  try {
    // Get user details (form data takes priority over stored data)
    if (role !== 'member' && role !== 'staff') {
      return res.status(400).json({ error: 'role must be member or staff' });
    }
    const isStaff = role === 'staff';

    const [guRows] = await db.query('SELECT phone, full_name, email FROM global_users WHERE id = ?', [globalUserId]);
    if (!guRows.length) return res.status(404).json({ error: 'Global user not found' });
    const phone = guRows[0].phone || formPhone?.trim() || null;
    const name  = (guRows[0].full_name || '').trim() || formName?.trim() || fullName || '';
    const email = guRows[0].email || formEmail?.trim() || tokenEmail || '';

    const [bizRows] = await db.query('SELECT id, name FROM businesses WHERE id = ? AND is_active = 1', [business_id]);
    if (!bizRows.length) return res.status(404).json({ error: 'Gym not found' });

    let locationId = location_id || null;
    if (locationId) {
      const [[loc]] = await db.query(
        'SELECT id FROM locations WHERE id = ? AND business_id = ? AND is_active = 1',
        [locationId, business_id],
      );
      if (!loc) return res.status(400).json({ error: 'Το κατάστημα δεν βρέθηκε' });
    } else {
      const [locs] = await db.query(
        'SELECT id FROM locations WHERE business_id = ? AND is_active = 1',
        [business_id],
      );
      if (locs.length > 1) {
        return res.status(400).json({ error: 'Επίλεξε κατάστημα', code: 'LOCATION_REQUIRED' });
      }
      locationId = locs[0]?.id || null;
    }

    if (isStaff) {
      const [linkedStaff] = await db.query(
        'SELECT id, role AS staff_role, COALESCE(is_nutritionist, 0) AS is_nutritionist FROM staff WHERE global_user_id = ? AND business_id = ? AND is_active = 1',
        [globalUserId, business_id],
      );
      if (linkedStaff.length) {
        const kind = staffKindFromRow({ specialty, is_nutritionist: 0 });
        const have = staffKindsFromRow(linkedStaff[0]);
        if (have.includes(kind)) {
          const label = kind === 'nutritionist' ? 'διατροφολόγος'
            : kind === 'physiotherapist' ? 'φυσιοθεραπευτής' : 'trainer';
          return res.status(409).json({ error: 'already_linked', message: `Είσαι ήδη ${label} σε αυτό το γυμναστήριο` });
        }
      }
    } else {
      const [linked] = await db.query(
        'SELECT id FROM users WHERE global_user_id = ? AND business_id = ? AND deleted_at IS NULL',
        [globalUserId, business_id],
      );
      if (linked.length) {
        return res.status(409).json({ error: 'already_linked', message: 'Είσαι ήδη μέλος αυτού του γυμναστηρίου' });
      }
    }

    let locationName = null;
    if (locationId) {
      const [[locRow]] = await db.query('SELECT name FROM locations WHERE id = ?', [locationId]);
      locationName = locRow?.name || null;
    }
    const place = locationName ? ` στο κατάστημα ${locationName}` : '';

    const notifyAdmin = async (reqId) => {
      try {
        const { createAdminNotification } = require('../lib/notifications');
        await createAdminNotification(db, {
          businessId: business_id,
          type: 'join_request',
          title: isStaff ? 'Αίτημα προσωπικού' : 'Αίτημα εγγραφής',
          body: isStaff
            ? `${name} ζητά να συνδεθεί ως ${staffKindLabel(specialty)}${place}.`
            : `${name} ζητά να γίνει μέλος${place}.`,
          payload: {
            join_request_id: reqId,
            global_user_id: globalUserId,
            full_name: name,
            email: email || '',
            phone: phone || '',
            role: isStaff ? 'staff' : 'member',
            location_id: locationId,
            location_name: locationName || '',
          },
          locationId,
        });
      } catch (_) {}
    };

    const [existing] = await db.query(
      `SELECT id, status FROM gym_join_requests
       WHERE global_user_id = ? AND business_id = ? AND role = ?
         AND location_id <=> ?`,
      [globalUserId, business_id, isStaff ? 'staff' : 'member', locationId],
    );
    if (existing.length) {
      const current = existing.find((row) => row.status === 'pending') || existing[0];
      if (current.status === 'pending') {
        return res.json({
          status: 'pending',
          role: isStaff ? 'staff' : 'member',
          location_id: locationId,
          message: 'Το αίτημά σου εκκρεμεί έγκριση',
        });
      }
      await db.query(
        `UPDATE gym_join_requests
         SET status = 'pending', full_name = ?, email = ?, phone = ?, specialty = ?, date_of_birth = ?, location_id = ?
         WHERE id = ?`,
        [name, email || '', phone || null, specialty || null, date_of_birth || null, locationId, current.id],
      );
      await notifyAdmin(current.id);
      return res.json({
        status: 'pending',
        role: isStaff ? 'staff' : 'member',
        message: 'Το αίτημά σου εστάλη. Ο διαχειριστής θα σε ειδοποιήσει.',
      });
    }

    const reqId = uuidv4();
    await db.query(
      `INSERT INTO gym_join_requests
        (id, global_user_id, business_id, full_name, email, phone, role, specialty, date_of_birth, location_id)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [reqId, globalUserId, business_id, name, email || '', phone || null, isStaff ? 'staff' : 'member', specialty || null, date_of_birth || null, locationId],
    );
    await notifyAdmin(reqId);
    return res.json({
      status: 'pending',
      role: isStaff ? 'staff' : 'member',
      message: 'Το αίτημά σου στάλθηκε. Ο διαχειριστής θα σε ειδοποιήσει.',
    });
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
      SELECT jr.id, jr.business_id, jr.status, jr.role, jr.specialty, jr.location_id, jr.created_at, jr.admin_note,
             b.name AS business_name, bc.app_name, bc.logo_url, bc.primary_color,
             loc.name AS location_name
      FROM gym_join_requests jr
      JOIN businesses b ON b.id = (jr.business_id COLLATE utf8mb4_unicode_ci)
      LEFT JOIN business_configs bc ON bc.business_id = (jr.business_id COLLATE utf8mb4_unicode_ci)
      LEFT JOIN locations loc ON loc.id = (jr.location_id COLLATE utf8mb4_unicode_ci)
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
// DELETE /api/global/gyms/:businessId  (auth)
// Remove a gym from the user's Omniplex list (unlinks global_user_id)
// ============================================================
// ── GET /api/global/trainer-token  — per-gym trainer JWT for global users linked as staff
router.post('/trainer-token', requireGlobal, async (req, res) => {
  const { business_id } = req.body;
  if (!business_id) return res.status(400).json({ error: 'business_id required' });
  try {
    const [rows] = await db.query(
      `SELECT s.id, s.full_name, s.role, COALESCE(s.is_nutritionist, 0) AS is_nutritionist
       FROM staff s
       WHERE s.global_user_id = ? AND s.business_id = ? AND s.is_active = 1`,
      [req.globalUser.globalUserId, business_id],
    );
    if (!rows.length) return res.status(404).json({ error: 'Staff record not found' });
    const s = rows[0];
    const requested = req.body.as === 'nutritionist' || req.body.as === 'trainer' ? req.body.as : null;
    const kind = requested || staffKindFromRow(s);
    if (kind === 'nutritionist' && Number(s.is_nutritionist) !== 1 && !/διατροφ|nutri/i.test(s.role || '')) {
      return res.status(403).json({ error: 'Δεν έχει εγκριθεί ακόμα η πρόσβαση διατροφολόγου' });
    }
    let nutritionistId = null;
    if (kind === 'nutritionist' || Number(s.is_nutritionist) === 1) {
      const [[nut]] = await db.query(
        'SELECT id FROM nutritionists WHERE business_id = ? AND staff_id = ? AND is_active = 1 LIMIT 1',
        [business_id, s.id],
      );
      nutritionistId = nut?.id || null;
    }
    const token = jwt.sign(
      {
        businessId: business_id,
        email: req.globalUser.email || '',
        role: kind === 'nutritionist' ? 'nutritionist' : 'trainer',
        name: s.full_name,
        staffId: s.id,
        nutritionistId,
        staffKind: kind,
      },
      process.env.JWT_SECRET,
      { expiresIn: '7d' },
    );
    return res.json({ token, staff_kind: kind });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.delete('/gyms/:businessId', requireGlobal, async (req, res) => {
  const { businessId } = req.params;
  const role = req.query.role;
  if (role && role !== 'member' && role !== 'staff') {
    return res.status(400).json({ error: 'role must be member or staff' });
  }
  const unlinkMember = !role || role === 'member';
  const unlinkStaff = !role || role === 'staff';
  try {
    const [memberPlaces] = unlinkMember ? await db.query(`
      SELECT DISTINCT ul.location_id
      FROM users u
      JOIN user_locations ul ON ul.user_id = u.id
      WHERE u.global_user_id = ? AND u.business_id = ? AND u.deleted_at IS NULL
    `, [req.globalUser.globalUserId, businessId]) : [[]];
    const [staffPlaces] = unlinkStaff ? await db.query(`
      SELECT DISTINCT sl.location_id
      FROM staff s
      JOIN staff_locations sl ON sl.staff_id = s.id
      WHERE s.global_user_id = ? AND s.business_id = ? AND s.is_active = 1
    `, [req.globalUser.globalUserId, businessId]) : [[]];
    const leaveLocations = [...new Set([
      ...memberPlaces.map((row) => row.location_id),
      ...staffPlaces.map((row) => row.location_id),
    ].filter(Boolean))];

    let memberRows = 0;
    let staffRows = 0;
    if (unlinkMember) {
      const [memberResult] = await db.query(
        `UPDATE users SET global_user_id = NULL
         WHERE global_user_id = ? AND business_id = ? AND deleted_at IS NULL`,
        [req.globalUser.globalUserId, businessId],
      );
      memberRows = memberResult.affectedRows;
    }
    if (unlinkStaff) {
      const [staffResult] = await db.query(
        `UPDATE staff SET global_user_id = NULL
         WHERE global_user_id = ? AND business_id = ? AND is_active = 1`,
        [req.globalUser.globalUserId, businessId],
      );
      staffRows = staffResult.affectedRows;
    }

    if (memberRows === 0 && staffRows === 0) {
      return res.status(404).json({ error: 'Gym not found in your list' });
    }

    // Notify gym admin
    try {
      const [[gu]] = await db.query(
        'SELECT full_name FROM global_users WHERE id = ?',
        [req.globalUser.globalUserId],
      );
      const userName = gu?.full_name || req.globalUser.fullName || 'Χρήστης';
      const [[biz]] = await db.query(
        `SELECT b.id, COALESCE(bc.app_name, b.name) AS app_name
         FROM businesses b LEFT JOIN business_configs bc ON bc.business_id = b.id
         WHERE b.id = ?`,
        [businessId],
      );
      const gymName = biz?.app_name || 'γυμναστήριο';
      const { createAdminNotification } = require('../lib/notifications');
      const leftAs = staffRows && memberRows ? 'μέλος και trainer'
        : staffRows ? 'trainer' : 'ασκούμενος';
      const places = leaveLocations.length ? leaveLocations : [null];
      for (const locationId of places) {
        await createAdminNotification(db, {
          businessId,
          type: 'member_left',
          title: 'Αποχώρηση',
          body: `${userName} αφαιρέθηκε ως ${leftAs} από το ${gymName}.`,
          locationId,
          payload: { global_user_id: req.globalUser.globalUserId, user_name: userName, role: role || 'both', location_id: locationId },
        });
      }
    } catch (notifErr) {
      console.error('[NOTIFY] gym-remove admin notification failed:', notifErr.message);
    }

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

    const locationId = String(req.query.location_id || '').trim() || null;
    const [plans] = await db.query(`
      SELECT bp.id, bp.name, bp.sessions, bp.price_cents, bp.billing_period, bp.plan_type, bp.sort_order,
             GROUP_CONCAT(DISTINCT s.name ORDER BY s.name SEPARATOR ', ') AS service_name
      FROM business_plans bp
      LEFT JOIN plan_service_items psi ON psi.plan_id = bp.id
      LEFT JOIN services s ON s.id = psi.service_id
      WHERE bp.business_id = ? AND bp.is_active = 1 AND bp.plan_type != 'nutrition'
        AND (? IS NULL
          OR NOT EXISTS (SELECT 1 FROM plan_service_items x WHERE x.plan_id = bp.id)
          OR EXISTS (
            SELECT 1 FROM plan_service_items x
            JOIN service_locations sl ON sl.service_id = x.service_id
            WHERE x.plan_id = bp.id AND sl.location_id = ?
          ))
        AND (? IS NULL
          OR NOT EXISTS (SELECT 1 FROM plan_locations pl WHERE pl.plan_id = bp.id)
          OR EXISTS (SELECT 1 FROM plan_locations pl WHERE pl.plan_id = bp.id AND pl.location_id = ?))
      GROUP BY bp.id
      ORDER BY bp.sort_order ASC, bp.price_cents ASC
    `, [biz.id, locationId, locationId, locationId, locationId]);
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

    const { loadPlanForBusiness } = require('../lib/member_plan_purchase');
    let plan = await loadPlanForBusiness(conn, biz.id, plan_id);
    if (!plan) {
      const [[legacy]] = await conn.query(
        `SELECT p.*, s.name AS service_name FROM service_plans p
         JOIN services s ON s.id = p.service_id
         WHERE p.id = ? AND s.business_id = ? AND p.is_active = 1`,
        [plan_id, biz.id],
      );
      plan = legacy || null;
    }
    if (!plan) return res.status(404).json({ error: 'Πακέτο δεν βρέθηκε' });

    // Get Stripe config for this gym
    const [[provRow]] = await conn.query(
      `SELECT * FROM payment_providers WHERE business_id = ? AND is_active = 1 LIMIT 1`,
      [biz.id],
    );
    if (!provRow) return res.status(400).json({ error: 'Οι online πληρωμές δεν είναι διαθέσιμες για αυτό το γυμναστήριο' });

    const cfg = typeof provRow.config === 'string' ? JSON.parse(provRow.config) : (provRow.config || {});
    const { assertStripeKeys, hideStripeKeyError } = require('../lib/online_payments');
    assertStripeKeys(cfg);
    const stripe = require('stripe')(cfg.secret_key);

    let intent;
    try {
      intent = await stripe.paymentIntents.create({
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
    } catch (err) {
      throw hideStripeKeyError(err);
    }

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
    return res.status(err.status || 500).json({ error: err.message });
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
  const { intent_id, user_info, plan_id, location_id } = req.body;
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
    const { assertStripeKeys, hideStripeKeyError } = require('../lib/online_payments');
    assertStripeKeys(cfg);
    const stripe = require('stripe')(cfg.secret_key);
    let intent;
    try {
      intent = await stripe.paymentIntents.retrieve(intent_id);
    } catch (err) {
      throw hideStripeKeyError(err);
    }
    if (intent.status !== 'succeeded') {
      return res.status(402).json({ error: 'Η πληρωμή δεν ολοκληρώθηκε' });
    }

    const { loadPlanForBusiness, grantPlanMembership } = require('../lib/member_plan_purchase');
    const businessPlan = await loadPlanForBusiness(conn, biz.id, plan_id);

    let plan = null;
    if (!businessPlan) {
      const [[legacy]] = await conn.query(
        `SELECT p.*, s.name AS service_name, s.id AS service_id FROM service_plans p
         JOIN services s ON s.id = p.service_id
         WHERE p.id = ? AND s.business_id = ?`,
        [plan_id, biz.id],
      );
      plan = legacy || null;
      if (!plan) return res.status(404).json({ error: 'Πακέτο δεν βρέθηκε' });
    }

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
      `SELECT id FROM users WHERE business_id = ? AND deleted_at IS NULL
         AND (phone = ? OR ${phoneLast10Eq('phone')})
       LIMIT 1`,
      [biz.id, phone, phone],
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
        `INSERT INTO users (id, business_id, global_user_id, full_name, email, phone, account_status, created_at)
         VALUES (?,?,?,?,?,?,'active',NOW())`,
        [gymUserId, biz.id, globalUser.id, user_info.full_name || '', String(user_info.email || '').trim() || null, phone],
      );
    }

    if (businessPlan) {
      await conn.beginTransaction();
      await grantPlanMembership(conn, {
        bizId: biz.id,
        userId: gymUserId,
        plan: businessPlan,
        paid: true,
        intentId: intent_id,
        locationId: location_id || null,
      });
      await conn.commit();
    } else {
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
    }

    // Approve/upsert join request
    const [existJR] = await conn.query(
      'SELECT id FROM gym_join_requests WHERE global_user_id = ? AND business_id = ?',
      [globalUser.id, biz.id],
    );
    if (location_id) {
      const [[loc]] = await conn.query(
        'SELECT id FROM locations WHERE id = ? AND business_id = ? AND is_active = 1',
        [location_id, biz.id],
      );
      if (loc) {
        const { replaceUserLocations } = require('../lib/locations');
        await replaceUserLocations(conn, gymUserId, [location_id]);
      }
    }

    if (existJR.length) {
      await conn.query(
        "UPDATE gym_join_requests SET status='approved', role='member', location_id=COALESCE(?, location_id) WHERE id=?",
        [location_id || null, existJR[0].id],
      );
    } else {
      await conn.query(
        `INSERT INTO gym_join_requests (id, global_user_id, business_id, status, role, location_id)
         VALUES (?,?,?,'approved','member',?)`,
        [require('uuid').v4(), globalUser.id, biz.id, location_id || null],
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
    try { await conn.rollback(); } catch (_) {}
    return res.status(err.status || 500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// ── Helper: auto-link global user to existing tenant records ──
async function autoLinkGlobalUser(globalUserId, phone, email) {
  // Match by normalized phone digits OR email
  const normalizePhone = (p) => (p || '').replace(/\D/g, '');
  const phoneDigits = normalizePhone(phone);

  if (phoneDigits.length >= 10) {
    await db.query(
      `UPDATE users
       SET global_user_id = ?
       WHERE global_user_id IS NULL
         AND deleted_at IS NULL
         AND ${phoneLast10Eq('phone')}`,
      [globalUserId, phoneDigits],
    );
    await db.query(
      `UPDATE staff
       SET global_user_id = ?
       WHERE is_active = 1
         AND (global_user_id IS NULL OR global_user_id = ?)
         AND ${phoneLast10Eq('phone')}`,
      [globalUserId, globalUserId, phoneDigits],
    );
  }
  if (email) {
    await db.query(
      `UPDATE users
       SET global_user_id = ?
       WHERE global_user_id IS NULL
         AND deleted_at IS NULL
         AND LOWER(TRIM(email)) = LOWER(TRIM(?))`,
      [globalUserId, email],
    );
  }
  await copyStoredProfile(globalUserId);
}

async function copyStoredProfile(globalUserId) {
  try {
    const [[gu]] = await db.query('SELECT full_name, email FROM global_users WHERE id = ?', [globalUserId]);
    if (!gu) return;
    const nameDone = !placeholderName(gu.full_name);
    const emailDone = String(gu.email || '').trim().length > 0;
    if (nameDone && emailDone) return;
    const [members] = await db.query(
      `SELECT full_name, email FROM users
       WHERE global_user_id = ? AND deleted_at IS NULL`,
      [globalUserId],
    );
    let staffRows = [];
    try {
      [staffRows] = await db.query(
        `SELECT full_name, portal_email AS email FROM staff
         WHERE global_user_id = ? AND is_active = 1`,
        [globalUserId],
      );
    } catch (err) {
      if (err.code !== 'ER_BAD_FIELD_ERROR') throw err;
      [staffRows] = await db.query(
        `SELECT full_name, NULL AS email FROM staff
         WHERE global_user_id = ? AND is_active = 1`,
        [globalUserId],
      );
    }
    const source = [...members, ...staffRows].find((row) => String(row.full_name || '').trim());
    if (!source) return;
    if (!nameDone && String(source.full_name || '').trim()) {
      await db.query('UPDATE global_users SET full_name = ? WHERE id = ?', [source.full_name.trim(), globalUserId]);
    }
    if (!emailDone && String(source.email || '').trim()) {
      await db.query(
        `UPDATE global_users SET email = ? WHERE id = ? AND (email IS NULL OR email = '')`,
        [source.email.trim(), globalUserId],
      );
    }
  } catch (err) {
    console.warn('profile copy skipped:', err.message);
  }
}

// ── Brevo SMS helper ──────────────────────────────────────────
async function sendBrevoSms(phone, message) {
  const apiKey = process.env.BREVO_API_KEY;
  const sender = process.env.BREVO_SMS_SENDER || 'OmniPlex';
  if (!apiKey) throw new Error('BREVO_API_KEY not configured');

  // Normalize to E.164 (Greek +30 prefix if starts with 6/2)
  let to = phone.replace(/\s/g, '');
  if (!to.startsWith('+')) {
    to = '+30' + to.replace(/^0+/, '');
  }

  const resp = await fetch('https://api.brevo.com/v3/transactionalSMS/sms', {
    method: 'POST',
    headers: { 'api-key': apiKey, 'Content-Type': 'application/json' },
    body: JSON.stringify({ sender, recipient: to, content: message }),
  });
  if (!resp.ok) {
    const body = await resp.text();
    throw new Error(`Brevo SMS error ${resp.status}: ${body}`);
  }
}

// ============================================================
// POST /api/global/auth/send-otp
// Body: { phone }   — sends 6-digit OTP via SMS
// ============================================================
router.post('/auth/send-otp', async (req, res) => {
  const { phone } = req.body;
  if (!phone) return res.status(400).json({ error: 'Απαιτείται τηλέφωνο' });

  const digits = phone.replace(/\D/g, '');
  if (digits.length < 10) return res.status(400).json({ error: 'Μη έγκυρος αριθμός τηλεφώνου' });

  try {
    // Rate limit: max 3 OTPs per phone per 10 minutes
    const [[{ cnt }]] = await db.query(
      `SELECT COUNT(*) AS cnt FROM global_otps
       WHERE phone = ? AND created_at > DATE_SUB(NOW(), INTERVAL 10 MINUTE)`,
      [digits],
    );
    if (cnt >= 3) return res.status(429).json({ error: 'Πολλές προσπάθειες. Δοκίμασε σε 10 λεπτά.' });

    const code = String(Math.floor(100000 + Math.random() * 900000));
    const id   = uuidv4();
    await db.query(
      `INSERT INTO global_otps (id, phone, code, expires_at)
       VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL 10 MINUTE))`,
      [id, digits, code],
    );

    let smsSent = false;
    try {
      await sendBrevoSms(phone, `Ο κωδικός επαλήθευσής σου για το OmniPlex είναι ${code}. Ισχύει για 10 λεπτά.`);
      smsSent = true;
    } catch (smsErr) {
      console.error('send-otp SMS error (non-fatal):', smsErr.message);
    }

    return res.json({ ok: true, sms_sent: smsSent });
  } catch (err) {
    console.error('send-otp error:', err.message);
    return res.status(500).json({
      error: 'Αποτυχία. Δοκίμασε ξανά.',
      debug: err.message,
    });
  }
});

// GET /api/global/debug/sms  — checks SMS config (no secrets exposed)
router.get('/debug/sms', async (req, res) => {
  const hasKey    = !!process.env.BREVO_API_KEY;
  const sender    = process.env.BREVO_SMS_SENDER || '(not set, default: OmniPlex)';
  const keyPrefix = hasKey ? process.env.BREVO_API_KEY.slice(0, 12) + '...' : null;
  res.json({ brevo_key_set: hasKey, brevo_key_prefix: keyPrefix, sender });
});

// DELETE /api/global/debug/clear-otps?phone=XXX  — clears rate-limit for a phone (debug only)
router.delete('/debug/clear-otps', async (req, res) => {
  const phone = req.query.phone;
  if (!phone) return res.status(400).json({ error: 'phone required' });
  const digits = String(phone).replace(/\D/g, '');
  await db.query(`DELETE FROM global_otps WHERE phone = ?`, [digits]);
  res.json({ ok: true, cleared: digits });
});

// ============================================================
// POST /api/global/auth/from-gym
// Bearer = gym member or staff JWT. Restores the OmniPlex session
// when the app still has the gym login but lost the global one.
// ============================================================
router.post('/auth/from-gym', async (req, res) => {
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'No token' });
  let decoded;
  try { decoded = jwt.verify(token, process.env.JWT_SECRET); }
  catch { return res.status(401).json({ error: 'Invalid token' }); }

  try {
    let globalUserId = decoded.globalUserId || null;
    if (!globalUserId && decoded.userId) {
      const [[member]] = await db.query(
        'SELECT global_user_id FROM users WHERE id = ? AND deleted_at IS NULL',
        [decoded.userId],
      );
      globalUserId = member?.global_user_id || null;
    }
    if (!globalUserId && decoded.staffId) {
      const [[staff]] = await db.query(
        'SELECT global_user_id FROM staff WHERE id = ? AND is_active = 1',
        [decoded.staffId],
      );
      globalUserId = staff?.global_user_id || null;
    }
    if (!globalUserId) return res.status(404).json({ error: 'Δεν υπάρχει λογαριασμός OmniPlex' });

    const [[user]] = await db.query(
      'SELECT id, email, full_name, phone FROM global_users WHERE id = ?',
      [globalUserId],
    );
    if (!user) return res.status(404).json({ error: 'Δεν υπάρχει λογαριασμός OmniPlex' });
    const gyms = await getGymsForGlobalUser(user.id);
    return res.json({ token: makeGlobalToken(user), user, gyms });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// POST /api/global/auth/verify-otp
// Body: { phone, code, full_name? }
// code = 6-digit OTP  OR  OmniPlex account password
// Returns: { token, user, gyms, is_new }
// ============================================================
router.post('/auth/verify-otp', async (req, res) => {
  const { phone, code, full_name } = req.body;
  if (!phone || !code) return res.status(400).json({ error: 'Απαιτούνται τηλέφωνο και κωδικός' });

  const digits = phone.replace(/\D/g, '');

  try {
    // ── Demo bypass: code 000000 always succeeds (testing only) ──
    const isDemo = code === '000000';

    // ── Step 1: try OTP first ────────────────────────────────
    const [[otp]] = isDemo ? [[{ id: null }]] : await db.query(
      `SELECT id FROM global_otps
       WHERE phone = ? AND code = ? AND used = 0 AND expires_at > NOW()
       ORDER BY created_at DESC LIMIT 1`,
      [digits, code],
    );

    // ── Step 2: if no OTP, try as password on existing global_user ──
    if (!otp) {
      const [[userWithPwd]] = await db.query(
        `SELECT id, email, full_name, phone, password_hash FROM global_users WHERE phone = ?`,
        [digits],
      );
      if (userWithPwd && userWithPwd.password_hash) {
        const pwdMatch = await bcrypt.compare(code, userWithPwd.password_hash);
        if (pwdMatch) {
          db.query('UPDATE global_users SET last_login = NOW() WHERE id = ?', [userWithPwd.id]).catch(() => {});
          await autoLinkGlobalUser(userWithPwd.id, digits, userWithPwd.email);
          const gyms  = await getGymsForGlobalUser(userWithPwd.id);
          const token = makeGlobalToken(userWithPwd);
          return res.json({ token, user: userWithPwd, gyms, is_new: false });
        }
      }
      return res.status(400).json({ error: 'Λάθος ή ληγμένος κωδικός' });
    }

    // Mark OTP used
    await db.query('UPDATE global_otps SET used = 1 WHERE id = ?', [otp.id]);

    // Find or create global user by phone
    let [[user]] = await db.query(
      `SELECT id, email, full_name, phone FROM global_users WHERE phone = ?`,
      [digits],
    );

    let is_new = false;
    if (!user) {
      const id = uuidv4();
      const name = (full_name || '').trim() || '';
      await db.query(
        `INSERT INTO global_users (id, phone, full_name, email) VALUES (?, ?, ?, NULL)`,
        [id, digits, name],
      );
      [[user]] = await db.query('SELECT id, email, full_name, phone FROM global_users WHERE id = ?', [id]);
      is_new = true;
    }

    // Auto-link to any existing tenant records
    await autoLinkGlobalUser(user.id, digits, user.email);
    db.query('UPDATE global_users SET last_login = NOW() WHERE id = ?', [user.id]).catch(() => {});

    const gyms  = await getGymsForGlobalUser(user.id);
    const token = makeGlobalToken(user);

    return res.json({ token, user, gyms, is_new });
  } catch (err) {
    console.error('verify-otp error:', err.message);
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// POST /api/global/fcm-token
// Body: { fcm_token, platform? }
// Registers (upserts) an FCM token for the logged-in global user
// ============================================================
router.post('/fcm-token', requireGlobal, async (req, res) => {
  const { fcm_token, platform = 'unknown' } = req.body;
  if (!fcm_token) return res.status(400).json({ error: 'fcm_token required' });
  const globalUserId = req.globalUser.globalUserId;
  try {
    // Upsert: one row per (global_user_id, token)
    await db.query(
      `INSERT INTO global_device_tokens (id, global_user_id, fcm_token, platform)
       VALUES (?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE platform = VALUES(platform), updated_at = NOW()`,
      [uuidv4(), globalUserId, fcm_token, platform],
    );
    return res.json({ ok: true });
  } catch (err) {
    console.error('fcm-token register error:', err.message);
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// PUT /api/global/profile
// Body: { full_name?, email? }
// Updates the logged-in global user's profile (name + email)
// Used after new-user registration flow
// ============================================================
router.put('/profile', requireGlobal, async (req, res) => {
  const { full_name, email } = req.body;
  if (!full_name && !email) return res.status(400).json({ error: 'Απαιτείται τουλάχιστον ένα πεδίο' });
  const globalUserId = req.globalUser.globalUserId;
  try {
    const sets = [];
    const vals = [];
    if (full_name) { sets.push('full_name = ?'); vals.push(full_name.trim()); }
    if (email)     { sets.push('email = ?');     vals.push(email.trim().toLowerCase()); }
    vals.push(globalUserId);
    await db.query(`UPDATE global_users SET ${sets.join(', ')} WHERE id = ?`, vals);
    const [[user]] = await db.query(
      'SELECT id, email, full_name, phone FROM global_users WHERE id = ?',
      [globalUserId],
    );
    return res.json({ user });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ── Helper: get all FCM tokens for a global user ─────────────
async function getGlobalUserFcmTokens(globalUserId) {
  const { getGlobalUserFcmTokens: fromPush } = require('../lib/push');
  return fromPush(db, globalUserId);
}

module.exports = { router, getGlobalUserFcmTokens };
