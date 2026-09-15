USE bookup;

-- Κρατά τα demo sessions στο σημερινό/αυριανό (idempotent — ασφαλές για επανεκτέλεση)
UPDATE bookings SET
  starts_at = CONCAT(CURDATE(), ' 10:00:00'),
  ends_at = CONCAT(CURDATE(), ' 11:00:00'),
  status = 'confirmed'
WHERE id = 'demo-trainer-bk-today-am';

UPDATE bookings SET
  starts_at = CONCAT(CURDATE(), ' 18:00:00'),
  ends_at = CONCAT(CURDATE(), ' 19:00:00'),
  status = 'pending'
WHERE id = 'demo-trainer-bk-today-pm';

UPDATE bookings SET
  starts_at = CONCAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY), ' 09:00:00'),
  ends_at = CONCAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY), ' 10:00:00'),
  status = 'confirmed'
WHERE id = 'demo-trainer-bk-tomorrow';
