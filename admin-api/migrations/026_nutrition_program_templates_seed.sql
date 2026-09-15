USE bookup;

-- Ready-made nutrition program templates for quick import
DELETE FROM nutrition_program_template_items
WHERE template_id IN (
  'tpl-seed-weight-loss',
  'tpl-seed-muscle-gain',
  'tpl-seed-mediterranean',
  'tpl-seed-vegetarian'
);

DELETE FROM nutrition_program_templates
WHERE id IN (
  'tpl-seed-weight-loss',
  'tpl-seed-muscle-gain',
  'tpl-seed-mediterranean',
  'tpl-seed-vegetarian'
);

INSERT INTO nutrition_program_templates (id, business_id, name, notes) VALUES
('tpl-seed-weight-loss', 'demo-business-id', 'Απώλεια βάρους',
 'Χαμηλές θερμίδες, υψηλή πρωτεΐνη. 2L νερό/ημέρα. Επίλεξε 1 επιλογή ανά γεύμα.'),
('tpl-seed-muscle-gain', 'demo-business-id', 'Μυϊκή ανάπτυξη',
 'Υψηλή πρωτεΐνη, ελεγχόμενοι υδατάνθρακες. Ιδανικό μετά από προπόνηση.'),
('tpl-seed-mediterranean', 'demo-business-id', 'Μεσογειακή διατροφή',
 'Φρέσκα λαχανικά, ελαιόλαδο, ψάρι & πουλερικά. Ισορροπημένα γεύματα.'),
('tpl-seed-vegetarian', 'demo-business-id', 'Χορτοφαγικό',
 'Πλήρης πρωτεΐνη από φυτικές πηγές. Χωρίς κρέας & ψάρι.');

-- ── Απώλεια βάρους (Δευ–Παρ) ──
INSERT INTO nutrition_program_template_items
  (id, template_id, day_of_week, meal_type, title, description, notes, portions_json, sort_order)
VALUES
('seed-wl-d1-bf', 'tpl-seed-weight-loss', 1, 'breakfast', 'Γιαούρτι με μέλι & καρύδια', 'Γιαούρτι 2%', 'Χωρίς επιπλέον ζάχαρη',
 JSON_ARRAY(JSON_OBJECT('ingredient','Γιαούρτι 2%','amount',170,'unit','g'), JSON_OBJECT('ingredient','Μέλι','amount',1,'unit','κ.σ.'), JSON_OBJECT('ingredient','Καρύδια','amount',15,'unit','g')), 0),
('seed-wl-d1-ln', 'tpl-seed-weight-loss', 1, 'lunch', 'Κοτόπουλο με ρύζι', 'Ψητό στήθος', 'Χωρίς σάλτσες',
 JSON_ARRAY(JSON_OBJECT('ingredient','Στήθος κοτόπουλο','amount',180,'unit','g'), JSON_OBJECT('ingredient','Ρύζι basmati','amount',80,'unit','g'), JSON_OBJECT('ingredient','Σαλάτα','amount',1,'unit','μπολ')), 0),
('seed-wl-d1-dn', 'tpl-seed-weight-loss', 1, 'dinner', 'Σαλάτα με τόνο', 'Ελαφρύ βραδινό', 'Ελαιόλαδο 1 κ.σ.',
 JSON_ARRAY(JSON_OBJECT('ingredient','Τόνος σε νερό','amount',1,'unit','κονσέρβα'), JSON_OBJECT('ingredient','Μαρούλι & ντομάτα','amount',200,'unit','g')), 0),
