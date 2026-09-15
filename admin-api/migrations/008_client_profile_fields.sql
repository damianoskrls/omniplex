USE bookup;

SET @has_dob = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'date_of_birth'
);
SET @sql_profile = IF(@has_dob = 0,
  'ALTER TABLE users
    ADD COLUMN date_of_birth DATE DEFAULT NULL,
    ADD COLUMN weight_kg DECIMAL(5,1) DEFAULT NULL,
    ADD COLUMN fitness_goal VARCHAR(100) DEFAULT NULL,
    ADD COLUMN trainer_notes TEXT DEFAULT NULL',
  'SELECT ''profile fields exist'' AS info');
PREPARE stmt FROM @sql_profile; EXECUTE stmt; DEALLOCATE PREPARE stmt;
