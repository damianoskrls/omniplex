const express = require('express');
const router = express.Router();
const db = require('../db');
const crypto = require('crypto');

function requireAdmin(req, res, next) {
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  const jwt = require('jsonwebtoken');
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    if (payload.role !== 'owner' && payload.role !== 'admin') return res.status(403).json({ error: 'Forbidden' });
    req.bizId = payload.business_id || payload.bizId;
    req.userId = payload.sub || payload.id;
    next();
  } catch { return res.status(401).json({ error: 'Unauthorized' }); }
}

// Public: get questionnaire to fill
router.get('/sign/:token', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT qr.id, qr.token, qr.status, qr.answers, qr.expires_at,
              qt.title, qt.description, qt.questions,
              u.full_name, u.email
       FROM questionnaire_responses qr
       JOIN questionnaire_templates qt ON qt.id = qr.template_id
       LEFT JOIN users u ON u.id = qr.user_id
       WHERE qr.token = ? AND qr.expires_at > NOW()`,
      [req.params.token]
    );
    if (!rows.length) return res.status(404).json({ error: 'Η φόρμα δεν βρέθηκε ή έχει λήξει.' });
    const r = rows[0];
    res.json({
      id: r.id,
      status: r.status,
      title: r.title,
      description: r.description,
      questions: JSON.parse(r.questions || '[]'),
      full_name: r.full_name,
      email: r.email,
      already_answered: r.status === 'completed',
      answers: r.status === 'completed' ? JSON.parse(r.answers || '{}') : null,
    });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Public: submit answers
router.post('/sign/:token', async (req, res) => {
  try {
    const { answers } = req.body;
    const [rows] = await db.query(
      'SELECT id, status, expires_at FROM questionnaire_responses WHERE token = ? AND expires_at > NOW()',
      [req.params.token]
    );
    if (!rows.length) return res.status(404).json({ error: 'Η φόρμα δεν βρέθηκε ή έχει λήξει.' });
    if (rows[0].status === 'completed') return res.status(400).json({ error: 'Έχει ήδη συμπληρωθεί.' });
    await db.query(
      'UPDATE questionnaire_responses SET status=?, answers=?, completed_at=NOW() WHERE id=?',
      ['completed', JSON.stringify(answers), rows[0].id]
    );
    res.json({ ok: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Admin: list templates
router.get('/templates', requireAdmin, async (req, res) => {
  try {
    const [rows] = await db.query(
      'SELECT id, title, description, questions, created_at FROM questionnaire_templates WHERE business_id=? ORDER BY created_at DESC',
      [req.bizId]
    );
    res.json(rows.map(r => ({ ...r, questions: JSON.parse(r.questions || '[]') })));
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Admin: create template
router.post('/templates', requireAdmin, async (req, res) => {
  try {
    const { title, description, questions } = req.body;
    if (!title || !questions?.length) return res.status(400).json({ error: 'Τίτλος και ερωτήσεις απαιτούνται' });
    const id = crypto.randomUUID();
    await db.query(
      'INSERT INTO questionnaire_templates (id, business_id, title, description, questions) VALUES (?,?,?,?,?)',
      [id, req.bizId, title, description || '', JSON.stringify(questions)]
    );
    res.json({ id });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Admin: update template
router.put('/templates/:id', requireAdmin, async (req, res) => {
  try {
    const { title, description, questions } = req.body;
    await db.query(
      'UPDATE questionnaire_templates SET title=?, description=?, questions=? WHERE id=? AND business_id=?',
      [title, description || '', JSON.stringify(questions), req.params.id, req.bizId]
    );
    res.json({ ok: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Admin: delete template
router.delete('/templates/:id', requireAdmin, async (req, res) => {
  try {
    await db.query('DELETE FROM questionnaire_templates WHERE id=? AND business_id=?', [req.params.id, req.bizId]);
    res.json({ ok: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Admin: send to client
router.post('/templates/:id/send', requireAdmin, async (req, res) => {
  try {
    const { user_id } = req.body;
    if (!user_id) return res.status(400).json({ error: 'user_id απαιτείται' });
    const [tmpl] = await db.query(
      'SELECT id FROM questionnaire_templates WHERE id=? AND business_id=?',
      [req.params.id, req.bizId]
    );
    if (!tmpl.length) return res.status(404).json({ error: 'Template not found' });
    const token = crypto.randomBytes(32).toString('hex');
    const id = crypto.randomUUID();
    const expires = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    await db.query(
      'INSERT INTO questionnaire_responses (id, template_id, business_id, user_id, token, status, expires_at) VALUES (?,?,?,?,?,?,?)',
      [id, req.params.id, req.bizId, user_id, token, 'pending', expires]
    );
    res.json({ token, url: `/q/${token}` });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Admin: list responses
router.get('/responses', requireAdmin, async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT qr.id, qr.token, qr.status, qr.answers, qr.completed_at, qr.created_at,
              qt.title AS template_title,
              u.full_name, u.phone, u.email
       FROM questionnaire_responses qr
       JOIN questionnaire_templates qt ON qt.id = qr.template_id
       LEFT JOIN users u ON u.id = qr.user_id
       WHERE qr.business_id=?
       ORDER BY qr.created_at DESC
       LIMIT 200`,
      [req.bizId]
    );
    res.json(rows.map(r => ({ ...r, answers: r.answers ? JSON.parse(r.answers) : null })));
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Admin: single response detail
router.get('/responses/:id', requireAdmin, async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT qr.*, qt.title AS template_title, qt.questions,
              u.full_name, u.phone, u.email
       FROM questionnaire_responses qr
       JOIN questionnaire_templates qt ON qt.id = qr.template_id
       LEFT JOIN users u ON u.id = qr.user_id
       WHERE qr.id=? AND qr.business_id=?`,
      [req.params.id, req.bizId]
    );
    if (!rows.length) return res.status(404).json({ error: 'Not found' });
    const r = rows[0];
    res.json({ ...r, questions: JSON.parse(r.questions || '[]'), answers: r.answers ? JSON.parse(r.answers) : null });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

module.exports = router;
