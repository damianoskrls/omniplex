USE bookup;

SET @has = (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='business_configs' AND COLUMN_NAME='at_risk_days');
SET @sql = IF(@has=0, "ALTER TABLE business_configs
  ADD COLUMN at_risk_days     INT  NOT NULL DEFAULT 14,
  ADD COLUMN at_risk_template TEXT DEFAULT NULL",
  "SELECT 'at_risk cols exist' AS info");
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

CREATE TABLE IF NOT EXISTS at_risk_outreach (
  id                CHAR(36)  NOT NULL PRIMARY KEY,
  business_id       CHAR(36)  NOT NULL,
  user_id           CHAR(36)  NOT NULL,
  sent_at           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  returned_at       DATETIME  DEFAULT NULL,
  template_snapshot TEXT      DEFAULT NULL,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id)     REFERENCES users(id)      ON DELETE CASCADE,
  INDEX idx_atrisk_biz  (business_id, sent_at),
  INDEX idx_atrisk_user (user_id, sent_at)
);
