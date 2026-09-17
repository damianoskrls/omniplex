USE bookup;

CREATE TABLE IF NOT EXISTS business_expenses (
  id           CHAR(36)      NOT NULL PRIMARY KEY,
  business_id  CHAR(36)      NOT NULL,
  year         SMALLINT      NOT NULL,
  month        TINYINT       NOT NULL,
  category     VARCHAR(100)  DEFAULT NULL,
  description  VARCHAR(255)  DEFAULT NULL,
  amount_cents INT           NOT NULL DEFAULT 0,
  created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  INDEX idx_biz_exp (business_id, year, month)
);
