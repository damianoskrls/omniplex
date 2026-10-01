const express = require('express');
const path = require('path');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const db = require('../db');
const { r2Multer } = require('../lib/r2_upload');
const { FITNESS_GOAL_LABELS, normalizeFitnessGoal, normalizeWeight } = require('../lib/client_profile');
const { createUserNotification } = require('../lib/user_notifications');
const { sqlActiveClients } = require('../lib/client_soft_delete');

const router = express.Router();
const GOALS = Object.keys(FITNESS_GOAL_LABELS);
const EXPERIENCE = new Set(['beginner', 'some', 'regular']);
const CONDITION_KEYS = ['cardiac', 'hypertension', 'diabetes', 'asthma', 'orthopedic', 'injury', 'other', 'none'];
const FITNESS_STATUSES = new Set(['fit', 'restricted', 'clearance']);
const GENDERS = new Set(['male', 'female', 'other']);
const BLOOD_TYPES = new Set(['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']);

function dateOnly(value) {
  if (!value) return null;
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    const y = value.getFullYear();
    const m = String(value.getMonth() + 1).padStart(2, '0');
    const d = String(value.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }
  const text = String(value).slice(0, 10);
  return /^\d{4}-\d{2}-\d{2}$/.test(text) ? text : null;
}

function clip(value, max) {
  const text = String(value || '').trim();
  return text ? text.slice(0, max) : null;
}

function presentHealth(row) {
  if (!row) return null;
  let keys = [];
  try {
    const parsed = JSON.parse(row.conditions_json || '[]');
    if (Array.isArray(parsed)) keys = parsed.filter(k => CONDITION_KEYS.includes(k));
  } catch { keys = []; }
  return { ...row, date_of_birth: dateOnly(row.date_of_birth), condition_keys: keys };
}

function authPayload(req) {
  return jwt.verify((req.headers.authorization || '').replace('Bearer ', ''), process.env.JWT_SECRET);
}

function requireMember(req, res, next) {
  try {
    const payload = authPayload(req);
    if (!payload.userId || payload.role === 'client_admin') return res.status(403).json({ error: 'Forbidden' });
    if (payload.businessId && payload.businessId !== req.params.bizId) {
      return res.status(403).json({ error: 'Λάθος γυμναστήριο' });
    }
    req.member = payload;
    next();
  } catch {
    return res.status(401).json({ error: 'Unauthorized' });
  }
}

function requireAdmin(req, res, next) {
  try {
    const payload = authPayload(req);
    if (payload.role !== 'client_admin' && payload.role !== 'owner' && payload.role !== 'admin') {
      return res.status(403).json({ error: 'Forbidden' });
    }
    req.bizId = payload.businessId;
    next();
  } catch {
    return res.status(401).json({ error: 'Unauthorized' });
  }
}

async function loadPair(bizId, userId) {
  const [[intake]] = await db.query(
    'SELECT * FROM member_intakes WHERE business_id = ? AND user_id = ?',
    [bizId, userId],
  );
  const [[health]] = await db.query(
    'SELECT * FROM member_health_cards WHERE business_id = ? AND user_id = ?',
    [bizId, userId],
  );
  const [[profile]] = await db.query(
    'SELECT full_name, date_of_birth, weight_kg, height_cm FROM users WHERE id = ? AND business_id = ?',
    [userId, bizId],
  );
  return {
    intake_completed: !!intake?.completed_at,
    intake: intake || null,
    health: presentHealth(health),
    profile: profile ? { ...profile, date_of_birth: dateOnly(profile.date_of_birth) } : null,
    goals: Object.entries(FITNESS_GOAL_LABELS).map(([id, label]) => ({ id, label })),
  };
}

const HEALTH_REMINDER = {
  type: 'health_card',
  title: 'Κάρτα υγείας',
  body: 'Συμπλήρωσε την κάρτα υγείας σου: φωτογραφία και ηλεκτρονική υπογραφή.',
};

