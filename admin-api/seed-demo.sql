USE bookup;

-- Demo services
INSERT IGNORE INTO services (id, business_id, name, description, duration_mins, price_cents, category, is_active)
VALUES
  ('demo-svc-pt',    'demo-business-id', 'Personal Training', 'Ατομική προπόνηση 1-1', 60, 4000, 'Training', 1),
  ('demo-svc-yoga',  'demo-business-id', 'Yoga Flow',         'Ομαδικό μάθημα yoga',  45, 1500, 'Classes',  1),
  ('demo-svc-pilates','demo-business-id', 'Pilates',          'Ενδυνάμωση & ευλυγισία', 50, 1800, 'Classes', 1),
  ('demo-svc-fitness','demo-business-id', 'Group Fitness',    'Ομαδικά μαθήματα Cross Training, Strength & TRX', 60, 2000, 'Classes', 1);

UPDATE services SET slot_label_mode = 'room' WHERE id = 'demo-svc-pilates';
UPDATE services SET slot_label_mode = 'class' WHERE id = 'demo-svc-fitness';

-- Demo staff
INSERT IGNORE INTO staff (id, business_id, full_name, role, bio, color_hex, is_active)
VALUES
  ('demo-staff-1', 'demo-business-id', 'Μαρία Παπαδοπούλου', 'Personal Trainer', 'Εξειδίκευση σε functional training', '#E91E63', 1),
  ('demo-staff-2', 'demo-business-id', 'Γιάννης Νικολάου',   'Yoga Instructor',  'Vinyasa & Hatha yoga',              '#2196F3', 1);

-- Staff can perform which services
INSERT IGNORE INTO staff_services (staff_id, service_id) VALUES
  ('demo-staff-1', 'demo-svc-pt'),
  ('demo-staff-1', 'demo-svc-pilates'),
  ('demo-staff-2', 'demo-svc-yoga'),
  ('demo-staff-2', 'demo-svc-pilates'),
  ('demo-staff-1', 'demo-svc-fitness'),
  ('demo-staff-2', 'demo-svc-fitness');

-- Availability Mon–Sat 09:00–18:00 (weekday: 0=Mon … 6=Sun per MySQL WEEKDAY)
INSERT IGNORE INTO staff_availability (id, staff_id, weekday, start_time, end_time, is_active) VALUES
  ('demo-avail-1', 'demo-staff-1', 0, '09:00:00', '18:00:00', 1),
  ('demo-avail-2', 'demo-staff-1', 1, '09:00:00', '18:00:00', 1),
  ('demo-avail-3', 'demo-staff-1', 2, '09:00:00', '18:00:00', 1),
  ('demo-avail-4', 'demo-staff-1', 3, '09:00:00', '18:00:00', 1),
  ('demo-avail-5', 'demo-staff-1', 4, '09:00:00', '18:00:00', 1),
  ('demo-avail-6', 'demo-staff-1', 5, '10:00:00', '14:00:00', 1),
  ('demo-avail-7', 'demo-staff-2', 0, '09:00:00', '18:00:00', 1),
  ('demo-avail-8', 'demo-staff-2', 1, '09:00:00', '18:00:00', 1),
  ('demo-avail-9', 'demo-staff-2', 2, '09:00:00', '18:00:00', 1),
  ('demo-avail-10','demo-staff-2', 3, '09:00:00', '18:00:00', 1),
  ('demo-avail-11','demo-staff-2', 4, '09:00:00', '18:00:00', 1),
  ('demo-avail-12','demo-staff-2', 5, '10:00:00', '14:00:00', 1);

-- Pricing plans (monthly packages)
INSERT IGNORE INTO business_plans (id, business_id, name, sessions, price_cents, billing_period, sort_order, is_active)
VALUES
  ('demo-plan-pt-8',  'demo-business-id', 'PT 8 συνεδρίες/μήνα',  8,    8000,  'monthly', 1, 1),
  ('demo-plan-yoga-unl','demo-business-id', 'Yoga Unlimited',       NULL, 4500,  'monthly', 2, 1),
  ('demo-plan-pilates', 'demo-business-id', 'Pilates 6/μήνα',       6,    5500,  'monthly', 3, 1),
  ('demo-plan-fitness', 'demo-business-id', 'Fitness Unlimited',    NULL, 5000,  'monthly', 4, 1);

-- Link plans to services
INSERT IGNORE INTO service_plan_assignments (service_id, plan_id) VALUES
  ('demo-svc-pt',     'demo-plan-pt-8'),
  ('demo-svc-yoga',   'demo-plan-yoga-unl'),
  ('demo-svc-pilates','demo-plan-pilates'),
  ('demo-svc-fitness','demo-plan-fitness');

-- Richer staff bios
UPDATE staff SET bio = 'Certified personal trainer με 8+ χρόνια εμπειρίας. Εξειδίκευση σε functional training, HIIT και αποκατάσταση τραυματισμών.'
WHERE id = 'demo-staff-1';
UPDATE staff SET bio = 'E-RYT 200 yoga instructor. Διδάσκει Vinyasa Flow και Hatha yoga για όλα τα επίπεδα.'
WHERE id = 'demo-staff-2';

-- Pilates: ώρες με αίθουσα (Δευ–Παρ)
INSERT IGNORE INTO service_slot_schedules (id, service_id, business_id, weekday, start_time, label, room_name, icon_key) VALUES
  ('demo-sch-p1', 'demo-svc-pilates', 'demo-business-id', 0, '09:00:00', 'Pilates Reformer', 'Αίθουσα A', 'pilates'),
  ('demo-sch-p2', 'demo-svc-pilates', 'demo-business-id', 0, '10:00:00', 'Pilates Mat',      'Αίθουσα B', 'pilates'),
  ('demo-sch-p3', 'demo-svc-pilates', 'demo-business-id', 0, '11:00:00', 'Pilates Reformer', 'Αίθουσα A', 'pilates'),
  ('demo-sch-p4', 'demo-svc-pilates', 'demo-business-id', 1, '09:00:00', 'Pilates Mat',      'Αίθουσα B', 'pilates'),
  ('demo-sch-p5', 'demo-svc-pilates', 'demo-business-id', 1, '10:30:00', 'Pilates Reformer', 'Αίθουσα A', 'pilates');

-- Group Fitness: ώρες με τίτλο μαθήματος (Δευ–Παρ)
INSERT IGNORE INTO service_slot_schedules (id, service_id, business_id, weekday, start_time, label, subtitle, icon_key) VALUES
  ('demo-sch-f1', 'demo-svc-fitness', 'demo-business-id', 0, '09:00:00', 'Cross Training',  'HIIT + functional', 'cross_training'),
  ('demo-sch-f2', 'demo-svc-fitness', 'demo-business-id', 0, '10:00:00', 'Strength & TRX',  'Μυϊκή ενδυνάμωση', 'strength'),
  ('demo-sch-f3', 'demo-svc-fitness', 'demo-business-id', 0, '11:00:00', 'Cycling RPM',     'Cardio interval',   'cycling'),
  ('demo-sch-f4', 'demo-svc-fitness', 'demo-business-id', 1, '09:00:00', 'Cross Training',  'HIIT + functional', 'cross_training'),
  ('demo-sch-f5', 'demo-svc-fitness', 'demo-business-id', 1, '10:00:00', 'Strength & TRX',  'Μυϊκή ενδυνάμωση', 'strength');
