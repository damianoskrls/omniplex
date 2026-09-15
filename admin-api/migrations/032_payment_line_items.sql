USE bookup;

CREATE TABLE IF NOT EXISTS payment_line_items (
  id CHAR(36) NOT NULL PRIMARY KEY,
  payment_id CHAR(36) NOT NULL,
  membership_id CHAR(36) DEFAULT NULL,
  service_id CHAR(36) DEFAULT NULL,
  plan_id CHAR(36) DEFAULT NULL,
  label VARCHAR(255) NOT NULL,
  amount_cents INT NOT NULL DEFAULT 0,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_payment_line_payment (payment_id),
  KEY idx_payment_line_membership (membership_id),
  CONSTRAINT fk_payment_line_payment FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE CASCADE
);
