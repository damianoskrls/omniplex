USE bookup;

-- Nutrition package features & promotional conditions
SET @has_nut_meal = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_plans' AND COLUMN_NAME = 'nutrition_includes_meal_plan'
);
SET @sql_nm = IF(@has_nut_meal = 0,
  'ALTER TABLE business_plans
     ADD COLUMN nutrition_includes_meal_plan TINYINT(1) NOT NULL DEFAULT 1 AFTER includes_nutrition,
     ADD COLUMN nutrition_includes_measurements TINYINT(1) NOT NULL DEFAULT 0 AFTER nutrition_includes_meal_plan,
     ADD COLUMN nutrition_includes_food_diary TINYINT(1) NOT NULL DEFAULT 1 AFTER nutrition_includes_measurements,
     ADD COLUMN nutrition_includes_consultations TINYINT(1) NOT NULL DEFAULT 0 AFTER nutrition_includes_food_diary,
     ADD COLUMN nutrition_consultation_sessions INT DEFAULT NULL AFTER nutrition_includes_consultations,
     ADD COLUMN promo_rules JSON DEFAULT NULL AFTER nutrition_consultation_sessions',
  'SELECT ''nutrition plan fields exist'' AS info');
PREPARE stmt FROM @sql_nm; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Mark existing nutrition-type plans
UPDATE business_plans SET plan_type = 'nutrition', includes_nutrition = 1
WHERE includes_nutrition = 1 AND (plan_type IS NULL OR plan_type = 'service');
