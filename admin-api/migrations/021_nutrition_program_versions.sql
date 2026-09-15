USE bookup;

-- Meal plans: recurring weekly template with effective_from (versioning)
SET @has_effective_from = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'meal_plans' AND COLUMN_NAME = 'effective_from'
);
SET @sql_ef = IF(@has_effective_from = 0,
  'ALTER TABLE meal_plans ADD COLUMN effective_from DATE NULL AFTER week_start',
  'SELECT ''effective_from exists'' AS info');
PREPARE stmt FROM @sql_ef; EXECUTE stmt; DEALLOCATE PREPARE stmt;

UPDATE meal_plans SET effective_from = week_start WHERE effective_from IS NULL;

SET @has_target_bf = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'target_body_fat_pct'
);
SET @sql_tbf = IF(@has_target_bf = 0,
  'ALTER TABLE users ADD COLUMN target_body_fat_pct DECIMAL(4,1) DEFAULT NULL AFTER body_fat_pct',
  'SELECT ''target_body_fat_pct exists'' AS info');
PREPARE stmt FROM @sql_tbf; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- New index must exist before dropping uq_meal_plan_user_week (FK on user_id uses it)
SET @has_idx_eff = (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'meal_plans' AND INDEX_NAME = 'idx_meal_plan_user_effective'
);
SET @sql_idx = IF(@has_idx_eff = 0,
  'CREATE INDEX idx_meal_plan_user_effective ON meal_plans (user_id, business_id, effective_from)',
  'SELECT ''idx_meal_plan_user_effective exists'' AS info');
PREPARE stmt FROM @sql_idx; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Drop week-only unique constraint if present (allows multiple program versions)
SET @has_uq_week = (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'meal_plans' AND INDEX_NAME = 'uq_meal_plan_user_week'
);
SET @sql_drop_uq = IF(@has_uq_week > 0,
  'ALTER TABLE meal_plans DROP INDEX uq_meal_plan_user_week',
  'SELECT ''uq_meal_plan_user_week absent'' AS info');
PREPARE stmt FROM @sql_drop_uq; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS nutrition_measurements (
  id                  CHAR(36)     PRIMARY KEY,
  business_id         CHAR(36)     NOT NULL,
  user_id             CHAR(36)     NOT NULL,
  measured_on         DATE         NOT NULL,
  weight_kg           DECIMAL(5,2) DEFAULT NULL,
  height_cm           DECIMAL(5,1) DEFAULT NULL,
  body_fat_pct        DECIMAL(4,1) DEFAULT NULL,
  muscle_mass_kg      DECIMAL(5,2) DEFAULT NULL,
  fat_mass_kg         DECIMAL(5,2) DEFAULT NULL,
  bone_mass_kg          DECIMAL(5,2) DEFAULT NULL,
  bmi                 DECIMAL(4,1) DEFAULT NULL,
  visceral_fat_level  TINYINT      DEFAULT NULL,
  bmr_kcal            INT          DEFAULT NULL,
  metabolic_age       TINYINT      DEFAULT NULL,
  notes               TEXT         DEFAULT NULL,
  created_at          TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  KEY idx_nutrition_meas_user_date (user_id, measured_on),
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
