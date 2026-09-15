const { resolveTips } = require('./tips');

function formatStaffPoolLabel(names) {
  if (!names?.length) return '';
  if (names.length === 1) return names[0];
  if (names.length === 2) return `${names[0]} ή ${names[1]}`;
  return `${names.slice(0, -1).join(', ')} ή ${names[names.length - 1]}`;
}

function pickRandomStaffForTime(slotMap, time) {
  const pool = slotMap[time];
  if (!pool?.length) return null;
  return pool[Math.floor(Math.random() * pool.length)];
}

function pickStaffForBooking(slotMap, time, existingStaffId) {
  const pool = slotMap[time];
  if (!pool?.length) return null;
  if (existingStaffId) {
    const existing = pool.find(s => s.id === existingStaffId);
    if (existing) return existing;
  }
  return pickRandomStaffForTime(slotMap, time);
}

function toHHMM(timeVal) {
  if (!timeVal) return null;
  return String(timeVal).slice(0, 5);
}

function startsAtKey(startsAt) {
  const d = new Date(startsAt);
  const h = String(d.getHours()).padStart(2, '0');
  const m = String(d.getMinutes()).padStart(2, '0');
  return `${h}:${m}`;
}

function parseOpeningHours(raw) {
  if (!raw) return null;
  try {
    return typeof raw === 'string' ? JSON.parse(raw) : raw;
  } catch {
    return null;
  }
}

function isWeekdayClosed(openingHours, wd) {
  if (!openingHours) return false;
  const day = openingHours[wd] ?? openingHours[String(wd)];
  if (!day) return false;
  return !!day.closed;
}

async function getOpeningHours(dbConn, bizId) {
  const [[cfg]] = await dbConn.query(
    'SELECT opening_hours FROM business_configs WHERE business_id = ?',
    [bizId]
  );
  return parseOpeningHours(cfg?.opening_hours);
}

async function assertGymOpenOnDate(dbConn, bizId, date) {
  const [[{ wd }]] = await dbConn.query('SELECT WEEKDAY(?) AS wd', [date]);
  const openingHours = await getOpeningHours(dbConn, bizId);
  if (isWeekdayClosed(openingHours, wd)) {
    throw new Error('Το γυμναστήριο είναι κλειστό αυτή την ημέρα.');
  }

  const [[closure]] = await dbConn.query(
    `SELECT id, time_from, time_to FROM business_closures
     WHERE business_id=? AND date_from <= ? AND date_to >= ? LIMIT 1`,
    [bizId, date, date]
  );
  if (closure && !closure.time_from) {
    throw new Error('Το γυμναστήριο είναι κλειστό αυτή την ημέρα.');
  }
}

function generateSlots(startTime, endTime, durationMins) {
  const slots = [];
  const [sh, sm] = startTime.split(':').map(Number);
  const [eh, em] = endTime.split(':').map(Number);

  let current = sh * 60 + sm;
  const end   = eh * 60 + em;

  while (current + durationMins <= end) {
    const h = String(Math.floor(current / 60)).padStart(2, '0');
    const m = String(current % 60).padStart(2, '0');
    slots.push(`${h}:${m}`);
    current += 30;
  }
  return slots;
}

function staffConflict(booking, staffId, serviceId, slotStart, slotEnd, excludeBookingId) {
  if (excludeBookingId && booking.id === excludeBookingId) return false;
  if (booking.staff_id !== staffId) return false;

  const bStart = new Date(booking.starts_at);
  const bEnd = new Date(booking.ends_at);
  const sameClass = String(booking.service_id) === String(serviceId)
    && bStart.getTime() === slotStart.getTime()
    && bEnd.getTime() === slotEnd.getTime();
  if (sameClass) return false;

  return bStart < slotEnd && bEnd > slotStart;
}

const { getLocationOpeningHours } = require('./locations');

