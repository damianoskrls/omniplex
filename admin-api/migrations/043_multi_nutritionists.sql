USE bookup;

SET @has_loc = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'nutritionists' AND COLUMN_NAME = 'location_id'
);
SET @sql_loc = IF(@has_loc = 0,
  'ALTER TABLE nutritionists ADD COLUMN location_id CHAR(36) DEFAULT NULL AFTER business_id',
  'SELECT ''nutritionists.location_id exists'' AS info');
PREPARE stmt FROM @sql_loc; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_uq = (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'nutritionists' AND INDEX_NAME = 'uq_nutritionist_business'
);
SET @sql_uq = IF(@has_uq > 0,
  'ALTER TABLE nutritionists DROP INDEX uq_nutritionist_business',
  'SELECT ''uq_nutritionist_business absent'' AS info');
PREPARE stmt2 FROM @sql_uq; EXECUTE stmt2; DEALLOCATE PREPARE stmt2;

UPDATE nutritionists n
LEFT JOIN locations l ON l.business_id = n.business_id AND l.is_active = 1
SET n.location_id = (
  SELECT id FROM locations
  WHERE business_id = n.business_id AND is_active = 1
  ORDER BY sort_order, name LIMIT 1
)
WHERE n.location_id IS NULL;
