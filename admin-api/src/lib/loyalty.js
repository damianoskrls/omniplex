const { v4: uuidv4 } = require('uuid');

async function countConfirmedSessions(conn, userId, businessId, month, year) {
  const [[row]] = await conn.query(`
    SELECT COUNT(*) AS cnt FROM bookings
    WHERE user_id = ? AND business_id = ?
      AND attendance_confirmed = 1
      AND status NOT IN ('cancelled', 'no_show')
      AND MONTH(starts_at) = ? AND YEAR(starts_at) = ?
  `, [userId, businessId, month, year]);
  return Number(row?.cnt || 0);
}

async function awardLoyaltyPoints(conn, userId, businessId, bookingId, rating) {
  const [[cfg]] = await conn.query(
    'SELECT feature_loyalty_points FROM business_configs WHERE business_id = ?',
    [businessId]
  );
  if (!cfg?.feature_loyalty_points) {
    return { pointsEarned: 0, totalPoints: null, reasons: [] };
  }

  const now = new Date();
  const month = now.getMonth() + 1;
  const year = now.getFullYear();
  const sessionsBefore = await countConfirmedSessions(conn, userId, businessId, month, year);

  const reasons = [];
  let points = 10;
  reasons.push('Παρουσία σε προπόνηση (+10)');

  if (rating >= 4) {
    points += 5;
    reasons.push('Υψηλή αξιολόγηση (+5)');
  }
  if (rating === 5) {
    points += 5;
    reasons.push('Τέλεια αξιολόγηση (+5)');
  }

  const sessionsAfter = sessionsBefore + 1;
  if (sessionsAfter >= 4) {
    points += 10;
    reasons.push('Συνέπεια 4+ προπονήσεις/μήνα (+10)');
  }
  if (sessionsAfter >= 6) {
    points += 15;
    reasons.push('Στόχος 6 προπονήσεις/μήνα (+15)');
  }

  await conn.query(
    'UPDATE users SET loyalty_points = loyalty_points + ? WHERE id = ?',
    [points, userId]
  );
  await conn.query(
    `INSERT INTO loyalty_transactions (id, user_id, business_id, booking_id, points, reason)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [uuidv4(), userId, businessId, bookingId, points, reasons.join('; ')]
  );

  const [[user]] = await conn.query('SELECT loyalty_points FROM users WHERE id = ?', [userId]);
  return {
    pointsEarned: points,
    totalPoints: user?.loyalty_points || 0,
    reasons,
    sessionsThisMonth: sessionsAfter,
  };
}

async function getUserStats(conn, userId, businessId) {
  const now = new Date();
  const month = now.getMonth() + 1;
  const year = now.getFullYear();

  const [[user]] = await conn.query(
    'SELECT loyalty_points FROM users WHERE id = ?',
    [userId]
  );
  const [[goal]] = await conn.query(
    'SELECT target_sessions, period FROM user_goals WHERE user_id = ? AND business_id = ? AND is_active = 1',
    [userId, businessId]
  );
  const sessionsThisMonth = await countConfirmedSessions(conn, userId, businessId, month, year);
  const target = goal?.target_sessions || 6;
  const progressPct = Math.min(100, Math.round((sessionsThisMonth / target) * 100));

  const [recentLoyalty] = await conn.query(
    `SELECT points, reason, created_at FROM loyalty_transactions
     WHERE user_id = ? ORDER BY created_at DESC LIMIT 5`,
    [userId]
  );

  return {
    loyalty_points: user?.loyalty_points || 0,
    sessions_this_month: sessionsThisMonth,
    goal: goal ? { target_sessions: target, period: goal.period } : { target_sessions: 6, period: 'monthly' },
    goal_progress_pct: progressPct,
    goal_met: sessionsThisMonth >= target,
    recent_loyalty: recentLoyalty,
  };
}

async function visitsLast30Days(conn, userId, businessId) {
  const [[row]] = await conn.query(`
    SELECT COUNT(*) AS cnt FROM bookings
    WHERE user_id = ? AND business_id = ?
      AND attendance_confirmed = 1
      AND status NOT IN ('cancelled', 'no_show')
      AND starts_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
  `, [userId, businessId]);
  return Number(row?.cnt || 0);
}

function discountedPrice(priceCents, reward) {
  const price = Number(priceCents) || 0;
  if (reward.reward_type === 'discount_percent') {
    const pct = Math.min(100, Math.max(0, Number(reward.discount_percent) || 0));
    return Math.max(0, Math.round(price * (1 - pct / 100)));
  }
  if (reward.reward_type === 'discount_fixed') {
    return Math.max(0, price - (Number(reward.discount_cents) || 0));
  }
  return price;
}

async function activeDiscountRows(conn, userId, businessId) {
  const [rows] = await conn.query(`
    SELECT r.id AS redemption_id, w.reward_type, w.discount_percent, w.discount_cents, w.title
    FROM loyalty_redemptions r
    JOIN loyalty_rewards w ON (w.id COLLATE utf8mb4_unicode_ci) = (r.reward_id COLLATE utf8mb4_unicode_ci)
    WHERE r.user_id = ? AND r.business_id = ? AND r.status = 'active'
      AND w.active = 1
      AND w.reward_type IN ('discount_percent', 'discount_fixed')
    ORDER BY r.created_at ASC
  `, [userId, businessId]);
  return rows;
}

function bestDiscount(priceCents, rows) {
  let best = null;
  for (const row of rows) {
    const next = discountedPrice(priceCents, row);
    if (next < Number(priceCents) && (!best || next < best.priceCents)) {
      best = { priceCents: next, redemptionId: row.redemption_id, title: row.title };
    }
  }
  return best;
}

async function previewRewardPrice(conn, userId, businessId, priceCents) {
  if (!userId) return { priceCents: Number(priceCents) || 0, title: null, redemptionId: null };
  const best = bestDiscount(priceCents, await activeDiscountRows(conn, userId, businessId));
  return best || { priceCents: Number(priceCents) || 0, title: null, redemptionId: null };
}

async function applyRewardPrice(conn, userId, businessId, priceCents) {
  const preview = await previewRewardPrice(conn, userId, businessId, priceCents);
  if (!preview.redemptionId) return preview;
  const [result] = await conn.query(
    `UPDATE loyalty_redemptions SET status = 'used', used_at = NOW() WHERE id = ? AND status = 'active'`,
    [preview.redemptionId],
  );
  if (!result.affectedRows) {
    return { priceCents: Number(priceCents) || 0, title: null, redemptionId: null };
  }
  return preview;
}

module.exports = {
  countConfirmedSessions,
  awardLoyaltyPoints,
  getUserStats,
  visitsLast30Days,
  previewRewardPrice,
  applyRewardPrice,
};
