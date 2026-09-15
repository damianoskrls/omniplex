USE bookup;

-- Συμβατό με MySQL 5.7+ (χωρίς ADD COLUMN IF NOT EXISTS)

SET @has_image_url = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'services' AND COLUMN_NAME = 'image_url'
);
SET @sql_image = IF(@has_image_url = 0,
  'ALTER TABLE services ADD COLUMN image_url VARCHAR(500) DEFAULT NULL',
  'SELECT ''image_url already exists'' AS info');
PREPARE stmt FROM @sql_image;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_slot_mode = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'services' AND COLUMN_NAME = 'slot_label_mode'
);
SET @sql_mode = IF(@has_slot_mode = 0,
  'ALTER TABLE services ADD COLUMN slot_label_mode VARCHAR(20) NOT NULL DEFAULT ''time_only''',
  'SELECT ''slot_label_mode already exists'' AS info');
PREPARE stmt FROM @sql_mode;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS service_slot_schedules (
  id          CHAR(36) PRIMARY KEY,
  service_id  CHAR(36) NOT NULL,
  business_id CHAR(36) NOT NULL,
  weekday     TINYINT  NOT NULL,
  start_time  TIME     NOT NULL,
  label       VARCHAR(255) DEFAULT NULL,
  room_name   VARCHAR(255) DEFAULT NULL,
  subtitle    TEXT         DEFAULT NULL,
  image_url   VARCHAR(500) DEFAULT NULL,
  icon_key    VARCHAR(50)  DEFAULT NULL,
  is_active   TINYINT(1)   NOT NULL DEFAULT 1,
  FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  UNIQUE KEY uq_service_slot (service_id, weekday, start_time)
);
