USE bookup;

SET @has_tod = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'nutrition_measurements' AND COLUMN_NAME = 'time_of_day'
);
SET @sql_tod = IF(@has_tod = 0,
  "ALTER TABLE nutrition_measurements ADD COLUMN time_of_day ENUM('morning','noon','afternoon','evening') NULL AFTER measured_on",
  "SELECT 'time_of_day exists' AS info");
PREPARE stmt FROM @sql_tod; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_mt = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'nutrition_measurements' AND COLUMN_NAME = 'measured_time'
);
SET @sql_mt = IF(@has_mt = 0,
  'ALTER TABLE nutrition_measurements ADD COLUMN measured_time TIME NULL AFTER time_of_day',
  "SELECT 'measured_time exists' AS info");
PREPARE stmt FROM @sql_mt; EXECUTE stmt; DEALLOCATE PREPARE stmt;
