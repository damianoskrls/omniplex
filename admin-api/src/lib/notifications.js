const { v4: uuidv4 } = require('uuid');

async function createAdminNotification(dbConn, { businessId, type, title, body, payload }) {
  const id = uuidv4();
  await dbConn.query(
    `INSERT INTO admin_notifications (id, business_id, type, title, body, payload)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [id, businessId, type, title, body || null, payload ? JSON.stringify(payload) : null]
  );
  return id;
}

module.exports = { createAdminNotification };
