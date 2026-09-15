export function slotKey(booking) {
  return [
    booking.starts_at,
    booking.ends_at,
    booking.service_id,
    booking.staff_id || '',
    booking.location_id || '',
    booking.room_name || '',
    booking.schedule_label || '',
  ].join('|');
}

export function groupBookingsBySlot(bookings) {
  const map = new Map();
  for (const b of bookings) {
    const key = slotKey(b);
    if (!map.has(key)) {
      map.set(key, {
        starts_at: b.starts_at,
        ends_at: b.ends_at,
        service_id: b.service_id,
        service_name: b.service_name,
        staff_id: b.staff_id,
        staff_name: b.staff_name,
        location_id: b.location_id,
        location_name: b.location_name,
        room_name: b.room_name,
        schedule_label: b.schedule_label,
        color_hex: b.color_hex,
        bookings: [],
      });
    }
    map.get(key).bookings.push(b);
  }

  return [...map.values()]
    .sort((a, b) => String(a.starts_at).localeCompare(String(b.starts_at)))
    .map((slot) => ({
      ...slot,
      bookings: slot.bookings.sort((a, b) =>
        (a.user_name || '').localeCompare(b.user_name || '', 'el')
      ),
    }));
}