/** @returns {{ service, slotMap, staffPoolNames, duration, scheduleByTime, bookedByTime, waitlistByTime, locationId } | null} */
async function computeAvailableSlots(dbConn, bizId, serviceId, date, excludeBookingId, locationId = null, restrictStaffId = null) {
  const [[service]] = await dbConn.query(
    'SELECT id, duration_mins, hide_staff_selection, image_url, slot_label_mode FROM services WHERE id = ? AND business_id = ?',
    [serviceId, bizId]
  );
  if (!service) return null;

  const duration = service.duration_mins;
  const [[{ wd }]] = await dbConn.query('SELECT WEEKDAY(?) AS wd', [date]);

  const openingHours = locationId
    ? await getLocationOpeningHours(dbConn, bizId, locationId)
    : await getOpeningHours(dbConn, bizId);
  if (isWeekdayClosed(openingHours, wd)) {
    return {
      service, slotMap: {}, staffPoolNames: [], duration,
      scheduleByTime: new Map(), bookedByTime: new Map(), waitlistByTime: new Map(),
      closedReason: 'gym_closed', locationId,
    };
  }

  // Prefer service-specific availability; fall back to general (service_id IS NULL)
  const staffLocFilter = locationId
    ? `AND (
        NOT EXISTS (SELECT 1 FROM staff_locations sl WHERE sl.staff_id = s.id)
        OR EXISTS (SELECT 1 FROM staff_locations sl WHERE sl.staff_id = s.id AND sl.location_id = ?)
      )`
    : '';
  const staffLocParams = locationId ? [locationId] : [];

  const availLocFilter = locationId
    ? 'AND (sa.location_id IS NULL OR sa.location_id = ?)'
    : '';
  const availLocParams = locationId ? [locationId] : [];

  const [availableStaff] = await dbConn.query(`
    SELECT s.id, s.full_name, s.role, s.color_hex, s.avatar_url, s.bio,
           sa.start_time, sa.end_time
    FROM staff s
    JOIN staff_services ss ON ss.staff_id = s.id AND ss.service_id = ?
    JOIN staff_availability sa ON sa.staff_id = s.id
      AND sa.weekday = ?
      AND sa.is_active = 1
      ${availLocFilter}
      AND (
        sa.service_id = ?
        OR (
          sa.service_id IS NULL
          AND NOT EXISTS (
            SELECT 1 FROM staff_availability sa2
            WHERE sa2.staff_id = s.id
              AND sa2.service_id = ?
              AND sa2.weekday = ?
              AND sa2.is_active = 1
          )
        )
      )
    WHERE s.business_id = ? AND s.is_active = 1
      AND COALESCE(s.is_general_pool, 0) = 0
      AND COALESCE(s.is_nutritionist, 0) = 0
      ${staffLocFilter}
  `, [serviceId, wd, ...availLocParams, serviceId, serviceId, wd, bizId, ...staffLocParams]);

  const scheduleLocFilter = locationId ? 'AND sss.location_id = ?' : '';
  const scheduleLocParams = locationId ? [locationId] : [];

  const [schedules] = await dbConn.query(`
    SELECT sss.start_time, sss.label, sss.room_id, sss.room_name, sss.subtitle, sss.image_url,
           r.name AS room_display_name, r.photo_url AS room_photo_url, r.short_info AS room_short_info,
           sss.icon_key, sss.max_capacity, sss.preparation_tips, sss.post_workout_tips,
           sss.staff_id,
           st.full_name AS staff_name, st.color_hex AS staff_color, st.avatar_url AS staff_avatar
    FROM service_slot_schedules sss
    LEFT JOIN staff st ON st.id = sss.staff_id
    LEFT JOIN rooms r ON r.id = sss.room_id
    WHERE sss.service_id = ? AND sss.business_id = ? AND sss.weekday = ? AND sss.is_active = 1
      ${scheduleLocFilter}
      ${restrictStaffId ? 'AND sss.staff_id = ?' : ''}
    ORDER BY sss.start_time
  `, [serviceId, bizId, wd, ...scheduleLocParams, ...(restrictStaffId ? [restrictStaffId] : [])]);

  // Build scheduleByTime — when multiple entries share the same time (multi-room/instructor),
  // keep the first one for metadata but collect all rooms.
  const scheduleByTime = new Map();
  for (const sch of schedules) {
    const key = toHHMM(sch.start_time);
    if (!scheduleByTime.has(key)) scheduleByTime.set(key, sch);
  }

  // Build a map of time → [assignedStaffId] for slot-level staff assignment
  const slotStaffByTime = new Map();
  for (const sch of schedules) {
    if (!sch.staff_id) continue;
    const key = toHHMM(sch.start_time);
    if (!slotStaffByTime.has(key)) slotStaffByTime.set(key, []);
    slotStaffByTime.get(key).push({ id: sch.staff_id, full_name: sch.staff_name, color_hex: sch.staff_color, avatar_url: sch.staff_avatar });
  }

  // Check if business is closed on this date (closures are business-wide until per-location closures exist)
  const [[closure]] = await dbConn.query(
    `SELECT id, time_from, time_to FROM business_closures
     WHERE business_id=? AND date_from <= ? AND date_to >= ?
     LIMIT 1`,
    [bizId, date, date]
  );
  if (closure && !closure.time_from) {
    return {
      service, slotMap: {}, staffPoolNames: [], duration, scheduleByTime,
      bookedByTime, waitlistByTime, closedReason: 'closure', locationId,
    };
  }

  // Remove staff who are on leave for this date
  const [onLeave] = await dbConn.query(
    `SELECT DISTINCT staff_id FROM staff_leaves
     WHERE business_id=? AND date_from <= ? AND date_to >= ?`,
    [bizId, date, date]
  );
  const onLeaveIds = new Set(onLeave.map(r => r.staff_id));
  const availableStaffFiltered = availableStaff.filter(s => !onLeaveIds.has(s.id));

  const bookingLocFilter = locationId ? 'AND location_id = ?' : '';
  const bookingStaffFilter = restrictStaffId ? 'AND staff_id = ?' : '';
  const bookingLocParams = locationId ? [bizId, date, locationId] : [bizId, date];
  const bookingParams = [
    ...bookingLocParams,
    ...(restrictStaffId ? [restrictStaffId] : []),
  ];

  const [existingBookings] = await dbConn.query(`
    SELECT id, staff_id, service_id, starts_at, ends_at
    FROM bookings
    WHERE business_id = ?
      AND DATE(starts_at) = ?
      AND status NOT IN ('cancelled', 'no_show')
      ${bookingLocFilter}
      ${bookingStaffFilter}
  `, bookingParams);

  const bookedByTime = new Map();
  for (const b of existingBookings) {
    if (String(b.service_id) !== String(serviceId)) continue;
    if (excludeBookingId && b.id === excludeBookingId) continue;
    const key = startsAtKey(b.starts_at);
    bookedByTime.set(key, (bookedByTime.get(key) || 0) + 1);
  }

  const [waitlistRows] = await dbConn.query(`
    SELECT starts_at, COUNT(*) AS cnt
    FROM waitlist_entries
    WHERE business_id = ? AND service_id = ?
      AND DATE(starts_at) = ?
      AND status IN ('waiting', 'offered')
    GROUP BY starts_at
  `, [bizId, serviceId, date]);

  const waitlistByTime = new Map();
  for (const w of waitlistRows) {
    waitlistByTime.set(startsAtKey(w.starts_at), Number(w.cnt));
  }

  // If all schedules have explicit staff assignments, use slot-level staff directly
  const hasSlotLevelStaff = schedules.length > 0 && schedules.every(s => s.staff_id);

  // Apply leave filter also to slot-level staff
  const filteredSlotStaffByTime = new Map();
  for (const [time, staffList] of slotStaffByTime) {
    filteredSlotStaffByTime.set(time, staffList.filter(s => !onLeaveIds.has(s.id)));
  }

  if (hasSlotLevelStaff) {
    // Build slotMap purely from slot schedules (no staff_availability needed)
    const slotMap = {};
    for (const [time, staffList] of filteredSlotStaffByTime) {
      const slotStart = new Date(`${date}T${time}:00`);
      const slotEnd   = new Date(slotStart.getTime() + duration * 60000);
      const availableForSlot = staffList.filter(st => {
        return !existingBookings.some(b =>
          staffConflict(b, st.id, serviceId, slotStart, slotEnd, excludeBookingId)
        );
      });
      slotMap[time] = availableForSlot;
    }
    // Ensure all schedule times appear even if staff is busy
    for (const [time] of scheduleByTime) {
      if (!slotMap[time]) slotMap[time] = [];
    }
    const staffPoolNames = [...new Set(schedules.filter(s => s.staff_name).map(s => s.staff_name))];
    return {
      service, slotMap, staffPoolNames, duration, scheduleByTime,
      bookedByTime, waitlistByTime, locationId,
    };
  }

  if (!availableStaffFiltered.length) {
    return {
      service, slotMap: {}, staffPoolNames: [], duration, scheduleByTime,
      bookedByTime, waitlistByTime, locationId,
    };
  }

  const slotMap = {};
  for (const staff of availableStaffFiltered) {
    const slots = generateSlots(staff.start_time, staff.end_time, duration);
    for (const slot of slots) {
      const slotStart = new Date(`${date}T${slot}:00`);
      const slotEnd   = new Date(slotStart.getTime() + duration * 60000);
      const isBusy = existingBookings.some(b =>
        staffConflict(b, staff.id, serviceId, slotStart, slotEnd, excludeBookingId)
      );
      if (!isBusy) {
        if (!slotMap[slot]) slotMap[slot] = [];
        if (!slotMap[slot].some(s => s.id === staff.id)) {
          slotMap[slot].push({
            id: staff.id, full_name: staff.full_name, role: staff.role,
            color_hex: staff.color_hex, avatar_url: staff.avatar_url, bio: staff.bio,
          });
        }
      }
    }
  }

  let finalSlotMap = slotMap;
  if (scheduleByTime.size) {
    finalSlotMap = {};
    for (const [time, staffList] of Object.entries(slotMap)) {
      if (scheduleByTime.has(time)) finalSlotMap[time] = staffList;
    }
    for (const [time] of scheduleByTime) {
      if (!finalSlotMap[time]) finalSlotMap[time] = [];
    }
  }

  const staffPoolNames = [...new Set(availableStaffFiltered.map(s => s.full_name))];
  return {
    service, slotMap: finalSlotMap, staffPoolNames, duration, scheduleByTime,
    bookedByTime, waitlistByTime, locationId,
  };
}

