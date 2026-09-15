USE bookup;

-- Demo sessions for trainer portal (Μαρία / demo-staff-1, πελάτης dam@test.com)
INSERT IGNORE INTO bookings (id, business_id, user_id, staff_id, service_id, starts_at, ends_at, status, source)
VALUES
  ('demo-trainer-bk-today-am', 'demo-business-id', '93c66d43-5be0-424b-8baf-654a94ed839c', 'demo-staff-1', 'demo-svc-pt',
   CONCAT(CURDATE(), ' 10:00:00'), CONCAT(CURDATE(), ' 11:00:00'), 'confirmed', 'admin'),
  ('demo-trainer-bk-today-pm', 'demo-business-id', '93c66d43-5be0-424b-8baf-654a94ed839c', 'demo-staff-1', 'demo-svc-pt',
   CONCAT(CURDATE(), ' 18:00:00'), CONCAT(CURDATE(), ' 19:00:00'), 'pending', 'app'),
  ('demo-trainer-bk-tomorrow', 'demo-business-id', '93c66d43-5be0-424b-8baf-654a94ed839c', 'demo-staff-1', 'demo-svc-pt',
   CONCAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY), ' 09:00:00'), CONCAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY), ' 10:00:00'), 'confirmed', 'app');
