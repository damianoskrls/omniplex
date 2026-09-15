-- Multi-location gyms (branches)

CREATE TABLE IF NOT EXISTS locations (
  id            CHAR(36) PRIMARY KEY,
  business_id   CHAR(36) NOT NULL,
  name          VARCHAR(255) NOT NULL,
  slug          VARCHAR(100) NOT NULL,
  address       VARCHAR(500) DEFAULT NULL,
  city          VARCHAR(120) DEFAULT NULL,
  phone         VARCHAR(50)  DEFAULT NULL,
  email         VARCHAR(255) DEFAULT NULL,
  opening_hours JSON         DEFAULT NULL,
  is_active     TINYINT(1)   NOT NULL DEFAULT 1,
  sort_order    INT          NOT NULL DEFAULT 0,
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_location_slug (business_id, slug),
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  INDEX idx_locations_business (business_id, is_active, sort_order)
);

CREATE TABLE IF NOT EXISTS staff_locations (
  staff_id    CHAR(36) NOT NULL,
  location_id CHAR(36) NOT NULL,
  PRIMARY KEY (staff_id, location_id),
  FOREIGN KEY (staff_id) REFERENCES staff(id) ON DELETE CASCADE,
  FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS user_locations (
  user_id     CHAR(36) NOT NULL,
  location_id CHAR(36) NOT NULL,
  PRIMARY KEY (user_id, location_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS service_locations (
  service_id  CHAR(36) NOT NULL,
  location_id CHAR(36) NOT NULL,
  PRIMARY KEY (service_id, location_id),
  FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE,
  FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE CASCADE
);

SET @has_room_loc = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rooms' AND COLUMN_NAME = 'location_id'
);
SET @sql_room_loc = IF(@has_room_loc = 0,
  'ALTER TABLE rooms ADD COLUMN location_id CHAR(36) DEFAULT NULL AFTER business_id',
  'SELECT ''rooms.location_id exists'' AS info');
PREPARE stmt FROM @sql_room_loc; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_sss_loc = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'service_slot_schedules' AND COLUMN_NAME = 'location_id'
);
SET @sql_sss_loc = IF(@has_sss_loc = 0,
  'ALTER TABLE service_slot_schedules ADD COLUMN location_id CHAR(36) DEFAULT NULL AFTER business_id',
  'SELECT ''service_slot_schedules.location_id exists'' AS info');
PREPARE stmt FROM @sql_sss_loc; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_book_loc = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bookings' AND COLUMN_NAME = 'location_id'
);
SET @sql_book_loc = IF(@has_book_loc = 0,
  'ALTER TABLE bookings ADD COLUMN location_id CHAR(36) DEFAULT NULL AFTER business_id',
  'SELECT ''bookings.location_id exists'' AS info');
PREPARE stmt FROM @sql_book_loc; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_sa_loc = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'staff_availability' AND COLUMN_NAME = 'location_id'
);
SET @sql_sa_loc = IF(@has_sa_loc = 0,
  'ALTER TABLE staff_availability ADD COLUMN location_id CHAR(36) DEFAULT NULL AFTER staff_id',
  'SELECT ''staff_availability.location_id exists'' AS info');
PREPARE stmt FROM @sql_sa_loc; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Replace slot schedule unique key to allow same time at different branches
-- uq_service_slot is used by FK on service_id — add replacement indexes first
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

-- Demo: default + sample branches
INSERT IGNORE INTO locations (id, business_id, name, slug, city, address, sort_order)
VALUES
  ('demo-loc-kifisia', 'demo-business-id', 'Κηφισιά', 'kifisia', 'Κηφισιά', 'Λ. Κηφισίας 100', 0),
  ('demo-loc-acharnes', 'demo-business-id', 'Αχαρνές', 'acharnes', 'Αχαρνές', 'Λ. Αθηνών 250', 1);

UPDATE rooms SET location_id = 'demo-loc-kifisia'
WHERE business_id = 'demo-business-id' AND location_id IS NULL;

UPDATE service_slot_schedules SET location_id = 'demo-loc-kifisia'
WHERE business_id = 'demo-business-id' AND location_id IS NULL;

UPDATE bookings SET location_id = 'demo-loc-kifisia'
WHERE business_id = 'demo-business-id' AND location_id IS NULL;

UPDATE business_configs SET feature_multi_location = 1
WHERE business_id = 'demo-business-id';
