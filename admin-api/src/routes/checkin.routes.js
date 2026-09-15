// ============================================================
// Entrance scanner check-in routes
// Two flows:
//   1. Member shows QR on phone → gym's hardware/web scanner reads it
//   2. Admin scanner page (web) scans via camera or HID keyboard input
// ============================================================

const express    = require('express');
const jwt        = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const db         = require('../db');

const router = express.Router();

// ── Mobile auth middleware (member) ──────────────────────────
function requireMobileUser(req, res, next) {
  const header = req.headers['authorization'];
  if (!header) return res.status(401).json({ error: 'Δεν είστε συνδεδεμένος' });
  const token = header.startsWith('Bearer ') ? header.slice(7) : header;
  try {
    const d = jwt.verify(token, process.env.JWT_SECRET);
    req.user = d;
    next();
  } catch {
    return res.status(401).json({ error: 'Μη έγκυρο token' });
  }
}

// ── Admin auth middleware ─────────────────────────────────────
function requireClientAdmin(req, res, next) {
  const header = req.headers['authorization'];
  if (!header) return res.status(401).json({ error: 'No token' });
  const token = header.startsWith('Bearer ') ? header.slice(7) : header;
  try {
    const d = jwt.verify(token, process.env.JWT_SECRET);
    if (d.role !== 'client_admin') return res.status(403).json({ error: 'Not authorized' });
    req.admin = d;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

// ── Ensure user has a check_in_token ─────────────────────────
async function ensureCheckinToken(userId) {
  const [[row]] = await db.query(
    'SELECT check_in_token FROM users WHERE id = ?', [userId]
  );
  if (row?.check_in_token) return row.check_in_token;
  const token = uuidv4();
  await db.query('UPDATE users SET check_in_token = ? WHERE id = ?', [token, userId]);
  return token;
}

// ── Find best active membership for deduction ────────────────
async function findActiveMembership(userId, bizId) {
  const [rows] = await db.query(
    `SELECT * FROM user_memberships
     WHERE user_id = ? AND business_id = ?
       AND valid_from <= CURDATE() AND valid_until >= CURDATE()
     ORDER BY
       CASE WHEN total_sessions >= 9999 THEN 1 ELSE 0 END ASC,
       valid_until ASC`,
    [userId, bizId]
  );
  return rows.find(m => m.total_sessions >= 9999 || m.used_sessions < m.total_sessions) || null;
}

// ============================================================
// GET /api/checkin/:bizId/my-code
// Member gets their personal check-in token (generates if needed)
// ============================================================
router.get('/:bizId/my-code', requireMobileUser, async (req, res) => {
  const { bizId } = req.params;
  const userId = req.user.userId;
  try {
    const [[user]] = await db.query(
      'SELECT id, full_name, business_id FROM users WHERE id = ? AND business_id = ?',
      [userId, bizId]
    );
    if (!user) return res.status(404).json({ error: 'Χρήστης δεν βρέθηκε' });

    const token = await ensureCheckinToken(userId);

    // Also return membership summary
    const membership = await findActiveMembership(userId, bizId);
    const remaining = membership
      ? (membership.total_sessions >= 9999 ? null : membership.total_sessions - membership.used_sessions)
      : 0;

    return res.json({
      token,
      userId,
      fullName: user.full_name,
      remaining,
      isUnlimited: membership?.total_sessions >= 9999,
      hasActiveMembership: !!membership,
    });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// POST /api/checkin/:bizId/scan
// Gym scanner submits a member token → deduct session
// Auth: admin JWT
// Body: { token: string }
// ============================================================
router.post('/:bizId/scan', requireClientAdmin, async (req, res) => {
  const { bizId } = req.params;
  const { token } = req.body || {};

  if (!token || typeof token !== 'string' || token.trim().length === 0) {
    return res.status(400).json({ error: 'Δεν στάλθηκε token' });
  }

  try {
    const [[user]] = await db.query(
      `SELECT id, full_name, email, phone
       FROM users WHERE check_in_token = ? AND business_id = ?`,
      [token.trim(), bizId]
    );

    if (!user) {
      return res.status(404).json({
        error: 'Μέλος δεν βρέθηκε',
        code: 'member_not_found',
      });
    }

    const membership = await findActiveMembership(user.id, bizId);

    if (!membership) {
      return res.status(403).json({
        error: 'Δεν υπάρχει ενεργή συνδρομή',
        code: 'no_membership',
        member: { fullName: user.full_name, email: user.email },
      });
    }

    const isUnlimited = membership.total_sessions >= 9999;
    let remaining = null;

    if (!isUnlimited) {
      await db.query(
        'UPDATE user_memberships SET used_sessions = used_sessions + 1 WHERE id = ?',
        [membership.id]
      );
      remaining = membership.total_sessions - membership.used_sessions - 1;
    }

    // Record entrance check-in
    await db.query(
      `INSERT INTO entrance_checkins (id, business_id, user_id, membership_id, session_deducted, checked_in_at)
       VALUES (?, ?, ?, ?, ?, NOW())`,
      [uuidv4(), bizId, user.id, membership.id, isUnlimited ? 0 : 1]
    );

    return res.json({
      success: true,
      member: {
        fullName: user.full_name,
        email: user.email,
        phone: user.phone,
      },
      isUnlimited,
      remaining,
      membershipValidUntil: membership.valid_until,
    });
  } catch (err) {
    console.error('entrance scan error', err);
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// GET /api/checkin/:bizId/recent
// Last 20 entrance check-ins today (admin)
// ============================================================
router.get('/:bizId/recent', requireClientAdmin, async (req, res) => {
  const { bizId } = req.params;
  try {
    const [rows] = await db.query(
      `SELECT ec.id, ec.checked_in_at, ec.session_deducted,
              u.full_name, u.email,
              um.total_sessions, um.used_sessions
       FROM entrance_checkins ec
       JOIN users u ON u.id = ec.user_id
       LEFT JOIN user_memberships um ON um.id = ec.membership_id
       WHERE ec.business_id = ?
         AND DATE(ec.checked_in_at) = CURDATE()
       ORDER BY ec.checked_in_at DESC
       LIMIT 20`,
      [bizId]
    );
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

module.exports = router;
