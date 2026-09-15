-- Trial lessons: booked session that does not consume package credits
ALTER TABLE bookings
  ADD COLUMN is_trial TINYINT(1) NOT NULL DEFAULT 0 AFTER source;
