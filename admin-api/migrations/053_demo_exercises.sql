-- Demo exercises & workout programs

SET @biz = 'demo-business-id';

-- ── Exercises ────────────────────────────────────────────────────────────────
INSERT IGNORE INTO exercises (id, business_id, name, description, muscle_group, animation_url, sort_order) VALUES
  ('ex-lat-pulldown',      @biz, 'Lat Pulldown',          'Τράβηγμα μπάρας από ψηλά προς στήθος σε μηχάνημα lat pulldown.', 'Πλάτη',         NULL, 1),
  ('ex-seated-row',        @biz, 'Seated Row',            'Κωπηλασία καθιστή σε μηχάνημα — τράβηγμα λαβής προς κοιλιά.', 'Πλάτη',         NULL, 2),
  ('ex-chest-press',       @biz, 'Chest Press',           'Ωθήσεις στήθους σε μηχάνημα — κλείσιμο χεριών μπροστά.', 'Στήθος',        NULL, 3),
  ('ex-assisted-pullup',   @biz, 'Assisted Pull-Up',      'Έλξεις σε μηχάνημα αντιστάθμισης βάρους.', 'Πλάτη, Δικέφαλοι', NULL, 4),
  ('ex-leg-press',         @biz, 'Leg Press',             'Ωθήσεις ποδιών σε μηχάνημα leg press.', 'Τετρακέφαλοι, Γλουτοί', NULL, 5),
  ('ex-leg-extension',     @biz, 'Leg Extension',         'Εκτάσεις ποδιών καθιστός σε μηχάνημα.', 'Τετρακέφαλοι', NULL, 6),
  ('ex-leg-curl',          @biz, 'Leg Curl',              'Κάμψεις ποδιών ξαπλωτός ή καθιστός σε μηχάνημα.', 'Δικέφαλος μηρός', NULL, 7),
  ('ex-calf-raise',        @biz, 'Calf Raise',            'Ανυψώσεις φτέρνας σε μηχάνημα ή ελεύθερα.', 'Γάμπες',        NULL, 8),
  ('ex-cable-curl',        @biz, 'Cable Curl',            'Κάμψεις δικεφάλων με τροχαλία χαμηλά.', 'Δικέφαλοι',     NULL, 9),
  ('ex-triceps-pushdown',  @biz, 'Triceps Pushdown',      'Εκτάσεις τρικεφάλων με τροχαλία ψηλά.', 'Τρικέφαλοι',    NULL, 10),
  ('ex-cable-woodchop',    @biz, 'Cable Woodchop',        'Διαγώνιες κινήσεις με τροχαλία — ενεργοποίηση κορμού.', 'Κοιλιακοί, Ώμοι', NULL, 11),
  ('ex-smith-squat',       @biz, 'Smith Squat',           'Κάθισμα σε μηχάνημα Smith — ελεγχόμενη κίνηση.', 'Τετρακέφαλοι, Γλουτοί', NULL, 12),
  ('ex-bench-db-row',      @biz, 'Bench Dumbbell Row',    'Κωπηλασία με αλτήρα σε παγκάκι — μονόπλευρα.', 'Πλάτη, Ρόμβοι', NULL, 13),
  ('ex-db-rdl',            @biz, 'DB Romanian Deadlift',  'Ρουμανικό deadlift με αλτήρες — εστίαση δικεφάλου μηρού.', 'Δικέφαλος μηρός, Γλουτοί', NULL, 14),
  ('ex-incline-db-press',  @biz, 'Incline DB Bench Press','Ωθήσεις με αλτήρες σε κεκλιμένο παγκάκι.', 'Άνω Στήθος',   NULL, 15),
  ('ex-bb-row',            @biz, 'Barbell Row',           'Κωπηλασία με μπάρα — κορμός παράλληλος στο έδαφος.', 'Πλάτη',         NULL, 16),
  ('ex-bulgarian-squat',   @biz, 'Bulgarian Split Squat', 'Μονόπλευρο κάθισμα με πίσω πόδι ανυψωμένο.', 'Τετρακέφαλοι, Γλουτοί', NULL, 17),
  ('ex-shoulder-press',    @biz, 'Shoulder Press',        'Ωθήσεις ώμων πάνω — με αλτήρες ή μπάρα.', 'Ώμοι',          NULL, 18),
  ('ex-plank',             @biz, 'Plank',                 'Στατική ισορροπία σε πρηνή θέση — ενεργοποίηση κορμού.', 'Κοιλιακοί',    NULL, 19),
  ('ex-hip-thrust',        @biz, 'Hip Thrust',            'Ώσεις ισχίων με μπάρα ή αλτήρα — μέγιστη ενεργοποίηση γλουτών.', 'Γλουτοί', NULL, 20);

