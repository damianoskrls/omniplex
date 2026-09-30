const express = require('express');
const router = express.Router();
const db = require('../db');
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
      SELECT g.id, g.kind, g.title, g.program_name, g.full_name, g.email, g.phone,
             g.signed_at, g.expires_at, g.created_at, u.full_name AS linked_client
      FROM gdpr_consents g
      LEFT JOIN users u ON u.id = (g.user_id COLLATE utf8mb4_unicode_ci)
      WHERE (g.business_id COLLATE utf8mb4_unicode_ci) = ?
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
  const { user_id, full_name, email, phone, program_name } = req.body;
  const kind = KINDS[req.body.kind] ? req.body.kind : 'gdpr';
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
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    const [[cfg]] = await db.query('SELECT gdpr_text FROM business_configs WHERE business_id = ?', [bizId]);
    const title = documentTitle(kind, program_name);
    const snapshot = documentBody(kind, program_name, cfg?.gdpr_text);
    const id = uuidv4();

    await db.query(`
      INSERT INTO gdpr_consents
        (id, business_id, user_id, full_name, email, phone, token, expires_at, kind, title, body_snapshot, program_name)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [id, bizId, user_id || null, name, userEmail || null, userPhone || null, token, expiresAt, kind, title, snapshot, program_name || null]);

    if (user_id) {
      try {
        const { createUserNotification } = require('../lib/user_notifications');
        await createUserNotification(db, {
          businessId: bizId,
          userId: user_id,
          type: 'enrollment_sign',
          title,
          body: 'Υπάρχει έγγραφο για ηλεκτρονική υπογραφή στην εφαρμογή.',
          payload: { action: 'open_enrollment', consent_id: id },
        });
      } catch (_) {}
    }

    const link = `${process.env.APP_URL || 'https://handstand.gr'}/gdpr/${token}`;
    res.json({ token, link, expires_at: expiresAt, kind, title });
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
             g.kind, g.title, g.body_snapshot, g.program_name,
             bc.gdpr_text, bc.app_name, b.name AS biz_name
      FROM gdpr_consents g
      JOIN businesses b ON b.id = (g.business_id COLLATE utf8mb4_unicode_ci)
      LEFT JOIN business_configs bc ON bc.business_id = (g.business_id COLLATE utf8mb4_unicode_ci)
      WHERE (g.token COLLATE utf8mb4_unicode_ci) = ?
    `, [req.params.token]);

    if (!consent) return res.status(404).json({ error: 'Ο σύνδεσμος δεν βρέθηκε' });
    if (new Date(consent.expires_at) < new Date()) return res.status(410).json({ error: 'Ο σύνδεσμος έχει λήξει' });

    res.json(presentConsent(consent));
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
      'SELECT id, signed_at, expires_at FROM gdpr_consents WHERE (token COLLATE utf8mb4_unicode_ci) = ?',
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

const KINDS = {
  gdpr: 'Συναίνεση GDPR',
  registration: 'Νέα εγγραφή μέλους',
  renewal: 'Ανανέωση συνδρομής',
  participation: 'Δήλωση συμμετοχής',
};

function documentTitle(kind, programName) {
  if (kind === 'participation' && programName) return `Δήλωση συμμετοχής — ${programName}`;
  return KINDS[kind] || KINDS.gdpr;
}

function documentBody(kind, programName, gdprText) {
  const program = programName ? ` «${programName}»` : '';
  const lead = {
    registration: 'Με την υπογραφή μου ζητώ την εγγραφή μου ως μέλος και αποδέχομαι τον κανονισμό και τους όρους συνδρομής.',
    renewal: 'Με την υπογραφή μου ανανεώνω τη συνδρομή μου και αποδέχομαι τους ισχύοντες όρους.',
    participation: `Με την υπογραφή μου δηλώνω συμμετοχή${program} και αποδέχομαι τους όρους του προγράμματος.`,
    gdpr: 'Με την υπογραφή μου συναινώ στην επεξεργασία των προσωπικών μου δεδομένων.',
  }[kind] || '';
  return `${lead}\n\n${gdprText || defaultGdprText}`;
}

function requireMember(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth) return res.status(401).json({ error: 'Unauthorized' });
  try {
    const payload = jwt.verify(auth.replace('Bearer ', ''), process.env.JWT_SECRET);
    if (!payload.userId || payload.role === 'client_admin') {
      return res.status(403).json({ error: 'Forbidden' });
    }
    req.member = payload;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

router.get('/mine', requireMember, async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT id, kind, title, program_name, full_name, signed_at, expires_at, created_at,
              body_snapshot IS NOT NULL AS has_body
       FROM gdpr_consents
       WHERE (user_id COLLATE utf8mb4_unicode_ci) = ? AND (business_id COLLATE utf8mb4_unicode_ci) = ?
       ORDER BY signed_at IS NULL DESC, created_at DESC
       LIMIT 50`,
      [req.member.userId, req.member.businessId],
    );
    res.json(rows.map((row) => ({
      ...row,
      kind_label: KINDS[row.kind] || row.kind,
      title: row.title || documentTitle(row.kind, row.program_name),
    })));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/mine/:id', requireMember, async (req, res) => {
  try {
    const [[row]] = await db.query(
      `SELECT g.*, bc.gdpr_text, COALESCE(bc.app_name, b.name) AS gym_name
       FROM gdpr_consents g
       JOIN businesses b ON b.id = (g.business_id COLLATE utf8mb4_unicode_ci)
       LEFT JOIN business_configs bc ON bc.business_id = (g.business_id COLLATE utf8mb4_unicode_ci)
       WHERE g.id = ? AND (g.user_id COLLATE utf8mb4_unicode_ci) = ? AND (g.business_id COLLATE utf8mb4_unicode_ci) = ?`,
      [req.params.id, req.member.userId, req.member.businessId],
    );
    if (!row) return res.status(404).json({ error: 'Δεν βρέθηκε' });
    res.json(presentConsent(row));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/mine/:id/sign', requireMember, async (req, res) => {
  const { signature_data } = req.body || {};
  if (!signature_data) return res.status(400).json({ error: 'Signature required' });
  try {
    const [[row]] = await db.query(
      'SELECT id, signed_at, expires_at FROM gdpr_consents WHERE id = ? AND (user_id COLLATE utf8mb4_unicode_ci) = ? AND (business_id COLLATE utf8mb4_unicode_ci) = ?',
      [req.params.id, req.member.userId, req.member.businessId],
    );
    if (!row) return res.status(404).json({ error: 'Δεν βρέθηκε' });
    if (new Date(row.expires_at) < new Date()) return res.status(410).json({ error: 'Ο σύνδεσμος έχει λήξει' });
    if (row.signed_at) return res.json({ ok: true, already_signed: true });
    const ip = req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.socket.remoteAddress;
    await db.query(
      'UPDATE gdpr_consents SET signed_at = NOW(), signature_data = ?, ip_address = ? WHERE id = ?',
      [signature_data, ip, row.id],
    );
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

function presentConsent(row) {
  const kind = row.kind || 'gdpr';
  return {
    id: row.id,
    kind,
    kind_label: KINDS[kind] || kind,
    title: row.title || documentTitle(kind, row.program_name),
    program_name: row.program_name,
    full_name: row.full_name,
    signed_at: row.signed_at,
    gym_name: row.gym_name || row.app_name || row.biz_name,
    gdpr_text: row.body_snapshot || documentBody(kind, row.program_name, row.gdpr_text),
  };
}

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
