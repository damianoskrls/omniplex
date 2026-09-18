const express = require('express');
const router = express.Router();
const db = require('../db');

function requireClientAdmin(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth) return res.status(401).json({ error: 'Unauthorized' });
  const token = auth.replace('Bearer ', '');
  const jwt = require('jsonwebtoken');
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    if (payload.role !== 'client_admin') return res.status(403).json({ error: 'Forbidden' });
    req.admin = payload;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

/** Escape a CSV cell value */
function csv(val) {
  if (val == null) return '';
  const s = String(val);
  if (s.includes(',') || s.includes('"') || s.includes('\n')) {
    return '"' + s.replace(/"/g, '""') + '"';
  }
  return s;
}

/** Convert array of objects to CSV string with UTF-8 BOM */
function toCsv(rows, cols) {
  const header = cols.map(c => csv(c.label)).join(',');
  const body = rows.map(r => cols.map(c => csv(r[c.key])).join(',')).join('\n');
  return '﻿' + header + '\n' + body;
}

function sendCsv(res, filename, content) {
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
  res.send(content);
}

// ── Clients ────────────────────────────────────────────────────────────────
router.get('/clients', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  try {
    const [rows] = await db.query(`
      SELECT u.full_name, u.email, u.phone, u.account_status,
             u.date_of_birth, u.created_at,
             COUNT(DISTINCT b.id) AS total_bookings,
             COUNT(DISTINCT m.id) AS active_packages,
             u.loyalty_points, u.notes
      FROM users u
      LEFT JOIN bookings b ON b.user_id = u.id AND b.business_id = u.business_id
      LEFT JOIN user_memberships m ON m.user_id = u.id AND m.business_id = u.business_id
                                   AND m.membership_status IN ('active','trial')
      WHERE u.business_id = ? AND u.deleted_at IS NULL
      GROUP BY u.id
      ORDER BY u.full_name
    `, [bizId]);

    const cols = [
      { key: 'full_name',      label: 'Ονοματεπώνυμο' },
      { key: 'email',          label: 'Email' },
      { key: 'phone',          label: 'Τηλέφωνο' },
      { key: 'account_status', label: 'Κατάσταση' },
      { key: 'date_of_birth',  label: 'Ημ. Γέννησης' },
      { key: 'created_at',     label: 'Εγγραφή' },
      { key: 'total_bookings', label: 'Κρατήσεις' },
      { key: 'active_packages',label: 'Ενεργά Πακέτα' },
      { key: 'loyalty_points', label: 'Πόντοι' },
      { key: 'notes',          label: 'Σημειώσεις' },
    ];

    sendCsv(res, `pelates-${new Date().toISOString().slice(0,10)}.csv`, toCsv(rows, cols));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Bookings ───────────────────────────────────────────────────────────────
router.get('/bookings', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { from, to } = req.query;
  try {
    let q = `
      SELECT b.starts_at, b.ends_at, b.status, b.is_trial,
             u.full_name AS client_name, u.phone AS client_phone,
             s.name AS service_name, st.full_name AS staff_name,
             b.notes, b.created_at
      FROM bookings b
      LEFT JOIN users u ON u.id = b.user_id
      LEFT JOIN services s ON s.id = b.service_id
      LEFT JOIN staff st ON st.id = b.staff_id
      WHERE b.business_id = ?
    `;
    const params = [bizId];
    if (from) { q += ' AND b.starts_at >= ?'; params.push(from); }
    if (to)   { q += ' AND b.starts_at <= ?'; params.push(to + ' 23:59:59'); }
    q += ' ORDER BY b.starts_at DESC LIMIT 10000';

    const [rows] = await db.query(q, params);
    const cols = [
      { key: 'starts_at',    label: 'Ημερομηνία/Ώρα' },
      { key: 'client_name',  label: 'Πελάτης' },
      { key: 'client_phone', label: 'Τηλέφωνο' },
      { key: 'service_name', label: 'Υπηρεσία' },
      { key: 'staff_name',   label: 'Συνεργάτης' },
      { key: 'status',       label: 'Κατάσταση' },
      { key: 'is_trial',     label: 'Δοκιμαστικό' },
      { key: 'notes',        label: 'Σημειώσεις' },
      { key: 'created_at',   label: 'Δημιουργήθηκε' },
    ];
    sendCsv(res, `kratiseis-${new Date().toISOString().slice(0,10)}.csv`, toCsv(rows, cols));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Memberships ────────────────────────────────────────────────────────────
router.get('/memberships', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  try {
    const [rows] = await db.query(`
      SELECT u.full_name AS client_name, u.phone AS client_phone,
             s.name AS service_name, bp.name AS plan_name,
             m.membership_status, m.sessions_remaining, m.total_sessions,
             m.valid_from, m.valid_until, m.price_paid_cents,
             m.created_at
      FROM user_memberships m
      JOIN users u ON u.id = m.user_id
      LEFT JOIN services s ON s.id = m.service_id
      LEFT JOIN business_plans bp ON bp.id = m.plan_id
      WHERE m.business_id = ?
      ORDER BY m.created_at DESC
      LIMIT 10000
    `, [bizId]);

    const toEur = v => v != null ? (v / 100).toFixed(2) : '';
    const mapped = rows.map(r => ({ ...r, price_paid_cents: toEur(r.price_paid_cents) }));

    const cols = [
      { key: 'client_name',       label: 'Πελάτης' },
      { key: 'client_phone',      label: 'Τηλέφωνο' },
      { key: 'service_name',      label: 'Υπηρεσία' },
      { key: 'plan_name',         label: 'Πακέτο' },
      { key: 'membership_status', label: 'Κατάσταση' },
      { key: 'sessions_remaining',label: 'Υπόλοιπο Συνεδριών' },
      { key: 'total_sessions',    label: 'Σύνολο Συνεδριών' },
      { key: 'valid_from',        label: 'Έναρξη' },
      { key: 'valid_until',       label: 'Λήξη' },
      { key: 'price_paid_cents',  label: 'Τιμή (€)' },
      { key: 'created_at',        label: 'Αγορά' },
    ];
    sendCsv(res, `syndromites-${new Date().toISOString().slice(0,10)}.csv`, toCsv(mapped, cols));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Expenses ───────────────────────────────────────────────────────────────
router.get('/expenses', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { year, month } = req.query;
  try {
    let q = 'SELECT year, month, category, description, amount_cents, created_at FROM business_expenses WHERE business_id = ?';
    const params = [bizId];
    if (year)  { q += ' AND year = ?';  params.push(year); }
    if (month) { q += ' AND month = ?'; params.push(month); }
    q += ' ORDER BY year DESC, month DESC, created_at DESC';

    const [rows] = await db.query(q, params);
    const toEur = v => v != null ? (v / 100).toFixed(2) : '';
    const mapped = rows.map(r => ({ ...r, amount_cents: toEur(r.amount_cents) }));

    const cols = [
      { key: 'year',        label: 'Χρόνος' },
      { key: 'month',       label: 'Μήνας' },
      { key: 'category',    label: 'Κατηγορία' },
      { key: 'description', label: 'Περιγραφή' },
      { key: 'amount_cents',label: 'Ποσό (€)' },
      { key: 'created_at',  label: 'Ημερομηνία' },
    ];
    sendCsv(res, `eksoda-${new Date().toISOString().slice(0,10)}.csv`, toCsv(mapped, cols));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