('seed-wl-d1-sn', 'tpl-seed-weight-loss', 1, 'snack', 'Αμύγδαλα & δαμάσκηνα', 'Μετά προπόνηση', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Αμύγδαλα','amount',15,'unit','g'), JSON_OBJECT('ingredient','Δαμάσκηνα','amount',2,'unit','τεμ')), 0),
('seed-wl-d2-bf', 'tpl-seed-weight-loss', 2, 'breakfast', 'Βρώμη με φρούτα', 'Πουρές βρώμης', 'Χωρίς ζάχαρη',
 JSON_ARRAY(JSON_OBJECT('ingredient','Νιφάδες βρώμης','amount',50,'unit','g'), JSON_OBJECT('ingredient','Γάλα 1.5%','amount',200,'unit','ml'), JSON_OBJECT('ingredient','Μπανάνα','amount',0.5,'unit','τεμ')), 0),
('seed-wl-d2-ln', 'tpl-seed-weight-loss', 2, 'lunch', 'Ψάρι με πατάτες', 'Ψητό φιλέτο', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Φιλέτο ψαριού','amount',200,'unit','g'), JSON_OBJECT('ingredient','Πατάτα','amount',200,'unit','g')), 0),
('seed-wl-d2-dn', 'tpl-seed-weight-loss', 2, 'dinner', 'Ομελέτα λαχανικών', '2 αυγά', 'Με σαλάτα',
 JSON_ARRAY(JSON_OBJECT('ingredient','Αυγά','amount',2,'unit','τεμ'), JSON_OBJECT('ingredient','Μανιτάρια','amount',100,'unit','g')), 0),
('seed-wl-d3-bf', 'tpl-seed-weight-loss', 3, 'breakfast', 'Smoothie πρωτεΐνης', 'Με μπανάνα', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Πρωτεΐνη ορού','amount',1,'unit','scoops'), JSON_OBJECT('ingredient','Γάλα 1.5%','amount',250,'unit','ml')), 0),
('seed-wl-d3-ln', 'tpl-seed-weight-loss', 3, 'lunch', 'Μοσχάρι με μπρόκολο', 'Ψητό', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Μοσχαρίσιο','amount',150,'unit','g'), JSON_OBJECT('ingredient','Μπρόκολο','amount',200,'unit','g')), 0),
('seed-wl-d3-dn', 'tpl-seed-weight-loss', 3, 'dinner', 'Σούπα λαχανικών', 'Χωρίς κρέμα', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Λαχανικά μίξη','amount',300,'unit','g'), JSON_OBJECT('ingredient','Κοτόπουλο','amount',100,'unit','g')), 0),
('seed-wl-d3-sn', 'tpl-seed-weight-loss', 3, 'snack', 'Γιαούρτι 0%', 'Ελαφρό σνακ', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Γιαούρτι 0%','amount',150,'unit','g')), 0),
('seed-wl-d4-bf', 'tpl-seed-weight-loss', 4, 'breakfast', 'Αυγά & φρυγανιά ολικής', '2 αυγά βραστά', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Αυγά','amount',2,'unit','τεμ'), JSON_OBJECT('ingredient','Φρυγανιά ολικής','amount',1,'unit','φέτα')), 0),
('seed-wl-d4-ln', 'tpl-seed-weight-loss', 4, 'lunch', 'Κοτόπουλο wrap', 'Ολικής άλεσης', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Τορτίγια ολικής','amount',1,'unit','τεμ'), JSON_OBJECT('ingredient','Κοτόπουλο','amount',120,'unit','g')), 0),
('seed-wl-d4-dn', 'tpl-seed-weight-loss', 4, 'dinner', 'Τυρί cottage & σαλάτα', 'Ελαφρύ', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Cottage','amount',150,'unit','g'), JSON_OBJECT('ingredient','Σαλάτα','amount',200,'unit','g')), 0),
('seed-wl-d5-bf', 'tpl-seed-weight-loss', 5, 'breakfast', 'Μπάρα δημητριακών', 'Whole grain', 'Με γάλα',
 JSON_ARRAY(JSON_OBJECT('ingredient','Μπάρα δημητριακών','amount',1,'unit','τεμ'), JSON_OBJECT('ingredient','Γάλα 1.5%','amount',200,'unit','ml')), 0),
('seed-wl-d5-ln', 'tpl-seed-weight-loss', 5, 'lunch', 'Κοτόπουλο με κινόα', 'Ψητό', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Κοτόπουλο','amount',170,'unit','g'), JSON_OBJECT('ingredient','Κινόα','amount',70,'unit','g')), 0),
('seed-wl-d5-dn', 'tpl-seed-weight-loss', 5, 'dinner', 'Σολομός με σπανάκι', 'Ψητός', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Σολομός','amount',160,'unit','g'), JSON_OBJECT('ingredient','Σπανάκι','amount',150,'unit','g')), 0),
('seed-wl-d6-bf', 'tpl-seed-weight-loss', 6, 'breakfast', 'Τοστ ολικής με τυρί', '2 φέτες', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Ψωμί ολικής','amount',2,'unit','φέτες'), JSON_OBJECT('ingredient','Τυρί light','amount',60,'unit','g')), 0),
('seed-wl-d6-ln', 'tpl-seed-weight-loss', 6, 'lunch', 'Χταπόδι σχάρας', 'Με λαχανικά', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Χταπόδι','amount',180,'unit','g'), JSON_OBJECT('ingredient','Σαλάτα','amount',1,'unit','μπολ')), 0),
('seed-wl-d7-bf', 'tpl-seed-weight-loss', 7, 'breakfast', 'Omelette πρωτεΐνης', '3 αυγά', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Αυγά','amount',3,'unit','τεμ'), JSON_OBJECT('ingredient','Κολοκυθάκι','amount',80,'unit','g')), 0),
('seed-wl-d7-ln', 'tpl-seed-weight-loss', 7, 'lunch', 'Κοτόπουλο με ρύζι', 'Ελεύθερη μέρα', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Κοτόπουλο','amount',180,'unit','g'), JSON_OBJECT('ingredient','Ρύζι','amount',80,'unit','g')), 0);

-- ── Μυϊκή ανάπτυξη ──
INSERT INTO nutrition_program_template_items
  (id, template_id, day_of_week, meal_type, title, description, notes, portions_json, sort_order)
VALUES
('seed-mg-d1-bf', 'tpl-seed-muscle-gain', 1, 'breakfast', 'Πουρές βρώμης πρωτεΐνης', 'Με φιστίκι', 'Πριν προπόνηση',
 JSON_ARRAY(JSON_OBJECT('ingredient','Βρώμη','amount',70,'unit','g'), JSON_OBJECT('ingredient','Πρωτεΐνη','amount',1,'unit','scoops'), JSON_OBJECT('ingredient','Φυστικοβούτυρο','amount',20,'unit','g')), 0),
('seed-mg-d1-ln', 'tpl-seed-muscle-gain', 1, 'lunch', 'Μοσχάρι με πατάτα', 'Υψηλή πρωτεΐνη', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Μοσχαρίσιο','amount',200,'unit','g'), JSON_OBJECT('ingredient','Πατάτα','amount',250,'unit','g')), 0),
('seed-mg-d1-dn', 'tpl-seed-muscle-gain', 1, 'dinner', 'Κοτόπουλο με ρύζι', 'Μετά προπόνηση', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Κοτόπουλο','amount',220,'unit','g'), JSON_OBJECT('ingredient','Ρύζι','amount',100,'unit','g')), 0),
('seed-mg-d1-sn', 'tpl-seed-muscle-gain', 1, 'snack', 'Shake πρωτεΐνης', 'Με γάλα', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Πρωτεΐνη','amount',1,'unit','scoops'), JSON_OBJECT('ingredient','Γάλα','amount',300,'unit','ml')), 0),
('seed-mg-d2-bf', 'tpl-seed-muscle-gain', 2, 'breakfast', '4 αυγά ομελέτα', 'Με τυρί', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Αυγά','amount',4,'unit','τεμ'), JSON_OBJECT('ingredient','Τυρί','amount',50,'unit','g')), 0),
('seed-mg-d2-ln', 'tpl-seed-muscle-gain', 2, 'lunch', 'Τόνος με ζυμαρικά', 'Ολικής', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Τόνος','amount',2,'unit','κονσέρβες'), JSON_OBJECT('ingredient','Ζυμαρικά','amount',100,'unit','g')), 0),
('seed-mg-d2-dn', 'tpl-seed-muscle-gain', 2, 'dinner', 'Χοιρινό φιλέτο', 'Με λαχανικά', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Χοιρινό φιλέτο','amount',200,'unit','g'), JSON_OBJECT('ingredient','Μπρόκολο','amount',200,'unit','g')), 0),
('seed-mg-d3-bf', 'tpl-seed-muscle-gain', 3, 'breakfast', 'Γιαούρτι με granola', 'Υψηλή πρωτεΐνη', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Γιαούρτι 5%','amount',200,'unit','g'), JSON_OBJECT('ingredient','Granola','amount',40,'unit','g')), 0),
('seed-mg-d3-ln', 'tpl-seed-muscle-gain', 3, 'lunch', 'Σολομός με κινόα', '', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Σολομός','amount',200,'unit','g'), JSON_OBJECT('ingredient','Κινόα','amount',90,'unit','g')), 0),
('seed-mg-d3-dn', 'tpl-seed-muscle-gain', 3, 'dinner', 'Κοτόπουλο burrito bowl', '', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Κοτόπουλο','amount',200,'unit','g'), JSON_OBJECT('ingredient','Ρύζι','amount',90,'unit','g'), JSON_OBJECT('ingredient','Φασόλια','amount',80,'unit','g')), 0),
('seed-mg-d4-bf', 'tpl-seed-muscle-gain', 4, 'breakfast', 'Τοστ με αβοκάντο & αυγά', '', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Ψωμί ολικής','amount',2,'unit','φέτες'), JSON_OBJECT('ingredient','Αυγά','amount',2,'unit','τεμ'), JSON_OBJECT('ingredient','Αβοκάντο','amount',0.5,'unit','τεμ')), 0),
('seed-mg-d4-ln', 'tpl-seed-muscle-gain', 4, 'lunch', 'Μοσχάρι burger', 'Χωρίς ψωμί', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Μοσχαρίσιο','amount',200,'unit','g'), JSON_OBJECT('ingredient','Σαλάτα','amount',1,'unit','μπολ')), 0),
('seed-mg-d5-bf', 'tpl-seed-muscle-gain', 5, 'breakfast', 'Cottage με μέλι', '', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Cottage','amount',200,'unit','g'), JSON_OBJECT('ingredient','Μέλι','amount',1,'unit','κ.σ.')), 0),
('seed-mg-d5-ln', 'tpl-seed-muscle-gain', 5, 'lunch', 'Κοτόπουλο με πατάτα', '', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Κοτόπουλο','amount',220,'unit','g'), JSON_OBJECT('ingredient','Πατάτα','amount',250,'unit','g')), 0),
('seed-mg-d6-bf', 'tpl-seed-muscle-gain', 6, 'breakfast', 'Pancakes πρωτεΐνης', '', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Πρωτεΐνη','amount',1,'unit','scoops'), JSON_OBJECT('ingredient','Βρώμη','amount',50,'unit','g')), 0),
('seed-mg-d7-ln', 'tpl-seed-muscle-gain', 7, 'lunch', 'Ψάρι με ρύζι', 'Ελεύθερη μέρα', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Ψάρι','amount',220,'unit','g'), JSON_OBJECT('ingredient','Ρύζι','amount',100,'unit','g')), 0);

-- ── Μεσογειακή ──
INSERT INTO nutrition_program_template_items
  (id, template_id, day_of_week, meal_type, title, description, notes, portions_json, sort_order)
VALUES
('seed-md-d1-bf', 'tpl-seed-mediterranean', 1, 'breakfast', 'Γιαούρτι με μέλι & καρύδια', '', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Γιαούρτι','amount',170,'unit','g'), JSON_OBJECT('ingredient','Μέλι','amount',1,'unit','κ.σ.')), 0),
('seed-md-d1-ln', 'tpl-seed-mediterranean', 1, 'lunch', 'Χωριάτικη & ψητό ψάρι', 'Με ελαιόλαδο', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Ψάρι','amount',180,'unit','g'), JSON_OBJECT('ingredient','Ντομάτα & αγγούρι','amount',250,'unit','g'), JSON_OBJECT('ingredient','Ελαιόλαδο','amount',1,'unit','κ.σ.')), 0),
('seed-md-d1-dn', 'tpl-seed-mediterranean', 1, 'dinner', 'Φασολάδα', 'Χωρίς λιπαρά', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Φασόλια','amount',200,'unit','g'), JSON_OBJECT('ingredient','Ντομάτα','amount',1,'unit','τεμ')), 0),
('seed-md-d2-bf', 'tpl-seed-mediterranean', 2, 'breakfast', 'Τοστ με τυρί & ντομάτα', '', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Ψωμί ολικής','amount',2,'unit','φέτες'), JSON_OBJECT('ingredient','Τυρί φέτα','amount',50,'unit','g')), 0),
('seed-md-d2-ln', 'tpl-seed-mediterranean', 2, 'lunch', 'Κοτόπουλο λεμονάτο', 'Με πατάτες φούρνου', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Κοτόπουλο','amount',180,'unit','g'), JSON_OBJECT('ingredient','Πατάτα','amount',200,'unit','g')), 0),
('seed-md-d3-bf', 'tpl-seed-mediterranean', 3, 'breakfast', 'Βρώμη με φρούτα', '', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Βρώμη','amount',50,'unit','g'), JSON_OBJECT('ingredient','Μήλο','amount',1,'unit','τεμ')), 0),
('seed-md-d3-ln', 'tpl-seed-mediterranean', 3, 'lunch', 'Χταπόδι με φακές', '', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Χταπόδι','amount',160,'unit','g'), JSON_OBJECT('ingredient','Φακές','amount',150,'unit','g')), 0),
('seed-md-d4-ln', 'tpl-seed-mediterranean', 4, 'lunch', 'Γεμιστά λαχανικά', 'Με ρύζι', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Ντομάτα/πιπεριά','amount',2,'unit','τεμ'), JSON_OBJECT('ingredient','Ρύζι','amount',80,'unit','g')), 0),
('seed-md-d5-dn', 'tpl-seed-mediterranean', 5, 'dinner', 'Σαλάτα με ελιές & τόνο', '', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Τόνος','amount',1,'unit','κονσέρβα'), JSON_OBJECT('ingredient','Ελιές','amount',8,'unit','τεμ')), 0),
('seed-md-d6-ln', 'tpl-seed-mediterranean', 6, 'lunch', 'Ψητό λαβράκι', 'Με λαχανικά', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Λαβράκι','amount',200,'unit','g'), JSON_OBJECT('ingredient','Λαχανικά','amount',200,'unit','g')), 0),
('seed-md-d7-bf', 'tpl-seed-mediterranean', 7, 'breakfast', 'Τυρί & φρυγανιά', 'Ελαφρό πρωινό', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Τυρί','amount',80,'unit','g'), JSON_OBJECT('ingredient','Φρυγανιά','amount',2,'unit','φέτες')), 0);

-- ── Χορτοφαγικό ──
INSERT INTO nutrition_program_template_items
  (id, template_id, day_of_week, meal_type, title, description, notes, portions_json, sort_order)
VALUES
('seed-vg-d1-bf', 'tpl-seed-vegetarian', 1, 'breakfast', 'Smoothie μπανάνας', 'Με σπόρους chia', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Μπανάνα','amount',1,'unit','τεμ'), JSON_OBJECT('ingredient','Γάλα αμυγδάλου','amount',250,'unit','ml'), JSON_OBJECT('ingredient','Chia','amount',1,'unit','κ.σ.')), 0),
('seed-vg-d1-ln', 'tpl-seed-vegetarian', 1, 'lunch', 'Ρεβίθια στιφάδο', 'Με σαλάτα', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Ρεβίθια','amount',200,'unit','g'), JSON_OBJECT('ingredient','Σαλάτα','amount',1,'unit','μπολ')), 0),
('seed-vg-d1-dn', 'tpl-seed-vegetarian', 1, 'dinner', 'Ομελέτα με μανιτάρια', '3 αυγά', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Αυγά','amount',3,'unit','τεμ'), JSON_OBJECT('ingredient','Μανιτάρια','amount',150,'unit','g')), 0),
('seed-vg-d2-bf', 'tpl-seed-vegetarian', 2, 'breakfast', 'Γιαούρτι με granola', '', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Γιαούρτι','amount',180,'unit','g'), JSON_OBJECT('ingredient','Granola','amount',40,'unit','g')), 0),
('seed-vg-d2-ln', 'tpl-seed-vegetarian', 2, 'lunch', 'Φακές με ρύζι', '', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Φακές','amount',180,'unit','g'), JSON_OBJECT('ingredient','Ρύζι','amount',70,'unit','g')), 0),
('seed-vg-d3-bf', 'tpl-seed-vegetarian', 3, 'breakfast', 'Τοστ αβοκάντο', '', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Ψωμί ολικής','amount',2,'unit','φέτες'), JSON_OBJECT('ingredient','Αβοκάντο','amount',0.5,'unit','τεμ')), 0),
('seed-vg-d3-ln', 'tpl-seed-vegetarian', 3, 'lunch', 'Μπριάμ', 'Λαχανικά φούρνου', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Λαχανικά μίξη','amount',350,'unit','g'), JSON_OBJECT('ingredient','Ελαιόλαδο','amount',1,'unit','κ.σ.')), 0),
('seed-vg-d4-ln', 'tpl-seed-vegetarian', 4, 'lunch', 'Τofu stir-fry', 'Με λαχανικά', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Tofu','amount',180,'unit','g'), JSON_OBJECT('ingredient','Λαχανικά','amount',200,'unit','g')), 0),
('seed-vg-d5-dn', 'tpl-seed-vegetarian', 5, 'dinner', 'Σαλάτα με φακές', '', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Φακές','amount',150,'unit','g'), JSON_OBJECT('ingredient','Σαλάτα','amount',200,'unit','g')), 0),
('seed-vg-d6-bf', 'tpl-seed-vegetarian', 6, 'breakfast', 'Βρώμη με καρύδια', '', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Βρώμη','amount',55,'unit','g'), JSON_OBJECT('ingredient','Καρύδια','amount',20,'unit','g')), 0),
('seed-vg-d7-ln', 'tpl-seed-vegetarian', 7, 'lunch', 'Παστίτσιο λαχανικών', 'Ελαφρή έκδοση', NULL,
 JSON_ARRAY(JSON_OBJECT('ingredient','Ζυμαρικά ολικής','amount',90,'unit','g'), JSON_OBJECT('ingredient','Λαχανικά','amount',250,'unit','g')), 0);
