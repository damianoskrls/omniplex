USE bookup;

SET @has = (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='business_configs' AND COLUMN_NAME='waitlist_mode');
SET @sql = IF(@has=0, "ALTER TABLE business_configs
  ADD COLUMN waitlist_mode          VARCHAR(20)  NOT NULL DEFAULT 'first_come',
  ADD COLUMN waitlist_offer_minutes INT          NOT NULL DEFAULT 15,
  ADD COLUMN waitlist_cutoff_hours  INT          NOT NULL DEFAULT 2,
  ADD COLUMN waitlist_sms           TINYINT(1)  NOT NULL DEFAULT 0",
  "SELECT 'waitlist config cols exist' AS info");
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @has = (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='waitlist_entries' AND COLUMN_NAME='auto_book');
SET @sql = IF(@has=0, "ALTER TABLE waitlist_entries
  ADD COLUMN auto_book  TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN offered_at DATETIME   DEFAULT NULL",
  "SELECT 'waitlist_entries cols exist' AS info");
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

CREATE TABLE IF NOT EXISTS waitlist_promotions (
  id                CHAR(36)  NOT NULL PRIMARY KEY,
  business_id       CHAR(36)  NOT NULL,
  waitlist_entry_id CHAR(36)  NOT NULL,
  booking_id        CHAR(36)  DEFAULT NULL,
  service_id        CHAR(36)  NOT NULL,
  starts_at         DATETIME  NOT NULL,
  promoted_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  method            ENUM('auto_book','first_come','priority') NOT NULL DEFAULT 'first_come',
  INDEX idx_wl_promo_biz  (business_id, promoted_at),
  INDEX idx_wl_promo_slot (service_id, starts_at)
);
