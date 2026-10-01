const https = require('https');
const { phoneLast10Eq } = require('./phone_sql');

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

async function getGlobalUserFcmTokens(dbConn, globalUserId) {
  if (!globalUserId) return [];
  const [rows] = await dbConn.query(
    'SELECT fcm_token FROM global_device_tokens WHERE global_user_id = ?',
    [globalUserId],
  );
  return rows.map((r) => r.fcm_token).filter(Boolean);
}

/** Gym device tokens plus the OmniPlex token, so pushes arrive outside the gym too. */
async function getUserFcmTokens(dbConn, userId) {
  if (!userId) return [];
  let gymTokens = [];
  try {
    const [gymRows] = await dbConn.query(
      'SELECT fcm_token FROM device_tokens WHERE user_id = ?',
      [userId],
    );
    gymTokens = gymRows.map((r) => r.fcm_token);
  } catch (err) {
    console.error('device token lookup failed:', err.message);
  }

  let globalUserId = null;
  try {
    const [[member]] = await dbConn.query(
      'SELECT global_user_id FROM users WHERE id = ?',
      [userId],
    );
    globalUserId = member?.global_user_id || null;
  } catch (_) {}
  if (!globalUserId) {
    try {
      const [[withPhone]] = await dbConn.query('SELECT phone FROM users WHERE id = ?', [userId]);
      const digits = String(withPhone?.phone || '').replace(/\D/g, '');
      if (digits.length >= 10) {
        const [[gu]] = await dbConn.query(
          `SELECT id FROM global_users WHERE ${phoneLast10Eq('phone')} LIMIT 1`,
          [digits],
        );
        globalUserId = gu?.id || null;
      }
    } catch (err) {
      console.error('global user link for push failed:', err.message);
    }
  }
  if (!globalUserId) {
    try {
      const [[staff]] = await dbConn.query(
        'SELECT global_user_id FROM staff WHERE id = ?',
        [userId],
      );
      globalUserId = staff?.global_user_id || null;
    } catch (_) {}
  }

  let globalTokens = [];
  try {
    globalTokens = await getGlobalUserFcmTokens(dbConn, globalUserId);
  } catch (err) {
    console.error('global token lookup failed:', err.message);
  }
  const tokens = [...new Set([...gymTokens, ...globalTokens].filter(Boolean))];
  if (!tokens.length) console.log(`FCM: no tokens for user ${userId}`);
  return tokens;
}

async function sendFcmMany(tokens, payload) {
  const admin = getAdmin();
  const unique = [...new Set((tokens || []).filter(Boolean))];
  if (!unique.length) return { sent: 0, failure: 0, skipped: true };
  if (!admin || typeof admin.messaging().sendEachForMulticast !== 'function') {
    return sendFcm(unique, payload);
  }
  const stringData = Object.fromEntries(
    Object.entries(payload.data || {}).map(([k, v]) => [k, String(v)]),
  );
  let sent = 0;
  let failure = 0;
  for (let i = 0; i < unique.length; i += 500) {
    const chunk = unique.slice(i, i + 500);
    const res = await admin.messaging().sendEachForMulticast({
      tokens: chunk,
      notification: { title: payload.title, body: payload.body },
      data: stringData,
      android: { priority: 'high', notification: { channelId: 'bookup_push', sound: 'default', priority: 'high' } },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    sent += res.successCount || 0;
    failure += res.failureCount || 0;
  }
  return { sent, failure, skipped: false };
}

module.exports = { sendFcm, sendFcmMany, getUserFcmTokens, getGlobalUserFcmTokens, absoluteMediaUrl };
