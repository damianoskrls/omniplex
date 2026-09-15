-- BookUp database schema
CREATE DATABASE IF NOT EXISTS bookup CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE bookup;

CREATE TABLE IF NOT EXISTS businesses (
  id            CHAR(36) PRIMARY KEY,
  slug          VARCHAR(100) NOT NULL UNIQUE,
  name          VARCHAR(255) NOT NULL,
  business_type VARCHAR(50)  NOT NULL,
  owner_email   VARCHAR(255) NOT NULL,
  plan          VARCHAR(50)  NOT NULL DEFAULT 'starter',
  is_active     TINYINT(1)   NOT NULL DEFAULT 1,
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS business_configs (
  id                            CHAR(36) PRIMARY KEY,
  business_id                   CHAR(36) NOT NULL UNIQUE,
  primary_color                 VARCHAR(7)  DEFAULT '#6200EE',
  secondary_color               VARCHAR(7)  DEFAULT '#03DAC6',
  accent_color                  VARCHAR(7)  DEFAULT '#FF6D00',
  background_color              VARCHAR(7)  DEFAULT NULL,
  surface_color                 VARCHAR(7)  DEFAULT NULL,
  font_family                   VARCHAR(100) DEFAULT 'Inter',
  app_name                      VARCHAR(255) NOT NULL,
  bundle_id                     VARCHAR(255) NOT NULL,
  android_package               VARCHAR(255) NOT NULL,
  version_name                  VARCHAR(50)  DEFAULT '1.0.0',
  logo_url                      VARCHAR(500) DEFAULT NULL,
  label_overrides               JSON         DEFAULT NULL,
  feature_online_booking        TINYINT(1)   DEFAULT 1,
  feature_loyalty_points        TINYINT(1)   DEFAULT 0,
  feature_memberships           TINYINT(1)   DEFAULT 0,
  feature_pos_integration       TINYINT(1)   DEFAULT 0,
  feature_multi_location        TINYINT(1)   DEFAULT 0,
  feature_waitlist              TINYINT(1)   DEFAULT 0,
  feature_video_consultations   TINYINT(1)   DEFAULT 0,
  feature_custom_module_id      VARCHAR(100) DEFAULT NULL,
  firebase_project_id           VARCHAR(255) DEFAULT NULL,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS users (
  id             CHAR(36) PRIMARY KEY,
  business_id    CHAR(36) NOT NULL,
  full_name      VARCHAR(255) NOT NULL,
  email          VARCHAR(255) NOT NULL,
  phone          VARCHAR(50)  DEFAULT NULL,
  auth_uid       VARCHAR(255) DEFAULT NULL,
  loyalty_points INT          NOT NULL DEFAULT 0,
  account_status VARCHAR(20)  NOT NULL DEFAULT 'active',
  deleted_at     TIMESTAMP    NULL DEFAULT NULL,
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_user_email_biz (business_id, email),
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS user_passwords (
  user_id       CHAR(36) PRIMARY KEY,
  password_hash VARCHAR(255) NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS client_admin_passwords (
  business_id   CHAR(36) PRIMARY KEY,
  password_hash VARCHAR(255) NOT NULL,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS services (
  id                   CHAR(36) PRIMARY KEY,
  business_id          CHAR(36) NOT NULL,
  name                 VARCHAR(255) NOT NULL,
  description          TEXT         DEFAULT NULL,
  duration_mins        INT          NOT NULL,
  price_cents          INT          NOT NULL DEFAULT 0,
  category             VARCHAR(100) DEFAULT NULL,
  image_url            VARCHAR(500) DEFAULT NULL,
  slot_label_mode      VARCHAR(20)  NOT NULL DEFAULT 'time_only',
  hide_staff_selection TINYINT(1)   NOT NULL DEFAULT 0,
  is_active            TINYINT(1)   NOT NULL DEFAULT 1,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS service_slot_schedules (
  id          CHAR(36) PRIMARY KEY,
  service_id  CHAR(36) NOT NULL,
  business_id CHAR(36) NOT NULL,
  weekday     TINYINT  NOT NULL,
  start_time  TIME     NOT NULL,
  label       VARCHAR(255) DEFAULT NULL,
  room_name   VARCHAR(255) DEFAULT NULL,
  subtitle    TEXT         DEFAULT NULL,
  image_url   VARCHAR(500) DEFAULT NULL,
  icon_key      VARCHAR(50)  DEFAULT NULL,
  max_capacity  INT          DEFAULT NULL,
  is_active     TINYINT(1)   NOT NULL DEFAULT 1,
  FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  UNIQUE KEY uq_service_slot (service_id, weekday, start_time)
);

CREATE TABLE IF NOT EXISTS waitlist_entries (
  id          CHAR(36) PRIMARY KEY,
  business_id CHAR(36) NOT NULL,
  user_id     CHAR(36) NOT NULL,
  service_id  CHAR(36) NOT NULL,
  staff_id    CHAR(36) DEFAULT NULL,
  starts_at   DATETIME NOT NULL,
  ends_at     DATETIME NOT NULL,
  status      VARCHAR(20) NOT NULL DEFAULT 'waiting',
  position    INT NOT NULL DEFAULT 1,
  notes       TEXT DEFAULT NULL,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE,
  FOREIGN KEY (staff_id) REFERENCES staff(id) ON DELETE SET NULL,
  INDEX idx_waitlist_slot (business_id, service_id, starts_at, status),
  INDEX idx_waitlist_user (user_id, service_id, starts_at)
);

CREATE TABLE IF NOT EXISTS admin_notifications (
  id          CHAR(36) PRIMARY KEY,
  business_id CHAR(36) NOT NULL,
  type        VARCHAR(50) NOT NULL,
  title       VARCHAR(255) NOT NULL,
  body        TEXT DEFAULT NULL,
  payload     JSON DEFAULT NULL,
  is_read     TINYINT(1) NOT NULL DEFAULT 0,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  INDEX idx_notif_business (business_id, is_read, created_at)
);

CREATE TABLE IF NOT EXISTS staff (
  id          CHAR(36) PRIMARY KEY,
  business_id CHAR(36) NOT NULL,
  full_name   VARCHAR(255) NOT NULL,
  role        VARCHAR(100) NOT NULL,
  bio         TEXT         DEFAULT NULL,
  color_hex   VARCHAR(7)   DEFAULT '#607D8B',
  avatar_url  VARCHAR(500) DEFAULT NULL,
  is_active   TINYINT(1)   NOT NULL DEFAULT 1,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS staff_services (
  staff_id   CHAR(36) NOT NULL,
  service_id CHAR(36) NOT NULL,
  PRIMARY KEY (staff_id, service_id),
  FOREIGN KEY (staff_id) REFERENCES staff(id) ON DELETE CASCADE,
  FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS staff_availability (
  id         CHAR(36) PRIMARY KEY,
  staff_id   CHAR(36) NOT NULL,
  weekday    TINYINT  NOT NULL,
  start_time TIME     NOT NULL,
  end_time   TIME     NOT NULL,
  is_active  TINYINT(1) NOT NULL DEFAULT 1,
  FOREIGN KEY (staff_id) REFERENCES staff(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS business_plans (
  id             CHAR(36) PRIMARY KEY,
  business_id    CHAR(36) NOT NULL,
  name           VARCHAR(255) NOT NULL,
  sessions       INT          NOT NULL,
  price_cents    INT          NOT NULL DEFAULT 0,
  billing_period VARCHAR(50)  DEFAULT 'monthly',
  sort_order     INT          NOT NULL DEFAULT 0,
  is_active      TINYINT(1)   NOT NULL DEFAULT 1,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS service_plan_assignments (
  service_id CHAR(36) NOT NULL,
  plan_id    CHAR(36) NOT NULL,
  PRIMARY KEY (service_id, plan_id),
  FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE,
  FOREIGN KEY (plan_id) REFERENCES business_plans(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS user_memberships (
  id               CHAR(36) PRIMARY KEY,
  user_id          CHAR(36) NOT NULL,
  business_id      CHAR(36) NOT NULL,
  plan_id          CHAR(36) DEFAULT NULL,
  service_id       CHAR(36) DEFAULT NULL,
  service_category VARCHAR(100) DEFAULT NULL,
  total_sessions   INT          NOT NULL,
  used_sessions    INT          NOT NULL DEFAULT 0,
  valid_from       DATE         NOT NULL,
  valid_until      DATE         NOT NULL,
  notes            TEXT         DEFAULT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS bookings (
  id          CHAR(36) PRIMARY KEY,
  business_id CHAR(36) NOT NULL,
  user_id     CHAR(36) NOT NULL,
  staff_id    CHAR(36) NOT NULL,
  service_id  CHAR(36) NOT NULL,
  starts_at   DATETIME     NOT NULL,
  ends_at     DATETIME     NOT NULL,
  status      VARCHAR(50)  NOT NULL DEFAULT 'confirmed',
  source      VARCHAR(50)  DEFAULT 'app',
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (staff_id) REFERENCES staff(id) ON DELETE CASCADE,
  FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS payments (
  id           CHAR(36) PRIMARY KEY,
  business_id  CHAR(36) NOT NULL,
  user_id      CHAR(36) DEFAULT NULL,
  amount_cents INT          NOT NULL,
  status       VARCHAR(50)  NOT NULL DEFAULT 'paid',
  created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE
);

-- Demo tenant for local development
INSERT IGNORE INTO businesses (id, slug, name, business_type, owner_email, plan, is_active)
VALUES ('demo-business-id', 'handstand', 'Handstand', 'gym', 'owner@demo.com', 'pro', 1);

INSERT IGNORE INTO business_configs (
  id, business_id, app_name, bundle_id, android_package,
  primary_color, secondary_color, accent_color, label_overrides,
  feature_online_booking, feature_loyalty_points, feature_memberships, logo_url
) VALUES (
  'demo-config-id', 'demo-business-id', 'Handstand', 'com.handstand.app', 'com.handstand.app',
  '#6200EE', '#03DAC6', '#FF6D00',
  JSON_OBJECT(
    'book_cta', 'Κράτηση',
    'staff_noun', 'Γυμναστής',
    'service_noun', 'Υπηρεσία',
    'appointment_noun', 'Ραντεβού',
    'home_hero', 'Κράτησε εύκολα το επόμενο ραντεβού σου.',
    'loyalty_label', 'Πόντοι'
  ),
  1, 1, 1,
  '/uploads/demo-business-id/logo/handstand.png'
);
