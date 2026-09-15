// ============================================================
// FILE: src/routes/auth.routes.js
// Login endpoint — returns JWT token
// ============================================================

const express = require('express');
const bcrypt  = require('bcryptjs');
const jwt     = require('jsonwebtoken');
const router  = express.Router();
require('dotenv').config();

// For now: one hardcoded master admin account.
// In production: store admins in a DB table with hashed passwords.
const MASTER_ADMIN = {
  email:    'admin@bookup.io',
  // bcrypt hash of: admin123  (change in production!)
  password: '$2a$10$A/8SvpX4Qr9G5Y91ng85bOcF/j0biwdGcJ6/tl50d0hgv18ooctAm',
  role:     'master_admin',
};

// POST /api/auth/login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    if (email !== MASTER_ADMIN.email) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const valid = await bcrypt.compare(password, MASTER_ADMIN.password);
    if (!valid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const token = jwt.sign(
      { email: MASTER_ADMIN.email, role: MASTER_ADMIN.role },
      process.env.JWT_SECRET,
      { expiresIn: '8h' }
    );

    return res.json({ token, role: MASTER_ADMIN.role });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
