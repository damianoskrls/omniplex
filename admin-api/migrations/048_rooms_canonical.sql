-- Canonical rooms: room_id FK on schedules/bookings, photo + short_info on rooms

CREATE TABLE IF NOT EXISTS service_rooms (
  service_id CHAR(36) NOT NULL,
  room_id    CHAR(36) NOT NULL,
  PRIMARY KEY (service_id, room_id),
  KEY idx_service_rooms_room (room_id)
);

ALTER TABLE rooms
  ADD COLUMN photo_url  VARCHAR(500) NULL AFTER description,
  ADD COLUMN short_info VARCHAR(500) NULL AFTER photo_url;

UPDATE rooms SET short_info = description WHERE short_info IS NULL AND description IS NOT NULL;

ALTER TABLE service_slot_schedules
  ADD COLUMN room_id CHAR(36) NULL AFTER room_name,
  ADD INDEX idx_sss_room (room_id);

UPDATE service_slot_schedules sss
JOIN rooms r
  ON r.business_id = sss.business_id
 AND TRIM(LOWER(r.name)) = TRIM(LOWER(sss.room_name))
 AND (
   sss.location_id IS NULL
   OR r.location_id IS NULL
   OR r.location_id = sss.location_id
 )
SET sss.room_id = r.id
WHERE sss.room_name IS NOT NULL
  AND sss.room_name != ''
  AND sss.room_id IS NULL;

ALTER TABLE bookings
  ADD COLUMN room_id CHAR(36) NULL AFTER location_id,
  ADD INDEX idx_bookings_room (room_id);

UPDATE bookings b
JOIN service_slot_schedules sss
  ON sss.service_id = b.service_id
 AND sss.business_id = b.business_id
 AND sss.weekday = WEEKDAY(b.starts_at)
 AND sss.start_time = TIME(b.starts_at)
 AND sss.is_active = 1
 AND (b.location_id IS NULL OR sss.location_id IS NULL OR sss.location_id = b.location_id)
 AND (b.staff_id IS NULL OR sss.staff_id IS NULL OR sss.staff_id = b.staff_id)
SET b.room_id = sss.room_id
WHERE b.room_id IS NULL
  AND sss.room_id IS NOT NULL;