-- ── Full Body Program ────────────────────────────────────────────────────────
INSERT IGNORE INTO workout_programs (id, business_id, name, description) VALUES
  ('prog-fullbody', @biz, 'Full Body — Αύξηση Μυϊκής Μάζας', 'Ολοκληρωμένο πρόγραμμα για όλες τις μυϊκές ομάδες. 4 σετ, ξεκούραση 60-90 δευτ.');

INSERT IGNORE INTO program_exercises (id, program_id, exercise_id, exercise_sets, exercise_reps, rest_secs, notes, sort_order) VALUES
  (UUID(), 'prog-fullbody', 'ex-db-rdl',         4, 12, 60,  'Κρατήστε πλάτη ίσια, αργή κατέβαση', 1),
  (UUID(), 'prog-fullbody', 'ex-incline-db-press',4, 12, 60,  'Γωνία παγκακιού 30-45°', 2),
  (UUID(), 'prog-fullbody', 'ex-bb-row',          4, 12, 60,  'Τράβηγμα προς ομφαλό', 3),
  (UUID(), 'prog-fullbody', 'ex-bulgarian-squat', 4, 12, 90,  '4x12 ανά πλευρά', 4),
  (UUID(), 'prog-fullbody', 'ex-lat-pulldown',    4, 12, 60,  'Πλατεία λαβή, αγκώνες κάτω', 5),
  (UUID(), 'prog-fullbody', 'ex-shoulder-press',  4, 12, 60,  '4x12 ανά πλευρά', 6);

-- ── Gym Machine Program ──────────────────────────────────────────────────────
INSERT IGNORE INTO workout_programs (id, business_id, name, description) VALUES
  ('prog-machines', @biz, 'Gym Machine Workout', 'Πρόγραμμα αποκλειστικά σε μηχανήματα — ιδανικό για αρχάριους.');

INSERT IGNORE INTO program_exercises (id, program_id, exercise_id, exercise_sets, exercise_reps, rest_secs, notes, sort_order) VALUES
  (UUID(), 'prog-machines', 'ex-leg-press',        3, 12, 60,  NULL, 1),
  (UUID(), 'prog-machines', 'ex-leg-extension',    3, 15, 45,  NULL, 2),
  (UUID(), 'prog-machines', 'ex-leg-curl',         3, 12, 45,  NULL, 3),
  (UUID(), 'prog-machines', 'ex-calf-raise',       4, 15, 45,  NULL, 4),
  (UUID(), 'prog-machines', 'ex-chest-press',      3, 12, 60,  NULL, 5),
  (UUID(), 'prog-machines', 'ex-lat-pulldown',     3, 12, 60,  NULL, 6),
  (UUID(), 'prog-machines', 'ex-seated-row',       3, 12, 60,  NULL, 7),
  (UUID(), 'prog-machines', 'ex-assisted-pullup',  3, 10, 90,  'Ρυθμίστε βάρος αντιστάθμισης', 8),
  (UUID(), 'prog-machines', 'ex-cable-curl',       3, 15, 45,  NULL, 9),
  (UUID(), 'prog-machines', 'ex-triceps-pushdown', 3, 15, 45,  NULL, 10),
  (UUID(), 'prog-machines', 'ex-cable-woodchop',   3, 12, 60,  '3x12 ανά πλευρά', 11),
  (UUID(), 'prog-machines', 'ex-smith-squat',      3, 12, 60,  NULL, 12);
