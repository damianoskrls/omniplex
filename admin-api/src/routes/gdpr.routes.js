const express = require('express');
const router = express.Router();
const db = require('../lib/db');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');

function requireClientAdmin(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth) return res.status(401).json({ error: 'Unauthorized' });
  try {
    const payload = jwt.verify(auth.replace('Bearer ', ''), process.env.JWT_SECRET);
    if (payload.role !== 'client_admin') return res.status(403).json({ error: 'Forbidden' });
    req.admin = payload;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

// ── Admin: list consents ────────────────────────────────────────────────────
router.get('/consents', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  try {
    const [rows] = await db.query(`
      SELECT g.id, g.full_name, g.email, g.phone, g.signed_at, g.expires_at, g.created_at,
             u.full_name AS linked_client
      FROM gdpr_consents g
      LEFT JOIN users u ON u.id = g.user_id
      WHERE g.business_id = ?
      ORDER BY g.created_at DESC
      LIMIT 200
    `, [bizId]);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Admin: create / send consent link ──────────────────────────────────────
router.post('/consents', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { user_id, full_name, email, phone } = req.body;
  if (!full_name && !user_id) return res.status(400).json({ error: 'full_name or user_id required' });

  try {
    let name = full_name, userEmail = email, userPhone = phone;

    if (user_id) {
      const [[u]] = await db.query('SELECT full_name, email, phone FROM users WHERE id = ? AND business_id = ?', [user_id, bizId]);
      if (!u) return res.status(404).json({ error: 'Client not found' });
      name = full_name || u.full_name;
      userEmail = email || u.email;
      userPhone = phone || u.phone;
    }

    const token = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days

    await db.query(`
      INSERT INTO gdpr_consents (id, business_id, user_id, full_name, email, phone, token, expires_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `, [uuidv4(), bizId, user_id || null, name, userEmail || null, userPhone || null, token, expiresAt]);

    const link = `${process.env.APP_URL || 'https://handstand.gr'}/gdpr/${token}`;
    res.json({ token, link, expires_at: expiresAt });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Admin: get GDPR text template ──────────────────────────────────────────
router.get('/template', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  try {
    const [[cfg]] = await db.query('SELECT gdpr_text FROM business_configs WHERE business_id = ?', [bizId]);
    res.json({ gdpr_text: cfg?.gdpr_text || defaultGdprText });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Admin: save GDPR text template ─────────────────────────────────────────
router.put('/template', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { gdpr_text } = req.body;
  try {
    await db.query('UPDATE business_configs SET gdpr_text = ? WHERE business_id = ?', [gdpr_text, bizId]);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Public: get consent form (by token) ────────────────────────────────────
router.get('/sign/:token', async (req, res) => {
  try {
    const [[consent]] = await db.query(`
      SELECT g.id, g.full_name, g.signed_at, g.expires_at, g.business_id,
             bc.gdpr_text, bc.app_name, b.name AS biz_name
      FROM gdpr_consents g
      JOIN businesses b ON b.id = g.business_id
      LEFT JOIN business_configs bc ON bc.business_id = g.business_id
      WHERE g.token = ?
    `, [req.params.token]);

    if (!consent) return res.status(404).json({ error: 'Ο σύνδεσμος δεν βρέθηκε' });
    if (new Date(consent.expires_at) < new Date()) return res.status(410).json({ error: 'Ο σύνδεσμος έχει λήξει' });

    res.json({
      id: consent.id,
      full_name: consent.full_name,
      signed_at: consent.signed_at,
      gym_name: consent.app_name || consent.biz_name,
      gdpr_text: consent.gdpr_text || defaultGdprText,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Public: submit signature ────────────────────────────────────────────────
router.post('/sign/:token', async (req, res) => {
  const { signature_data } = req.body;
  if (!signature_data) return res.status(400).json({ error: 'Signature required' });

  try {
    const [[consent]] = await db.query(
      'SELECT id, signed_at, expires_at FROM gdpr_consents WHERE token = ?',
      [req.params.token]
    );
    if (!consent) return res.status(404).json({ error: 'Ο σύνδεσμος δεν βρέθηκε' });
    if (new Date(consent.expires_at) < new Date()) return res.status(410).json({ error: 'Ο σύνδεσμος έχει λήξει' });
    if (consent.signed_at) return res.json({ ok: true, already_signed: true });

    const ip = req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.socket.remoteAddress;
    await db.query(
      'UPDATE gdpr_consents SET signed_at = NOW(), signature_data = ?, ip_address = ? WHERE token = ?',
      [signature_data, ip, req.params.token]
    );
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const defaultGdprText = `**Δήλωση Συναίνεσης για Επεξεργασία Προσωπικών Δεδομένων (GDPR)**

Σύμφωνα με τον Γενικό Κανονισμό Προστασίας Δεδομένων (ΕΕ) 2016/679 (GDPR) και την ισχύουσα ελληνική νομοθεσία, η επιχείρησή μας συλλέγει και επεξεργάζεται τα ακόλουθα προσωπικά δεδομένα:

**Δεδομένα που συλλέγουμε:**
- Ονοματεπώνυμο και στοιχεία επικοινωνίας (τηλέφωνο, email)
- Ημερομηνία γέννησης
- Ιστορικό κρατήσεων και συμμετοχών
- Πληροφορίες υγείας/φυσικής κατάστασης (εφόσον μας τις κοινοποιήσετε)

**Σκοπός επεξεργασίας:**
- Διαχείριση κρατήσεων και συνδρομών
- Αποστολή ενημερώσεων σχετικά με τις υπηρεσίες μας
- Βελτίωση της εξυπηρέτησής σας

**Δικαιώματά σας:**
Έχετε δικαίωμα πρόσβασης, διόρθωσης, διαγραφής και φορητότητας των δεδομένων σας. Μπορείτε να αποσύρετε τη συγκατάθεσή σας οποτεδήποτε.

**Χρόνος διατήρησης:** Τα δεδομένα σας διατηρούνται για 5 χρόνια μετά τη λήξη της συνεργασίας μας.

Με την υπογραφή μου, επιβεβαιώνω ότι έχω διαβάσει και κατανοήσει τους παραπάνω όρους και συναινώ στην επεξεργασία των προσωπικών μου δεδομένων.`;

module.exports = router;
