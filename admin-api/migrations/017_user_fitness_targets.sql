USE bookup;

SET @has_target_weight = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'target_weight_kg'
);
SET @sql_target = IF(@has_target_weight = 0,
  'ALTER TABLE users ADD COLUMN target_weight_kg DECIMAL(5,1) DEFAULT NULL AFTER weight_kg',
  'SELECT ''target_weight_kg exists'' AS info');
PREPARE stmt FROM @sql_target; EXECUTE stmt; DEALLOCATE PREPARE stmt;
