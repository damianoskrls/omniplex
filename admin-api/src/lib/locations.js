const { v4: uuidv4 } = require('uuid');

async function isMultiLocationEnabled(dbConn, bizId) {
  const [[cfg]] = await dbConn.query(
    'SELECT feature_multi_location FROM business_configs WHERE business_id = ?',
    [bizId],
  );
  return !!cfg?.feature_multi_location;
}

async function listLocations(dbConn, bizId, { activeOnly = true, userId = null } = {}) {
  let sql = `
    SELECT l.id, l.business_id, l.name, l.slug, l.address, l.city, l.phone, l.email,
           l.opening_hours, l.is_active, l.sort_order
    FROM locations l
    WHERE l.business_id = ?
  `;
  const params = [bizId];
  if (activeOnly) {
    sql += ' AND l.is_active = 1';
  }
  if (userId) {
    sql += ` AND (
      NOT EXISTS (SELECT 1 FROM user_locations ul WHERE ul.user_id = ?)
      OR EXISTS (SELECT 1 FROM user_locations ul WHERE ul.user_id = ? AND ul.location_id = l.id)
    )`;
    params.push(userId, userId);
  }
  sql += ' ORDER BY l.sort_order, l.name';
  const [rows] = await dbConn.query(sql, params);
  return rows;
}

async function getDefaultLocationId(dbConn, bizId) {
  const [[row]] = await dbConn.query(
    `SELECT id FROM locations WHERE business_id = ? AND is_active = 1
     ORDER BY sort_order, name LIMIT 1`,
    [bizId],
  );
  return row?.id || null;
}

async function resolveLocationId(dbConn, bizId, locationId, { userId = null, requireExplicit = false } = {}) {
  const multi = await isMultiLocationEnabled(dbConn, bizId);
  let resolved = locationId || null;
  if (!resolved) {
    resolved = await getDefaultLocationId(dbConn, bizId);
  }
  if (!resolved) return null;

  const [[loc]] = await dbConn.query(
    'SELECT id FROM locations WHERE id = ? AND business_id = ? AND is_active = 1',
    [resolved, bizId],
  );
  if (!loc) {
    const err = new Error('Το γυμναστήριο (τοποθεσία) δεν βρέθηκε');
    err.status = 404;
    throw err;
  }

  if (userId) {
    await assertUserCanAccessLocation(dbConn, userId, resolved, bizId);
  }

  if (
    requireExplicit
    && multi
    && !locationId
    && (await listLocations(dbConn, bizId, { activeOnly: true, userId })).length > 1
  ) {
    const err = new Error('Επίλεξε τοποθεσία γυμναστηρίου');
    err.status = 400;
    err.code = 'LOCATION_REQUIRED';
    throw err;
  }

  return resolved;
}

async function assertUserCanAccessLocation(dbConn, userId, locationId, bizId) {
  const [[restricted]] = await dbConn.query(
    'SELECT 1 FROM user_locations WHERE user_id = ? LIMIT 1',
    [userId],
  );
  if (!restricted) return;

  const [[allowed]] = await dbConn.query(
    'SELECT 1 FROM user_locations WHERE user_id = ? AND location_id = ?',
    [userId, locationId],
  );
  if (!allowed) {
    const err = new Error('Δεν έχεις πρόσβαση σε αυτό το γυμναστήριο');
    err.status = 403;
    throw err;
  }
}

async function assertServiceAtLocation(dbConn, serviceId, locationId, bizId) {
  const [[svc]] = await dbConn.query(
    'SELECT id FROM services WHERE id = ? AND business_id = ? AND is_active = 1',
    [serviceId, bizId],
  );
  if (!svc) {
    const err = new Error('Η υπηρεσία δεν βρέθηκε');
    err.status = 404;
    throw err;
  }

  const [[restricted]] = await dbConn.query(
    'SELECT 1 FROM service_locations WHERE service_id = ? LIMIT 1',
    [serviceId],
  );
  if (!restricted) return;

  const [[allowed]] = await dbConn.query(
    'SELECT 1 FROM service_locations WHERE service_id = ? AND location_id = ?',
    [serviceId, locationId],
  );
  if (!allowed) {
    const err = new Error('Η υπηρεσία δεν είναι διαθέσιμη σε αυτό το γυμναστήριο');
    err.status = 400;
    throw err;
  }
}

