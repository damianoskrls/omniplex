USE bookup;

-- pending: self-registration awaiting admin approval
-- active: can log in and use the app
-- suspended: deactivated by admin (left gym, rejected, etc.)

SET @has_account_status = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'account_status'
);
SET @sql_account_status = IF(@has_account_status = 0,
  'ALTER TABLE users
    ADD COLUMN account_status VARCHAR(20) NOT NULL DEFAULT ''active''
      AFTER loyalty_points',
  'SELECT ''account_status exists'' AS info');
PREPARE stmt FROM @sql_account_status; EXECUTE stmt; DEALLOCATE PREPARE stmt;

UPDATE users SET account_status = 'active' WHERE account_status IS NULL OR account_status = '';