function effectiveCapacity(maxCapacity, staffCount) {
  if (maxCapacity == null || maxCapacity <= 0) return staffCount;
  return maxCapacity;
}

const BOOKING_MIN_LEAD_MINUTES = 5;

function localDateString(d = new Date()) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

/** True if the slot can still be booked (today: must be after now + lead buffer). */
function isSlotBookableForDate(dateStr, timeStr, minLeadMinutes = BOOKING_MIN_LEAD_MINUTES) {
  if (!dateStr || !timeStr) return false;
  if (String(dateStr).slice(0, 10) !== localDateString()) return true;

  const [h, m] = String(timeStr).slice(0, 5).split(':').map(Number);
  const slotStart = new Date();
  slotStart.setHours(h, m, 0, 0);

  const cutoff = new Date();
  cutoff.setMinutes(cutoff.getMinutes() + minLeadMinutes);

  return slotStart > cutoff;
}

function buildSlotsPayload(computed, options = {}) {
  const { featureWaitlist = true, date = null, minLeadMinutes = BOOKING_MIN_LEAD_MINUTES } = options;
  const {
    service, slotMap, staffPoolNames, duration, scheduleByTime,
    bookedByTime, waitlistByTime,
  } = computed;
  const hideStaff = !!service.hide_staff_selection;
  const staffPoolLabel = formatStaffPoolLabel(staffPoolNames);

  const allTimes = new Set([
    ...Object.keys(slotMap),
    ...(scheduleByTime ? [...scheduleByTime.keys()] : []),
  ]);

  const slots = [...allTimes]
    .sort((a, b) => a.localeCompare(b))
    .map((time) => {
      const staff = slotMap[time] || [];
      const sch = scheduleByTime?.get(time);
      const schForTips = sch ? {
        ...sch,
        room_name: sch.room_display_name || sch.room_name || null,
      } : null;
      const tipInfo = resolveTips(schForTips, sch?.icon_key);
      const bookedCount = bookedByTime?.get(time) || 0;
      const waitlistCount = waitlistByTime?.get(time) || 0;
      const maxCap = sch?.max_capacity ?? null;
      const capacity = effectiveCapacity(maxCap, staff.length || 1);
      const remaining = Math.max(0, capacity - bookedCount);
      const isFull = remaining <= 0;
      const hasStaff = staff.length > 0;

      return {
        time,
        available_count: hasStaff && !isFull ? Math.min(remaining, staff.length) : 0,
        available_staff: isFull ? [] : staff,
        booked_count: bookedCount,
        capacity,
        remaining_spots: remaining,
        is_full: isFull,
        waitlist_available: isFull && featureWaitlist && hasStaff,
        waitlist_count: waitlistCount,
        label: sch?.label || null,
        room_id: sch?.room_id || null,
        room_name: sch?.room_display_name || sch?.room_name || null,
        room_photo_url: sch?.room_photo_url || null,
        room_short_info: sch?.room_short_info || null,
        subtitle: sch?.subtitle || null,
        image_url: sch?.image_url || null,
        icon_key: sch?.icon_key || null,
        max_capacity: maxCap,
        preparation_tips: tipInfo.preparation_tips,
      };
    })
    .filter(s => s.available_staff.length > 0 || s.is_full || s.waitlist_available)
    .filter(s => !date || isSlotBookableForDate(date, s.time, minLeadMinutes));

  return {
    slots,
    duration_mins: duration,
    hide_staff_selection: hideStaff,
    staff_pool_label: hideStaff ? staffPoolLabel : null,
    service_image_url: service.image_url || null,
    slot_label_mode: service.slot_label_mode || 'time_only',
  };
}

