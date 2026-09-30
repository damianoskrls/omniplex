'use strict';

function normalizePhone(to) {
  let n = String(to || '').replace(/[^\d+]/g, '');
  if (n.startsWith('00')) n = `+${n.slice(2)}`;
  if (!n.startsWith('+')) {
    if (n.startsWith('30') && n.length >= 12) n = `+${n}`;
    else n = `+30${n.replace(/^0+/, '')}`;
  }
  return n;
}

async function sendSms(to, body) {
  const apiKey = process.env.BREVO_API_KEY;
  const sender = process.env.BREVO_SMS_SENDER || 'OmniPlex';

  if (!apiKey) {
    const err = new Error('Τα SMS δεν είναι ρυθμισμένα στον server');
    err.status = 400;
    throw err;
  }

  const normalized = normalizePhone(to);
  if (normalized.length < 8) {
    const err = new Error('Μη έγκυρο τηλέφωνο');
    err.status = 400;
    throw err;
  }

  const res = await fetch('https://api.brevo.com/v3/transactionalSMS/sms', {
    method: 'POST',
    headers: {
      'api-key': apiKey,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      sender,
      recipient: normalized,
      content: body,
      type: 'transactional',
      unicodeEnabled: true,
    }),
  });

  if (!res.ok) {
    const txt = await res.text();
    console.error('[SMS] Brevo error:', txt);
    const err = new Error('Το SMS δεν στάλθηκε');
    err.status = 502;
    throw err;
  }
  console.log(`[SMS] Sent to ${normalized}`);
  return { ok: true };
}

module.exports = { sendSms };
