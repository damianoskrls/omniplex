const { v4: uuidv4 } = require('uuid');
const { GYM_STAFF_WHERE_ALIAS } = require('./gym_staff');

function mapSlots(rows) {
  return (rows || []).map((s) => ({
    weekday: s.weekday,
    start_time: String(s.start_time).slice(0, 5),
    end_time: String(s.end_time).slice(0, 5),
  }));
}

async function listActiveLocations(dbConn, bizId) {
  const [rows] = await dbConn.query(
    `SELECT id, name, opening_hours
     FROM locations
     WHERE business_id = ? AND is_active = 1
     ORDER BY sort_order, name`,
    [bizId],
  );
  return rows;
}

async function listGymStaff(dbConn, bizId) {
  const [rows] = await dbConn.query(
    `SELECT s.id, s.full_name, s.role, s.color_hex
     FROM staff s
     WHERE ${GYM_STAFF_WHERE_ALIAS}
     ORDER BY s.full_name`,
    [bizId],
  );
  return rows;
}

async function listBookableServices(dbConn, bizId) {
  const [rows] = await dbConn.query(
    `SELECT id, name FROM services
     WHERE business_id = ? AND is_active = 1
       AND (category IS NULL OR category <> 'nutrition_consultation')
     ORDER BY name`,
    [bizId],
  );
  return rows;
}

async function loadIndexes(dbConn, staffIds) {
  if (!staffIds.length) {
    return {
      locationsByStaff: new Map(),
      servicesByStaff: new Map(),
      placeServices: new Map(),
      configured: new Set(),
    };
  }
  const [locRows] = await dbConn.query(
    `SELECT staff_id, location_id FROM staff_locations WHERE staff_id IN (?)`,
    [staffIds],
  );
  const [svcRows] = await dbConn.query(
    `SELECT staff_id, service_id FROM staff_services WHERE staff_id IN (?)`,
    [staffIds],
  );
  const [placeRows] = await dbConn.query(
    `SELECT staff_id, location_id, service_id FROM staff_location_services WHERE staff_id IN (?)`,
    [staffIds],
  );
  const [prefRows] = await dbConn.query(
    `SELECT staff_id, location_id FROM staff_place_prefs WHERE staff_id IN (?)`,
    [staffIds],
  );

  const locationsByStaff = new Map();
  for (const row of locRows) {
    if (!locationsByStaff.has(row.staff_id)) locationsByStaff.set(row.staff_id, []);
    locationsByStaff.get(row.staff_id).push(row.location_id);
  }
  const servicesByStaff = new Map();
  for (const row of svcRows) {
    if (!servicesByStaff.has(row.staff_id)) servicesByStaff.set(row.staff_id, []);
    servicesByStaff.get(row.staff_id).push(row.service_id);
  }
  const placeServices = new Map();
  for (const row of placeRows) {
    const key = `${row.staff_id}:${row.location_id}`;
    if (!placeServices.has(key)) placeServices.set(key, []);
    placeServices.get(key).push(row.service_id);
  }
  const configured = new Set(prefRows.map((r) => `${r.staff_id}:${r.location_id}`));
  return { locationsByStaff, servicesByStaff, placeServices, configured };
}

async function slotsFor(dbConn, staffId, locationId) {
  const [specific] = await dbConn.query(
    `SELECT weekday, start_time, end_time
     FROM staff_availability
     WHERE staff_id = ? AND location_id = ? AND service_id IS NULL AND is_active = 1
     ORDER BY weekday, start_time`,
    [staffId, locationId],
  );
  if (specific.length) return { slots: mapSlots(specific), inherited: false };
  const [generic] = await dbConn.query(
    `SELECT weekday, start_time, end_time
     FROM staff_availability
     WHERE staff_id = ? AND location_id IS NULL AND service_id IS NULL AND is_active = 1
     ORDER BY weekday, start_time`,
    [staffId],
  );
  return { slots: mapSlots(generic), inherited: generic.length > 0 };
}

function worksHere(locationIds, locationId) {
  if (!locationIds.length) return { works: true, implicitAll: true };
  return { works: locationIds.includes(locationId), implicitAll: false };
}

