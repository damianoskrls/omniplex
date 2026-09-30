const express = require('express');
const path = require('path');
const fs = require('fs');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const { v4: uuidv4 } = require('uuid');
const db = require('../db');
const { FITNESS_GOAL_LABELS, normalizeFitnessGoal } = require('../lib/client_profile');

const router = express.Router();
const GOALS = Object.keys(FITNESS_GOAL_LABELS);
const EXPERIENCE = new Set(['beginner', 'some', 'regular']);

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
  return {
    intake_completed: !!intake?.completed_at,
    intake: intake || null,
    health: health || null,
    goals: Object.entries(FITNESS_GOAL_LABELS).map(([id, label]) => ({ id, label })),
  };
}

router.get('/admin/:userId', requireAdmin, async (req, res) => {
  try {
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
  const userId = req.member.userId;
  const bizId = req.params.bizId;
  const goal = GOALS.includes(req.body?.fitness_goal) ? req.body.fitness_goal : 'general';
  const experience = EXPERIENCE.has(req.body?.experience) ? req.body.experience : 'beginner';
  const visits = Math.min(14, Math.max(1, Number(req.body?.visits_per_week) || 3));
  const motivation = String(req.body?.motivation || '').trim().slice(0, 2000);
  const goalText = String(req.body?.goal_text || '').trim().slice(0, 2000);
  try {
    const id = uuidv4();
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
      [id, bizId, userId, goal, motivation || null, goalText || null, experience, visits],
    );
    await db.query('UPDATE users SET fitness_goal = ? WHERE id = ? AND business_id = ?', [
      normalizeFitnessGoal(goal), userId, bizId,
    ]);
    res.json(await loadPair(bizId, userId));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:bizId/health', requireMember, async (req, res) => {
  const userId = req.member.userId;
  const bizId = req.params.bizId;
  const hasConditions = req.body?.has_conditions ? 1 : 0;
  const takesMedication = req.body?.takes_medication ? 1 : 0;
  const conditions = String(req.body?.conditions_text || '').trim().slice(0, 4000);
  const medication = String(req.body?.medication_text || '').trim().slice(0, 4000);
  try {
    await db.query(
      `INSERT INTO member_health_cards
        (id, business_id, user_id, has_conditions, conditions_text, takes_medication, medication_text)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
        has_conditions = VALUES(has_conditions),
        conditions_text = VALUES(conditions_text),
        takes_medication = VALUES(takes_medication),
        medication_text = VALUES(medication_text)`,
      [uuidv4(), bizId, userId, hasConditions, hasConditions ? conditions || null : null, takesMedication, takesMedication ? medication || null : null],
    );
    res.json(await loadPair(bizId, userId));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const upload = multer({
  storage: multer.diskStorage({
    destination(req, _file, cb) {
      const dir = path.join(process.env.UPLOAD_DIR || './uploads', req.params.bizId, 'health', req.member.userId);
      fs.mkdirSync(dir, { recursive: true });
      cb(null, dir);
    },
    filename(_req, file, cb) {
      const ext = path.extname(file.originalname || '').toLowerCase().slice(0, 8) || '.jpg';
      cb(null, `${Date.now()}${ext}`);
    },
  }),
  limits: { fileSize: 8 * 1024 * 1024 },
  fileFilter(_req, file, cb) {
    const ok = /^(image\/(jpeg|png|webp|heic)|application\/pdf)$/.test(file.mimetype);
    cb(ok ? null : new Error('Μόνο φωτογραφία ή PDF'), ok);
  },
});

router.post('/:bizId/health/document', requireMember, (req, res) => {
  upload.single('document')(req, res, async (err) => {
    if (err) return res.status(400).json({ error: err.message || 'Αποτυχία ανεβάσματος' });
    if (!req.file) return res.status(400).json({ error: 'Δεν επιλέχθηκε αρχείο' });
    const url = `/uploads/${req.params.bizId}/health/${req.member.userId}/${req.file.filename}`;
    try {
      await db.query(
        `INSERT INTO member_health_cards (id, business_id, user_id, document_url, document_name)
         VALUES (?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE document_url = VALUES(document_url), document_name = VALUES(document_name)`,
        [uuidv4(), req.params.bizId, req.member.userId, url, req.file.originalname || req.file.filename],
      );
      res.json(await loadPair(req.params.bizId, req.member.userId));
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  });
});

module.exports = router;
