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
    if (err.code !== 'ER_DUP_FIELDNAME' && err.code !== 'ER_NO_SUCH_TABLE') throw err;
  }

  try {
    await db.query(
      'ALTER TABLE messages ADD COLUMN attachment_url VARCHAR(500) NULL',
    );
    console.log('✓ Schema: προστέθηκε messages.attachment_url');
  } catch (err) {
    if (err.code !== 'ER_DUP_FIELDNAME' && err.code !== 'ER_NO_SUCH_TABLE') throw err;
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

  try {
    await db.query(
      'ALTER TABLE bookings ADD COLUMN trial_considering TINYINT(1) NOT NULL DEFAULT 0',
    );
    console.log('✓ Schema: προστέθηκε bookings.trial_considering');
  } catch (err) {
    if (err.code !== 'ER_DUP_FIELDNAME') throw err;
  }

  // ── Bulk campaigns table ─────────────────────────────────────
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS bulk_campaigns (
        id              VARCHAR(36)   NOT NULL PRIMARY KEY,
        business_id     VARCHAR(36)   NOT NULL,
        channel         ENUM('email','sms') NOT NULL,
        subject         VARCHAR(255)  NULL,
        body            TEXT          NOT NULL,
        filter_type     VARCHAR(50)   NOT NULL DEFAULT 'all',
        filter_value    VARCHAR(255)  NULL,
        recipient_count INT           NOT NULL DEFAULT 0,
        sent_count      INT           NOT NULL DEFAULT 0,
        status          ENUM('draft','sending','done','failed') NOT NULL DEFAULT 'done',
        created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_camp_biz (business_id)
      )
    `);
    console.log('✓ Schema: bulk_campaigns table ready');
  } catch (err) {
    console.warn('bulk_campaigns table skipped:', err.message);
  }

  // ── GDPR text column in business_configs ─────────────────────
  try {
    await db.query('ALTER TABLE business_configs ADD COLUMN gdpr_text MEDIUMTEXT NULL');
    console.log('✓ Schema: προστέθηκε business_configs.gdpr_text');
  } catch (err) {
    if (err.code !== 'ER_DUP_FIELDNAME') throw err;
  }

  // ── GDPR Consents table ──────────────────────────────────────
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS gdpr_consents (
        id              VARCHAR(36)  NOT NULL PRIMARY KEY,
        business_id     VARCHAR(36)  NOT NULL,
        user_id         VARCHAR(36)  NULL,
        full_name       VARCHAR(200) NULL,
        email           VARCHAR(200) NULL,
        phone           VARCHAR(50)  NULL,
        token           VARCHAR(64)  NOT NULL UNIQUE,
        signed_at       DATETIME     NULL,
        signature_data  MEDIUMTEXT   NULL,
        ip_address      VARCHAR(45)  NULL,
        expires_at      DATETIME     NOT NULL,
        created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_gdpr_biz (business_id),
        INDEX idx_gdpr_token (token),
        INDEX idx_gdpr_user (user_id)
      )
    `);
    console.log('✓ Schema: gdpr_consents table ready');
  } catch (err) {
    console.warn('gdpr_consents table skipped:', err.message);
  }

  // Add last_seen_at to users for online presence
  try {
    await db.query('ALTER TABLE users ADD COLUMN last_seen_at DATETIME NULL');
    console.log('✓ Schema: users.last_seen_at added');
  } catch (err) { if (err.code !== 'ER_DUP_FIELDNAME') console.warn('last_seen_at skipped:', err.message); }

  // Questionnaire templates
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS questionnaire_templates (
        id          VARCHAR(36)   NOT NULL PRIMARY KEY,
        business_id VARCHAR(36)   NOT NULL,
        title       VARCHAR(255)  NOT NULL,
        description TEXT          NULL,
        questions   JSON          NOT NULL,
        created_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_qt_biz (business_id)
      )
    `);
    console.log('✓ Schema: questionnaire_templates ready');
  } catch (err) { console.warn('questionnaire_templates skipped:', err.message); }

  // Questionnaire responses
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS questionnaire_responses (
        id          VARCHAR(36)   NOT NULL PRIMARY KEY,
        template_id VARCHAR(36)   NOT NULL,
        business_id VARCHAR(36)   NOT NULL,
        user_id     VARCHAR(36)   NULL,
        token       VARCHAR(128)  NOT NULL UNIQUE,
        status      ENUM('pending','completed') NOT NULL DEFAULT 'pending',
        answers     JSON          NULL,
        completed_at DATETIME     NULL,
        expires_at  DATETIME      NOT NULL,
        created_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_qr_biz (business_id),
        INDEX idx_qr_token (token),
        INDEX idx_qr_user (user_id)
      )
    `);
    console.log('✓ Schema: questionnaire_responses ready');
  } catch (err) { console.warn('questionnaire_responses skipped:', err.message); }

  // Sent reminders (dedup log)
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS sent_reminders (
        id          VARCHAR(36)   NOT NULL PRIMARY KEY,
        business_id VARCHAR(36)   NOT NULL,
        user_id     VARCHAR(36)   NOT NULL,
        type        VARCHAR(50)   NOT NULL,
        channel     VARCHAR(10)   NOT NULL DEFAULT 'sms',
        ref_id      VARCHAR(36)   NULL,
        status      VARCHAR(20)   NOT NULL DEFAULT 'sent',
        sent_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_sr_biz (business_id),
        INDEX idx_sr_user (user_id),
        INDEX idx_sr_type_ref (type, ref_id)
      )
    `);
    console.log('✓ Schema: sent_reminders ready');
  } catch (err) { console.warn('sent_reminders skipped:', err.message); }

  // Add reminder_settings column to business_configs
  try {
    await db.query('ALTER TABLE business_configs ADD COLUMN reminder_settings JSON NULL');
    console.log('✓ Schema: business_configs.reminder_settings added');
  } catch (err) { if (err.code !== 'ER_DUP_FIELDNAME') console.warn('reminder_settings col skipped:', err.message); }

  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS business_expenses (
        id          VARCHAR(36)  NOT NULL PRIMARY KEY,
        business_id VARCHAR(36)  NOT NULL,
        year        SMALLINT     NOT NULL,
        month       TINYINT      NOT NULL,
        category    VARCHAR(100) NOT NULL DEFAULT 'Άλλο',
        description VARCHAR(255) NULL,
        amount_cents INT          NOT NULL DEFAULT 0,
        created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_be_biz_ym (business_id, year, month)
      )
    `);
    console.log('✓ Schema: business_expenses table ready');
  } catch (err) {
    console.warn('business_expenses table skipped:', err.message);
  }

  // users.avatar_url — profile photo for mobile clients
  try {
    await db.query('ALTER TABLE users ADD COLUMN avatar_url VARCHAR(500) NULL');
    console.log('✓ Schema: users.avatar_url added');
  } catch (err) { if (err.code !== 'ER_DUP_FIELDNAME') console.warn('users.avatar_url skipped:', err.message); }

  // business_configs.annual_leave_days
  try {
    await db.query('ALTER TABLE business_configs ADD COLUMN annual_leave_days INT NOT NULL DEFAULT 20');
    console.log('✓ Schema: business_configs.annual_leave_days added');
  } catch (err) { if (err.code !== 'ER_DUP_FIELDNAME') console.warn('annual_leave_days skipped:', err.message); }

  // staff_leaves — leave requests with status workflow
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS staff_leaves (
        id          VARCHAR(36)  NOT NULL PRIMARY KEY,
        staff_id    VARCHAR(36)  NOT NULL,
        business_id VARCHAR(36)  NOT NULL,
        date_from   DATE         NOT NULL,
        date_to     DATE         NOT NULL,
        reason      VARCHAR(500) NULL,
        status      ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
        created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_sl_staff (staff_id, business_id)
      )
    `);
    console.log('✓ Schema: staff_leaves table ready');
  } catch (err) {
    console.warn('staff_leaves table skipped:', err.message);
  }

  // staff_leaves.status + admin_note + reviewed_at + created_at — add if table existed without them
  try {
    await db.query(`ALTER TABLE staff_leaves ADD COLUMN status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending'`);
    console.log('✓ Schema: staff_leaves.status added');
  } catch (err) { if (err.code !== 'ER_DUP_FIELDNAME') console.warn('staff_leaves.status skipped:', err.message); }
  try {
    await db.query(`ALTER TABLE staff_leaves ADD COLUMN admin_note VARCHAR(500) NULL`);
    console.log('✓ Schema: staff_leaves.admin_note added');
  } catch (err) { if (err.code !== 'ER_DUP_FIELDNAME') console.warn('staff_leaves.admin_note skipped:', err.message); }
  try {
    await db.query(`ALTER TABLE staff_leaves ADD COLUMN reviewed_at DATETIME NULL`);
    console.log('✓ Schema: staff_leaves.reviewed_at added');
  } catch (err) { if (err.code !== 'ER_DUP_FIELDNAME') console.warn('staff_leaves.reviewed_at skipped:', err.message); }
  try {
    await db.query(`ALTER TABLE staff_leaves ADD COLUMN created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`);
    console.log('✓ Schema: staff_leaves.created_at added');
  } catch (err) { if (err.code !== 'ER_DUP_FIELDNAME') console.warn('staff_leaves.created_at skipped:', err.message); }

  // ── Drop-in bookings ─────────────────────────────────────────
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS dropin_bookings (
        id                VARCHAR(36)   NOT NULL PRIMARY KEY,
        business_id       VARCHAR(36)   NOT NULL,
        booking_id        VARCHAR(36)   NULL,
        user_id           VARCHAR(36)   NULL,
        guest_name        VARCHAR(200)  NULL,
        guest_email       VARCHAR(200)  NULL,
        guest_phone       VARCHAR(50)   NULL,
        service_id        VARCHAR(36)   NOT NULL,
        service_name      VARCHAR(200)  NOT NULL,
        booking_date      DATE          NOT NULL,
        booking_time      TIME          NOT NULL,
        staff_name        VARCHAR(200)  NULL,
        price_cents       INT           NOT NULL DEFAULT 0,
        payment_method    ENUM('card','venue') NOT NULL DEFAULT 'venue',
        payment_status    ENUM('pending','paid','failed') NOT NULL DEFAULT 'pending',
        payment_intent_id VARCHAR(300)  NULL,
        status            ENUM('pending','confirmed','rejected','attended','cancelled') NOT NULL DEFAULT 'confirmed',
        admin_note        TEXT          NULL,
        qr_token          VARCHAR(100)  NOT NULL,
        created_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_dib_biz_date (business_id, booking_date),
        INDEX idx_dib_user (user_id),
        UNIQUE idx_dib_qr (qr_token)
      )
    `);
    console.log('✓ Schema: dropin_bookings table ready');
  } catch (err) {
    console.warn('dropin_bookings table skipped:', err.message);
  }

  // ── global_users ────────────────────────────────────────────
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS global_users (
        id           VARCHAR(36)  NOT NULL PRIMARY KEY,
        email        VARCHAR(255) NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        full_name    VARCHAR(200) NOT NULL,
        phone        VARCHAR(50)  NULL,
        created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY idx_gu_email (email)
      )
    `);
    console.log('✓ Schema: global_users table ready');
  } catch (err) {
    console.warn('global_users table skipped:', err.message);
  }

  // ── users.global_user_id ────────────────────────────────────
  try {
    await db.query('ALTER TABLE users ADD COLUMN global_user_id VARCHAR(36) NULL');
    console.log('✓ Schema: users.global_user_id added');
  } catch (err) {
    if (err.code !== 'ER_DUP_FIELDNAME') console.warn('users.global_user_id skipped:', err.message);
  }
  try {
    await db.query('CREATE INDEX idx_users_global ON users (global_user_id)');
  } catch (err) {
    if (err.code !== 'ER_DUP_KEYNAME') {}
  }

  // ── businesses discovery fields ─────────────────────────────
  const bizCols = [
    ['city',            'VARCHAR(100) NULL'],
    ['country',         "VARCHAR(100) NULL DEFAULT 'GR'"],
    ['latitude',        'DECIMAL(10,8) NULL'],
    ['longitude',       'DECIMAL(11,8) NULL'],
    ['description',     'TEXT NULL'],
    ['is_discoverable', 'TINYINT(1) NOT NULL DEFAULT 0'],
  ];
  for (const [col, def] of bizCols) {
    try {
      await db.query(`ALTER TABLE businesses ADD COLUMN ${col} ${def}`);
      console.log(`✓ Schema: businesses.${col} added`);
    } catch (err) {
      if (err.code !== 'ER_DUP_FIELDNAME') console.warn(`businesses.${col} skipped:`, err.message);
    }
  }

  // ── gym_join_requests ────────────────────────────────────────
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS gym_join_requests (
        id              VARCHAR(36)  NOT NULL PRIMARY KEY,
        global_user_id  VARCHAR(36)  NOT NULL,
        business_id     VARCHAR(36)  NOT NULL,
        full_name       VARCHAR(200) NOT NULL,
        email           VARCHAR(255) NOT NULL,
        phone           VARCHAR(50)  NULL,
        status          ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
        admin_note      TEXT         NULL,
        created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_gjr_biz_status (business_id, status),
        INDEX idx_gjr_global (global_user_id)
      )
    `);
    console.log('✓ Schema: gym_join_requests table ready');
  } catch (err) {
    console.warn('gym_join_requests table skipped:', err.message);
  }

  // ── users.global_phone (phone on global_users) ───────────────
  // Add UNIQUE index on global_users.phone if column exists but index doesn't
  try {
    await db.query('CREATE INDEX idx_gu_phone ON global_users (phone)');
  } catch (err) {
    if (err.code !== 'ER_DUP_KEYNAME') {}
  }
}

module.exports = { bootstrapSchema };
