USE bookup;

SET @dam_user_id = (
  SELECT id FROM users WHERE email = 'dam@test.com' AND business_id = 'demo-business-id' LIMIT 1
);
SET @week_start = DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY);

-- Skip if test user does not exist (e.g. fresh DB without dam@test.com)
SELECT IF(@dam_user_id IS NULL, 'dam@test.com not found — skipping nutrition demo seed', CONCAT('Seeding nutrition for ', @dam_user_id)) AS info;

UPDATE users
SET weight_kg = 85.0,
    target_weight_kg = 78.0,
    height_cm = 175.0,
    body_fat_pct = 23.5,
    fitness_goal = 'weight_loss'
WHERE id = @dam_user_id;

INSERT INTO meal_plans (id, business_id, user_id, week_start, notes)
SELECT
  COALESCE(
    (SELECT id FROM meal_plans WHERE user_id = @dam_user_id AND week_start = @week_start LIMIT 1),
    'dam-meal-plan-week'
  ),
  'demo-business-id',
  @dam_user_id,
  @week_start,
  'Πρόγραμμα απώλειας βάρους — επίλεξε 1 επιλογή ανά γεύμα. Πίνε 2L νερό/ημέρα.'
FROM DUAL
WHERE @dam_user_id IS NOT NULL
ON DUPLICATE KEY UPDATE notes = VALUES(notes);

SET @plan_id = (
  SELECT id FROM meal_plans WHERE user_id = @dam_user_id AND week_start = @week_start LIMIT 1
);

DELETE FROM meal_plan_items WHERE meal_plan_id = @plan_id AND @plan_id IS NOT NULL;

-- Monday breakfast — 3 options
INSERT INTO meal_plan_items (id, meal_plan_id, day_of_week, meal_type, title, description, notes, portions_json, recipe_text, sort_order)
SELECT * FROM (
  SELECT 'dam-opt-m1-b1' AS id, @plan_id AS meal_plan_id, 1 AS day_of_week, 'breakfast' AS meal_type,
    'Μπάρα δημητριακών' AS title, 'Μπάρα δημητριακών' AS description,
    'Με 1 ποτήρι νερό πριν το φαγητό' AS notes,
    JSON_ARRAY(JSON_OBJECT('ingredient','Μπάρα δημητριακών whole grain','amount',1,'unit','τεμ'), JSON_OBJECT('ingredient','Γάλα 1.5%','amount',200,'unit','ml')) AS portions_json,
    '1 μπάρα + 200ml γάλα. Εναλλακτικά σκέτο γιαούρτι.' AS recipe_text, 0 AS sort_order
  UNION ALL SELECT 'dam-opt-m1-b2', @plan_id, 1, 'breakfast', 'Γιαούρτι με μέλι & καρύδια', 'Γιαούρτι με μέλι', 'Χωρίς επιπλέον ζάχαρη',
    JSON_ARRAY(JSON_OBJECT('ingredient','Γιαούρτι 2%','amount',170,'unit','g'), JSON_OBJECT('ingredient','Μέλι','amount',1,'unit','κ.σ.'), JSON_OBJECT('ingredient','Καρύδια','amount',15,'unit','g')),
    'Ανακατέψε και πρόσθεσε καρύδια από πάνω.', 1
  UNION ALL SELECT 'dam-opt-m1-b3', @plan_id, 1, 'breakfast', 'Omelette πρωτεΐνης', 'Omelette 3 αυγών', 'Με λαχανικά',
    JSON_ARRAY(JSON_OBJECT('ingredient','Αυγά','amount',3,'unit','τεμ'), JSON_OBJECT('ingredient','Κολοκυθάκι','amount',80,'unit','g'), JSON_OBJECT('ingredient','Ελαιόλαδο','amount',1,'unit','κ.σ.')),
    'Σοτέ λαχανικά, μετά αυγά. Χωρίς ψωμί.', 2
) AS seed WHERE @plan_id IS NOT NULL;

