USE bookup;

-- Per-trainer fee configuration
CREATE TABLE IF NOT EXISTS trainer_fees (
  id            CHAR(36)       NOT NULL PRIMARY KEY,
  business_id   CHAR(36)       NOT NULL,
  staff_id      CHAR(36)       NOT NULL,
  fee_per_class DECIMAL(10,2)  DEFAULT NULL COMMENT 'Fixed amount per class taught',
  fee_per_head  DECIMAL(10,2)  DEFAULT NULL COMMENT 'Per-participant amount',
  notes         TEXT           DEFAULT NULL,
  created_at    TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_trainer_fee (business_id, staff_id),
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  FOREIGN KEY (staff_id)    REFERENCES staff(id)      ON DELETE CASCADE
);
