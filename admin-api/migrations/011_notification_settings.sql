USE bookup;

SET @has_br24 = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_configs' AND COLUMN_NAME = 'booking_reminder_24h'
);
SET @sql_br24 = IF(@has_br24 = 0,
  'ALTER TABLE business_configs
     ADD COLUMN booking_reminder_24h TINYINT(1) NOT NULL DEFAULT 1,
     ADD COLUMN booking_reminder_1h TINYINT(1) NOT NULL DEFAULT 1,
     ADD COLUMN auto_payment_reminders TINYINT(1) NOT NULL DEFAULT 0',
  'SELECT ''notification settings exist'' AS info');
PREPARE stmt FROM @sql_br24; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_dbn = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bookings' AND COLUMN_NAME = 'day_before_notified'
);
SET @sql_dbn = IF(@has_dbn = 0,
  'ALTER TABLE bookings ADD COLUMN day_before_notified TINYINT(1) NOT NULL DEFAULT 0',
  'SELECT ''day_before_notified exists'' AS info');
PREPARE stmt FROM @sql_dbn; EXECUTE stmt; DEALLOCATE PREPARE stmt;