-- Monday lunch
INSERT INTO meal_plan_items (id, meal_plan_id, day_of_week, meal_type, title, description, notes, portions_json, recipe_text, sort_order)
SELECT * FROM (
  SELECT 'dam-opt-m1-l1', @plan_id, 1, 'lunch', 'Κοτόπουλο με ρύζι', 'Ψητό στήθος κοτόπουλο', 'Χωρίς σάλτσες',
    JSON_ARRAY(JSON_OBJECT('ingredient','Στήθος κοτόπουλο','amount',180,'unit','g'), JSON_OBJECT('ingredient','Ρύζι basmati','amount',80,'unit','g'), JSON_OBJECT('ingredient','Σαλάτα μαρούλι','amount',1,'unit','μπολ')),
    NULL, 0
  UNION ALL SELECT 'dam-opt-m1-l2', @plan_id, 1, 'lunch', 'Ψάρι με πατάτες', 'Φιλέτο ψαριού', 'Ψητό ή ατμός',
    JSON_ARRAY(JSON_OBJECT('ingredient','Φιλέτο ψαριού','amount',200,'unit','g'), JSON_OBJECT('ingredient','Πατάτα','amount',200,'unit','g'), JSON_OBJECT('ingredient','Λεμόνι','amount',0.5,'unit','τεμ')),
    NULL, 1
) AS seed WHERE @plan_id IS NOT NULL;

-- Monday dinner
INSERT INTO meal_plan_items (id, meal_plan_id, day_of_week, meal_type, title, description, notes, portions_json, sort_order)
SELECT * FROM (
  SELECT 'dam-opt-m1-d1', @plan_id, 1, 'dinner', 'Σαλάτα με τόνο', 'Σαλάτα τόνου', 'Ελαιόλαδο 1 κ.σ. max',
    JSON_ARRAY(JSON_OBJECT('ingredient','Τόνος σε νερό','amount',1,'unit','κονσέρβα'), JSON_OBJECT('ingredient','Μαρούλι & ντομάτα','amount',200,'unit','g')), 0
  UNION ALL SELECT 'dam-opt-m1-d2', @plan_id, 1, 'dinner', 'Ομελέτα λαχανικών', 'Ελαφρύ βραδινό', 'Με σαλάτα',
    JSON_ARRAY(JSON_OBJECT('ingredient','Αυγά','amount',2,'unit','τεμ'), JSON_OBJECT('ingredient','Μανιτάρια','amount',100,'unit','g')), 1
) AS seed WHERE @plan_id IS NOT NULL;

-- Tuesday breakfast
INSERT INTO meal_plan_items (id, meal_plan_id, day_of_week, meal_type, title, description, notes, portions_json, sort_order)
SELECT * FROM (
  SELECT 'dam-opt-m2-b1', @plan_id, 2, 'breakfast', 'Βρώμη με φρούτα', 'Πουρές βρώμης', 'Χωρίς ζάχαρη',
    JSON_ARRAY(JSON_OBJECT('ingredient','Νιφάδες βρώμης','amount',50,'unit','g'), JSON_OBJECT('ingredient','Γάλα αμυγδάλου','amount',200,'unit','ml'), JSON_OBJECT('ingredient','Μπανάνα','amount',0.5,'unit','τεμ')), 0
  UNION ALL SELECT 'dam-opt-m2-b2', @plan_id, 2, 'breakfast', 'Τοστ ολικής με τυρί', '2 φέτες τοστ', 'Λεπτό επάλειμμα',
    JSON_ARRAY(JSON_OBJECT('ingredient','Ψωμί ολικής','amount',2,'unit','φέτες'), JSON_OBJECT('ingredient','Τυρί cottage','amount',80,'unit','g')), 1
) AS seed WHERE @plan_id IS NOT NULL;