async function getLocationTeam(dbConn, bizId, locationId) {
  const [[loc]] = await dbConn.query(
    'SELECT id FROM locations WHERE id = ? AND business_id = ? AND is_active = 1',
    [locationId, bizId],
  );
  if (!loc) {
    const err = new Error('Το κατάστημα δεν βρέθηκε');
    err.status = 404;
    throw err;
  }
  const [staff, services] = await Promise.all([
    listGymStaff(dbConn, bizId),
    listBookableServices(dbConn, bizId),
  ]);
  const indexes = await loadIndexes(dbConn, staff.map((s) => s.id));
  const trainers = [];
  for (const member of staff) {
    const assignedLocs = indexes.locationsByStaff.get(member.id) || [];
    const here = worksHere(assignedLocs, locationId);
    const key = `${member.id}:${locationId}`;
    const explicit = indexes.placeServices.get(key);
    const configured = indexes.configured.has(key);
    const serviceIds = configured
      ? (explicit || [])
      : (indexes.servicesByStaff.get(member.id) || []);
    const hours = await slotsFor(dbConn, member.id, locationId);
    trainers.push({
      id: member.id,
      full_name: member.full_name,
      role: member.role,
      color_hex: member.color_hex,
      works_here: here.works,
      implicit_all: here.implicitAll,
      services_configured: configured,
      service_ids: serviceIds,
      slots: hours.slots,
      hours_inherited: hours.inherited,
    });
  }
  return { services, trainers };
}

async function setWorksHere(conn, staffId, locationId, shouldWork, allLocationIds) {
  const [rows] = await conn.query(
    'SELECT location_id FROM staff_locations WHERE staff_id = ?',
    [staffId],
  );
  const current = rows.map((r) => r.location_id);
  if (!current.length) {
    if (shouldWork) return;
    for (const id of allLocationIds) {
      if (id === locationId) continue;
      await conn.query(
        'INSERT IGNORE INTO staff_locations (staff_id, location_id) VALUES (?, ?)',
        [staffId, id],
      );
    }
    return;
  }
  if (shouldWork) {
    await conn.query(
      'INSERT IGNORE INTO staff_locations (staff_id, location_id) VALUES (?, ?)',
      [staffId, locationId],
    );
  } else {
    await conn.query(
      'DELETE FROM staff_locations WHERE staff_id = ? AND location_id = ?',
      [staffId, locationId],
    );
  }
}

async function replacePlaceServices(conn, staffId, locationId, serviceIds) {
  await conn.query(
    'DELETE FROM staff_location_services WHERE staff_id = ? AND location_id = ?',
    [staffId, locationId],
  );
  await conn.query(
    'INSERT IGNORE INTO staff_place_prefs (staff_id, location_id) VALUES (?, ?)',
    [staffId, locationId],
  );
  for (const serviceId of serviceIds) {
    await conn.query(
      'INSERT IGNORE INTO staff_location_services (staff_id, location_id, service_id) VALUES (?, ?, ?)',
      [staffId, locationId, serviceId],
    );
    await conn.query(
      'INSERT IGNORE INTO staff_services (staff_id, service_id) VALUES (?, ?)',
      [staffId, serviceId],
    );
    const [[restricted]] = await conn.query(
      'SELECT 1 FROM service_locations WHERE service_id = ? LIMIT 1',
      [serviceId],
    );
    if (restricted) {
      await conn.query(
        'INSERT IGNORE INTO service_locations (service_id, location_id) VALUES (?, ?)',
        [serviceId, locationId],
      );
    }
  }
}

async function clearPlace(conn, staffId, locationId) {
  await conn.query(
    'DELETE FROM staff_location_services WHERE staff_id = ? AND location_id = ?',
    [staffId, locationId],
  );
  await conn.query(
    'DELETE FROM staff_place_prefs WHERE staff_id = ? AND location_id = ?',
    [staffId, locationId],
  );
}

async function replaceLocationHours(conn, staffId, locationId, slots) {
  await conn.query(
    'DELETE FROM staff_availability WHERE staff_id = ? AND location_id = ?',
    [staffId, locationId],
  );
  for (const slot of slots || []) {
    if (slot.weekday === undefined || slot.weekday === null || !slot.start_time || !slot.end_time) continue;
    await conn.query(
      `INSERT INTO staff_availability
        (id, staff_id, location_id, service_id, weekday, start_time, end_time, is_active)
       VALUES (?, ?, ?, NULL, ?, ?, ?, 1)`,
      [uuidv4(), staffId, locationId, Number(slot.weekday), slot.start_time, slot.end_time],
    );
  }
}

