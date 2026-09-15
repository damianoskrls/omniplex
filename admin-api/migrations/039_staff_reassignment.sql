SET @has_pool = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'staff' AND COLUMN_NAME = 'is_general_pool'
);
SET @sql_pool = IF(@has_pool = 0,
  'ALTER TABLE staff ADD COLUMN is_general_pool TINYINT(1) NOT NULL DEFAULT 0 AFTER is_active',
  'SELECT ''staff.is_general_pool exists'' AS info');
PREPARE stmt FROM @sql_pool; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_assign = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bookings' AND COLUMN_NAME = 'staff_assignment_status'
);
SET @sql_assign = IF(@has_assign = 0,
  "ALTER TABLE bookings ADD COLUMN staff_assignment_status VARCHAR(30) NOT NULL DEFAULT 'assigned' AFTER staff_id",
  'SELECT ''bookings.staff_assignment_status exists'' AS info');
PREPARE stmt FROM @sql_assign; EXECUTE stmt; DEALLOCATE PREPARE stmt;
