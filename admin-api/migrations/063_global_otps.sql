-- OTP codes for global user phone verification
CREATE TABLE IF NOT EXISTS global_otps (
  id          VARCHAR(36)  NOT NULL PRIMARY KEY,
  phone       VARCHAR(30)  NOT NULL,
  code        VARCHAR(6)   NOT NULL,
  expires_at  DATETIME     NOT NULL,
  used        TINYINT(1)   NOT NULL DEFAULT 0,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_phone_code (phone, code),
  INDEX idx_expires (expires_at)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
