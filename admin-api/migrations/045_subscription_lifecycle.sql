-- Grace period after membership expiry before booking block
SET @has_grace := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_configs' AND COLUMN_NAME = 'grace_period_days'
);
SET @sql_grace := IF(@has_grace = 0,
  'ALTER TABLE business_configs ADD COLUMN grace_period_days INT NOT NULL DEFAULT 15',
  'SELECT ''grace_period_days exists'' AS info');
PREPARE stmt FROM @sql_grace; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_cancelled_at := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user_memberships' AND COLUMN_NAME = 'cancelled_at'
);
SET @sql_cancel := IF(@has_cancelled_at = 0,
  'ALTER TABLE user_memberships
     ADD COLUMN cancelled_at DATETIME NULL AFTER trial_booking_id,
     ADD COLUMN cancellation_reason VARCHAR(500) NULL AFTER cancelled_at,
     ADD COLUMN cancelled_by_user_id CHAR(36) NULL AFTER cancellation_reason,
     ADD COLUMN reactivated_at DATETIME NULL AFTER cancelled_by_user_id',
  'SELECT ''cancellation columns exist'' AS info');
PREPARE stmt FROM @sql_cancel; EXECUTE stmt; DEALLOCATE PREPARE stmt;
