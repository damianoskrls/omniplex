USE bookup;

-- Client profile: notes + referral
SET @has_user_notes = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'notes'
);
SET @sql_user_notes = IF(@has_user_notes = 0,
  'ALTER TABLE users
    ADD COLUMN notes TEXT DEFAULT NULL,
    ADD COLUMN referred_by_user_id CHAR(36) DEFAULT NULL',
  'SELECT ''user notes exist'' AS info');
PREPARE stmt FROM @sql_user_notes; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Structured payment fields
SET @has_pay_service = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payments' AND COLUMN_NAME = 'service_id'
);
SET @sql_pay_struct = IF(@has_pay_service = 0,
  'ALTER TABLE payments
    ADD COLUMN service_id CHAR(36) DEFAULT NULL,
    ADD COLUMN plan_id CHAR(36) DEFAULT NULL,
    ADD COLUMN payment_type VARCHAR(50) DEFAULT NULL,
    ADD COLUMN billing_month DATE DEFAULT NULL,
    ADD COLUMN package_months INT DEFAULT NULL,
    ADD COLUMN period_start DATE DEFAULT NULL,
    ADD COLUMN period_end DATE DEFAULT NULL,
    ADD COLUMN discount_cents INT NOT NULL DEFAULT 0,
    ADD COLUMN registration_fee_cents INT NOT NULL DEFAULT 0',
  'SELECT ''payment struct exists'' AS info');
PREPARE stmt FROM @sql_pay_struct; EXECUTE stmt; DEALLOCATE PREPARE stmt;
