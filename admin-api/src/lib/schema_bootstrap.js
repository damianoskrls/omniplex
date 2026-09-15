const db = require('../db');
const { buildServicePlanName } = require('./plan_names');

/** Εφαρμόζει μικρές αλλαγές schema που μπορεί να λείπουν από παλιές εγκαταστάσεις */
async function bootstrapSchema() {
  try {
    await db.query(
      'ALTER TABLE users ADD COLUMN deleted_at TIMESTAMP NULL DEFAULT NULL',
    );
    console.log('✓ Schema: προστέθηκε users.deleted_at');
  } catch (err) {
    if (err.code !== 'ER_DUP_FIELDNAME') throw err;
  }

  try {
    await db.query(
      'CREATE INDEX idx_users_biz_deleted ON users (business_id, deleted_at)',
    );
    console.log('✓ Schema: προστέθηκε index idx_users_biz_deleted');
  } catch (err) {
    if (err.code !== 'ER_DUP_KEYNAME') throw err;
  }

  try {
    const [result] = await db.query(`
      UPDATE user_memberships
      SET total_sessions = 9999
      WHERE membership_status IN ('active')
        AND total_sessions = 0
    `);
    if (result.affectedRows > 0) {
      console.log(`✓ Schema: διόρθωση ${result.affectedRows} memberships με 0 συνεδρίες → απεριόριστες`);
    }
  } catch (err) {
    console.warn('membership sessions fix skipped:', err.message);
  }

  try {
    const [dupes] = await db.query(`
      SELECT s.id, s.business_id
      FROM services s
      JOIN business_configs bc ON bc.business_id = s.business_id
      WHERE s.category = 'nutrition_consultation'
        AND s.is_active = 1
        AND s.id != COALESCE(bc.nutrition_consultation_service_id, '')
    `);
    if (dupes.length) {
      const ids = dupes.map((r) => r.id);
      await db.query('UPDATE services SET is_active = 0 WHERE id IN (?)', [ids]);
      console.log(`✓ Schema: απενεργοποιήθηκαν ${ids.length} διπλότυπες υπηρεσίες διατροφολόγου`);
    }
  } catch (err) {
    console.warn('nutrition service dedupe skipped:', err.message);
  }

  try {
    const [zeroPlans] = await db.query(`
      SELECT bp.id, bp.sessions, bp.duration_mins, bp.billing_period, bp.price_cents, s.name AS service_name
      FROM business_plans bp
      LEFT JOIN services s ON s.id = bp.service_id
      WHERE bp.plan_type = 'service' AND bp.sessions = 0
    `);
    for (const plan of zeroPlans) {
      const name = buildServicePlanName(plan.service_name || 'Πακέτο', {
        sessions: null,
        duration_mins: plan.duration_mins,
        billing_period: plan.billing_period,
        price_cents: plan.price_cents,
      });
      await db.query(
        'UPDATE business_plans SET sessions = NULL, name = ? WHERE id = ?',
        [name, plan.id],
      );
    }
    if (zeroPlans.length) {
      console.log(`✓ Schema: διόρθωση ${zeroPlans.length} πλάνων με 0 συνεδρίες → απεριόριστες`);
    }
  } catch (err) {
    console.warn('plan sessions fix skipped:', err.message);
  }

  try {
    await db.query(
      "ALTER TABLE messages ADD COLUMN message_type ENUM('text', 'image') NOT NULL DEFAULT 'text'",
    );
    console.log('✓ Schema: προστέθηκε messages.message_type');
  } catch (err) {
    if (err.code !== 'ER_DUP_FIELDNAME') throw err;
  }

  try {
    await db.query(
      'ALTER TABLE messages ADD COLUMN attachment_url VARCHAR(500) NULL',
    );
    console.log('✓ Schema: προστέθηκε messages.attachment_url');
  } catch (err) {
    if (err.code !== 'ER_DUP_FIELDNAME') throw err;
  }

  // ── Entrance check-in token per user ────────────────────────
  try {
    await db.query(
      'ALTER TABLE users ADD COLUMN check_in_token VARCHAR(36) NULL UNIQUE',
    );
    console.log('✓ Schema: προστέθηκε users.check_in_token');
  } catch (err) {
    if (err.code !== 'ER_DUP_FIELDNAME') throw err;
  }

  // ── Entrance check-ins table ─────────────────────────────────
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS entrance_checkins (
        id              VARCHAR(36)  NOT NULL PRIMARY KEY,
        business_id     VARCHAR(36)  NOT NULL,
        user_id         VARCHAR(36)  NOT NULL,
        membership_id   VARCHAR(36)  NULL,
        session_deducted TINYINT(1) NOT NULL DEFAULT 0,
        checked_in_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_ec_biz_date (business_id, checked_in_at),
        INDEX idx_ec_user (user_id)
      )
    `);
    console.log('✓ Schema: entrance_checkins table ready');
  } catch (err) {
    console.warn('entrance_checkins table skipped:', err.message);
  }

  try {
    await db.query(`
      UPDATE businesses
      SET name = 'Handstand', slug = 'handstand'
      WHERE id = 'demo-business-id' AND (name = 'Demo Gym' OR slug = 'demo-gym')
    `);
    await db.query(`
      UPDATE business_configs
      SET app_name = 'Handstand',
          logo_url = COALESCE(logo_url, '/uploads/demo-business-id/logo/handstand.png')
      WHERE business_id = 'demo-business-id'
        AND (app_name IN ('BookUp Demo', 'Demo Gym') OR logo_url IS NULL)
    `);
  } catch (err) {
    console.warn('handstand branding fix skipped:', err.message);
  }
}

module.exports = { bootstrapSchema };
