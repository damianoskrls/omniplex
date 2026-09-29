const { v4: uuidv4 } = require('uuid');
const { GYM_STAFF_WHERE_ALIAS } = require('./gym_staff');

function mapTime(t) {
  return String(t).slice(0, 5);
}

function toMinutes(t) {
  const [h, m] = String(t).slice(0, 5).split(':').map(Number);
  if (Number.isNaN(h) || Number.isNaN(m)) return null;
  return h * 60 + m;
}

function weekdayFromDate(dateStr) {
  const d = new Date(`${String(dateStr).slice(0, 10)}T12:00:00`);
  const js = d.getDay();
  return js === 0 ? 6 : js - 1;
}

async function listDropinSetup(db, bizId) {
  const [services] = await db.query(
    `SELECT id, name, duration_mins FROM services
     WHERE business_id = ? AND is_active = 1
       AND (category IS NULL OR category <> 'nutrition_consultation')
     ORDER BY name`,
    [bizId],
  );
  const [locations] = await db.query(
    `SELECT id, name, opening_hours FROM locations
     WHERE business_id = ? AND is_active = 1
     ORDER BY sort_order, name`,
    [bizId],
  );
  const [staff] = await db.query(
    `SELECT s.id, s.full_name FROM staff s
     WHERE ${GYM_STAFF_WHERE_ALIAS}
     ORDER BY s.full_name`,
    [bizId],
  );
  const [offers] = await db.query(
    `SELECT o.id, o.service_id, o.location_id, o.price_cents, o.is_active,
            s.name AS service_name, l.name AS location_name
     FROM dropin_offers o
     JOIN services s ON s.id = o.service_id
     JOIN locations l ON l.id = o.location_id
     WHERE o.business_id = ?
     ORDER BY l.name, s.name`,
    [bizId],
  );
  if (!offers.length) return { services, locations, staff, offers: [] };

  const ids = offers.map((o) => o.id);
  const [hours] = await db.query(
    `SELECT offer_id, weekday, start_time, end_time
     FROM dropin_offer_hours WHERE offer_id IN (?)
     ORDER BY weekday, start_time`,
    [ids],
  );
  const [people] = await db.query(
    `SELECT os.offer_id, os.staff_id, st.full_name
     FROM dropin_offer_staff os
     JOIN staff st ON st.id = os.staff_id
     WHERE os.offer_id IN (?)`,
    [ids],
  );
  return {
    services,
    locations,
    staff,
    offers: offers.map((o) => ({
      ...o,
      slots: hours.filter((h) => h.offer_id === o.id).map((h) => ({
        weekday: h.weekday,
        start_time: mapTime(h.start_time),
        end_time: mapTime(h.end_time),
      })),
      staff_ids: people.filter((p) => p.offer_id === o.id).map((p) => p.staff_id),
      staff_names: people.filter((p) => p.offer_id === o.id).map((p) => p.full_name),
    })),
  };
}

async function syncFlags(conn, bizId, serviceId, locationId, priceCents) {
  await conn.query(
    'UPDATE services SET drop_in_price_cents = ? WHERE id = ? AND business_id = ?',
    [priceCents, serviceId, bizId],
  );
  await conn.query(
    'UPDATE locations SET accepts_drop_in = 1 WHERE id = ? AND business_id = ?',
    [locationId, bizId],
  );
}

async function clearFlagsIfUnused(conn, bizId, serviceId, locationId) {
  const [[svcLeft]] = await conn.query(
    `SELECT price_cents FROM dropin_offers
     WHERE business_id = ? AND service_id = ? AND is_active = 1
     ORDER BY price_cents ASC LIMIT 1`,
    [bizId, serviceId],
  );
  if (!svcLeft) {
    await conn.query(
      'UPDATE services SET drop_in_price_cents = NULL WHERE id = ? AND business_id = ?',
      [serviceId, bizId],
    );
  } else {
    await conn.query(
      'UPDATE services SET drop_in_price_cents = ? WHERE id = ? AND business_id = ?',
      [svcLeft.price_cents, serviceId, bizId],
    );
  }
  const [[locLeft]] = await conn.query(
    `SELECT id FROM dropin_offers
     WHERE business_id = ? AND location_id = ? AND is_active = 1 LIMIT 1`,
    [bizId, locationId],
  );
  if (!locLeft) {
    await conn.query(
      'UPDATE locations SET accepts_drop_in = 0 WHERE id = ? AND business_id = ?',
      [locationId, bizId],
    );
  }
}

