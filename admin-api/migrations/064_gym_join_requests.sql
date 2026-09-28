-- Create gym_join_requests table if not exists, and add missing columns

CREATE TABLE IF NOT EXISTS gym_join_requests (
  id              VARCHAR(36)   NOT NULL PRIMARY KEY,
  global_user_id  VARCHAR(36)   NOT NULL,
  business_id     VARCHAR(36)   NOT NULL,
  full_name       VARCHAR(100)  NOT NULL DEFAULT '',
  email           VARCHAR(255)  NOT NULL DEFAULT '',
  phone           VARCHAR(30)   NULL,
  role            VARCHAR(20)   NOT NULL DEFAULT 'member',
  date_of_birth   DATE          NULL,
  specialty       VARCHAR(100)  NULL,
  status          VARCHAR(20)   NOT NULL DEFAULT 'pending',
  admin_note      TEXT          NULL,
  created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_global_user (global_user_id),
  INDEX idx_business    (business_id),
  INDEX idx_status      (status)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Add columns if the table already exists without them
ALTER TABLE gym_join_requests
  ADD COLUMN IF NOT EXISTS role          VARCHAR(20)  NOT NULL DEFAULT 'member',
  ADD COLUMN IF NOT EXISTS date_of_birth DATE         NULL,
  ADD COLUMN IF NOT EXISTS specialty     VARCHAR(100) NULL,
  ADD COLUMN IF NOT EXISTS admin_note    TEXT         NULL,
  ADD COLUMN IF NOT EXISTS updated_at    DATETIME     NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;
