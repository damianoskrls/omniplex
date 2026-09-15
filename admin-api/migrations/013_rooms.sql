CREATE TABLE IF NOT EXISTS rooms (
  id CHAR(36) NOT NULL,
  business_id CHAR(36) NOT NULL,
  name VARCHAR(255) NOT NULL,
  description VARCHAR(500) DEFAULT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  sort_order INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_business (business_id)
);
