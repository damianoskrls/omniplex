USE bookup;

SET @has = (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='business_configs' AND COLUMN_NAME='minutes_per_booking');
SET @sql = IF(@has=0, "ALTER TABLE business_configs
  ADD COLUMN minutes_per_booking INT NOT NULL DEFAULT 5",
  "SELECT 'minutes_per_booking exists' AS info");
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

CREATE TABLE IF NOT EXISTS monthly_reports (
  id           CHAR(36)  NOT NULL PRIMARY KEY,
  business_id  CHAR(36)  NOT NULL,
  report_month DATE      NOT NULL,
  data         JSON      NOT NULL,
  created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_report (business_id, report_month),
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE
);