async function getMaxCapacityForSlot(dbConn, serviceId, bizId, date, time, locationId = null) {
  const [[{ wd }]] = await dbConn.query('SELECT WEEKDAY(?) AS wd', [date]);
  const locFilter = locationId ? 'AND location_id = ?' : '';
  const params = [serviceId, bizId, wd, `${time}:00`, ...(locationId ? [locationId] : [])];
  const [[sch]] = await dbConn.query(`
    SELECT max_capacity FROM service_slot_schedules
    WHERE service_id = ? AND business_id = ? AND weekday = ?
      AND start_time = ? AND is_active = 1
      ${locFilter}
  `, params);
  return sch?.max_capacity ?? null;
}

async function countBookingsAtSlot(dbConn, bizId, serviceId, startsAt, excludeBookingId, locationId = null, staffId = null) {
  const params = [bizId, serviceId, startsAt];
  let q = `
    SELECT COUNT(*) AS cnt FROM bookings
    WHERE business_id = ? AND service_id = ? AND starts_at = ?
      AND status NOT IN ('cancelled', 'no_show')
  `;
  if (locationId) {
    q += ' AND location_id = ?';
    params.push(locationId);
  }
  if (staffId) {
    q += ' AND staff_id = ?';
    params.push(staffId);
  }
  if (excludeBookingId) {
    q += ' AND id != ?';
    params.push(excludeBookingId);
  }
  const [[row]] = await dbConn.query(q, params);
  return Number(row?.cnt || 0);
}

