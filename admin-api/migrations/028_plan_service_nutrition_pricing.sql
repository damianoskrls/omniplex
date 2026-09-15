USE bookup;

-- Link plans to primary service + distinguish nutrition-only plans
SET @has_service_id = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_plans' AND COLUMN_NAME = 'service_id'
);
SET @sql_sid = IF(@has_service_id = 0,
  'ALTER TABLE business_plans ADD COLUMN service_id CHAR(36) DEFAULT NULL AFTER business_id,
   ADD CONSTRAINT fk_plan_service FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE SET NULL',
  'SELECT ''service_id exists'' AS info');
PREPARE stmt FROM @sql_sid; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_plan_type = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_plans' AND COLUMN_NAME = 'plan_type'
);
SET @sql_pt = IF(@has_plan_type = 0,
  'ALTER TABLE business_plans ADD COLUMN plan_type ENUM(''service'',''nutrition'') NOT NULL DEFAULT ''service'' AFTER service_id',
  'SELECT ''plan_type exists'' AS info');
PREPARE stmt FROM @sql_pt; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Nutritionist profile + pricing
SET @has_nut_phone = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'nutritionists' AND COLUMN_NAME = 'phone'
);
SET @sql_np = IF(@has_nut_phone = 0,
  'ALTER TABLE nutritionists
     ADD COLUMN phone VARCHAR(40) DEFAULT NULL AFTER email,
     ADD COLUMN bio TEXT DEFAULT NULL AFTER phone,
     ADD COLUMN monthly_price_cents INT DEFAULT NULL AFTER bio,
     ADD COLUMN per_session_price_cents INT DEFAULT NULL AFTER monthly_price_cents,
     ADD COLUMN package_sessions INT DEFAULT NULL AFTER per_session_price_cents,
     ADD COLUMN package_price_cents INT DEFAULT NULL AFTER package_sessions,
     ADD COLUMN default_billing_period VARCHAR(50) NOT NULL DEFAULT ''monthly'' AFTER package_price_cents,
     ADD COLUMN nutrition_plan_id CHAR(36) DEFAULT NULL AFTER default_billing_period',
  'SELECT ''nutritionist pricing exists'' AS info');
PREPARE stmt FROM @sql_np; EXECUTE stmt; DEALLOCATE PREPARE stmt;
