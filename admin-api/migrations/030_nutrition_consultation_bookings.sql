USE bookup;

SET @has_staff_id = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'nutritionists' AND COLUMN_NAME = 'staff_id'
);
SET @sql_ns = IF(@has_staff_id = 0,
  'ALTER TABLE nutritionists ADD COLUMN staff_id CHAR(36) DEFAULT NULL AFTER is_active',
  'SELECT ''nutritionists.staff_id exists'' AS info');
PREPARE stmt FROM @sql_ns; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_consult_svc = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_configs' AND COLUMN_NAME = 'nutrition_consultation_service_id'
);
SET @sql_cs = IF(@has_consult_svc = 0,
  'ALTER TABLE business_configs ADD COLUMN nutrition_consultation_service_id CHAR(36) DEFAULT NULL AFTER feature_nutrition',
  'SELECT ''nutrition_consultation_service_id exists'' AS info');
PREPARE stmt FROM @sql_cs; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_booking_mem = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bookings' AND COLUMN_NAME = 'membership_id'
);
SET @sql_bm = IF(@has_booking_mem = 0,
  'ALTER TABLE bookings ADD COLUMN membership_id CHAR(36) DEFAULT NULL AFTER service_id',
  'SELECT ''bookings.membership_id exists'' AS info');
PREPARE stmt FROM @sql_bm; EXECUTE stmt; DEALLOCATE PREPARE stmt;
