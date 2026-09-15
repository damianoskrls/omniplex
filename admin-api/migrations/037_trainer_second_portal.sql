USE bookup;

-- 2ος demo γυμναστής (Γιάννης / Yoga) με δικά του credentials
UPDATE staff
SET portal_email = 'yoga@demo.com'
WHERE id = 'demo-staff-2' AND business_id = 'demo-business-id';

INSERT INTO staff_passwords (staff_id, password_hash)
SELECT 'demo-staff-2', '$2a$10$3usqVZ.5BxFOD9IJXBh0VueFXdjo0s0Qyio4cRi03WsuuUwOxMJwy'
FROM DUAL
WHERE EXISTS (SELECT 1 FROM staff WHERE id = 'demo-staff-2')
ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash);

-- Demo κρατήσεις Yoga για τον Γιάννη (υπηρεσία demo-svc-yoga)
INSERT IGNORE INTO bookings (id, business_id, user_id, staff_id, service_id, starts_at, ends_at, status, source)
VALUES
  ('demo-trainer2-bk-today', 'demo-business-id', '93c66d43-5be0-424b-8baf-654a94ed839c', 'demo-staff-2', 'demo-svc-yoga',
   CONCAT(CURDATE(), ' 11:00:00'), CONCAT(CURDATE(), ' 11:45:00'), 'confirmed', 'app'),
  ('demo-trainer2-bk-tomorrow', 'demo-business-id', '93c66d43-5be0-424b-8baf-654a94ed839c', 'demo-staff-2', 'demo-svc-yoga',
   CONCAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY), ' 17:00:00'), CONCAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY), ' 17:45:00'), 'pending', 'app');

UPDATE bookings SET
  starts_at = CONCAT(CURDATE(), ' 11:00:00'),
  ends_at = CONCAT(CURDATE(), ' 11:45:00'),
  status = 'confirmed'
WHERE id = 'demo-trainer2-bk-today';

UPDATE bookings SET
  starts_at = CONCAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY), ' 17:00:00'),
  ends_at = CONCAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY), ' 17:45:00'),
  status = 'pending'
WHERE id = 'demo-trainer2-bk-tomorrow';