async function assertStaffAtLocation(dbConn, staffId, locationId, bizId) {
  const [[staff]] = await dbConn.query(
    `SELECT id FROM staff WHERE id = ? AND business_id = ? AND is_active = 1
     AND COALESCE(is_nutritionist, 0) = 0`,
    [staffId, bizId],
  );
  if (!staff) {
    const err = new Error('Ο γυμναστής δεν βρέθηκε');
    err.status = 404;
    throw err;
  }

  const [[restricted]] = await dbConn.query(
    'SELECT 1 FROM staff_locations WHERE staff_id = ? LIMIT 1',
    [staffId],
  );
  if (!restricted) return;

  const [[allowed]] = await dbConn.query(
    'SELECT 1 FROM staff_locations WHERE staff_id = ? AND location_id = ?',
    [staffId, locationId],
  );
  if (!allowed) {
    const err = new Error('Ο γυμναστής δεν εργάζεται σε αυτό το γυμναστήριο');
    err.status = 400;
    throw err;
  }
}

async function getLocationOpeningHours(dbConn, bizId, locationId) {
  const [[loc]] = await dbConn.query(
    'SELECT opening_hours FROM locations WHERE id = ? AND business_id = ?',
    [locationId, bizId],
  );
  if (loc?.opening_hours) {
    try {
      return typeof loc.opening_hours === 'string'
        ? JSON.parse(loc.opening_hours)
        : loc.opening_hours;
    } catch {
      /* fall through */
    }
  }
  const { getOpeningHours } = require('./slots');
  return getOpeningHours(dbConn, bizId);
}

async function getStaffLocationIds(dbConn, staffId) {
  const [rows] = await dbConn.query(
    'SELECT location_id FROM staff_locations WHERE staff_id = ?',
    [staffId],
  );
  return rows.map((r) => r.location_id);
}

async function getServiceLocationIds(dbConn, serviceId) {
  const [rows] = await dbConn.query(
    'SELECT location_id FROM service_locations WHERE service_id = ?',
    [serviceId],
  );
  return rows.map((r) => r.location_id);
}

async function getUserLocationIds(dbConn, userId) {
  const [rows] = await dbConn.query(
    'SELECT location_id FROM user_locations WHERE user_id = ?',
    [userId],
  );
  return rows.map((r) => r.location_id);
}

async function replaceStaffLocations(dbConn, staffId, locationIds = []) {
  await dbConn.query('DELETE FROM staff_locations WHERE staff_id = ?', [staffId]);
  for (const locationId of locationIds) {
    await dbConn.query(
      'INSERT IGNORE INTO staff_locations (staff_id, location_id) VALUES (?, ?)',
      [staffId, locationId],
    );
  }
}

async function replaceUserLocations(dbConn, userId, locationIds = []) {
  await dbConn.query('DELETE FROM user_locations WHERE user_id = ?', [userId]);
  for (const locationId of locationIds) {
    await dbConn.query(
      'INSERT IGNORE INTO user_locations (user_id, location_id) VALUES (?, ?)',
      [userId, locationId],
    );
  }
}

async function replaceServiceLocations(dbConn, serviceId, locationIds = []) {
  await dbConn.query('DELETE FROM service_locations WHERE service_id = ?', [serviceId]);
  for (const locationId of locationIds) {
    await dbConn.query(
      'INSERT IGNORE INTO service_locations (service_id, location_id) VALUES (?, ?)',
      [serviceId, locationId],
    );
  }
}

async function ensureDefaultLocation(dbConn, bizId, name = 'Κεντρικό') {
  const existing = await getDefaultLocationId(dbConn, bizId);
  if (existing) return existing;
  const id = uuidv4();
  const slug = `branch-${Date.now()}`;
  await dbConn.query(
    `INSERT INTO locations (id, business_id, name, slug, sort_order)
     VALUES (?, ?, ?, ?, 0)`,
    [id, bizId, name, slug],
  );
  return id;
}

async function listLocationsForService(dbConn, bizId, serviceId, { userId = null } = {}) {
  const all = await listLocations(dbConn, bizId, { activeOnly: true, userId });
  const [[restricted]] = await dbConn.query(
    'SELECT 1 FROM service_locations WHERE service_id = ? LIMIT 1',
    [serviceId],
  );
  if (!restricted) return all;
  const [rows] = await dbConn.query(
    'SELECT location_id FROM service_locations WHERE service_id = ?',
    [serviceId],
  );
  const allowed = new Set(rows.map((r) => r.location_id));
  return all.filter((l) => allowed.has(l.id));
}

module.exports = {
  isMultiLocationEnabled,
  listLocations,
  listLocationsForService,
  getDefaultLocationId,
  resolveLocationId,
  assertUserCanAccessLocation,
  assertServiceAtLocation,
  assertStaffAtLocation,
  getLocationOpeningHours,
  getStaffLocationIds,
  getServiceLocationIds,
  getUserLocationIds,
  replaceStaffLocations,
  replaceUserLocations,
  replaceServiceLocations,
  ensureDefaultLocation,
};