async function assertStaffInBusiness(conn, bizId, staffId) {
  const [[row]] = await conn.query(
    `SELECT s.id FROM staff s WHERE s.id = ? AND ${GYM_STAFF_WHERE_ALIAS}`,
    [staffId, bizId],
  );
  return !!row;
}

async function saveLocationTeam(dbConn, bizId, locationId, { trainers = [], hours = null } = {}) {
  const locations = await listActiveLocations(dbConn, bizId);
  if (!locations.some((l) => l.id === locationId)) {
    const err = new Error('Το κατάστημα δεν βρέθηκε');
    err.status = 404;
    throw err;
  }
  const allIds = locations.map((l) => l.id);
  const conn = await dbConn.getConnection();
  try {
    await conn.beginTransaction();
    for (const member of trainers) {
      if (!member?.staff_id) continue;
      if (!(await assertStaffInBusiness(conn, bizId, member.staff_id))) continue;
      await setWorksHere(conn, member.staff_id, locationId, !!member.works_here, allIds);
      if (member.works_here) {
        await replacePlaceServices(conn, member.staff_id, locationId, member.service_ids || []);
      } else {
        await clearPlace(conn, member.staff_id, locationId);
      }
    }
    if (hours && Array.isArray(hours.slots)) {
      let targets = [];
      if (hours.apply_to === 'all') {
        targets = trainers.filter((t) => t.works_here).map((t) => t.staff_id);
      } else if (hours.apply_to) {
        const chosen = trainers.find((t) => t.staff_id === hours.apply_to && t.works_here);
        if (chosen) targets = [chosen.staff_id];
      }
      for (const staffId of targets) {
        if (!(await assertStaffInBusiness(conn, bizId, staffId))) continue;
        await replaceLocationHours(conn, staffId, locationId, hours.slots);
      }
    }
    await conn.commit();
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
}

async function getStaffPlaces(dbConn, bizId, staffId) {
  if (!(await assertStaffInBusiness(dbConn, bizId, staffId))) {
    const err = new Error('Ο γυμναστής δεν βρέθηκε');
    err.status = 404;
    throw err;
  }
  const [locations, services] = await Promise.all([
    listActiveLocations(dbConn, bizId),
    listBookableServices(dbConn, bizId),
  ]);
  const indexes = await loadIndexes(dbConn, [staffId]);
  const assignedLocs = indexes.locationsByStaff.get(staffId) || [];
  const places = [];
  for (const loc of locations) {
    const here = worksHere(assignedLocs, loc.id);
    const key = `${staffId}:${loc.id}`;
    const configured = indexes.configured.has(key);
    const explicit = indexes.placeServices.get(key);
    const hours = await slotsFor(dbConn, staffId, loc.id);
    places.push({
      id: loc.id,
      name: loc.name,
      opening_hours: loc.opening_hours,
      works_here: here.works,
      implicit_all: here.implicitAll,
      services_configured: configured,
      service_ids: configured ? (explicit || []) : (indexes.servicesByStaff.get(staffId) || []),
      slots: hours.slots,
      hours_inherited: hours.inherited,
    });
  }
  return { services, places };
}

async function saveStaffPlaces(dbConn, bizId, staffId, { places = [] } = {}) {
  if (!(await assertStaffInBusiness(dbConn, bizId, staffId))) {
    const err = new Error('Ο γυμναστής δεν βρέθηκε');
    err.status = 404;
    throw err;
  }
  const locations = await listActiveLocations(dbConn, bizId);
  const allIds = locations.map((l) => l.id);
  const allowed = new Set(allIds);
  const conn = await dbConn.getConnection();
  try {
    await conn.beginTransaction();
    for (const place of places) {
      if (!place?.location_id || !allowed.has(place.location_id)) continue;
      await setWorksHere(conn, staffId, place.location_id, !!place.works_here, allIds);
      if (place.works_here) {
        await replacePlaceServices(conn, staffId, place.location_id, place.service_ids || []);
        if (Array.isArray(place.slots)) {
          await replaceLocationHours(conn, staffId, place.location_id, place.slots);
        }
      } else {
        await clearPlace(conn, staffId, place.location_id);
      }
    }
    await conn.commit();
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
}

module.exports = {
  getLocationTeam,
  saveLocationTeam,
  getStaffPlaces,
  saveStaffPlaces,
};
