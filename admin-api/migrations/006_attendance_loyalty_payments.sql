USE bookup;

SET @has_att = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bookings' AND COLUMN_NAME = 'attendance_confirmed'
);
SET @sql_att = IF(@has_att = 0,
  'ALTER TABLE bookings ADD COLUMN attendance_confirmed TINYINT(1) NOT NULL DEFAULT 0, ADD COLUMN attendance_confirmed_at DATETIME DEFAULT NULL',
  'SELECT ''attendance exists'' AS info');
PREPARE stmt FROM @sql_att; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS user_goals (
  id               CHAR(36) PRIMARY KEY,
  user_id          CHAR(36) NOT NULL,
  business_id      CHAR(36) NOT NULL,
  target_sessions  INT NOT NULL DEFAULT 6,
  period           VARCHAR(20) NOT NULL DEFAULT 'monthly',
  is_active        TINYINT(1) NOT NULL DEFAULT 1,
  created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  UNIQUE KEY uq_user_goal (user_id, business_id)
);

CREATE TABLE IF NOT EXISTS loyalty_transactions (
  id          CHAR(36) PRIMARY KEY,
  user_id     CHAR(36) NOT NULL,
  business_id CHAR(36) NOT NULL,
  booking_id  CHAR(36) DEFAULT NULL,
  points      INT NOT NULL,
  reason      VARCHAR(255) NOT NULL,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE SET NULL
);

SET @has_pay_desc = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payments' AND COLUMN_NAME = 'description'
);
SET @sql_pay = IF(@has_pay_desc = 0,
  'ALTER TABLE payments
    ADD COLUMN description VARCHAR(255) DEFAULT NULL,
    ADD COLUMN payment_date DATE DEFAULT NULL,
    ADD COLUMN due_date DATE DEFAULT NULL,
    ADD COLUMN paid_amount_cents INT NOT NULL DEFAULT 0,
    ADD COLUMN notes TEXT DEFAULT NULL,
    ADD COLUMN method VARCHAR(50) DEFAULT ''cash''',
  'SELECT ''payment cols exist'' AS info');
PREPARE stmt FROM @sql_pay; EXECUTE stmt; DEALLOCATE PREPARE stmt;

UPDATE business_configs SET feature_loyalty_points = 1 WHERE business_id = 'demo-business-id';

UPDATE payments SET paid_amount_cents = amount_cents WHERE paid_amount_cents = 0 AND status = 'paid';
