const { v4: uuidv4 } = require('uuid');

async function locationIdsFor(dbConn, { locationId, userId, staffId }) {
  if (locationId) return [locationId];
  if (userId) {
    const [rows] = await dbConn.query(
      'SELECT location_id FROM user_locations WHERE user_id = ?',
      [userId],
    );
    const ids = rows.map((row) => row.location_id).filter(Boolean);
    if (ids.length) return ids;
  }
  if (staffId) {
    const [rows] = await dbConn.query(
      'SELECT location_id FROM staff_locations WHERE staff_id = ?',
      [staffId],
    );
    const ids = rows.map((row) => row.location_id).filter(Boolean);
    if (ids.length) return ids;
  }
  return [null];
}

async function createAdminNotification(dbConn, { businessId, type, title, body, payload, locationId = null, userId = null, staffId = null }) {
  const locationIds = await locationIdsFor(dbConn, { locationId, userId, staffId });
  let first = null;
  for (const loc of locationIds) {
    const id = uuidv4();
    await dbConn.query(
      `INSERT INTO admin_notifications (id, business_id, location_id, type, title, body, payload)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [id, businessId, loc, type, title, body || null, payload ? JSON.stringify(payload) : null],
    );
    if (!first) first = id;
  }
  return first;
}

module.exports = { createAdminNotification };
