USE bookup;

-- Link payments to memberships + reminder settings
SET @has_membership_id = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payments' AND COLUMN_NAME = 'membership_id'
);
SET @sql_membership_id = IF(@has_membership_id = 0,
  'ALTER TABLE payments ADD COLUMN membership_id CHAR(36) DEFAULT NULL',
  'SELECT ''membership_id exists'' AS info');
PREPARE stmt FROM @sql_membership_id; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_reminder_days = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_configs' AND COLUMN_NAME = 'payment_reminder_days'
);
SET @sql_reminder = IF(@has_reminder_days = 0,
  'ALTER TABLE business_configs ADD COLUMN payment_reminder_days INT NOT NULL DEFAULT 3',
  'SELECT ''payment_reminder_days exists'' AS info');
PREPARE stmt FROM @sql_reminder; EXECUTE stmt; DEALLOCATE PREPARE stmt;
