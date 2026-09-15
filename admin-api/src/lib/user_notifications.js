const { v4: uuidv4 } = require('uuid');
const { sendFcm, getUserFcmTokens } = require('./push');

async function createUserNotification(dbConn, {
  businessId, userId, bookingId, type, title, body, payload, imageUrl, sendPush = true,
}) {
  const id = uuidv4();
  let sentPush = 0;
  const finalPayload = {
    ...(payload || {}),
    ...(imageUrl ? { image_url: imageUrl } : {}),
  };
  const payloadJson = Object.keys(finalPayload).length ? finalPayload : null;

  if (sendPush) {
    const tokens = await getUserFcmTokens(dbConn, userId);
    const result = await sendFcm(tokens, {
      title,
      body,
      imageUrl,
      data: {
        type,
        notification_id: id,
        booking_id: bookingId || '',
        ...(payloadJson || {}),
      },
    });
    sentPush = result.sent > 0 ? 1 : 0;
  }

  await dbConn.query(
    `INSERT INTO user_notifications
      (id, business_id, user_id, booking_id, type, title, body, payload, sent_push)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      id, businessId, userId, bookingId || null, type, title, body || null,
      payloadJson ? JSON.stringify(payloadJson) : null, sentPush,
    ]
  );

  return { id, sentPush };
}

module.exports = { createUserNotification };