-- Tue–Fri samples
INSERT INTO meal_plan_items (id, meal_plan_id, day_of_week, meal_type, title, description, portions_json, sort_order)
SELECT * FROM (
  SELECT 'dam-opt-m2-l1', @plan_id, 2, 'lunch', 'Κοτόπουλο wrap', 'Ολικής άλεσης', JSON_ARRAY(JSON_OBJECT('ingredient','Τορτίγια ολικής','amount',1,'unit','τεμ'), JSON_OBJECT('ingredient','Κοτόπουλο','amount',120,'unit','g')), 0
  UNION ALL SELECT 'dam-opt-m3-l1', @plan_id, 3, 'lunch', 'Μοσχάρι με μπρόκολο', 'Ψητό μοσχαρίσιο', JSON_ARRAY(JSON_OBJECT('ingredient','Μοσχαρίσιο','amount',150,'unit','g'), JSON_OBJECT('ingredient','Μπρόκολο','amount',200,'unit','g')), 0
  UNION ALL SELECT 'dam-opt-m3-b1', @plan_id, 3, 'breakfast', 'Smoothie πρωτεΐνης', 'Με μπανάνα', JSON_ARRAY(JSON_OBJECT('ingredient','Πρωτεΐνη ορού','amount',1,'unit','scoops'), JSON_OBJECT('ingredient','Γάλα 1.5%','amount',250,'unit','ml')), 0
  UNION ALL SELECT 'dam-opt-m4-b1', @plan_id, 4, 'breakfast', 'Αυγά βραστά & φρυγανιά', '2 αυγά + 1 φρυγανιά', JSON_ARRAY(JSON_OBJECT('ingredient','Αυγά','amount',2,'unit','τεμ'), JSON_OBJECT('ingredient','Φρυγανιά ολικής','amount',1,'unit','φέτα')), 0
  UNION ALL SELECT 'dam-opt-m5-d1', @plan_id, 5, 'dinner', 'Σούπα λαχανικών', 'Χωρίς κρέμα γάλακτος', JSON_ARRAY(JSON_OBJECT('ingredient','Λαχανικά μίξη','amount',300,'unit','g'), JSON_OBJECT('ingredient','Κοτόπουλο τεμαχισμένο','amount',100,'unit','g')), 0
) AS seed WHERE @plan_id IS NOT NULL;

-- Snacks
INSERT INTO meal_plan_items (id, meal_plan_id, day_of_week, meal_type, title, description, notes, portions_json, sort_order)
SELECT * FROM (
  SELECT 'dam-opt-snack1', @plan_id, 1, 'snack', 'Καρπός & δαμάσκηνο', 'Μικρό σνακ', 'Μετά την προπόνηση',
    JSON_ARRAY(JSON_OBJECT('ingredient','Αμύγδαλα','amount',15,'unit','g'), JSON_OBJECT('ingredient','Δαμάσκηνα αποξηραμένα','amount',2,'unit','τεμ')), 0
  UNION ALL SELECT 'dam-opt-snack2', @plan_id, 3, 'snack', 'Γιαούρτι 0%', 'Ελαφρύ σνακ', NULL,
    JSON_ARRAY(JSON_OBJECT('ingredient','Γιαούρτι 0%','amount',150,'unit','g')), 0
) AS seed WHERE @plan_id IS NOT NULL;

DELETE FROM food_logs
WHERE user_id = @dam_user_id AND log_date = CURDATE() AND id = 'dam-log-breakfast';

INSERT INTO food_logs (id, business_id, user_id, log_date, meal_type, description, logged_at)
SELECT
  'dam-log-breakfast',
  'demo-business-id',
  @dam_user_id,
  CURDATE(),
  'breakfast',
  'Έφαγα γιαούρτι με μέλι και καρύδια όπως πρότεινες',
  DATE_SUB(NOW(), INTERVAL 4 HOUR)
FROM DUAL
WHERE @dam_user_id IS NOT NULL;
