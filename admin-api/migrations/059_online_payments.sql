USE bookup;

-- Feature flag
SET @has = (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='business_configs' AND COLUMN_NAME='feature_online_payments');
SET @sql = IF(@has=0,
  "ALTER TABLE business_configs ADD COLUMN feature_online_payments TINYINT(1) NOT NULL DEFAULT 0",
  "SELECT 'feature_online_payments exists' AS info");
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- Extend payments table with online-payment fields
SET @has = (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='payments' AND COLUMN_NAME='provider');
SET @sql = IF(@has=0,
  "ALTER TABLE payments
     ADD COLUMN provider           VARCHAR(30)  DEFAULT NULL COMMENT 'stripe | viva | everypay | null=manual',
     ADD COLUMN provider_txn_id    VARCHAR(255) DEFAULT NULL COMMENT 'Stripe charge/payment_intent id',
     ADD COLUMN provider_intent_id VARCHAR(255) DEFAULT NULL COMMENT 'Pending intent id (pre-capture)',
     ADD COLUMN mydata_mark        VARCHAR(100) DEFAULT NULL COMMENT 'AADE myDATA MARK',
     ADD COLUMN mydata_uid         VARCHAR(100) DEFAULT NULL COMMENT 'AADE myDATA UID',
     ADD COLUMN mydata_invoice_type VARCHAR(20) DEFAULT NULL COMMENT '11.1 = retail receipt',
     ADD COLUMN mydata_submitted_at DATETIME    DEFAULT NULL",
  "SELECT 'payment online cols exist' AS info");
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- Payment provider config per tenant
CREATE TABLE IF NOT EXISTS payment_providers (
  id           CHAR(36)     NOT NULL PRIMARY KEY,
  business_id  CHAR(36)     NOT NULL,
  provider     VARCHAR(30)  NOT NULL COMMENT 'stripe | viva | everypay',
  is_active    TINYINT(1)   NOT NULL DEFAULT 0,
  config       JSON         DEFAULT NULL COMMENT 'Keys: secret_key, publishable_key, webhook_secret, etc.',
  created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_biz_provider (business_id, provider),
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE
);

-- myDATA config per tenant (issuer details required by AADE)
CREATE TABLE IF NOT EXISTS mydata_config (
  id                CHAR(36)    NOT NULL PRIMARY KEY,
  business_id       CHAR(36)    NOT NULL UNIQUE,
  is_enabled        TINYINT(1)  NOT NULL DEFAULT 0,
  aade_user_id      VARCHAR(100) DEFAULT NULL COMMENT 'AADE user id',
  aade_subscription_key VARCHAR(255) DEFAULT NULL COMMENT 'AADE Ocp-Apim-Subscription-Key',
  vat_number        VARCHAR(20)  DEFAULT NULL COMMENT 'ΑΦΜ γυμναστηρίου',
  tax_authority     VARCHAR(20)  DEFAULT NULL COMMENT 'ΔΟΥ',
  legal_name        VARCHAR(255) DEFAULT NULL,
  address           VARCHAR(255) DEFAULT NULL,
  is_production     TINYINT(1)  NOT NULL DEFAULT 0 COMMENT '0=sandbox 1=live AADE',
  invoice_type      VARCHAR(10)  NOT NULL DEFAULT '11.1' COMMENT 'Default: Απόδειξη Λιανικής',
  vat_category      TINYINT(1)  NOT NULL DEFAULT 1 COMMENT '1=24% 2=13% 3=6% 8=0%',
  created_at        TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE
);
