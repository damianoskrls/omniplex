const express = require('express');
const { v4: uuidv4 } = require('uuid');
const jwt = require('jsonwebtoken');
const db = require('../db');
const { visitsLast30Days } = require('../lib/loyalty');

const router = express.Router();
const TYPES = new Set(['discount_percent', 'discount_fixed', 'offer']);

function requireAdmin(req, res, next) {
  try {
    const payload = jwt.verify((req.headers.authorization || '').replace('Bearer ', ''), process.env.JWT_SECRET);
    if (payload.role !== 'client_admin' && payload.role !== 'owner' && payload.role !== 'admin') {
      return res.status(403).json({ error: 'Forbidden' });
    }
    req.bizId = payload.businessId;
    next();
  } catch {
    return res.status(401).json({ error: 'Unauthorized' });
  }
}

function requireMember(req, res, next) {
  try {
    const payload = jwt.verify((req.headers.authorization || '').replace('Bearer ', ''), process.env.JWT_SECRET);
    if (!payload.userId || payload.role === 'client_admin') return res.status(403).json({ error: 'Forbidden' });
    req.member = payload;
    next();
  } catch {
    return res.status(401).json({ error: 'Unauthorized' });
  }
}

function cleanReward(body) {
  const rewardType = TYPES.has(body.reward_type) ? body.reward_type : 'offer';
  const title = String(body.title || '').trim();
  if (!title) return { error: 'Χρειάζεται τίτλος' };
  return {
    title,
    description: String(body.description || '').trim() || null,
    reward_type: rewardType,
    discount_percent: rewardType === 'discount_percent' ? Math.min(100, Math.max(1, Number(body.discount_percent) || 0)) : null,
    discount_cents: rewardType === 'discount_fixed' ? Math.max(0, Math.round(Number(body.discount_cents) || 0)) : null,
    points_cost: Math.max(0, Math.round(Number(body.points_cost) || 0)),
    min_visits: Math.max(0, Math.round(Number(body.min_visits) || 0)),
    active: body.active === false || body.active === 0 ? 0 : 1,
  };
}

