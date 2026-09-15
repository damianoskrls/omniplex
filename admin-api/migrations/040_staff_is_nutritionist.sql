SET @has_nutritionist = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'staff' AND COLUMN_NAME = 'is_nutritionist'
);
SET @sql_nutritionist = IF(@has_nutritionist = 0,
  'ALTER TABLE staff ADD COLUMN is_nutritionist TINYINT(1) NOT NULL DEFAULT 0 AFTER is_active',
  'SELECT ''staff.is_nutritionist exists'' AS info');
PREPARE stmt FROM @sql_nutritionist; EXECUTE stmt; DEALLOCATE PREPARE stmt;

UPDATE staff s
INNER JOIN nutritionists n ON n.staff_id = s.id
SET s.is_nutritionist = 1;
