const bcrypt = require('bcryptjs');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const { v4: uuidv4 } = require('uuid');
const { convertWaitlistEntry, cancelWaitlistEntry, notifyWaitlistOnCancel } = require('../lib/waitlist');

const TRAINER_BOOKING_SELECT = `
  SELECT b.id, b.service_id, b.staff_id, b.user_id, b.starts_at, b.ends_at, b.status, b.source, b.is_trial,
         b.attendance_confirmed, b.attendance_confirmed_at, b.feedback_rating, b.feedback_note,
         b.health_calories_kcal, b.health_duration_mins, b.health_avg_heart_rate, b.health_activity_label,
         u.full_name AS user_name, u.phone AS user_phone, u.email AS user_email,
         u.fitness_goal, u.weight_kg, u.trainer_notes, u.date_of_birth,
         sv.name AS service_name, sv.duration_mins, sv.image_url AS service_image_url,
         sss.room_name, sss.label AS schedule_label, sss.subtitle AS schedule_subtitle,
         sss.icon_key, sss.preparation_tips, sss.post_workout_tips
`;

const TRAINER_BOOKING_FROM = `
  FROM bookings b
  JOIN users u ON u.id = b.user_id
  JOIN services sv ON sv.id = b.service_id
  INNER JOIN staff_services ss_scope ON ss_scope.staff_id = b.staff_id AND ss_scope.service_id = b.service_id
  LEFT JOIN service_slot_schedules sss ON sss.service_id = b.service_id
    AND sss.business_id = b.business_id
    AND sss.weekday = WEEKDAY(b.starts_at)
    AND sss.start_time = TIME(b.starts_at)
    AND sss.is_active = 1
`;

const TRAINER_BOOKING_WHERE = `b.business_id = ? AND b.staff_id = ?`;

const TRAINER_WAITLIST_WHERE = `
  w.business_id = ? AND w.status IN ('waiting', 'offered')
  AND (
    w.staff_id = ?
    OR (w.staff_id IS NULL AND EXISTS (
      SELECT 1 FROM staff_services ss WHERE ss.staff_id = ? AND ss.service_id = w.service_id
    ))
  )
`;

function parseOpeningHours(raw) {
  if (!raw) return null;
  try { return typeof raw === 'string' ? JSON.parse(raw) : raw; } catch { return null; }
}

function normalizeAvailabilitySlots(slots) {
  return (slots || [])
    .filter((s) => s.weekday !== undefined && s.start_time && s.end_time)
    .map((s) => ({
      weekday: Number(s.weekday),
      start_time: String(s.start_time).slice(0, 8),
      end_time: String(s.end_time).slice(0, 8),
      is_active: s.is_active !== false,
    }));
}

function parseProposedSlots(raw) {
  if (!raw) return [];
  if (Array.isArray(raw)) return raw;
  try { return JSON.parse(raw); } catch { return []; }
}

function createTrainerAvatarUpload() {
  return multer({
    storage: multer.diskStorage({
      destination: (req, _file, cb) => {
        const dir = path.join(process.env.UPLOAD_DIR || './uploads', req.admin.businessId, 'staff');
        fs.mkdirSync(dir, { recursive: true });
        cb(null, dir);
      },
      filename: (req, file, cb) => {
        const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
        cb(null, `${req.admin.staffId}${ext}`);
      },
    }),
    limits: { fileSize: 5 * 1024 * 1024 },
    fileFilter: (_req, file, cb) => {
      if (/^image\/(jpeg|jpg|png|webp|gif)$/.test(file.mimetype)) cb(null, true);
      else cb(new Error('Μόνο εικόνες (JPEG, PNG, WebP) επιτρέπονται'));
    },
  });
}

const trainerAvatarUpload = createTrainerAvatarUpload();