router.post('/admin/remind-missing', requireAdmin, async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT u.id FROM users u
       WHERE u.business_id = ? AND ${sqlActiveClients('u')}
         AND NOT EXISTS (
           SELECT 1 FROM member_health_cards hc
           WHERE (hc.user_id COLLATE utf8mb4_unicode_ci) = (u.id COLLATE utf8mb4_unicode_ci)
             AND (hc.business_id COLLATE utf8mb4_unicode_ci) = (u.business_id COLLATE utf8mb4_unicode_ci)
             AND hc.signed_at IS NOT NULL
         )
       LIMIT 300`,
      [req.bizId],
    );
    let sent = 0;
    for (const row of rows) {
      try {
        await createUserNotification(db, {
          businessId: req.bizId,
          userId: row.id,
          ...HEALTH_REMINDER,
          payload: { action: 'open_health_card' },
        });
        sent += 1;
      } catch (_) {}
    }
    res.json({ sent });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/admin/:userId/remind', requireAdmin, async (req, res) => {
  try {
    const [[user]] = await db.query(
      'SELECT id, full_name FROM users WHERE id = ? AND business_id = ?',
      [req.params.userId, req.bizId],
    );
    if (!user) return res.status(404).json({ error: 'Ο πελάτης δεν βρέθηκε' });
    await createUserNotification(db, {
      businessId: req.bizId,
      userId: user.id,
      ...HEALTH_REMINDER,
      payload: { action: 'open_health_card' },
    });
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

async function ownsUser(bizId, userId) {
  const [[user]] = await db.query(
    'SELECT id FROM users WHERE id = ? AND business_id = ?',
    [userId, bizId],
  );
  return !!user;
}

async function saveIntake(bizId, userId, body) {
  const goal = GOALS.includes(body?.fitness_goal) ? body.fitness_goal : 'general';
  const experience = EXPERIENCE.has(body?.experience) ? body.experience : 'beginner';
  const visits = Math.min(14, Math.max(1, Number(body?.visits_per_week) || 3));
  const motivation = String(body?.motivation || '').trim().slice(0, 2000);
  const goalText = String(body?.goal_text || '').trim().slice(0, 2000);
  await db.query(
    `INSERT INTO member_intakes
      (id, business_id, user_id, fitness_goal, motivation, goal_text, experience, visits_per_week, completed_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())
     ON DUPLICATE KEY UPDATE
      fitness_goal = VALUES(fitness_goal),
      motivation = VALUES(motivation),
      goal_text = VALUES(goal_text),
      experience = VALUES(experience),
      visits_per_week = VALUES(visits_per_week),
      completed_at = NOW()`,
    [uuidv4(), bizId, userId, goal, motivation || null, goalText || null, experience, visits],
  );
  await db.query('UPDATE users SET fitness_goal = ? WHERE id = ? AND business_id = ?', [
    normalizeFitnessGoal(goal), userId, bizId,
  ]);
}

async function saveHealth(bizId, userId, body) {
  let keys = Array.isArray(body?.condition_keys)
    ? [...new Set(body.condition_keys.filter(k => CONDITION_KEYS.includes(k)))]
    : [];
  if (keys.includes('none')) keys = ['none'];
  const hasConditions = keys.some(k => k !== 'none') || body?.has_conditions ? 1 : 0;
  const takesMedication = body?.takes_medication ? 1 : 0;
  const conditions = clip(body?.conditions_text, 4000);
  const medication = clip(body?.medication_text, 4000);
  const status = FITNESS_STATUSES.has(body?.fitness_status) ? body.fitness_status : null;
  const gender = GENDERS.has(body?.gender) ? body.gender : null;
  const blood = BLOOD_TYPES.has(body?.blood_type) ? body.blood_type : null;
  const dob = dateOnly(body?.date_of_birth);
  let height = null;
  let weight = null;
  const heightRaw = body?.height_cm;
  if (heightRaw !== '' && heightRaw != null) {
    const n = Number(heightRaw);
    if (Number.isFinite(n) && n > 0 && n <= 260) height = Math.round(n * 10) / 10;
  }
  try { weight = normalizeWeight(body?.weight_kg); } catch { weight = null; }
  if (height === undefined) height = null;
  if (weight === undefined) weight = null;

  await db.query(
    `INSERT INTO member_health_cards
      (id, business_id, user_id, has_conditions, conditions_text, takes_medication, medication_text,
       date_of_birth, gender, height_cm, weight_kg, fitness_status, conditions_json,
       injury_area, injury_problem, injury_limits, injury_recovery,
       emergency_name, emergency_relation, emergency_phone,
       allergies, blood_type, emergency_instructions, other_info)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE
      has_conditions = VALUES(has_conditions),
      conditions_text = VALUES(conditions_text),
      takes_medication = VALUES(takes_medication),
      medication_text = VALUES(medication_text),
      date_of_birth = VALUES(date_of_birth),
      gender = VALUES(gender),
      height_cm = VALUES(height_cm),
      weight_kg = VALUES(weight_kg),
      fitness_status = VALUES(fitness_status),
      conditions_json = VALUES(conditions_json),
      injury_area = VALUES(injury_area),
      injury_problem = VALUES(injury_problem),
      injury_limits = VALUES(injury_limits),
      injury_recovery = VALUES(injury_recovery),
      emergency_name = VALUES(emergency_name),
      emergency_relation = VALUES(emergency_relation),
      emergency_phone = VALUES(emergency_phone),
      allergies = VALUES(allergies),
      blood_type = VALUES(blood_type),
      emergency_instructions = VALUES(emergency_instructions),
      other_info = VALUES(other_info)`,
    [
      uuidv4(), bizId, userId, hasConditions, conditions, takesMedication, takesMedication ? medication : null,
      dob, gender, height, weight, status, JSON.stringify(keys),
      clip(body?.injury_area, 160), clip(body?.injury_problem, 2000), clip(body?.injury_limits, 2000), clip(body?.injury_recovery, 160),
      clip(body?.emergency_name, 120), clip(body?.emergency_relation, 80), clip(body?.emergency_phone, 40),
      clip(body?.allergies, 2000), blood, clip(body?.emergency_instructions, 2000), clip(body?.other_info, 2000),
    ],
  );
  await db.query(
    `UPDATE users
     SET date_of_birth = COALESCE(?, date_of_birth),
         weight_kg = COALESCE(?, weight_kg),
         height_cm = COALESCE(?, height_cm)
     WHERE id = ? AND business_id = ?`,
    [dob, weight, height, userId, bizId],
  ).catch(() => {});
}

router.get('/admin/:userId', requireAdmin, async (req, res) => {
  try {
    res.json(await loadPair(req.bizId, req.params.userId));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/admin/:userId', requireAdmin, async (req, res) => {
  try {
    if (!(await ownsUser(req.bizId, req.params.userId))) {
      return res.status(404).json({ error: 'Ο πελάτης δεν βρέθηκε' });
    }
    await saveIntake(req.bizId, req.params.userId, req.body?.intake || req.body);
    await saveHealth(req.bizId, req.params.userId, req.body?.health || req.body);
    res.json(await loadPair(req.bizId, req.params.userId));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/:bizId', requireMember, async (req, res) => {
  try {
    res.json(await loadPair(req.params.bizId, req.member.userId));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:bizId/intake', requireMember, async (req, res) => {
  try {
    await saveIntake(req.params.bizId, req.member.userId, req.body);
    res.json(await loadPair(req.params.bizId, req.member.userId));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:bizId/health', requireMember, async (req, res) => {
  try {
    await saveHealth(req.params.bizId, req.member.userId, req.body);
    res.json(await loadPair(req.params.bizId, req.member.userId));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const healthUpload = r2Multer({
  keyFn(req, file) {
    const bizId = req.params.bizId || req.bizId;
    const userId = req.member?.userId || req.params.userId;
    const ext = path.extname(file.originalname || '').toLowerCase().replace(/[^.a-z0-9]/g, '').slice(0, 8) || '.jpg';
    const kind = file.fieldname === 'document' ? 'document' : 'photo';
    return `uploads/${bizId}/health/${userId}/${kind}-${Date.now()}${ext}`;
  },
  allowedMimes: ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'application/pdf'],
  maxSizeMb: 8,
});

function storeHealthUpload(field, urlCol, nameCol) {
  const allowed = new Set(['document_url', 'document_name', 'photo_url']);
  if (!allowed.has(urlCol) || (nameCol && !allowed.has(nameCol))) {
    throw new Error('Invalid health upload column');
  }
  return (req, res) => {
    healthUpload.single(field)(req, res, async (err) => {
      if (err) return res.status(400).json({ error: err.message || 'Αποτυχία ανεβάσματος' });
      if (!req.file?.publicUrl) return res.status(400).json({ error: 'Μόνο JPG, PNG, WEBP ή PDF' });
      if (req.bizId && !(await ownsUser(req.bizId, req.params.userId))) {
        return res.status(404).json({ error: 'Ο πελάτης δεν βρέθηκε' });
      }
      const bizId = req.params.bizId || req.bizId;
      const userId = req.member?.userId || req.params.userId;
      const url = req.file.publicUrl;
      const name = req.file.originalname || path.basename(req.file.key || 'file');
      const cols = nameCol ? `${urlCol}, ${nameCol}` : urlCol;
      const marks = nameCol ? '?, ?' : '?';
      const update = nameCol
        ? `${urlCol} = VALUES(${urlCol}), ${nameCol} = VALUES(${nameCol})`
        : `${urlCol} = VALUES(${urlCol})`;
      try {
        await db.query(
          `INSERT INTO member_health_cards (id, business_id, user_id, ${cols})
           VALUES (?, ?, ?, ${marks})
           ON DUPLICATE KEY UPDATE ${update}`,
          [uuidv4(), bizId, userId, url, ...(nameCol ? [name] : [])],
        );
        res.json(await loadPair(bizId, userId));
      } catch (e) {
        res.status(500).json({ error: e.message });
      }
    });
  };
}

router.post('/:bizId/health/document', requireMember, storeHealthUpload('document', 'document_url', 'document_name'));
router.post('/:bizId/health/photo', requireMember, storeHealthUpload('photo', 'photo_url'));
router.post('/admin/:userId/health/document', requireAdmin, storeHealthUpload('document', 'document_url', 'document_name'));
router.post('/admin/:userId/health/photo', requireAdmin, storeHealthUpload('photo', 'photo_url'));

router.post('/admin/:userId/health/sign', requireAdmin, async (req, res) => {
  const signature = String(req.body?.signature_data || '');
  if (!signature.startsWith('data:image/png;base64,') || signature.length < 80 || signature.length > 1500000) {
    return res.status(400).json({ error: 'Υπόγραψε στο πλαίσιο' });
  }
  try {
    if (!(await ownsUser(req.bizId, req.params.userId))) {
      return res.status(404).json({ error: 'Ο πελάτης δεν βρέθηκε' });
    }
    await db.query(
      `INSERT INTO member_health_cards (id, business_id, user_id, signature_data, signed_at, signed_ip)
       VALUES (?, ?, ?, ?, NOW(), 'admin')
       ON DUPLICATE KEY UPDATE signature_data = VALUES(signature_data), signed_at = NOW(), signed_ip = 'admin'`,
      [uuidv4(), req.bizId, req.params.userId, signature],
    );
    res.json(await loadPair(req.bizId, req.params.userId));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/:bizId/health/sign', requireMember, async (req, res) => {
  const signature = String(req.body?.signature_data || '');
  if (!signature.startsWith('data:image/png;base64,') || signature.length < 80 || signature.length > 1500000) {
    return res.status(400).json({ error: 'Υπόγραψε στο πλαίσιο' });
  }
  const userId = req.member.userId;
  const bizId = req.params.bizId;
  try {
    const [[card]] = await db.query(
      'SELECT photo_url FROM member_health_cards WHERE business_id = ? AND user_id = ?',
      [bizId, userId],
    );
    if (!card?.photo_url) return res.status(400).json({ error: 'Βάλε πρώτα μια φωτογραφία σου' });
    const ip = String(req.headers['x-forwarded-for'] || req.socket?.remoteAddress || '').split(',')[0].trim().slice(0, 45);
    await db.query(
      `UPDATE member_health_cards
       SET signature_data = ?, signed_at = NOW(), signed_ip = ?
       WHERE business_id = ? AND user_id = ?`,
      [signature, ip || null, bizId, userId],
    );
    res.json(await loadPair(bizId, userId));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