function bad(message, status = 400) {
  const err = new Error(message);
  err.status = status;
  return err;
}

async function saveDropinOffer(db, bizId, body, offerId = null) {
  const { service_id, location_id, price_cents, staff_ids = [], slots = [] } = body;
  if (!service_id || !location_id) throw bad('Διάλεξε υπηρεσία και κατάστημα');
  const price = Number(price_cents);
  if (!Number.isFinite(price) || price <= 0) throw bad('Βάλε τιμή drop-in');
  if (!Array.isArray(staff_ids) || !staff_ids.length) throw bad('Διάλεξε ποιος το αναλαμβάνει');
  const cleanSlots = (Array.isArray(slots) ? slots : []).filter(
    (s) => s && s.weekday != null && s.start_time && s.end_time,
  );
  if (!cleanSlots.length) throw bad('Βάλε διαθέσιμες ώρες');

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const [[svc]] = await conn.query(
      'SELECT id FROM services WHERE id = ? AND business_id = ?',
      [service_id, bizId],
    );
    const [[loc]] = await conn.query(
      'SELECT id FROM locations WHERE id = ? AND business_id = ?',
      [location_id, bizId],
    );
    if (!svc || !loc) throw bad('Η υπηρεσία ή το κατάστημα δεν βρέθηκε');

    let id = offerId;
    if (id) {
      const [[existing]] = await conn.query(
        'SELECT id, service_id, location_id FROM dropin_offers WHERE id = ? AND business_id = ?',
        [id, bizId],
      );
      if (!existing) throw bad('Δεν βρέθηκε', 404);
      await conn.query(
        `UPDATE dropin_offers
         SET service_id = ?, location_id = ?, price_cents = ?, is_active = 1
         WHERE id = ? AND business_id = ?`,
        [service_id, location_id, price, id, bizId],
      );
      if (existing.service_id !== service_id || existing.location_id !== location_id) {
        await clearFlagsIfUnused(conn, bizId, existing.service_id, existing.location_id);
      }
    } else {
      const [[dup]] = await conn.query(
        'SELECT id FROM dropin_offers WHERE business_id = ? AND service_id = ? AND location_id = ?',
        [bizId, service_id, location_id],
      );
      id = dup?.id || uuidv4();
      if (dup) {
        await conn.query(
          'UPDATE dropin_offers SET price_cents = ?, is_active = 1 WHERE id = ?',
          [price, id],
        );
      } else {
        await conn.query(
          `INSERT INTO dropin_offers (id, business_id, service_id, location_id, price_cents, is_active)
           VALUES (?,?,?,?,?,1)`,
          [id, bizId, service_id, location_id, price],
        );
      }
    }

    await conn.query('DELETE FROM dropin_offer_staff WHERE offer_id = ?', [id]);
    await conn.query('DELETE FROM dropin_offer_hours WHERE offer_id = ?', [id]);
    for (const staffId of staff_ids) {
      await conn.query(
        'INSERT IGNORE INTO dropin_offer_staff (offer_id, staff_id) VALUES (?,?)',
        [id, staffId],
      );
    }
    for (const slot of cleanSlots) {
      await conn.query(
        'INSERT INTO dropin_offer_hours (id, offer_id, weekday, start_time, end_time) VALUES (?,?,?,?,?)',
        [uuidv4(), id, Number(slot.weekday), slot.start_time, slot.end_time],
      );
    }
    await syncFlags(conn, bizId, service_id, location_id, price);
    await conn.commit();
    return { id };
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
}

async function deleteDropinOffer(db, bizId, offerId) {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const [[existing]] = await conn.query(
      'SELECT service_id, location_id FROM dropin_offers WHERE id = ? AND business_id = ?',
      [offerId, bizId],
    );
    if (!existing) throw bad('Δεν βρέθηκε', 404);
    await conn.query('DELETE FROM dropin_offer_staff WHERE offer_id = ?', [offerId]);
    await conn.query('DELETE FROM dropin_offer_hours WHERE offer_id = ?', [offerId]);
    await conn.query('DELETE FROM dropin_offers WHERE id = ? AND business_id = ?', [offerId, bizId]);
    await clearFlagsIfUnused(conn, bizId, existing.service_id, existing.location_id);
    await conn.commit();
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
}