router.get('/admin', requireAdmin, async (req, res) => {
  try {
    const [rewards] = await db.query(
      'SELECT * FROM loyalty_rewards WHERE business_id = ? ORDER BY created_at DESC',
      [req.bizId],
    );
    const [redemptions] = await db.query(
      `SELECT r.id, r.status, r.points_spent, r.created_at, r.used_at,
              w.title, u.full_name
       FROM loyalty_redemptions r
       JOIN loyalty_rewards w ON (w.id COLLATE utf8mb4_unicode_ci) = (r.reward_id COLLATE utf8mb4_unicode_ci)
       LEFT JOIN users u ON (u.id COLLATE utf8mb4_unicode_ci) = (r.user_id COLLATE utf8mb4_unicode_ci)
       WHERE r.business_id = ?
       ORDER BY r.created_at DESC
       LIMIT 40`,
      [req.bizId],
    );
    res.json({ rewards, redemptions });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/admin', requireAdmin, async (req, res) => {
  const reward = cleanReward(req.body || {});
  if (reward.error) return res.status(400).json({ error: reward.error });
  try {
    const id = uuidv4();
    await db.query(
      `INSERT INTO loyalty_rewards
        (id, business_id, title, description, reward_type, discount_percent, discount_cents, points_cost, min_visits, active)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [id, req.bizId, reward.title, reward.description, reward.reward_type, reward.discount_percent, reward.discount_cents, reward.points_cost, reward.min_visits, reward.active],
    );
    res.status(201).json({ id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.patch('/admin/:id', requireAdmin, async (req, res) => {
  const reward = cleanReward(req.body || {});
  if (reward.error) return res.status(400).json({ error: reward.error });
  try {
    const [result] = await db.query(
      `UPDATE loyalty_rewards
       SET title=?, description=?, reward_type=?, discount_percent=?, discount_cents=?, points_cost=?, min_visits=?, active=?
       WHERE id=? AND business_id=?`,
      [reward.title, reward.description, reward.reward_type, reward.discount_percent, reward.discount_cents, reward.points_cost, reward.min_visits, reward.active, req.params.id, req.bizId],
    );
    if (!result.affectedRows) return res.status(404).json({ error: 'Δεν βρέθηκε' });
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/admin/:id', requireAdmin, async (req, res) => {
  try {
    await db.query('UPDATE loyalty_rewards SET active = 0 WHERE id = ? AND business_id = ?', [req.params.id, req.bizId]);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/mine', requireMember, async (req, res) => {
  const userId = req.member.userId;
  const bizId = req.member.businessId;
  try {
    const [[user]] = await db.query('SELECT loyalty_points FROM users WHERE id = ?', [userId]);
    const visits = await visitsLast30Days(db, userId, bizId);
    const [rewards] = await db.query(
      'SELECT * FROM loyalty_rewards WHERE business_id = ? AND active = 1 ORDER BY min_visits DESC, points_cost ASC',
      [bizId],
    );
    const [active] = await db.query(
      `SELECT reward_id FROM loyalty_redemptions WHERE user_id = ? AND business_id = ? AND status = 'active'`,
      [userId, bizId],
    );
    const activeIds = new Set(active.map((row) => row.reward_id));
    res.json({
      points: Number(user?.loyalty_points || 0),
      visits_30d: visits,
      rewards: rewards.map((reward) => ({
        ...reward,
        eligible: visits >= Number(reward.min_visits || 0) && Number(user?.loyalty_points || 0) >= Number(reward.points_cost || 0),
        claimed: activeIds.has(reward.id),
      })),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/mine/:id/redeem', requireMember, async (req, res) => {
  const userId = req.member.userId;
  const bizId = req.member.businessId;
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const [[reward]] = await conn.query(
      'SELECT * FROM loyalty_rewards WHERE id = ? AND business_id = ? AND active = 1',
      [req.params.id, bizId],
    );
    if (!reward) {
      await conn.rollback();
      return res.status(404).json({ error: 'Η προσφορά δεν βρέθηκε' });
    }
    const visits = await visitsLast30Days(conn, userId, bizId);
    if (visits < Number(reward.min_visits || 0)) {
      await conn.rollback();
      return res.status(400).json({ error: `Χρειάζεσαι ${reward.min_visits} παρουσίες τις τελευταίες 30 ημέρες` });
    }
    const [[existing]] = await conn.query(
      `SELECT id FROM loyalty_redemptions WHERE user_id = ? AND reward_id = ? AND status = 'active'`,
      [userId, reward.id],
    );
    if (existing) {
      await conn.rollback();
      return res.status(400).json({ error: 'Η προσφορά είναι ήδη ενεργή' });
    }
    const cost = Number(reward.points_cost || 0);
    if (cost > 0) {
      const [updated] = await conn.query(
        'UPDATE users SET loyalty_points = loyalty_points - ? WHERE id = ? AND loyalty_points >= ?',
        [cost, userId, cost],
      );
      if (!updated.affectedRows) {
        await conn.rollback();
        return res.status(400).json({ error: 'Δεν έχεις αρκετούς πόντους' });
      }
      await conn.query(
        `INSERT INTO loyalty_transactions (id, user_id, business_id, booking_id, points, reason)
         VALUES (?, ?, ?, NULL, ?, ?)`,
        [uuidv4(), userId, bizId, -cost, `Εξαργύρωση: ${reward.title}`],
      );
    }
    await conn.query(
      `INSERT INTO loyalty_redemptions (id, business_id, user_id, reward_id, points_spent, status)
       VALUES (?, ?, ?, ?, ?, 'active')`,
      [uuidv4(), bizId, userId, reward.id, cost],
    );
    await conn.commit();
    const [[user]] = await db.query('SELECT loyalty_points FROM users WHERE id = ?', [userId]);
    res.json({ ok: true, points: Number(user?.loyalty_points || 0) });
  } catch (err) {
    await conn.rollback();
    res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

module.exports = router;
