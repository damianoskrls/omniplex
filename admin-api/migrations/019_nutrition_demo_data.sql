USE bookup;

-- Demo client with nutrition package
INSERT IGNORE INTO users (id, business_id, full_name, email, phone, auth_uid, account_status, weight_kg, target_weight_kg, height_cm, body_fat_pct, fitness_goal)
VALUES (
  'demo-client-nutrition',
  'demo-business-id',
  'Νίκος Παπαδάκης',
  'client@demo.com',
  '6900000001',
  'demo-client-nutrition',
  'active',
  88.5,
  82.0,
  178.0,
  22.5,
  'weight_loss'
);

INSERT IGNORE INTO user_passwords (user_id, password_hash)
VALUES ('demo-client-nutrition', '$2a$10$xbbGuwT7bWv5iDDAFsChse8B7dwJwA7WqyLfCM7NozbwOSCa5XpYa');

INSERT IGNORE INTO user_memberships (id, user_id, business_id, plan_id, total_sessions, used_sessions, valid_from, valid_until, notes)
VALUES (
  'demo-membership-nutrition',
  'demo-client-nutrition',
  'demo-business-id',
  'demo-plan-pt-8',
  8,
  2,
  DATE_SUB(CURDATE(), INTERVAL 10 DAY),
  DATE_ADD(CURDATE(), INTERVAL 50 DAY),
  'Demo πακέτο με διατροφή'
);

SET @week_start = DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY);

INSERT INTO meal_plans (id, business_id, user_id, week_start, notes)
VALUES (
  'demo-meal-plan-week',
  'demo-business-id',
  'demo-client-nutrition',
  @week_start,
  'Πρόγραμμα απώλειας βάρους — επιλέγεις 1 επιλογή ανά γεύμα. Πίνε 2L νερό/ημέρα.'
)
ON DUPLICATE KEY UPDATE notes = VALUES(notes);

DELETE FROM meal_plan_items WHERE meal_plan_id = 'demo-meal-plan-week';

-- Monday breakfast — 3 options
INSERT INTO meal_plan_items (id, meal_plan_id, day_of_week, meal_type, title, description, notes, portions_json, recipe_text, sort_order) VALUES
('demo-opt-m1-b1', 'demo-meal-plan-week', 1, 'breakfast', 'Μπάρα δημητριακών', 'Μπάρα δημητριακών', 'Με 1 ποτήρι νερό πριν το φαγητό', JSON_ARRAY(JSON_OBJECT('ingredient','Μπάρα δημητριακών whole grain','amount',1,'unit','τεμ'), JSON_OBJECT('ingredient','Γάλα 1.5%','amount',200,'unit','ml')), '1 μπάρα + 200ml γάλα. Εναλλακτικά σκέτο γιαούρτι.', 0),
('demo-opt-m1-b2', 'demo-meal-plan-week', 1, 'breakfast', 'Γιαούρτι με μέλι & καρύδια', 'Γιαούρτι με μέλι', 'Χωρίς επιπλέον ζάχαρη', JSON_ARRAY(JSON_OBJECT('ingredient','Γιαούρτι 2%','amount',170,'unit','g'), JSON_OBJECT('ingredient','Μέλι','amount',1,'unit','κ.σ.'), JSON_OBJECT('ingredient','Καρύδια','amount',15,'unit','g')), 'Ανακατέψε και πρόσθεσε καρύδια από πάνω.', 1),
('demo-opt-m1-b3', 'demo-meal-plan-week', 1, 'breakfast', 'Omelette πρωτεΐνης', 'Omelette 3 αυγών', 'Με λαχανικά', JSON_ARRAY(JSON_OBJECT('ingredient','Αυγά','amount',3,'unit','τεμ'), JSON_OBJECT('ingredient','Κολοκυθάκι','amount',80,'unit','g'), JSON_OBJECT('ingredient','Ελαιόλαδο','amount',1,'unit','κ.σ.')), 'Σοτέ λαχανικά, μετά αυγά. Χωρίς ψωμί.', 2);

-- Monday lunch
INSERT INTO meal_plan_items (id, meal_plan_id, day_of_week, meal_type, title, description, notes, portions_json, recipe_text, sort_order) VALUES
('demo-opt-m1-l1', 'demo-meal-plan-week', 1, 'lunch', 'Κοτόπουλο με ρύζι', 'Ψητό στήθος κοτόπουλο', 'Χωρίς σάλτσες', JSON_ARRAY(JSON_OBJECT('ingredient','Στήθος κοτόπουλο','amount',180,'unit','g'), JSON_OBJECT('ingredient','Ρύζι basmati','amount',80,'unit','g'), JSON_OBJECT('ingredient','Σαλάτα μαρούλι','amount',1,'unit','μπολ')), NULL, 0),
('demo-opt-m1-l2', 'demo-meal-plan-week', 1, 'lunch', 'Ψάρι με πατάτες', 'Φιλέτο ψαριού', 'Ψητό ή ατμός', JSON_ARRAY(JSON_OBJECT('ingredient','Φιλέτο ψαριού','amount',200,'unit','g'), JSON_OBJECT('ingredient','Πατάτα','amount',200,'unit','g'), JSON_OBJECT('ingredient','Λεμόνι','amount',0.5,'unit','τεμ')), NULL, 1);

