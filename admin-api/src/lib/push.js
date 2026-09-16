const https = require('https');

let _admin = null;

function getAdmin() {
  if (_admin) return _admin;
  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!serviceAccountJson) return null;
  try {
    const admin = require('firebase-admin');
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert(JSON.parse(serviceAccountJson)),
      });
    }
    _admin = admin;
    return _admin;
  } catch (e) {
    console.warn('firebase-admin init failed:', e.message);
    return null;
  }
}

function absoluteMediaUrl(pathOrUrl) {
  if (!pathOrUrl) return null;
  if (String(pathOrUrl).startsWith('http')) return pathOrUrl;
  const base = process.env.PUBLIC_API_URL || process.env.API_BASE_URL;
  if (!base) return null;
  return `${String(base).replace(/\/$/, '')}${pathOrUrl}`;
}

async function sendFcm(tokens, { title, body, data = {}, imageUrl }) {
  if (!tokens?.length) return { sent: 0, skipped: true };

  const admin = getAdmin();
  if (!admin) {
    // Legacy fallback (will fail if Legacy API disabled, but graceful)
    const serverKey = process.env.FCM_SERVER_KEY;
    if (!serverKey) return { sent: 0, skipped: true };
    return sendFcmLegacy(tokens, { title, body, data, imageUrl }, serverKey);
  }

  const unique = [...new Set(tokens.filter(Boolean))];
  const absImage = absoluteMediaUrl(imageUrl);
  const stringData = Object.fromEntries(
    Object.entries(data).map(([k, v]) => [k, String(v)])
  );

  let sent = 0;
  let failure = 0;
  for (const token of unique) {
    try {
      await admin.messaging().send({
        token,
        notification: { title, body, ...(absImage ? { imageUrl: absImage } : {}) },
        data: stringData,
        android: {
          priority: 'high',
          notification: {
            channelId: 'bookup_push',
            sound: 'default',
            priority: 'high',
          },
        },
        apns: { payload: { aps: { sound: 'default' } } },
      });
      sent++;
    } catch (e) {
      console.error('FCM send error:', e.message, 'token prefix:', token?.slice(0, 20));
      failure++;
    }
  }
  console.log(`FCM: sent=${sent} failure=${failure} tokens=${unique.length}`);
  return { sent, failure, skipped: false };
}

function sendFcmLegacy(tokens, { title, body, data, imageUrl }, serverKey) {
  const unique = [...new Set(tokens.filter(Boolean))];
  const notification = { title, body, sound: 'default' };
  const absImage = absoluteMediaUrl(imageUrl);
  if (absImage) notification.image = absImage;

  const payload = JSON.stringify({
    registration_ids: unique,
    notification,
    data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
    priority: 'high',
  });

  return new Promise((resolve) => {
    const req = https.request({
      hostname: 'fcm.googleapis.com',
      path: '/fcm/send',
      method: 'POST',
      headers: {
        Authorization: `key=${serverKey}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
      },
    }, (res) => {
      let raw = '';
      res.on('data', (c) => { raw += c; });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(raw);
          resolve({ sent: parsed.success || 0, failure: parsed.failure || 0, skipped: false });
        } catch {
          resolve({ sent: 0, skipped: false, error: raw });
        }
      });
    });
    req.on('error', (err) => resolve({ sent: 0, error: err.message }));
    req.write(payload);
    req.end();
  });
}

async function getUserFcmTokens(dbConn, userId) {
  const [rows] = await dbConn.query(
    'SELECT fcm_token FROM device_tokens WHERE user_id = ?',
    [userId]
  );
  return rows.map(r => r.fcm_token);
}

module.exports = { sendFcm, getUserFcmTokens, absoluteMediaUrl };
