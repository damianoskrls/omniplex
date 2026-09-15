USE bookup;

-- MySQL uses uq_meal_plan_slot as the FK index on meal_plan_id — add a replacement index first.
SET @has_idx_plan = (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'meal_plan_items'
    AND INDEX_NAME = 'idx_meal_plan_items_plan'
);
SET @sql_add_idx = IF(@has_idx_plan = 0,
  'CREATE INDEX idx_meal_plan_items_plan ON meal_plan_items (meal_plan_id)',
  'SELECT ''idx_meal_plan_items_plan exists'' AS info');
PREPARE stmt FROM @sql_add_idx; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Allow multiple options per meal slot (drop composite unique)
SET @has_uq_slot = (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'meal_plan_items'
    AND INDEX_NAME = 'uq_meal_plan_slot'
);
SET @sql_drop_uq = IF(@has_uq_slot > 0,
  'ALTER TABLE meal_plan_items DROP INDEX uq_meal_plan_slot',
  'SELECT ''uq_meal_plan_slot absent'' AS info');
PREPARE stmt FROM @sql_drop_uq; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_title = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'meal_plan_items' AND COLUMN_NAME = 'title'
);
SET @sql_title = IF(@has_title = 0,
  'ALTER TABLE meal_plan_items ADD COLUMN title VARCHAR(200) DEFAULT NULL AFTER meal_type',
  'SELECT ''title exists'' AS info');
PREPARE stmt FROM @sql_title; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_notes = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'meal_plan_items' AND COLUMN_NAME = 'notes'
);
SET @sql_notes = IF(@has_notes = 0,
  'ALTER TABLE meal_plan_items ADD COLUMN notes TEXT DEFAULT NULL AFTER title',
  'SELECT ''notes exists'' AS info');
PREPARE stmt FROM @sql_notes; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_portions = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'meal_plan_items' AND COLUMN_NAME = 'portions_json'
);
SET @sql_portions = IF(@has_portions = 0,
  'ALTER TABLE meal_plan_items ADD COLUMN portions_json JSON DEFAULT NULL AFTER notes',
  'SELECT ''portions_json exists'' AS info');
PREPARE stmt FROM @sql_portions; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_img = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'meal_plan_items' AND COLUMN_NAME = 'image_url'
);
SET @sql_img = IF(@has_img = 0,
  'ALTER TABLE meal_plan_items ADD COLUMN image_url VARCHAR(500) DEFAULT NULL AFTER portions_json',
  'SELECT ''image_url exists'' AS info');
PREPARE stmt FROM @sql_img; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_recipe = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'meal_plan_items' AND COLUMN_NAME = 'recipe_text'
);
SET @sql_recipe = IF(@has_recipe = 0,
  'ALTER TABLE meal_plan_items ADD COLUMN recipe_text TEXT DEFAULT NULL AFTER image_url',
  'SELECT ''recipe_text exists'' AS info');
PREPARE stmt FROM @sql_recipe; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_title_col = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'meal_plan_items' AND COLUMN_NAME = 'title'
);
SET @sql_backfill = IF(@has_title_col > 0,
  'UPDATE meal_plan_items SET title = description WHERE title IS NULL AND description IS NOT NULL AND description != ''''',
  'SELECT ''title column missing'' AS info');
PREPARE stmt FROM @sql_backfill; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_photo = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'food_logs' AND COLUMN_NAME = 'photo_url'
);
SET @sql_photo = IF(@has_photo = 0,
  'ALTER TABLE food_logs ADD COLUMN photo_url VARCHAR(500) DEFAULT NULL AFTER description',
  'SELECT ''photo_url exists'' AS info');
PREPARE stmt FROM @sql_photo; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_opt = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'food_logs' AND COLUMN_NAME = 'plan_option_id'
);
SET @sql_opt = IF(@has_opt = 0,
  'ALTER TABLE food_logs ADD COLUMN plan_option_id CHAR(36) DEFAULT NULL AFTER photo_url',
  'SELECT ''plan_option_id exists'' AS info');
PREPARE stmt FROM @sql_opt; EXECUTE stmt; DEALLOCATE PREPARE stmt;
