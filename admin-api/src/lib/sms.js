'use strict';

async function sendSms(to, body) {
  const apiKey = process.env.BREVO_API_KEY;
  const sender = process.env.BREVO_SMS_SENDER || 'Handstand';

  if (!apiKey) {
    console.log(`[SMS] (not configured) → ${to}: ${body}`);
    return;
  }

  // Normalize to E.164 (Greek numbers: 69XXXXXXXX → +3069XXXXXXXX)
  let normalized = String(to).replace(/[\s\-().]/g, '');
  if (!normalized.startsWith('+')) {
    normalized = '+30' + normalized.replace(/^0+/, '');
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
    }),
  });

  if (!res.ok) {
    const txt = await res.text();
    console.error('[SMS] Brevo error:', txt);
  } else {
    console.log(`[SMS] Sent to ${normalized}`);
  }
}

module.exports = { sendSms };
