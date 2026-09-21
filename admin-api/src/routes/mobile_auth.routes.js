// ============================================================
// FILE: src/routes/mobile_auth.routes.js
// Auth endpoints for mobile app users (customers)
// Separate from Master Admin auth
// ============================================================

const express  = require('express');
const bcrypt   = require('bcryptjs');
const jwt      = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const db       = require('../db');
const { createAdminNotification } = require('../lib/notifications');
const { STATUS_MESSAGES, getCustomerStatus } = require('../lib/customer_auth');
const {
  FITNESS_GOAL_LABELS,
  enrichClientProfile,
  normalizeFitnessGoal,
  normalizeWeight,
} = require('../lib/client_profile');

const { listLocations, replaceUserLocations } = require('../lib/locations');

const router = express.Router();

// ============================================================
// POST /api/mobile/register
// Body: { business_id, full_name, phone, email?, pin?, location_id? }
// Creates a pending user — admin must approve before login is possible.
// ============================================================
router.post('/register', async (req, res) => {
  const { business_id, full_name, phone, email, pin, location_id } = req.body;

  if (!business_id || !full_name || !phone) {
    return res.status(400).json({ error: 'Απαιτούνται: ονοματεπώνυμο και κινητό τηλέφωνο' });
  }

  const normalizedPhone = String(phone).replace(/[\s\-().]/g, '');
  const effectivePin = pin ? String(pin) : normalizedPhone.slice(-4);
  if (!/^\d{4}$/.test(effectivePin)) {
    return res.status(400).json({ error: 'Το PIN πρέπει να είναι 4 ψηφία' });
  }

  try {
    const [biz] = await db.query(
      'SELECT id FROM businesses WHERE id = ? AND is_active = 1',
      [business_id]
    );
    if (!biz.length) {
      return res.status(404).json({ error: 'Η επιχείρηση δεν βρέθηκε' });
    }

    // Check phone not already used
    const [existing] = await db.query(
      `SELECT id FROM users WHERE business_id = ?
       AND REPLACE(REPLACE(REPLACE(REPLACE(phone,' ',''),'-',''),'(',''),')','') = ?
       AND deleted_at IS NULL`,
      [business_id, normalizedPhone]
    );
    if (existing.length) {
      return res.status(409).json({ error: 'Ο αριθμός κινητού χρησιμοποιείται ήδη' });
    }

    const id   = uuidv4();
    const hash = await bcrypt.hash(effectivePin, 10);

    // Auto-link to global account if same email exists
    let globalUserId = null;
    if (email?.trim()) {
      const [gu] = await db.query('SELECT id FROM global_users WHERE email = ?', [email.trim().toLowerCase()]);
      if (gu.length) globalUserId = gu[0].id;
    }

    await db.query(
      `INSERT INTO users (id, business_id, full_name, phone, email, auth_uid, global_user_id, account_status)
       VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')`,
      [id, business_id, full_name.trim(), normalizedPhone, email?.trim() || null, id, globalUserId]
    );

    await db.query(
      'INSERT INTO user_passwords (user_id, password_hash) VALUES (?, ?)',
      [id, hash]
    );

    if (location_id) {
      const locs = await listLocations(db, business_id, { activeOnly: true });
      const valid = locs.find(l => l.id === location_id);
      if (valid) await replaceUserLocations(db, id, [location_id]);
    }

    await createAdminNotification(db, {
      businessId: business_id,
      type: 'client_pending_approval',
      title: 'Νέα αίτηση εγγραφής',
      body: `${full_name.trim()} (${normalizedPhone}) περιμένει έγκριση για σύνδεση στην εφαρμογή.`,
      payload: { user_id: id, phone: normalizedPhone, full_name: full_name.trim() },
    });

    return res.status(201).json({
      pending_approval: true,
      message: 'Η αίτησή σου καταχωρήθηκε. Θα λάβεις SMS όταν το γυμναστήριο εγκρίνει τον λογαριασμό σου.',
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Σφάλμα διακομιστή' });
  }
});

// ============================================================
// POST /api/mobile/login
// Body: { business_id, phone, pin }  — phone = mobile number, pin = 4-digit PIN
// ============================================================
router.post('/login', async (req, res) => {
  const { business_id, phone, pin } = req.body;

  if (!business_id || !phone || !pin) {
    return res.status(400).json({ error: 'Απαιτούνται κινητό και PIN' });
  }
  if (!/^\d{4}$/.test(String(pin))) {
    return res.status(400).json({ error: 'Το PIN πρέπει να είναι 4 ψηφία' });
  }

  // Normalise phone: strip spaces/dashes, keep digits and leading +
  const normalised = String(phone).replace(/[\s\-().]/g, '');

  try {
    const [rows] = await db.query(`
      SELECT u.id, u.full_name, u.email, u.phone, u.loyalty_points, u.account_status,
             u.deleted_at, p.password_hash
      FROM users u
      LEFT JOIN user_passwords p ON p.user_id = u.id
      WHERE u.business_id = ?
        AND REPLACE(REPLACE(REPLACE(REPLACE(u.phone,' ',''),'-',''),'(',''),')','') = ?
    `, [business_id, normalised]);

    if (!rows.length || !rows[0].password_hash) {
      return res.status(401).json({ error: 'Λάθος κινητό ή PIN' });
    }

    const user = rows[0];

    const valid = await bcrypt.compare(String(pin), user.password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Λάθος κινητό ή PIN' });
    }

    if (user.deleted_at) {
      return res.status(403).json({
        error: STATUS_MESSAGES.deleted,
        code: 'ACCOUNT_DELETED',
        account_status: 'deleted',
      });
    }

    const status = user.account_status || 'active';
    if (status !== 'active') {
      return res.status(403).json({
        error: STATUS_MESSAGES[status] || 'Ο λογαριασμός δεν είναι ενεργός',
        code: status === 'pending' ? 'ACCOUNT_PENDING' : 'ACCOUNT_SUSPENDED',
        account_status: status,
      });
    }

    const token = _makeToken(user.id, business_id, user.email, user.full_name);
    return res.json({
      token,
      user: {
        id:             user.id,
        full_name:      user.full_name,
        email:          user.email,
        phone:          user.phone,
        business_id,
        loyalty_points: user.loyalty_points,
      },
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Σφάλμα διακομιστή' });
  }
});

// ============================================================
// GET /api/mobile/me  (requires Bearer token)
// ============================================================
router.get('/me', async (req, res) => {
  const header = req.headers['authorization'];
  if (!header) return res.status(401).json({ error: 'Δεν είστε συνδεδεμένος' });

  const token = header.startsWith('Bearer ') ? header.slice(7) : header;
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const status = await getCustomerStatus(decoded.userId);
    if (status !== 'active') {
      return res.status(403).json({
        error: STATUS_MESSAGES[status] || 'Ο λογαριασμός δεν είναι ενεργός',
        code: status === 'pending' ? 'ACCOUNT_PENDING' : 'ACCOUNT_SUSPENDED',
        account_status: status,
      });
    }
    const [rows] = await db.query(
      `SELECT id, full_name, email, phone, loyalty_points, business_id, account_status,
              date_of_birth, weight_kg, target_weight_kg, fitness_goal
       FROM users WHERE id = ?`,
      [decoded.userId]
    );
    if (!rows.length) return res.status(404).json({ error: 'Ο χρήστης δεν βρέθηκε' });
    return res.json(enrichClientProfile(rows[0]));
  } catch {
    return res.status(401).json({ error: 'Μη έγκυρο token' });
  }
});

// ============================================================
// GET /api/mobile/fitness-goals
// ============================================================
router.get('/fitness-goals', (_req, res) => {
  return res.json(
    Object.entries(FITNESS_GOAL_LABELS).map(([id, label]) => ({ id, label }))
  );
});

// ============================================================
// PATCH /api/mobile/me/fitness
// Body: { weight_kg?, target_weight_kg?, fitness_goal? }
// ============================================================
router.patch('/me/fitness', async (req, res) => {
  const header = req.headers['authorization'];
  if (!header) return res.status(401).json({ error: 'Δεν είστε συνδεδεμένος' });

  const token = header.startsWith('Bearer ') ? header.slice(7) : header;
  let decoded;
  try { decoded = jwt.verify(token, process.env.JWT_SECRET); }
  catch { return res.status(401).json({ error: 'Μη έγκυρο token' }); }

  const status = await getCustomerStatus(decoded.userId);
  if (status !== 'active') {
    return res.status(403).json({
      error: STATUS_MESSAGES[status] || 'Ο λογαριασμός δεν είναι ενεργός',
      account_status: status,
    });
  }

  const { weight_kg, target_weight_kg, fitness_goal } = req.body || {};
  const updates = [];
  const params = [];

  try {
    if (weight_kg !== undefined) {
      updates.push('weight_kg = ?');
      params.push(normalizeWeight(weight_kg));
    }
    if (target_weight_kg !== undefined) {
      updates.push('target_weight_kg = ?');
      params.push(normalizeWeight(target_weight_kg));
    }
    if (fitness_goal !== undefined) {
      updates.push('fitness_goal = ?');
      params.push(normalizeFitnessGoal(fitness_goal));
    }
  } catch (err) {
    return res.status(400).json({ error: err.message });
  }

  if (!updates.length) {
    return res.status(400).json({ error: 'Δεν υπάρχουν στοιχεία προς ενημέρωση' });
  }

  try {
    params.push(decoded.userId);
    await db.query(`UPDATE users SET ${updates.join(', ')} WHERE id = ?`, params);
    const [rows] = await db.query(
      `SELECT id, full_name, email, phone, loyalty_points, business_id, account_status,
              date_of_birth, weight_kg, target_weight_kg, fitness_goal
       FROM users WHERE id = ?`,
      [decoded.userId]
    );
    if (!rows.length) return res.status(404).json({ error: 'Ο χρήστης δεν βρέθηκε' });
    return res.json(enrichClientProfile(rows[0]));
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// POST /api/mobile/change-password
// ============================================================
router.post('/change-password', async (req, res) => {
  const header = req.headers['authorization'];
  if (!header) return res.status(401).json({ error: 'Δεν είστε συνδεδεμένος' });

  const token = header.startsWith('Bearer ') ? header.slice(7) : header;
  let decoded;
  try { decoded = jwt.verify(token, process.env.JWT_SECRET); }
  catch { return res.status(401).json({ error: 'Μη έγκυρο token' }); }

  const status = await getCustomerStatus(decoded.userId);
  if (status !== 'active') {
    return res.status(403).json({
      error: STATUS_MESSAGES[status] || 'Ο λογαριασμός δεν είναι ενεργός',
      code: status === 'pending' ? 'ACCOUNT_PENDING' : 'ACCOUNT_SUSPENDED',
      account_status: status,
    });
  }

  const { old_password, new_password } = req.body;
  if (!old_password || !new_password) {
    return res.status(400).json({ error: 'Απαιτούνται παλιός και νέος κωδικός' });
  }
  if (new_password.length < 6) {
    return res.status(400).json({ error: 'Ο νέος κωδικός πρέπει να έχει τουλάχιστον 6 χαρακτήρες' });
  }

  try {
    const [rows] = await db.query(
      'SELECT password_hash FROM user_passwords WHERE user_id = ?',
      [decoded.userId]
    );
    if (!rows.length) return res.status(404).json({ error: 'Χρήστης δεν βρέθηκε' });

    const valid = await bcrypt.compare(old_password, rows[0].password_hash);
    if (!valid) return res.status(401).json({ error: 'Λάθος τρέχων κωδικός' });

    const newHash = await bcrypt.hash(new_password, 10);
    await db.query('UPDATE user_passwords SET password_hash=? WHERE user_id=?',
      [newHash, decoded.userId]);

    return res.json({ ok: true, message: 'Ο κωδικός άλλαξε επιτυχώς' });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ── Helper ────────────────────────────────────────────────────
function _makeToken(userId, businessId, email, fullName) {
  return jwt.sign(
    { userId, businessId, email, fullName, role: 'customer' },
    process.env.JWT_SECRET,
    { expiresIn: '30d' }
  );
}

// ============================================================
// POST /api/mobile/device-token
// Body: { fcm_token, platform }
// ============================================================
router.post('/device-token', async (req, res) => {
  const header = req.headers['authorization'];
  if (!header) return res.status(401).json({ error: 'Δεν είστε συνδεδεμένος' });

  const token = header.startsWith('Bearer ') ? header.slice(7) : header;
  let decoded;
  try { decoded = jwt.verify(token, process.env.JWT_SECRET); }
  catch { return res.status(401).json({ error: 'Μη έγκυρο token' }); }

  const { fcm_token, platform } = req.body;
  if (!fcm_token) return res.status(400).json({ error: 'Απαιτείται fcm_token' });

  try {
    await db.query(
      `INSERT INTO device_tokens (id, user_id, business_id, fcm_token, platform)
       VALUES (?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE fcm_token = VALUES(fcm_token), platform = VALUES(platform), updated_at = NOW()`,
      [uuidv4(), decoded.userId, decoded.businessId, fcm_token, platform || 'unknown']
    );
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// DELETE /api/mobile/device-token
// Unregister FCM token for the current user/business (called on gym switch)
// ============================================================
router.delete('/device-token', async (req, res) => {
  const header = req.headers['authorization'];
  if (!header) return res.status(401).json({ error: 'Δεν είστε συνδεδεμένος' });

  const token = header.startsWith('Bearer ') ? header.slice(7) : header;
  let decoded;
  try { decoded = jwt.verify(token, process.env.JWT_SECRET); }
  catch { return res.status(401).json({ error: 'Μη έγκυρο token' }); }

  const { fcm_token } = req.body;
  if (!fcm_token) return res.status(400).json({ error: 'Απαιτείται fcm_token' });

  try {
    await db.query(
      `DELETE FROM device_tokens WHERE user_id = ? AND business_id = ? AND fcm_token = ?`,
      [decoded.userId, decoded.businessId, fcm_token]
    );
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// ── Auth helper ──────────────────────────────────────────────────────────────
function requireMobileAuth(req, res) {
  const header = req.headers['authorization'];
  if (!header) { res.status(401).json({ error: 'Δεν είστε συνδεδεμένος' }); return null; }
  const token = header.startsWith('Bearer ') ? header.slice(7) : header;
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    db.query('UPDATE users SET last_seen_at = NOW() WHERE id = ?', [decoded.userId]).catch(() => {});
    return decoded;
  }
  catch { res.status(401).json({ error: 'Μη έγκυρο token' }); return null; }
}

// Time-sensitive types: skip in the response if the booking was more than 4h ago.
const STALE_TYPES = new Set([
  'checkin_reminder', 'workout_complete', 'booking_reminder_24h', 'prep_reminder',
]);
const STALE_HOURS = 4;

// GET /api/mobile/notifications
// ============================================================
router.get('/notifications', async (req, res) => {
  const decoded = requireMobileAuth(req, res);
  if (!decoded) return;

  try {
    const [rows] = await db.query(`
      SELECT n.id, n.booking_id, n.type, n.title, n.body, n.payload, n.is_read, n.created_at,
             b.starts_at AS booking_starts_at
      FROM user_notifications n
      LEFT JOIN bookings b ON b.id = n.booking_id
      WHERE n.user_id = ? AND n.business_id = ?
      ORDER BY n.created_at DESC
      LIMIT 60
    `, [decoded.userId, decoded.businessId]);

    const cutoff = new Date(Date.now() - STALE_HOURS * 3600 * 1000);

    // Auto-mark-read stale time-sensitive notifications so unread_count stays accurate.
    const staleIds = rows
      .filter(r => !r.is_read && STALE_TYPES.has(r.type))
      .filter(r => {
        const ref = r.booking_starts_at ? new Date(r.booking_starts_at) : new Date(r.created_at);
        return ref < cutoff;
      })
      .map(r => r.id);
    if (staleIds.length) {
      await db.query(
        `UPDATE user_notifications SET is_read = 1 WHERE id IN (${staleIds.map(() => '?').join(',')})`,
        staleIds
      ).catch(() => {});
    }

    const notifications = rows
      .filter((row) => {
        // Drop stale time-sensitive from the response (already marked read above).
        if (STALE_TYPES.has(row.type)) {
          const ref = row.booking_starts_at ? new Date(row.booking_starts_at) : new Date(row.created_at);
          if (ref < cutoff) return false;
        }
        return true;
      })
      .map((row) => {
        let payload = row.payload;
        if (typeof payload === 'string') {
          try { payload = JSON.parse(payload); } catch { payload = null; }
        }
        // Embed booking_starts_at into payload so the Flutter client can also check staleness.
        if (row.booking_starts_at) {
          payload = payload || {};
          payload.booking_starts_at = row.booking_starts_at;
        }
        const imageUrl = payload?.image_url || null;
        const { booking_starts_at: _skip, ...rest } = row;
        return { ...rest, payload, image_url: imageUrl };
      });

    const unread = notifications.filter(n => !n.is_read).length;
    return res.json({ notifications, unread_count: unread });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.patch('/notifications/:id/read', async (req, res) => {
  const decoded = requireMobileAuth(req, res);
  if (!decoded) return;
  await db.query(
    'UPDATE user_notifications SET is_read = 1 WHERE id = ? AND user_id = ?',
    [req.params.id, decoded.userId]
  );
  return res.json({ ok: true });
});

router.patch('/notifications/read-all', async (req, res) => {
  const decoded = requireMobileAuth(req, res);
  if (!decoded) return;
  await db.query(
    'UPDATE user_notifications SET is_read = 1 WHERE user_id = ? AND business_id = ? AND is_read = 0',
    [decoded.userId, decoded.businessId]
  );
  return res.json({ ok: true });
});

// ── Staff / Trainer mobile login ─────────────────────────────────────────────

// POST /api/mobile/staff/login
// Body: { email, password }
// Returns JWT with role=staff, staffId, businessId
router.post('/staff/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) return res.status(400).json({ error: 'Email και κωδικός απαιτούνται' });

  try {
    const [rows] = await db.query(`
      SELECT s.id AS staff_id, s.business_id, s.full_name, s.portal_email,
             s.role, s.avatar_url, s.color_hex, s.bio,
             p.password_hash,
             b.name AS biz_name, b.slug
      FROM staff s
      JOIN businesses b ON b.id = s.business_id AND b.is_active = 1
      LEFT JOIN staff_passwords p ON p.staff_id = s.id
      WHERE s.portal_email = ? AND s.is_active = 1
    `, [email.trim().toLowerCase()]);

    if (!rows.length || !rows[0].password_hash) {
      return res.status(401).json({ error: 'Λάθος email ή κωδικός' });
    }

    const staff = rows[0];
    const valid = await bcrypt.compare(password, staff.password_hash);
    if (!valid) return res.status(401).json({ error: 'Λάθος email ή κωδικός' });

    const token = jwt.sign(
      {
        staffId:    staff.staff_id,
        businessId: staff.business_id,
        email:      staff.portal_email,
        role:       'staff',
        name:       staff.full_name,
      },
      process.env.JWT_SECRET || 'secret',
      { expiresIn: '30d' },
    );

    return res.json({
      token,
      staff: {
        id:          staff.staff_id,
        full_name:   staff.full_name,
        email:       staff.portal_email,
        role:        staff.role,
        avatar_url:  staff.avatar_url,
        color_hex:   staff.color_hex,
        bio:         staff.bio,
        business_id: staff.business_id,
      },
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Σφάλμα διακομιστή' });
  }
});

// GET /api/mobile/staff/me
router.get('/staff/me', async (req, res) => {
  const header = req.headers.authorization;
  if (!header) return res.status(401).json({ error: 'Μη εξουσιοδοτημένο' });
  const token = header.startsWith('Bearer ') ? header.slice(7) : header;
  let decoded;
  try { decoded = jwt.verify(token, process.env.JWT_SECRET || 'secret'); }
  catch { return res.status(401).json({ error: 'Λήξη ή μη έγκυρο token' }); }
  if (decoded.role !== 'staff') return res.status(403).json({ error: 'Απαγορεύεται' });

  try {
    const [[s]] = await db.query(
      'SELECT id, full_name, portal_email, role, avatar_url, color_hex, bio, business_id FROM staff WHERE id = ? AND is_active = 1',
      [decoded.staffId],
    );
    if (!s) return res.status(404).json({ error: 'Δεν βρέθηκε' });
    return res.json({
      id:          s.id,
      full_name:   s.full_name,
      email:       s.portal_email,
      role:        s.role,
      avatar_url:  s.avatar_url,
      color_hex:   s.color_hex,
      bio:         s.bio,
      business_id: s.business_id,
    });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// Middleware for staff-only mobile routes
function requireMobileStaff(req, res, next) {
  const header = req.headers.authorization;
  if (!header) return res.status(401).json({ error: 'Μη εξουσιοδοτημένο' });
  const token = header.startsWith('Bearer ') ? header.slice(7) : header;
  try {
    const d = jwt.verify(token, process.env.JWT_SECRET || 'secret');
    if (d.role !== 'staff') return res.status(403).json({ error: 'Απαγορεύεται' });
    req.staffId    = d.staffId;
    req.businessId = d.businessId;
    next();
  } catch {
    return res.status(401).json({ error: 'Λήξη ή μη έγκυρο token' });
  }
}

// GET /api/mobile/staff/schedule?date=YYYY-MM-DD
// Returns bookings for the staff member on a given date (or today)
router.get('/staff/schedule', requireMobileStaff, async (req, res) => {
  const date = req.query.date || new Date().toISOString().slice(0, 10);
  const nextDate = new Date(date); nextDate.setDate(nextDate.getDate() + 1);
  const nextStr = nextDate.toISOString().slice(0, 10);
  try {
    const [bookings] = await db.query(`
      SELECT b.id, b.starts_at, b.ends_at, b.status, b.attendance_confirmed,
             b.notes, b.is_trial,
             s.name AS service_name, s.color_hex AS service_color, s.duration_mins,
             u.full_name AS client_name, u.phone AS client_phone, u.avatar_url AS client_avatar,
             l.name AS location_name, r.name AS room_name
      FROM bookings b
      JOIN services s ON s.id = b.service_id
      JOIN users u ON u.id = b.user_id
      LEFT JOIN locations l ON l.id = b.location_id
      LEFT JOIN rooms r ON r.id = b.room_id
      WHERE b.business_id = ?
        AND b.starts_at >= ?
        AND b.starts_at < ?
        AND b.status NOT IN ('cancelled')
      ORDER BY b.starts_at ASC
    `, [req.businessId, date, nextStr]);
    return res.json({ bookings, date });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// GET /api/mobile/staff/schedule/week?from=YYYY-MM-DD
router.get('/staff/schedule/week', requireMobileStaff, async (req, res) => {
  const from = req.query.from || new Date().toISOString().slice(0, 10);
  const to   = new Date(from); to.setDate(to.getDate() + 7);
  const toStr = to.toISOString().slice(0, 10);
  try {
    const [bookings] = await db.query(`
      SELECT b.id, b.starts_at, b.ends_at, b.status, b.attendance_confirmed,
             s.name AS service_name, s.color_hex AS service_color,
             u.full_name AS client_name
      FROM bookings b
      JOIN services s ON s.id = b.service_id
      JOIN users u ON u.id = b.user_id
      WHERE b.business_id = ?
        AND b.starts_at >= ?
        AND b.starts_at < ?
        AND b.status NOT IN ('cancelled')
      ORDER BY b.starts_at ASC
    `, [req.businessId, from, toStr]);
    return res.json({ bookings, from, to: toStr });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// PATCH /api/mobile/staff/bookings/:id/attendance
router.patch('/staff/bookings/:id/attendance', requireMobileStaff, async (req, res) => {
  const { confirmed } = req.body;
  try {
    await db.query(
      'UPDATE bookings SET attendance_confirmed = ?, attendance_confirmed_at = NOW() WHERE id = ? AND business_id = ?',
      [confirmed ? 1 : 0, req.params.id, req.businessId],
    );
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// PATCH /api/mobile/staff/bookings/:id/claim — staff claims (assigns themselves to) a booking
router.patch('/staff/bookings/:id/claim', requireMobileStaff, async (req, res) => {
  try {
    const [result] = await db.query(
      'UPDATE bookings SET staff_id = ? WHERE id = ? AND business_id = ?',
      [req.staffId, req.params.id, req.businessId],
    );
    if (result.affectedRows === 0) return res.status(404).json({ error: 'Booking not found' });
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// PATCH /api/mobile/staff/trials/:id/claim — staff claims a trial booking + optional note
router.patch('/staff/trials/:id/claim', requireMobileStaff, async (req, res) => {
  const { notes } = req.body;
  try {
    const sets = ['staff_id = ?'];
    const params = [req.staffId];
    if (notes !== undefined) { sets.push('notes = ?'); params.push(notes); }
    params.push(req.params.id, req.businessId);
    const [result] = await db.query(
      `UPDATE bookings SET ${sets.join(', ')} WHERE id = ? AND business_id = ? AND is_trial = 1`,
      params,
    );
    if (result.affectedRows === 0) return res.status(404).json({ error: 'Trial not found' });
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// PATCH /api/mobile/staff/trials/:id/note — update notes on a trial (membership interest etc.)
router.patch('/staff/trials/:id/note', requireMobileStaff, async (req, res) => {
  const { notes } = req.body;
  try {
    const [result] = await db.query(
      'UPDATE bookings SET notes = ? WHERE id = ? AND business_id = ? AND is_trial = 1',
      [notes || null, req.params.id, req.businessId],
    );
    if (result.affectedRows === 0) return res.status(404).json({ error: 'Trial not found' });
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// GET /api/mobile/staff/leaves — includes status and annual balance
router.get('/staff/leaves', requireMobileStaff, async (req, res) => {
  try {
    const [leaves] = await db.query(
      `SELECT id, date_from, date_to, reason, status, admin_note, reviewed_at,
              DATEDIFF(date_to, date_from) + 1 AS days_count
       FROM staff_leaves WHERE staff_id = ? AND business_id = ? ORDER BY date_from DESC`,
      [req.staffId, req.businessId],
    );
    const [[used]] = await db.query(
      `SELECT COALESCE(SUM(DATEDIFF(date_to, date_from) + 1), 0) AS days_used
       FROM staff_leaves WHERE staff_id=? AND business_id=? AND status='approved'
       AND YEAR(date_from)=YEAR(CURDATE())`,
      [req.staffId, req.businessId],
    );
    const [[cfg]] = await db.query(
      'SELECT annual_leave_days FROM business_configs WHERE business_id=?', [req.businessId]);
    return res.json({
      leaves,
      days_used: used.days_used,
      annual_leave_days: cfg?.annual_leave_days ?? 20,
    });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/mobile/staff/leaves — submits a leave REQUEST (pending approval)
router.post('/staff/leaves', requireMobileStaff, async (req, res) => {
  const { date_from, date_to, reason } = req.body;
  if (!date_from || !date_to) return res.status(400).json({ error: 'Απαιτούνται ημερομηνίες' });
  try {
    const id = uuidv4();
    await db.query(
      `INSERT INTO staff_leaves (id, staff_id, business_id, date_from, date_to, reason, status)
       VALUES (?,?,?,?,?,?,'pending')`,
      [id, req.staffId, req.businessId, date_from, date_to, reason || null],
    );
    return res.json({ id, date_from, date_to, reason: reason || null, status: 'pending' });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// DELETE /api/mobile/staff/leaves/:id — only pending leaves can be cancelled by staff
router.delete('/staff/leaves/:id', requireMobileStaff, async (req, res) => {
  try {
    await db.query(
      `DELETE FROM staff_leaves WHERE id = ? AND staff_id = ? AND business_id = ? AND status = 'pending'`,
      [req.params.id, req.staffId, req.businessId],
    );
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ── Staff Trials ────────────────────────────────────────────────────────────

// GET /api/mobile/staff/trials — list all (or unassigned) trials for this business
router.get('/staff/trials', requireMobileStaff, async (req, res) => {
  const unassignedOnly = req.query.unassigned === '1';
  try {
    const [rows] = await db.query(`
      SELECT b.id, b.starts_at, b.ends_at, b.status, b.notes,
             b.user_id, b.service_id, b.staff_id, b.trial_became_member,
             u.full_name AS user_name, u.phone AS user_phone,
             s.name AS service_name,
             st.full_name AS staff_name
      FROM bookings b
      LEFT JOIN users u ON u.id = b.user_id
      LEFT JOIN services s ON s.id = b.service_id
      LEFT JOIN staff st ON st.id = b.staff_id
      WHERE b.business_id = ? AND b.is_trial = 1 AND b.status != 'cancelled'
        ${unassignedOnly ? 'AND b.staff_id IS NULL' : ''}
      ORDER BY b.starts_at DESC
      LIMIT 200
    `, [req.businessId]);
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// PATCH /api/mobile/staff/trials/:id/claim — staff claims an unassigned trial
router.patch('/staff/trials/:id/claim', requireMobileStaff, async (req, res) => {
  try {
    const [[trial]] = await db.query(
      'SELECT id, staff_id FROM bookings WHERE id = ? AND business_id = ? AND is_trial = 1',
      [req.params.id, req.businessId]
    );
    if (!trial) return res.status(404).json({ error: 'Δεν βρέθηκε' });
    if (trial.staff_id && trial.staff_id !== req.staffId) {
      return res.status(409).json({ error: 'Έχει ήδη εκπαιδευτή' });
    }
    await db.query('UPDATE bookings SET staff_id = ? WHERE id = ?', [req.staffId, req.params.id]);
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// PATCH /api/mobile/staff/trials/:id/became-member — mark trial_became_member
router.patch('/staff/trials/:id/became-member', requireMobileStaff, async (req, res) => {
  const became = req.body.became_member ? 1 : 0;
  try {
    const [[trial]] = await db.query(
      'SELECT id FROM bookings WHERE id = ? AND business_id = ? AND is_trial = 1',
      [req.params.id, req.businessId]
    );
    if (!trial) return res.status(404).json({ error: 'Δεν βρέθηκε' });
    await db.query('UPDATE bookings SET trial_became_member = ? WHERE id = ?', [became, req.params.id]);
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

module.exports = router;
