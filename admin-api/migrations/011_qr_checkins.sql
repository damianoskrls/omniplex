-- QR code walk-in check-ins (independent of bookings)
CREATE TABLE IF NOT EXISTS qr_checkins (
  id            CHAR(36)     NOT NULL,
  business_id   CHAR(36)     NOT NULL,
  user_id       CHAR(36)     NOT NULL,
  membership_id CHAR(36)     DEFAULT NULL,
  checked_in_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  session_deducted TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_user_business_date (user_id, business_id, checked_in_at)
);