async function assertSlotCapacity(dbConn, bizId, serviceId, date, time, startsAt, endsAt, excludeBookingId, force = false, locationId = null, restrictStaffId = null) {
  const computed = await computeAvailableSlots(dbConn, bizId, serviceId, date, excludeBookingId, locationId, restrictStaffId);
  if (!computed) throw new Error('Η υπηρεσία δεν βρέθηκε');

  const staff = computed.slotMap[time] || [];
  if (!staff.length && !force) {
    throw new Error('Αυτή η ώρα δεν είναι πλέον διαθέσιμη');
  }

  const sch = computed.scheduleByTime?.get(time);
  const maxCap = sch?.max_capacity ?? null;
  const capacity = effectiveCapacity(maxCap, staff.length || 1);
  const booked = await countBookingsAtSlot(
    dbConn, bizId, serviceId, startsAt, excludeBookingId, locationId, restrictStaffId,
  );

  if (!force && booked >= capacity) {
    const err = new Error('Η θέση συμπληρώθηκε. Μπορείς να μπεις σε λίστα αναμονής.');
    err.code = 'SLOT_FULL';
    throw err;
  }

  return { computed, capacity, booked, staff };
}

async function assertStaffAvailable(dbConn, bizId, staffId, serviceId, startsAt, endsAt, excludeBookingId) {
  const [[conflict]] = await dbConn.query(`
    SELECT id FROM bookings
    WHERE staff_id = ? AND business_id = ?
      AND status NOT IN ('cancelled','no_show')
      AND starts_at < ? AND ends_at > ?
      AND NOT (service_id = ? AND starts_at = ? AND ends_at = ?)
      ${excludeBookingId ? 'AND id != ?' : ''}
  `, excludeBookingId
    ? [staffId, bizId, endsAt, startsAt, serviceId, startsAt, endsAt, excludeBookingId]
    : [staffId, bizId, endsAt, startsAt, serviceId, startsAt, endsAt]);

  if (conflict) {
    throw new Error('Ο γυμναστής είναι ήδη απασχολημένος αυτή την ώρα σε άλλο πρόγραμμα.');
  }
}

