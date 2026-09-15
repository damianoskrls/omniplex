USE bookup;

CREATE TABLE IF NOT EXISTS nutrition_program_templates (
  id           CHAR(36)     PRIMARY KEY,
  business_id  CHAR(36)     NOT NULL,
  name         VARCHAR(120) NOT NULL,
  notes        TEXT         DEFAULT NULL,
  created_at   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_nutrition_tpl_business (business_id),
  FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS nutrition_program_template_items (
  id            CHAR(36) PRIMARY KEY,
  template_id   CHAR(36) NOT NULL,
  day_of_week   TINYINT  NOT NULL COMMENT '1=Mon .. 7=Sun',
  meal_type     ENUM('breakfast','lunch','dinner','snack') NOT NULL,
  title         VARCHAR(255) NOT NULL,
  description   TEXT     NOT NULL,
  notes         TEXT     DEFAULT NULL,
  portions_json JSON     DEFAULT NULL,
  image_url     VARCHAR(500) DEFAULT NULL,
  recipe_text   TEXT     DEFAULT NULL,
  sort_order    INT      NOT NULL DEFAULT 0,
  FOREIGN KEY (template_id) REFERENCES nutrition_program_templates(id) ON DELETE CASCADE,
  KEY idx_nutrition_tpl_items (template_id, day_of_week, meal_type)
);
