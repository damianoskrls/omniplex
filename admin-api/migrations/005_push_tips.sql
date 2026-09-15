USE bookup;

SET @has_prep = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'service_slot_schedules' AND COLUMN_NAME = 'preparation_tips'
);
SET @sql_prep = IF(@has_prep = 0,
  'ALTER TABLE service_slot_schedules ADD COLUMN preparation_tips TEXT DEFAULT NULL',
  'SELECT ''preparation_tips exists'' AS info');
PREPARE stmt FROM @sql_prep; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_post = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'service_slot_schedules' AND COLUMN_NAME = 'post_workout_tips'
);
SET @sql_post = IF(@has_post = 0,
  'ALTER TABLE service_slot_schedules ADD COLUMN post_workout_tips TEXT DEFAULT NULL',
  'SELECT ''post_workout_tips exists'' AS info');
PREPARE stmt FROM @sql_post; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS device_tokens (
  id          CHAR(36) PRIMARY KEY,
  user_id     CHAR(36) NOT NULL,
  business_id CHAR(36) NOT NULL,
  fcm_token   VARCHAR(512) NOT NULL,
  platform    VARCHAR(20) DEFAULT 'unknown',
  updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  UNIQUE KEY uq_user_token (user_id, fcm_token)
);

CREATE TABLE IF NOT EXISTS user_notifications (
  id          CHAR(36) PRIMARY KEY,
  business_id CHAR(36) NOT NULL,
  user_id     CHAR(36) NOT NULL,
  booking_id  CHAR(36) DEFAULT NULL,
  type        VARCHAR(50) NOT NULL,
  title       VARCHAR(255) NOT NULL,
  body        TEXT DEFAULT NULL,
  payload     JSON DEFAULT NULL,
  is_read     TINYINT(1) NOT NULL DEFAULT 0,
  sent_push   TINYINT(1) NOT NULL DEFAULT 0,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE SET NULL,
  INDEX idx_user_notif (user_id, is_read, created_at)
);

SET @has_rating = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bookings' AND COLUMN_NAME = 'feedback_rating'
);
SET @sql_rating = IF(@has_rating = 0,
  'ALTER TABLE bookings ADD COLUMN feedback_rating TINYINT DEFAULT NULL, ADD COLUMN feedback_note TEXT DEFAULT NULL, ADD COLUMN prep_notified TINYINT(1) NOT NULL DEFAULT 0, ADD COLUMN post_notified TINYINT(1) NOT NULL DEFAULT 0',
  'SELECT ''feedback columns exist'' AS info');
PREPARE stmt FROM @sql_rating; EXECUTE stmt; DEALLOCATE PREPARE stmt;

UPDATE service_slot_schedules SET
  preparation_tips = 'Φέρε πετσέτα και μπουκάλι νερό
Φάε ελαφρύ γεύμα 1–2 ώρες πριν (π.χ. γιαούρτι + μπανάνα)
Φόρα αθλητικά με καλή πρόσφυση
Αποφυγε βαριά γεύματα αμέσως πριν',
  post_workout_tips = 'Πιες νερό μέσα στα επόμενα 15 λεπτά
Φάε πρωτεΐνη εντός 30–60 λεπτών (γιαούρτι, αυγό ή shake)
5 λεπτά διατάσεις για αποκατάσταση
Καλή ξεκούραση — το σώμα χτίζεται στην ανάκαμψη!'
WHERE business_id = 'demo-business-id' AND service_id = 'demo-svc-fitness';

UPDATE service_slot_schedules SET
  preparation_tips = 'Φέρε πετσέτα (υποχρεωτική)
Μπουκάλι νερό
Φόρα κολλάνες ή κάλτσες αν χρειάζεται
Φάε ελαφρά 1 ώρα πριν — όχι γεμάτο στομάχι',
  post_workout_tips = 'Πιες νερό αργά-αργά
Προτείνεται ελαφρό σνακ με πρωτεΐνη
Κάνε 3–5 λεπτά διατάσεις core
Απόφυγε έντονη καταπίεση μετά το μάθημα'
WHERE business_id = 'demo-business-id' AND service_id = 'demo-svc-pilates';
