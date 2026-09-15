-- Soft delete πελατών — κάδος ανακύκλωσης
SET @has_deleted_at = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'deleted_at'
);
SET @sql_deleted_at = IF(@has_deleted_at = 0,
  'ALTER TABLE users ADD COLUMN deleted_at TIMESTAMP NULL DEFAULT NULL AFTER account_status',
  'SELECT ''deleted_at exists'' AS info');
PREPARE stmt FROM @sql_deleted_at; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_deleted = (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND INDEX_NAME = 'idx_users_biz_deleted'
);
SET @sql_idx = IF(@idx_deleted = 0,
  'CREATE INDEX idx_users_biz_deleted ON users (business_id, deleted_at)',
  'SELECT ''idx_users_biz_deleted exists'' AS info');
PREPARE stmt FROM @sql_idx; EXECUTE stmt; DEALLOCATE PREPARE stmt;
