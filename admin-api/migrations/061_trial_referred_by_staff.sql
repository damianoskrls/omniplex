USE bookup;

SET @has = (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='bookings' AND COLUMN_NAME='referred_by_staff_id');
SET @sql = IF(@has=0,
  "ALTER TABLE bookings ADD COLUMN referred_by_staff_id CHAR(36) DEFAULT NULL AFTER staff_id",
  "SELECT 'referred_by_staff_id exists' AS info");
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @has2 = (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='bookings' AND COLUMN_NAME='trial_became_member');
SET @sql2 = IF(@has2=0,
  "ALTER TABLE bookings ADD COLUMN trial_became_member TINYINT(1) NOT NULL DEFAULT 0 AFTER referred_by_staff_id",
  "SELECT 'trial_became_member exists' AS info");
PREPARE s2 FROM @sql2; EXECUTE s2; DEALLOCATE PREPARE s2;
