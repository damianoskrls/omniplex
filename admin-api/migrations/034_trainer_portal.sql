USE bookup;

SET @has_portal_email = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'staff' AND COLUMN_NAME = 'portal_email'
);
SET @sql_portal_email = IF(@has_portal_email = 0,
  'ALTER TABLE staff ADD COLUMN portal_email VARCHAR(255) DEFAULT NULL',
  'SELECT ''portal_email exists'' AS info');
PREPARE stmt FROM @sql_portal_email; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS staff_passwords (
  staff_id CHAR(36) NOT NULL PRIMARY KEY,
  password_hash VARCHAR(255) NOT NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_staff_passwords_staff FOREIGN KEY (staff_id) REFERENCES staff(id) ON DELETE CASCADE
);

UPDATE staff
SET portal_email = 'trainer@demo.com'
WHERE id = 'demo-staff-1' AND business_id = 'demo-business-id';

INSERT INTO staff_passwords (staff_id, password_hash)
SELECT 'demo-staff-1', '$2a$10$g3CWwlRvofJvZ4lurwToBOebMrzcB2LTc8mwbSccGZh3nIm5X60R2'
FROM DUAL
WHERE EXISTS (SELECT 1 FROM staff WHERE id = 'demo-staff-1')
ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash);
