USE bookup;

-- Feature flag
SET @has = (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='business_configs' AND COLUMN_NAME='feature_marketplace');
SET @sql = IF(@has=0,
  "ALTER TABLE business_configs ADD COLUMN feature_marketplace TINYINT(1) NOT NULL DEFAULT 0",
  "SELECT 'feature_marketplace exists' AS info");
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- Products catalogue
CREATE TABLE IF NOT EXISTS products (
  id           CHAR(36)      NOT NULL PRIMARY KEY,
  business_id  CHAR(36)      NOT NULL,
  name         VARCHAR(255)  NOT NULL,
  description  TEXT          DEFAULT NULL,
  category     VARCHAR(100)  DEFAULT NULL COMMENT 'merch | supplements | equipment | other',
  price_cents  INT           NOT NULL,
  stock        INT           DEFAULT NULL COMMENT 'NULL = unlimited',
  image_url    VARCHAR(500)  DEFAULT NULL,
  is_active    TINYINT(1)    NOT NULL DEFAULT 1,
  sort_order   INT           NOT NULL DEFAULT 0,
  created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  INDEX idx_products_biz (business_id, is_active, sort_order)
);

-- Customer orders
CREATE TABLE IF NOT EXISTS orders (
  id                CHAR(36)    NOT NULL PRIMARY KEY,
  business_id       CHAR(36)    NOT NULL,
  user_id           CHAR(36)    NOT NULL,
  status            VARCHAR(30) NOT NULL DEFAULT 'pending'
    COMMENT 'pending | paid | fulfilled | cancelled | refunded',
  total_cents       INT         NOT NULL,
  provider          VARCHAR(30) DEFAULT NULL,
  provider_txn_id   VARCHAR(255) DEFAULT NULL,
  provider_intent_id VARCHAR(255) DEFAULT NULL,
  mydata_mark       VARCHAR(100) DEFAULT NULL,
  mydata_uid        VARCHAR(100) DEFAULT NULL,
  notes             TEXT        DEFAULT NULL,
  created_at        TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id)     REFERENCES users(id)      ON DELETE CASCADE,
  INDEX idx_orders_biz  (business_id, status, created_at),
  INDEX idx_orders_user (user_id, created_at)
);

-- Order line items
CREATE TABLE IF NOT EXISTS order_items (
  id               CHAR(36) NOT NULL PRIMARY KEY,
  order_id         CHAR(36) NOT NULL,
  product_id       CHAR(36) NOT NULL,
  product_name     VARCHAR(255) NOT NULL COMMENT 'snapshot at time of order',
  qty              INT      NOT NULL DEFAULT 1,
  unit_price_cents INT      NOT NULL,
  FOREIGN KEY (order_id)   REFERENCES orders(id)   ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
);