function mountTrainerPortal(router, deps) {
  const {
    db,
    jwt,
    requireClientAdmin,
    enrichClientProfile,
    normalizeFitnessGoal,
    FITNESS_GOAL_LABELS,
    getUserStats,
  } = deps;

  function requireTrainerStaff(req, res, next) {
    const header = req.headers.authorization;
    if (!header) return res.status(401).json({ error: 'No token' });
    const token = header.startsWith('Bearer ') ? header.slice(7) : header;
    try {
      const d = jwt.verify(token, process.env.JWT_SECRET);
      if (d.role !== 'trainer' || !d.staffId) {
        return res.status(403).json({ error: 'Not authorized' });
      }
      req.admin = d;
      next();
    } catch {
      return res.status(401).json({ error: 'Invalid token' });
    }
  }

  async function loadTrainerBooking(businessId, staffId, bookingId) {
    const [[row]] = await db.query(
      `${TRAINER_BOOKING_SELECT} ${TRAINER_BOOKING_FROM}
       WHERE b.id = ? AND ${TRAINER_BOOKING_WHERE}`,
      [bookingId, businessId, staffId],
    );
    return row || null;
  }

  async function assertTrainerClient(businessId, staffId, userId) {
    const [[row]] = await db.query(
      `SELECT 1 FROM bookings b
       INNER JOIN staff_services ss ON ss.staff_id = b.staff_id AND ss.service_id = b.service_id
       WHERE b.business_id = ? AND b.staff_id = ? AND b.user_id = ?
       LIMIT 1`,
      [businessId, staffId, userId],
    );
    if (!row) {
      const err = new Error('Ο πελάτης δεν έχει κρατήσεις μαζί σου');
      err.status = 404;
      throw err;
    }
  }

  router.get('/trainer/bootstrap', requireTrainerStaff, async (req, res) => {
    try {
      const bizId = req.admin.businessId;
      const staffId = req.admin.staffId;
      const [[staff]] = await db.query(
        `SELECT id, full_name, role, bio, avatar_url, color_hex, portal_email
         FROM staff WHERE id = ? AND business_id = ? AND is_active = 1`,
        [staffId, bizId],
      );
      if (!staff) return res.status(404).json({ error: 'Ο γυμναστής δεν βρέθηκε' });

      const [services] = await db.query(
        `SELECT sv.id, sv.name, sv.category, sv.image_url
         FROM staff_services ss
         JOIN services sv ON sv.id = ss.service_id
         WHERE ss.staff_id = ? AND sv.is_active = 1
         ORDER BY sv.name`,
        [staffId],
      );

      const [[cfg]] = await db.query(
        'SELECT logo_url, opening_hours FROM business_configs WHERE business_id = ?',
        [bizId],
      );
      const [[biz]] = await db.query(
        'SELECT name FROM businesses WHERE id = ?',
        [bizId],
      );

      return res.json({
        staff,
        services,
        business: { id: bizId, name: biz?.name },
        logo_url: cfg?.logo_url || null,
        opening_hours: parseOpeningHours(cfg?.opening_hours),
      });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  });

  router.get('/trainer/overview', requireTrainerStaff, async (req, res) => {
    try {
      const bizId = req.admin.businessId;
      const staffId = req.admin.staffId;
      const [[dates]] = await db.query(
        `SELECT DATE_FORMAT(CURDATE(), '%Y-%m-%d') AS today,
                DATE_FORMAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY), '%Y-%m-%d') AS tomorrow,
                DATE_FORMAT(DATE_ADD(CURDATE(), INTERVAL 6 DAY), '%Y-%m-%d') AS week_end`,
      );
      const today = dates.today;
      const tomorrow = dates.tomorrow;
      const weekEnd = dates.week_end;

      const [rows] = await db.query(
        `SELECT DATE_FORMAT(DATE(b.starts_at), '%Y-%m-%d') AS day, b.status, COUNT(*) AS cnt
         FROM bookings b
         INNER JOIN staff_services ss ON ss.staff_id = b.staff_id AND ss.service_id = b.service_id
         WHERE ${TRAINER_BOOKING_WHERE}
           AND DATE(b.starts_at) IN (?, ?)
           AND b.status NOT IN ('cancelled')
         GROUP BY DATE_FORMAT(DATE(b.starts_at), '%Y-%m-%d'), b.status`,
        [bizId, staffId, today, tomorrow],
      );

      const summarize = (day) => {
        const dayRows = rows.filter((r) => r.day === day);
        const total = dayRows.reduce((s, r) => s + Number(r.cnt), 0);
        const pending = dayRows
          .filter((r) => r.status === 'pending')
          .reduce((s, r) => s + Number(r.cnt), 0);
        return { total, pending };
      };

      const [weekRows] = await db.query(
        `${TRAINER_BOOKING_SELECT} ${TRAINER_BOOKING_FROM}
         WHERE ${TRAINER_BOOKING_WHERE}
           AND DATE(b.starts_at) >= ? AND DATE(b.starts_at) <= ?
           AND b.status NOT IN ('cancelled')
         ORDER BY b.starts_at ASC`,
        [bizId, staffId, today, weekEnd],
      );

      return res.json({
        dates: { today, tomorrow, week_end: weekEnd },
        today: summarize(today),
        tomorrow: summarize(tomorrow),
        week_sessions: weekRows.length,
        next_sessions: weekRows.slice(0, 5).map((r) => ({
          ...r,
          fitness_goal_label: r.fitness_goal
            ? (FITNESS_GOAL_LABELS[r.fitness_goal] || r.fitness_goal)
            : null,
        })),
      });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  });

  router.get('/trainer/bookings', requireTrainerStaff, async (req, res) => {
    try {
      const bizId = req.admin.businessId;
      const staffId = req.admin.staffId;
      let q = `${TRAINER_BOOKING_SELECT} ${TRAINER_BOOKING_FROM}
        WHERE ${TRAINER_BOOKING_WHERE}`;
      const params = [bizId, staffId];

      if (req.query.date) {
        q += ' AND DATE(b.starts_at) = ?';
        params.push(req.query.date);
      }
      if (req.query.from) {
        q += ' AND DATE(b.starts_at) >= ?';
        params.push(req.query.from);
      }
      if (req.query.to) {
        q += ' AND DATE(b.starts_at) <= ?';
        params.push(req.query.to);
      }
      if (req.query.status) {
        q += ' AND b.status = ?';
        params.push(req.query.status);
      }
      q += ' ORDER BY b.starts_at ASC';

      const [rows] = await db.query(q, params);
      return res.json(rows.map((r) => ({
        ...r,
        fitness_goal_label: r.fitness_goal
          ? (FITNESS_GOAL_LABELS[r.fitness_goal] || r.fitness_goal)
          : null,
      })));
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  });

  router.get('/trainer/waitlist', requireTrainerStaff, async (req, res) => {
    try {
      const bizId = req.admin.businessId;
      const staffId = req.admin.staffId;
      let q = `
        SELECT w.id, w.service_id, w.user_id, w.staff_id, w.starts_at, w.ends_at,
               w.status, w.position, u.full_name AS user_name, u.phone AS user_phone,
               sv.name AS service_name, sv.image_url AS service_image_url
        FROM waitlist_entries w
        JOIN users u ON u.id = w.user_id
        JOIN services sv ON sv.id = w.service_id
        WHERE ${TRAINER_WAITLIST_WHERE}`;
      const params = [bizId, staffId, staffId];

      if (req.query.date) {
        q += ' AND DATE(w.starts_at) = ?';
        params.push(req.query.date);
      }
      if (req.query.from) {
        q += ' AND DATE(w.starts_at) >= ?';
        params.push(req.query.from);
      }
      if (req.query.to) {
        q += ' AND DATE(w.starts_at) <= ?';
        params.push(req.query.to);
      }
      q += ' ORDER BY w.starts_at ASC, w.position ASC';

      const [rows] = await db.query(q, params);
      return res.json(rows);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  });

  router.post('/trainer/waitlist/:id/convert', requireTrainerStaff, async (req, res) => {
    const bizId = req.admin.businessId;
    const staffId = req.admin.staffId;
    const conn = await db.getConnection();
    try {
      const [[allowed]] = await conn.query(`
        SELECT w.id FROM waitlist_entries w
        WHERE w.id = ? AND ${TRAINER_WAITLIST_WHERE}
      `, [req.params.id, bizId, staffId, staffId]);
      if (!allowed) {
        return res.status(404).json({ error: 'Η εγγραφή αναμονής δεν βρέθηκε' });
      }

      await conn.beginTransaction();
      const result = await convertWaitlistEntry(conn, bizId, req.params.id, {
        force: !!req.body?.force,
        use_credit: req.body?.use_credit !== false,
      });
      await conn.commit();
      return res.status(201).json({
        booking_id: result.booking_id,
        message: 'Η κράτηση επιβεβαιώθηκε',
      });
    } catch (err) {
      await conn.rollback();
      return res.status(err.status || 400).json({ error: err.message });
    } finally {
      conn.release();
    }
  });

  router.delete('/trainer/waitlist/:id', requireTrainerStaff, async (req, res) => {
    const bizId = req.admin.businessId;
    const staffId = req.admin.staffId;
    const conn = await db.getConnection();
    try {
      const [[allowed]] = await conn.query(`
        SELECT w.id FROM waitlist_entries w
        WHERE w.id = ? AND ${TRAINER_WAITLIST_WHERE}
      `, [req.params.id, bizId, staffId, staffId]);
      if (!allowed) {
        return res.status(404).json({ error: 'Η εγγραφή αναμονής δεν βρέθηκε' });
      }
      await conn.beginTransaction();
      await cancelWaitlistEntry(conn, bizId, req.params.id);
      await conn.commit();
      return res.json({ ok: true });
    } catch (err) {
      await conn.rollback();
      return res.status(err.status || 400).json({ error: err.message });
    } finally {
      conn.release();
    }
  });

  router.patch('/trainer/bookings/:id/status', requireTrainerStaff, async (req, res) => {
    const { status } = req.body;
    const allowed = ['confirmed', 'cancelled', 'completed', 'no_show'];
    if (!allowed.includes(status)) {
      return res.status(400).json({ error: 'Μη έγκυρη κατάσταση' });
    }

    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();
      const booking = await loadTrainerBooking(
        req.admin.businessId,
        req.admin.staffId,
        req.params.id,
      );
      if (!booking) {
        await conn.rollback();
        return res.status(404).json({ error: 'Η κράτηση δεν βρέθηκε' });
      }

      await conn.query(
        'UPDATE bookings SET status = ? WHERE id = ? AND business_id = ? AND staff_id = ?',
        [status, req.params.id, req.admin.businessId, req.admin.staffId],
      );

      if (status === 'completed' && !booking.attendance_confirmed) {
        await conn.query(
          `UPDATE bookings SET attendance_confirmed = 1, attendance_confirmed_at = NOW()
           WHERE id = ?`,
          [req.params.id],
        );
      }

      if (['cancelled', 'no_show'].includes(status) && !['cancelled', 'no_show'].includes(booking.status)) {
        await notifyWaitlistOnCancel(
          conn, req.admin.businessId, booking.service_id, booking.starts_at, booking.service_name,
        );
      }

      await conn.commit();
      return res.json({ ok: true });
    } catch (err) {
      await conn.rollback();
      return res.status(500).json({ error: err.message });
    } finally {
      conn.release();
    }
  });

  router.patch('/trainer/bookings/:id/attendance', requireTrainerStaff, async (req, res) => {
    const { attended = true } = req.body;
    try {
      const booking = await loadTrainerBooking(
        req.admin.businessId,
        req.admin.staffId,
        req.params.id,
      );
      if (!booking) return res.status(404).json({ error: 'Η κράτηση δεν βρέθηκε' });

      if (attended) {
        await db.query(
          `UPDATE bookings SET attendance_confirmed = 1, attendance_confirmed_at = NOW(), status = 'completed'
           WHERE id = ? AND business_id = ? AND staff_id = ?`,
          [req.params.id, req.admin.businessId, req.admin.staffId],
        );
      } else {
        await db.query(
          `UPDATE bookings SET status = 'no_show' WHERE id = ? AND business_id = ? AND staff_id = ?`,
          [req.params.id, req.admin.businessId, req.admin.staffId],
        );
      }
      return res.json({ ok: true });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  });

  router.get('/trainer/clients', requireTrainerStaff, async (req, res) => {
    try {
      const bizId = req.admin.businessId;
      const staffId = req.admin.staffId;
      const [rows] = await db.query(
        `SELECT u.id, u.full_name, u.phone, u.email, u.fitness_goal, u.weight_kg, u.trainer_notes,
                u.date_of_birth, u.account_status,
                COUNT(b.id) AS sessions_total,
                SUM(CASE WHEN b.starts_at >= NOW() AND b.status NOT IN ('cancelled','completed','no_show') THEN 1 ELSE 0 END) AS upcoming_sessions,
                MAX(CASE WHEN b.starts_at < NOW() THEN b.starts_at END) AS last_session_at,
                MIN(CASE WHEN b.starts_at >= NOW() AND b.status NOT IN ('cancelled','completed','no_show') THEN b.starts_at END) AS next_session_at
         FROM bookings b
         INNER JOIN staff_services ss ON ss.staff_id = b.staff_id AND ss.service_id = b.service_id
         JOIN users u ON u.id = b.user_id
         WHERE ${TRAINER_BOOKING_WHERE}
         GROUP BY u.id, u.full_name, u.phone, u.email, u.fitness_goal, u.weight_kg, u.trainer_notes, u.date_of_birth, u.account_status
         ORDER BY next_session_at IS NULL, next_session_at ASC, u.full_name ASC`,
        [bizId, staffId],
      );

      return res.json(rows.map((row) => enrichClientProfile({
        ...row,
        fitness_goal_label: row.fitness_goal
          ? (FITNESS_GOAL_LABELS[row.fitness_goal] || row.fitness_goal)
          : null,
      })));
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  });

  router.get('/trainer/clients/:userId', requireTrainerStaff, async (req, res) => {
    try {
      const bizId = req.admin.businessId;
      const staffId = req.admin.staffId;
      const userId = req.params.userId;
      await assertTrainerClient(bizId, staffId, userId);

      const [[user]] = await db.query(
        `SELECT id, full_name, phone, email, date_of_birth, weight_kg, fitness_goal, trainer_notes,
                account_status, loyalty_points, notes
         FROM users WHERE id = ? AND business_id = ?`,
        [userId, bizId],
      );
      if (!user) return res.status(404).json({ error: 'Ο πελάτης δεν βρέθηκε' });

      const [sessions] = await db.query(
        `${TRAINER_BOOKING_SELECT} ${TRAINER_BOOKING_FROM}
         WHERE ${TRAINER_BOOKING_WHERE} AND b.user_id = ?
         ORDER BY b.starts_at DESC LIMIT 20`,
        [bizId, staffId, userId],
      );

      const [memberships] = await db.query(
        `SELECT m.id, m.service_id, s.name AS service_name, m.total_sessions, m.used_sessions,
                m.valid_from, m.valid_until, m.membership_status, bp.name AS plan_name
         FROM user_memberships m
         LEFT JOIN services s ON s.id = m.service_id
         LEFT JOIN business_plans bp ON bp.id = m.plan_id
         WHERE m.user_id = ? AND m.business_id = ?
           AND m.service_id IN (SELECT service_id FROM staff_services WHERE staff_id = ?)
           AND (m.valid_until IS NULL OR m.valid_until >= CURDATE())
         ORDER BY m.valid_until DESC`,
        [userId, bizId, staffId],
      );

      const conn = await db.getConnection();
      let stats = null;
      try {
        stats = await getUserStats(conn, userId, bizId);
      } finally {
        conn.release();
      }

      return res.json({
        client: enrichClientProfile(user),
        sessions,
        memberships,
        stats,
      });
    } catch (err) {
      return res.status(err.status || 500).json({ error: err.message });
    }
  });

  router.patch('/trainer/clients/:userId', requireTrainerStaff, async (req, res) => {
    try {
      const bizId = req.admin.businessId;
      const staffId = req.admin.staffId;
      const userId = req.params.userId;
      await assertTrainerClient(bizId, staffId, userId);

      const { trainer_notes, fitness_goal, weight_kg } = req.body;
      const updates = [];
      const params = [];

      if (trainer_notes !== undefined) {
        updates.push('trainer_notes = ?');
        params.push(trainer_notes?.trim() || null);
      }
      if (fitness_goal !== undefined) {
        updates.push('fitness_goal = ?');
        params.push(normalizeFitnessGoal(fitness_goal));
      }
      if (weight_kg !== undefined) {
        const { normalizeWeight } = require('../lib/client_profile');
        updates.push('weight_kg = ?');
        params.push(normalizeWeight(weight_kg));
      }

      if (!updates.length) {
        return res.status(400).json({ error: 'Δεν υπάρχουν πεδία προς ενημέρωση' });
      }

      params.push(userId, bizId);
      await db.query(
        `UPDATE users SET ${updates.join(', ')} WHERE id = ? AND business_id = ?`,
        params,
      );

      const [[user]] = await db.query(
        `SELECT id, full_name, phone, email, date_of_birth, weight_kg, fitness_goal, trainer_notes
         FROM users WHERE id = ? AND business_id = ?`,
        [userId, bizId],
      );
      return res.json(enrichClientProfile(user));
    } catch (err) {
      return res.status(400).json({ error: err.message });
    }
  });

  router.get('/trainer/fitness-goals', requireTrainerStaff, (_req, res) => {
    return res.json(
      Object.entries(FITNESS_GOAL_LABELS).map(([id, label]) => ({ id, label })),
    );
  });

  async function assertTrainerService(staffId, serviceId) {
    const [[row]] = await db.query(
      'SELECT 1 FROM staff_services WHERE staff_id = ? AND service_id = ?',
      [staffId, serviceId],
    );
    if (!row) {
      const err = new Error('Η υπηρεσία δεν σου έχει ανατεθεί');
      err.status = 403;
      throw err;
    }
  }

  router.get('/trainer/profile', requireTrainerStaff, async (req, res) => {
    try {
      const [[staff]] = await db.query(
        `SELECT id, full_name, role, bio, avatar_url, color_hex, portal_email
         FROM staff WHERE id = ? AND business_id = ? AND is_active = 1`,
        [req.admin.staffId, req.admin.businessId],
      );
      if (!staff) return res.status(404).json({ error: 'Ο γυμναστής δεν βρέθηκε' });
      return res.json(staff);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  });

  router.patch('/trainer/profile', requireTrainerStaff, async (req, res) => {
    try {
      const { bio, color_hex } = req.body;
      const updates = [];
      const params = [];
      if (bio !== undefined) {
        updates.push('bio = ?');
        params.push(bio?.trim() || null);
      }
      if (color_hex !== undefined) {
        updates.push('color_hex = ?');
        params.push(color_hex || '#607D8B');
      }
      if (!updates.length) {
        return res.status(400).json({ error: 'Δεν υπάρχουν πεδία προς ενημέρωση' });
      }
      params.push(req.admin.staffId, req.admin.businessId);
      await db.query(
        `UPDATE staff SET ${updates.join(', ')} WHERE id = ? AND business_id = ?`,
        params,
      );
      const [[staff]] = await db.query(
        `SELECT id, full_name, role, bio, avatar_url, color_hex, portal_email
         FROM staff WHERE id = ? AND business_id = ?`,
        [req.admin.staffId, req.admin.businessId],
      );
      return res.json(staff);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  });

  router.put('/trainer/password', requireTrainerStaff, async (req, res) => {
    try {
      const { current_password, new_password } = req.body;
      if (!new_password || String(new_password).length < 6) {
        return res.status(400).json({ error: 'Ο νέος κωδικός πρέπει να έχει τουλάχιστον 6 χαρακτήρες' });
      }
      const [[pw]] = await db.query(
        'SELECT password_hash FROM staff_passwords WHERE staff_id = ?',
        [req.admin.staffId],
      );
      if (!pw || !(await bcrypt.compare(current_password || '', pw.password_hash))) {
        return res.status(401).json({ error: 'Λάθος τρέχων κωδικός' });
      }
      const hash = await bcrypt.hash(new_password, 10);
      await db.query(
        'UPDATE staff_passwords SET password_hash = ? WHERE staff_id = ?',
        [hash, req.admin.staffId],
      );
      return res.json({ ok: true });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  });

  router.post('/trainer/avatar', requireTrainerStaff, (req, res) => {
    trainerAvatarUpload.single('avatar')(req, res, async (err) => {
      if (err) return res.status(400).json({ error: err.message });
      if (!req.file) return res.status(400).json({ error: 'Δεν επιλέχθηκε εικόνα' });
      try {
        const avatarUrl = `/uploads/${req.admin.businessId}/staff/${req.file.filename}`;
        await db.query(
          'UPDATE staff SET avatar_url = ? WHERE id = ? AND business_id = ?',
          [avatarUrl, req.admin.staffId, req.admin.businessId],
        );
        return res.json({ avatar_url: avatarUrl });
      } catch (e) {
        return res.status(500).json({ error: e.message });
      }
    });
  });

  router.get('/trainer/availability', requireTrainerStaff, async (req, res) => {
    try {
      const staffId = req.admin.staffId;
      const { service_id: serviceId } = req.query;
      if (!serviceId) return res.status(400).json({ error: 'Απαιτείται service_id' });
      await assertTrainerService(staffId, serviceId);

      const [approved] = await db.query(
        `SELECT weekday, start_time, end_time, is_active
         FROM staff_availability
         WHERE staff_id = ? AND service_id = ?
         ORDER BY weekday, start_time`,
        [staffId, serviceId],
      );

      const [[pending]] = await db.query(
        `SELECT id, proposed_slots, submitted_at
         FROM staff_availability_requests
         WHERE staff_id = ? AND service_id = ? AND status = 'pending'
         ORDER BY submitted_at DESC LIMIT 1`,
        [staffId, serviceId],
      );

      return res.json({
        approved,
        pending: pending ? {
          id: pending.id,
          slots: parseProposedSlots(pending.proposed_slots),
          submitted_at: pending.submitted_at,
        } : null,
      });
    } catch (err) {
      return res.status(err.status || 500).json({ error: err.message });
    }
  });

  router.put('/trainer/availability', requireTrainerStaff, async (req, res) => {
    try {
      const staffId = req.admin.staffId;
      const bizId = req.admin.businessId;
      const { service_id: serviceId, slots = [] } = req.body;
      if (!serviceId) return res.status(400).json({ error: 'Απαιτείται service_id' });
      await assertTrainerService(staffId, serviceId);

      const normalized = normalizeAvailabilitySlots(slots);
      const [[existing]] = await db.query(
        `SELECT id FROM staff_availability_requests
         WHERE staff_id = ? AND service_id = ? AND status = 'pending'`,
        [staffId, serviceId],
      );

      if (existing) {
        await db.query(
          `UPDATE staff_availability_requests
           SET proposed_slots = ?, submitted_at = NOW(), review_note = NULL
           WHERE id = ?`,
          [JSON.stringify(normalized), existing.id],
        );
        return res.json({ ok: true, status: 'pending', request_id: existing.id });
      }

      const requestId = uuidv4();
      await db.query(
        `INSERT INTO staff_availability_requests
         (id, staff_id, business_id, service_id, proposed_slots)
         VALUES (?, ?, ?, ?, ?)`,
        [requestId, staffId, bizId, serviceId, JSON.stringify(normalized)],
      );
      return res.json({ ok: true, status: 'pending', request_id: requestId });
    } catch (err) {
      return res.status(err.status || 500).json({ error: err.message });
    }
  });

  router.get('/staff/:id/availability-requests', requireClientAdmin, async (req, res) => {
    try {
      const status = req.query.status || 'pending';
      const [rows] = await db.query(
        `SELECT r.id, r.staff_id, r.service_id, r.status, r.proposed_slots, r.submitted_at,
                r.reviewed_at, r.reviewed_by, r.review_note, sv.name AS service_name
         FROM staff_availability_requests r
         LEFT JOIN services sv ON sv.id = r.service_id
         WHERE r.staff_id = ? AND r.business_id = ? AND r.status = ?
         ORDER BY r.submitted_at DESC`,
        [req.params.id, req.admin.businessId, status],
      );
      return res.json(rows.map((r) => ({
        ...r,
        proposed_slots: parseProposedSlots(r.proposed_slots),
      })));
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  });

  router.post('/staff/:id/availability-requests/:requestId/approve', requireClientAdmin, async (req, res) => {
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();
      const [[row]] = await conn.query(
        `SELECT * FROM staff_availability_requests
         WHERE id = ? AND staff_id = ? AND business_id = ? AND status = 'pending'`,
        [req.params.requestId, req.params.id, req.admin.businessId],
      );
      if (!row) {
        await conn.rollback();
        return res.status(404).json({ error: 'Η αίτηση δεν βρέθηκε' });
      }

      const slots = parseProposedSlots(row.proposed_slots);
      if (row.service_id) {
        await conn.query(
          'DELETE FROM staff_availability WHERE staff_id = ? AND service_id = ?',
          [req.params.id, row.service_id],
        );
      } else {
        await conn.query(
          'DELETE FROM staff_availability WHERE staff_id = ? AND service_id IS NULL',
          [req.params.id],
        );
      }
      for (const slot of slots) {
        await conn.query(
          `INSERT INTO staff_availability
           (id, staff_id, service_id, weekday, start_time, end_time, is_active)
           VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [
            uuidv4(),
            req.params.id,
            row.service_id || null,
            slot.weekday,
            slot.start_time,
            slot.end_time,
            slot.is_active !== false ? 1 : 0,
          ],
        );
      }
      await conn.query(
        `UPDATE staff_availability_requests
         SET status = 'approved', reviewed_at = NOW(), reviewed_by = ?
         WHERE id = ?`,
        [req.admin.email, req.params.requestId],
      );
      await conn.commit();
      return res.json({ ok: true });
    } catch (err) {
      await conn.rollback();
      return res.status(500).json({ error: err.message });
    } finally {
      conn.release();
    }
  });

  router.post('/staff/:id/availability-requests/:requestId/reject', requireClientAdmin, async (req, res) => {
    try {
      const { note } = req.body;
      const [result] = await db.query(
        `UPDATE staff_availability_requests
         SET status = 'rejected', reviewed_at = NOW(), reviewed_by = ?, review_note = ?
         WHERE id = ? AND staff_id = ? AND business_id = ? AND status = 'pending'`,
        [req.admin.email, note?.trim() || null, req.params.requestId, req.params.id, req.admin.businessId],
      );
      if (!result.affectedRows) {
        return res.status(404).json({ error: 'Η αίτηση δεν βρέθηκε' });
      }
      return res.json({ ok: true });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  });

  router.get('/staff/:id/portal', requireClientAdmin, async (req, res) => {
    try {
      const [[staff]] = await db.query(
        `SELECT id, full_name, portal_email, is_active
         FROM staff WHERE id = ? AND business_id = ?`,
        [req.params.id, req.admin.businessId],
      );
      if (!staff) return res.status(404).json({ error: 'Το μέλος προσωπικού δεν βρέθηκε' });

      const [[pw]] = await db.query(
        'SELECT staff_id FROM staff_passwords WHERE staff_id = ?',
        [req.params.id],
      );

      return res.json({
        portal_email: staff.portal_email,
        portal_enabled: !!staff.portal_email && staff.is_active,
        has_password: !!pw,
      });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  });

  router.put('/staff/:id/portal', requireClientAdmin, async (req, res) => {
    const { portal_email, password, enabled } = req.body;
    try {
      const [[staff]] = await db.query(
        'SELECT id FROM staff WHERE id = ? AND business_id = ?',
        [req.params.id, req.admin.businessId],
      );
      if (!staff) return res.status(404).json({ error: 'Το μέλος προσωπικού δεν βρέθηκε' });

      if (enabled === false) {
        await db.query(
          'UPDATE staff SET portal_email = NULL WHERE id = ? AND business_id = ?',
          [req.params.id, req.admin.businessId],
        );
        await db.query('DELETE FROM staff_passwords WHERE staff_id = ?', [req.params.id]);
        return res.json({ ok: true, portal_enabled: false });
      }

      const email = String(portal_email || '').trim().toLowerCase();
      if (!email) return res.status(400).json({ error: 'Απαιτείται email για το portal' });

      const [[existingPw]] = await db.query(
        'SELECT staff_id FROM staff_passwords WHERE staff_id = ?',
        [req.params.id],
      );
      if (!existingPw && !password) {
        return res.status(400).json({ error: 'Ορίστε κωδικό για την πρώτη ενεργοποίηση του portal' });
      }

      const [dup] = await db.query(
        `SELECT id, business_id FROM staff
         WHERE portal_email = ? AND id != ?`,
        [email, req.params.id],
      );
      if (dup.length) {
        return res.status(409).json({ error: 'Το email χρησιμοποιείται ήδη από άλλο μέλος προσωπικού' });
      }

      const [nutDup] = await db.query(
        `SELECT id FROM nutritionists WHERE business_id = ? AND email = ?`,
        [req.admin.businessId, email],
      );
      if (nutDup.length) {
        return res.status(409).json({ error: 'Το email χρησιμοποιείται από διατροφολόγο' });
      }

      const [[owner]] = await db.query(
        'SELECT id FROM businesses WHERE id = ? AND owner_email = ?',
        [req.admin.businessId, email],
      );
      if (owner) {
        return res.status(409).json({ error: 'Το email ανήκει στον ιδιοκτήτη' });
      }

      await db.query(
        'UPDATE staff SET portal_email = ? WHERE id = ? AND business_id = ?',
        [email, req.params.id, req.admin.businessId],
      );

      if (password) {
        const hash = await bcrypt.hash(password, 10);
        await db.query(
          `INSERT INTO staff_passwords (staff_id, password_hash) VALUES (?,?)
           ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash)`,
          [req.params.id, hash],
        );
      }

      return res.json({ ok: true, portal_email: email, portal_enabled: true });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  });

  return { requireTrainerStaff };
}

module.exports = { mountTrainerPortal };