async function findStaffForSlot(dbConn, bizId, serviceId, computed, time, startsAt, { excludedStaffIds = [] } = {}) {
  const [existing] = await dbConn.query(`
    SELECT staff_id FROM bookings
    WHERE business_id = ? AND service_id = ? AND starts_at = ?
      AND status NOT IN ('cancelled','no_show')
    LIMIT 1
  `, [bizId, serviceId, startsAt]);

  const excluded = new Set((excludedStaffIds || []).map(String));
  const pool = (computed.slotMap[time] || []).filter((s) => !excluded.has(String(s.id)));
  if (!pool.length) {
    throw new Error('Δεν υπάρχει διαθέσιμος γυμναστής για αυτή την ώρα (ή όλοι έχουν εξαιρεθεί).');
  }

  const preferredId = existing[0]?.staff_id || null;
  const tempMap = { ...computed.slotMap, [time]: pool };
  const picked = pickStaffForBooking(tempMap, time, preferredId);
  if (!picked) throw new Error('Αυτή η ώρα δεν είναι πλέον διαθέσιμη');
  return picked.id;
}

module.exports = {
  formatStaffPoolLabel,
  pickRandomStaffForTime,
  pickStaffForBooking,
  toHHMM,
  startsAtKey,
  parseOpeningHours,
  isWeekdayClosed,
  getOpeningHours,
  assertGymOpenOnDate,
  generateSlots,
  staffConflict,
  computeAvailableSlots,
  buildSlotsPayload,
  effectiveCapacity,
  getMaxCapacityForSlot,
  countBookingsAtSlot,
  assertSlotCapacity,
  assertStaffAvailable,
  findStaffForSlot,
  BOOKING_MIN_LEAD_MINUTES,
  localDateString,
  isSlotBookableForDate,
};
