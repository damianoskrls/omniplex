// ============================================================
// FILE: src/middleware/auth.js
// JWT authentication + Master Admin check
// ============================================================

const jwt = require('jsonwebtoken');
require('dotenv').config();

// Verifies JWT token sent in Authorization header
function authenticate(req, res, next) {
  const header = req.headers['authorization'];
  if (!header) return res.status(401).json({ error: 'No token provided' });

  const token = header.startsWith('Bearer ') ? header.slice(7) : header;

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

// Checks that the logged-in user is a master admin
function requireMasterAdmin(req, res, next) {
  if (!req.user || req.user.role !== 'master_admin') {
    return res.status(403).json({ error: 'Master admin access required' });
  }
  next();
}

module.exports = { authenticate, requireMasterAdmin };
