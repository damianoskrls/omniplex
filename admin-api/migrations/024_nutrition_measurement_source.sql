USE bookup;

SET @has_recorded_by = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'nutrition_measurements' AND COLUMN_NAME = 'recorded_by'
);
SET @sql_rb = IF(@has_recorded_by = 0,
  "ALTER TABLE nutrition_measurements ADD COLUMN recorded_by ENUM('athlete','nutritionist') NOT NULL DEFAULT 'nutritionist' AFTER user_id",
  "SELECT 'recorded_by exists' AS info");
PREPARE stmt FROM @sql_rb; EXECUTE stmt; DEALLOCATE PREPARE stmt;
