USE bookup;

SET @col_exists = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bookings' AND COLUMN_NAME = 'health_calories_kcal'
);
SET @sql = IF(@col_exists = 0,
  'ALTER TABLE bookings
    ADD COLUMN health_external_id VARCHAR(120) DEFAULT NULL AFTER feedback_note,
    ADD COLUMN health_activity_type VARCHAR(80) DEFAULT NULL,
    ADD COLUMN health_activity_label VARCHAR(120) DEFAULT NULL,
    ADD COLUMN health_workout_started_at DATETIME DEFAULT NULL,
    ADD COLUMN health_workout_ended_at DATETIME DEFAULT NULL,
    ADD COLUMN health_duration_mins INT DEFAULT NULL,
    ADD COLUMN health_calories_kcal INT DEFAULT NULL,
    ADD COLUMN health_avg_heart_rate INT DEFAULT NULL,
    ADD COLUMN health_distance_m DECIMAL(8,2) DEFAULT NULL,
    ADD COLUMN health_source VARCHAR(40) DEFAULT NULL,
    ADD COLUMN health_synced_at DATETIME DEFAULT NULL',
  'SELECT ''booking health columns exist'' AS info');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
