const { resolveTips } = require('./tips');
const { loadRoomForBooking } = require('./rooms');

async function loadScheduleForBooking(dbConn, booking) {
  const [[sch]] = await dbConn.query(`
    SELECT sss.label, sss.room_id, sss.room_name, sss.icon_key,
           sss.preparation_tips, sss.post_workout_tips,
           r.name AS room_display_name, r.photo_url AS room_photo_url, r.short_info AS room_short_info
    FROM service_slot_schedules sss
    LEFT JOIN rooms r ON r.id = sss.room_id
    WHERE sss.service_id = ? AND sss.business_id = ?
      AND sss.weekday = WEEKDAY(?)
      AND sss.start_time = TIME(?)
      AND sss.is_active = 1
      AND (sss.location_id IS NULL OR sss.location_id = ?)
      AND (sss.staff_id IS NULL OR sss.staff_id = ?)
    ORDER BY
      (sss.staff_id = ?) DESC,
      (sss.location_id = ?) DESC,
      sss.room_id IS NOT NULL DESC
    LIMIT 1
  `, [
    booking.service_id,
    booking.business_id,
    booking.starts_at,
    booking.starts_at,
    booking.location_id,
    booking.staff_id,
    booking.staff_id,
    booking.location_id,
  ]);
  return sch || null;
}

async function enrichBookingWithTips(dbConn, booking) {
  const sch = await loadScheduleForBooking(dbConn, booking);
  let serviceCategory = booking.service_category || null;
  if (!serviceCategory && booking.service_id) {
    const [[svc]] = await dbConn.query(
      'SELECT category FROM services WHERE id = ? LIMIT 1',
      [booking.service_id],
    );
    serviceCategory = svc?.category || null;
  }
  const scheduleForTips = sch ? {
    ...sch,
    room_name: sch.room_display_name || sch.room_name || null,
  } : null;
  const tips = resolveTips(scheduleForTips, sch?.icon_key, { serviceCategory });
  const roomFields = await loadRoomForBooking(dbConn, booking, sch);

  return {
    ...booking,
    schedule_label: tips.label,
    schedule_room: roomFields.room_name || tips.room_name,
    room_id: roomFields.room_id,
    room_photo_url: roomFields.room_photo_url,
    room_short_info: roomFields.room_short_info,
    icon_key: tips.icon_key,
    preparation_tips: tips.preparation_tips,
    post_workout_tips: tips.post_workout_tips,
  };
}

module.exports = { loadScheduleForBooking, enrichBookingWithTips };
