USE bookup;

-- Feature flag
SET @has_feature_nutrition = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_configs' AND COLUMN_NAME = 'feature_nutrition'
);
SET @sql_fn = IF(@has_feature_nutrition = 0,
  'ALTER TABLE business_configs ADD COLUMN feature_nutrition TINYINT(1) NOT NULL DEFAULT 0 AFTER feature_waitlist',
  'SELECT ''feature_nutrition exists'' AS info');
PREPARE stmt FROM @sql_fn; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Plan add-on flag
SET @has_includes_nutrition = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_plans' AND COLUMN_NAME = 'includes_nutrition'
);
SET @sql_in = IF(@has_includes_nutrition = 0,
  'ALTER TABLE business_plans ADD COLUMN includes_nutrition TINYINT(1) NOT NULL DEFAULT 0 AFTER is_active',
  'SELECT ''includes_nutrition exists'' AS info');
PREPARE stmt FROM @sql_in; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- User nutrition profile fields
SET @has_height = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'height_cm'
);
SET @sql_h = IF(@has_height = 0,
  'ALTER TABLE users ADD COLUMN height_cm DECIMAL(5,1) DEFAULT NULL AFTER target_weight_kg',
  'SELECT ''height_cm exists'' AS info');
PREPARE stmt FROM @sql_h; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_body_fat = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'body_fat_pct'
);
SET @sql_bf = IF(@has_body_fat = 0,
  'ALTER TABLE users ADD COLUMN body_fat_pct DECIMAL(4,1) DEFAULT NULL AFTER height_cm',
  'SELECT ''body_fat_pct exists'' AS info');
PREPARE stmt FROM @sql_bf; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- One nutritionist per gym
CREATE TABLE IF NOT EXISTS nutritionists (
  id           CHAR(36)     PRIMARY KEY,
  business_id  CHAR(36)     NOT NULL,
  full_name    VARCHAR(120) NOT NULL,
  email        VARCHAR(255) NOT NULL,
  is_active    TINYINT(1)   NOT NULL DEFAULT 1,
  created_at   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_nutritionist_business (business_id),
  UNIQUE KEY uq_nutritionist_email (business_id, email),
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS nutritionist_passwords (
  nutritionist_id CHAR(36) PRIMARY KEY,
  password_hash   VARCHAR(255) NOT NULL,
  FOREIGN KEY (nutritionist_id) REFERENCES nutritionists(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS meal_plans (
  id           CHAR(36) PRIMARY KEY,
  business_id  CHAR(36) NOT NULL,
  user_id      CHAR(36) NOT NULL,
  week_start   DATE     NOT NULL,
  notes        TEXT,
  created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_meal_plan_user_week (user_id, week_start),
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS meal_plan_items (
  id            CHAR(36) PRIMARY KEY,
  meal_plan_id  CHAR(36) NOT NULL,
  day_of_week   TINYINT  NOT NULL COMMENT '1=Mon .. 7=Sun',
  meal_type     ENUM('breakfast','lunch','dinner','snack') NOT NULL,
  description   TEXT     NOT NULL,
  sort_order    INT      NOT NULL DEFAULT 0,
  FOREIGN KEY (meal_plan_id) REFERENCES meal_plans(id) ON DELETE CASCADE,
  UNIQUE KEY uq_meal_plan_slot (meal_plan_id, day_of_week, meal_type)
);

CREATE TABLE IF NOT EXISTS food_logs (
  id           CHAR(36) PRIMARY KEY,
  business_id  CHAR(36) NOT NULL,
  user_id      CHAR(36) NOT NULL,
  log_date     DATE     NOT NULL,
  meal_type    ENUM('breakfast','lunch','dinner','snack') NOT NULL,
  description  TEXT     NOT NULL,
  logged_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  KEY idx_food_logs_user_date (user_id, log_date)
);

-- Demo: enable nutrition + sample nutritionist
UPDATE business_configs SET feature_nutrition = 1 WHERE business_id = 'demo-business-id';

INSERT IGNORE INTO nutritionists (id, business_id, full_name, email, is_active)
VALUES ('demo-nutritionist-id', 'demo-business-id', 'Μαρία Διατροφολόγος', 'nutrition@demo.com', 1);

UPDATE business_plans SET includes_nutrition = 1 WHERE id = 'demo-plan-pt-8' AND business_id = 'demo-business-id';
