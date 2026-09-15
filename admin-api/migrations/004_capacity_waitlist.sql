USE bookup;

SET @has_max_capacity = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'service_slot_schedules' AND COLUMN_NAME = 'max_capacity'
);
SET @sql_cap = IF(@has_max_capacity = 0,
  'ALTER TABLE service_slot_schedules ADD COLUMN max_capacity INT DEFAULT NULL COMMENT ''Max participants per slot; NULL = staff-limited only''',
  'SELECT ''max_capacity already exists'' AS info');
PREPARE stmt FROM @sql_cap;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS waitlist_entries (
  id          CHAR(36) PRIMARY KEY,
  business_id CHAR(36) NOT NULL,
  user_id     CHAR(36) NOT NULL,
  service_id  CHAR(36) NOT NULL,
  staff_id    CHAR(36) DEFAULT NULL,
  starts_at   DATETIME NOT NULL,
  ends_at     DATETIME NOT NULL,
  status      VARCHAR(20) NOT NULL DEFAULT 'waiting',
  position    INT NOT NULL DEFAULT 1,
  notes       TEXT DEFAULT NULL,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE,
  FOREIGN KEY (staff_id) REFERENCES staff(id) ON DELETE SET NULL,
  INDEX idx_waitlist_slot (business_id, service_id, starts_at, status),
  INDEX idx_waitlist_user (user_id, service_id, starts_at)
);

CREATE TABLE IF NOT EXISTS admin_notifications (
  id          CHAR(36) PRIMARY KEY,
  business_id CHAR(36) NOT NULL,
  type        VARCHAR(50) NOT NULL,
  title       VARCHAR(255) NOT NULL,
  body        TEXT DEFAULT NULL,
  payload     JSON DEFAULT NULL,
  is_read     TINYINT(1) NOT NULL DEFAULT 0,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  INDEX idx_notif_business (business_id, is_read, created_at)
);

UPDATE business_configs SET feature_waitlist = 1 WHERE business_id = 'demo-business-id';

UPDATE service_slot_schedules SET max_capacity = 1
WHERE business_id = 'demo-business-id' AND room_name IS NOT NULL;

UPDATE service_slot_schedules SET max_capacity = 10
WHERE business_id = 'demo-business-id' AND service_id = 'demo-svc-fitness';
