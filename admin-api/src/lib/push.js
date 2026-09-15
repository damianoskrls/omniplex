const https = require('https');

function absoluteMediaUrl(pathOrUrl) {
  if (!pathOrUrl) return null;
  if (String(pathOrUrl).startsWith('http')) return pathOrUrl;
  const base = process.env.PUBLIC_API_URL || process.env.API_BASE_URL;
  if (!base) return null;
  return `${String(base).replace(/\/$/, '')}${pathOrUrl}`;
}

function sendFcm(tokens, { title, body, data = {}, imageUrl }) {
  const serverKey = process.env.FCM_SERVER_KEY;
  if (!serverKey || !tokens?.length) {
    return Promise.resolve({ sent: 0, skipped: true });
  }

  const unique = [...new Set(tokens.filter(Boolean))];
  const notification = { title, body, sound: 'default' };
  const absImage = absoluteMediaUrl(imageUrl);
  if (absImage) notification.image = absImage;

  const payload = JSON.stringify({
    registration_ids: unique,
    notification,
    data: Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, String(v)])
    ),
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