-- Monday dinner
INSERT INTO meal_plan_items (id, meal_plan_id, day_of_week, meal_type, title, description, notes, portions_json, sort_order) VALUES
('demo-opt-m1-d1', 'demo-meal-plan-week', 1, 'dinner', 'Σαλάτα με τόνο', 'Σαλάτα τόνου', 'Ελαιόλαδο 1 κ.σ. max', JSON_ARRAY(JSON_OBJECT('ingredient','Τόνος σε νερό','amount',1,'unit','κονσέρβα'), JSON_OBJECT('ingredient','Μαρούλι & ντομάτα','amount',200,'unit','g')), 0),
('demo-opt-m1-d2', 'demo-meal-plan-week', 1, 'dinner', 'Ομελέτα λαχανικών', 'Ελαφρύ βραδινό', 'Με σαλάτα', JSON_ARRAY(JSON_OBJECT('ingredient','Αυγά','amount',2,'unit','τεμ'), JSON_OBJECT('ingredient','Μανιτάρια','amount',100,'unit','g')), 1);

-- Tuesday breakfast — 2 options
INSERT INTO meal_plan_items (id, meal_plan_id, day_of_week, meal_type, title, description, notes, portions_json, sort_order) VALUES
('demo-opt-m2-b1', 'demo-meal-plan-week', 2, 'breakfast', 'Βρώμη με φρούτα', 'Πουρές βρώμης', 'Χωρίς ζάχαρη', JSON_ARRAY(JSON_OBJECT('ingredient','Νιφάδες βρώμης','amount',50,'unit','g'), JSON_OBJECT('ingredient','Γάλα αμυγδάλου','amount',200,'unit','ml'), JSON_OBJECT('ingredient','Μπανάνα','amount',0.5,'unit','τεμ')), 0),
('demo-opt-m2-b2', 'demo-meal-plan-week', 2, 'breakfast', 'Τοστ ολικής με τυρί', '2 φέτες τοστ', 'Λεπτό επάλειμμα', JSON_ARRAY(JSON_OBJECT('ingredient','Ψωμί ολικής','amount',2,'unit','φέτες'), JSON_OBJECT('ingredient','Τυρί cottage','amount',80,'unit','g')), 1);

-- Wednesday–Friday samples (1–2 options each main meal)
INSERT INTO meal_plan_items (id, meal_plan_id, day_of_week, meal_type, title, description, portions_json, sort_order) VALUES
('demo-opt-m3-l1', 'demo-meal-plan-week', 3, 'lunch', 'Μοσχάρι με μπρόκολο', 'Ψητό μοσχαρίσιο', JSON_ARRAY(JSON_OBJECT('ingredient','Μοσχαρίσιο','amount',150,'unit','g'), JSON_OBJECT('ingredient','Μπρόκολο','amount',200,'unit','g')), 0),
('demo-opt-m4-b1', 'demo-meal-plan-week', 4, 'breakfast', 'Smoothie πρωτεΐνης', 'Με μπανάνα', JSON_ARRAY(JSON_OBJECT('ingredient','Πρωτεΐνη ορού','amount',1,'unit','scoops'), JSON_OBJECT('ingredient','Γάλα 1.5%','amount',250,'unit','ml')), 0),
('demo-opt-m4-b2', 'demo-meal-plan-week', 4, 'breakfast', 'Αυγά βραστά & φρυγανιά', '2 αυγά + 1 φρυγανιά', JSON_ARRAY(JSON_OBJECT('ingredient','Αυγά','amount',2,'unit','τεμ'), JSON_OBJECT('ingredient','Φρυγανιά ολικής','amount',1,'unit','φέτα')), 1),
('demo-opt-m5-d1', 'demo-meal-plan-week', 5, 'dinner', 'Σούπα λαχανικών', 'Χωρίς κρέμα γάλακτος', JSON_ARRAY(JSON_OBJECT('ingredient','Λαχανικά μίξη','amount',300,'unit','g'), JSON_OBJECT('ingredient','Κοτόπουλο τεμαχισμένο','amount',100,'unit','g')), 0);

-- Snacks
INSERT INTO meal_plan_items (id, meal_plan_id, day_of_week, meal_type, title, description, notes, portions_json, sort_order) VALUES
('demo-opt-snack1', 'demo-meal-plan-week', 1, 'snack', 'Καρπός & δαμάσκηνο', 'Μικρό σνακ', 'Μετά την προπόνηση', JSON_ARRAY(JSON_OBJECT('ingredient','Αμύγδαλα','amount',15,'unit','g'), JSON_OBJECT('ingredient','Δαμάσκηνα αποξηραμένα','amount',2,'unit','τεμ')), 0),
('demo-opt-snack2', 'demo-meal-plan-week', 3, 'snack', 'Γιαούρτι 0%', 'Ελαφρύ σνακ', NULL, JSON_ARRAY(JSON_OBJECT('ingredient','Γιαούρτι 0%','amount',150,'unit','g')), 0);

-- Today's food logs (if Monday=1 use weekday)
INSERT IGNORE INTO food_logs (id, business_id, user_id, log_date, meal_type, description, logged_at) VALUES
('demo-log-1', 'demo-business-id', 'demo-client-nutrition', CURDATE(), 'breakfast', 'Έφαγα γιαούρτι με μέλι και καρύδια όπως πρότεινες', DATE_SUB(NOW(), INTERVAL 5 HOUR));
