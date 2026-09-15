CREATE TABLE IF NOT EXISTS service_class_types (
  id CHAR(36) NOT NULL,
  service_id CHAR(36) NOT NULL,
  business_id CHAR(36) NOT NULL,
  label VARCHAR(255) NOT NULL,
  subtitle TEXT,
  icon_key VARCHAR(50),
  preparation_tips TEXT,
  post_workout_tips TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_service (service_id, business_id)
);