async function loadActiveOffer(db, bizId, serviceId, locationId) {
  if (!serviceId) return null;
  const params = [bizId, serviceId];
  let locSql = '';
  if (locationId) {
    locSql = ' AND location_id = ?';
    params.push(locationId);
  }
  const [[offer]] = await db.query(
    `SELECT id, service_id, location_id, price_cents
     FROM dropin_offers
     WHERE business_id = ? AND service_id = ? AND is_active = 1 ${locSql}
     LIMIT 1`,
    params,
  );
  if (!offer) return null;
  const [hours] = await db.query(
    'SELECT weekday, start_time, end_time FROM dropin_offer_hours WHERE offer_id = ?',
    [offer.id],
  );
  const [people] = await db.query(
    'SELECT staff_id FROM dropin_offer_staff WHERE offer_id = ?',
    [offer.id],
  );
  return {
    ...offer,
    hours,
    staffIds: new Set(people.map((p) => p.staff_id)),
  };
}

async function businessHasDropinOffers(db, bizId) {
  const [[row]] = await db.query(
    'SELECT id FROM dropin_offers WHERE business_id = ? AND is_active = 1 LIMIT 1',
    [bizId],
  );
  return !!row;
}

async function buildDropinSlotMap(db, bizId, offer, date, durationMins) {
  const wd = weekdayFromDate(date);
  const ranges = (offer.hours || []).filter((h) => Number(h.weekday) === wd);
  const ids = [...(offer.staffIds || [])];
  if (!ranges.length || !ids.length || !durationMins) return {};

  const [staffRows] = await db.query(
    `SELECT id, full_name, role, color_hex, avatar_url, bio
     FROM staff WHERE business_id = ? AND id IN (?)`,
    [bizId, ids],
  );
  const [bookings] = await db.query(
    `SELECT id, staff_id, starts_at, ends_at
     FROM bookings
     WHERE business_id = ? AND staff_id IN (?)
       AND DATE(starts_at) = ?
       AND status IN ('confirmed', 'pending')`,
    [bizId, ids, String(date).slice(0, 10)],
  );

  const slotMap = {};
  for (const range of ranges) {
    const times = generateHalfHourSlots(range.start_time, range.end_time, durationMins);
    for (const time of times) {
      const slotStart = new Date(`${String(date).slice(0, 10)}T${time}:00`);
      const slotEnd = new Date(slotStart.getTime() + durationMins * 60000);
      const free = staffRows.filter((st) => !bookings.some((b) => {
        if (b.staff_id !== st.id) return false;
        const bStart = new Date(b.starts_at);
        const bEnd = new Date(b.ends_at);
        return bStart < slotEnd && bEnd > slotStart;
      }));
      if (!free.length) continue;
      slotMap[time] = free.map((st) => ({
        id: st.id,
        full_name: st.full_name,
        role: st.role,
        color_hex: st.color_hex,
        avatar_url: st.avatar_url,
        bio: st.bio,
      }));
    }
  }
  return slotMap;
}

function generateHalfHourSlots(startTime, endTime, durationMins) {
  const start = toMinutes(startTime);
  const end = toMinutes(endTime);
  if (start == null || end == null) return [];
  const slots = [];
  for (let current = start; current + durationMins <= end; current += 30) {
    const h = String(Math.floor(current / 60)).padStart(2, '0');
    const m = String(current % 60).padStart(2, '0');
    slots.push(`${h}:${m}`);
  }
  return slots;
}

function filterSlotsByOffer(slotMap, offer, weekday, durationMins) {
  const ranges = (offer.hours || []).filter((h) => Number(h.weekday) === Number(weekday));
  const next = {};
  for (const [time, staff] of Object.entries(slotMap || {})) {
    const start = toMinutes(time);
    if (start == null) continue;
    const fits = ranges.some((r) => {
      const open = toMinutes(r.start_time);
      const close = toMinutes(r.end_time);
      if (open == null || close == null) return false;
      return start >= open && start + (durationMins || 0) <= close;
    });
    if (!fits) continue;
    const allowed = (staff || []).filter((s) => offer.staffIds.has(s.id));
    if (!allowed.length) continue;
    next[time] = allowed;
  }
  return next;
}

module.exports = {
  listDropinSetup,
  saveDropinOffer,
  deleteDropinOffer,
  loadActiveOffer,
  businessHasDropinOffers,
  filterSlotsByOffer,
  buildDropinSlotMap,
  weekdayFromDate,
};
