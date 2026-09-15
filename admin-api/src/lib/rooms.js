async function getRoomById(conn, roomId, bizId) {
  if (!roomId) return null;
  const [[row]] = await conn.query(
    `SELECT id, business_id, location_id, name, description, short_info, photo_url, is_active
     FROM rooms WHERE id = ? AND business_id = ? AND is_active = 1`,
    [roomId, bizId],
  );
  return row || null;
}

async function syncRoomFromId(conn, roomId, bizId) {
  if (!roomId) return { room_id: null, room_name: null };
  const room = await getRoomById(conn, roomId, bizId);
  if (!room) {
    throw Object.assign(new Error('Η αίθουσα δεν βρέθηκε'), { status: 400 });
  }
  return { room_id: room.id, room_name: room.name };
}

function mapRoomFields(room) {
  if (!room) {
    return {
      room_id: null,
      room_name: null,
      room_photo_url: null,
      room_short_info: null,
    };
  }
  return {
    room_id: room.id,
    room_name: room.name,
    room_photo_url: room.photo_url || null,
    room_short_info: room.short_info || room.description || null,
  };
}

async function loadRoomForBooking(conn, booking, schedule = null) {
  const roomId = booking.room_id || schedule?.room_id || null;
  if (!roomId) {
    const fallbackName = schedule?.room_name || null;
    return fallbackName
      ? { room_id: null, room_name: fallbackName, room_photo_url: null, room_short_info: null }
      : mapRoomFields(null);
  }
  const room = await getRoomById(conn, roomId, booking.business_id);
  if (room) return mapRoomFields(room);
  return {
    room_id: roomId,
    room_name: schedule?.room_name || null,
    room_photo_url: null,
    room_short_info: null,
  };
}

async function resolveScheduleRoomId(conn, {
  bizId, serviceId, startsAt, locationId, staffId,
}) {
  const [[row]] = await conn.query(
    `SELECT room_id
     FROM service_slot_schedules
     WHERE service_id = ? AND business_id = ?
       AND weekday = WEEKDAY(?)
       AND start_time = TIME(?)
       AND is_active = 1
       AND (location_id IS NULL OR location_id = ?)
       AND (staff_id IS NULL OR staff_id = ?)
     ORDER BY
       (staff_id = ?) DESC,
       (location_id = ?) DESC,
       room_id IS NOT NULL DESC
     LIMIT 1`,
    [serviceId, bizId, startsAt, startsAt, locationId, staffId, staffId, locationId],
  );
  return row?.room_id || null;
}

module.exports = {
  getRoomById,
  syncRoomFromId,
  mapRoomFields,
  loadRoomForBooking,
  resolveScheduleRoomId,
};
