-- Fix: uq_service_slot cannot be dropped until service_id has another index (FK dependency)

SET @has_svc_idx = (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'service_slot_schedules' AND INDEX_NAME = 'idx_sss_service_id'
);
SET @sql_add_svc_idx = IF(@has_svc_idx = 0,
  'ALTER TABLE service_slot_schedules ADD INDEX idx_sss_service_id (service_id)',
  'SELECT ''idx_sss_service_id exists'' AS info');
PREPARE stmt FROM @sql_add_svc_idx; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_uq_new = (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'service_slot_schedules' AND INDEX_NAME = 'uq_service_slot_loc'
);
SET @sql_add_uq = IF(@has_uq_new = 0,
  'ALTER TABLE service_slot_schedules ADD UNIQUE KEY uq_service_slot_loc (service_id, location_id, weekday, start_time)',
  'SELECT ''uq_service_slot_loc exists'' AS info');
PREPARE stmt FROM @sql_add_uq; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_uq_old = (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'service_slot_schedules' AND INDEX_NAME = 'uq_service_slot'
);
SET @sql_drop_uq = IF(@has_uq_old > 0,
  'ALTER TABLE service_slot_schedules DROP INDEX uq_service_slot',
  'SELECT ''uq_service_slot absent'' AS info');
PREPARE stmt FROM @sql_drop_uq; EXECUTE stmt; DEALLOCATE PREPARE stmt;
