'use strict';

async function sendEmail({ to, toName, subject, htmlContent, textContent }) {
  const apiKey = process.env.BREVO_API_KEY;
  const senderEmail = process.env.BREVO_SENDER_EMAIL || 'noreply@handstand.gr';
  const senderName  = process.env.BREVO_SENDER_NAME  || 'Handstand';

  if (!apiKey) {
    console.log(`[EMAIL] (not configured) → ${to}: ${subject}`);
    return { ok: true, simulated: true };
  }

  const res = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: { 'api-key': apiKey, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      sender: { name: senderName, email: senderEmail },
      to: [{ email: to, name: toName || to }],
      subject,
      htmlContent: htmlContent || `<p>${textContent || ''}</p>`,
      textContent,
    }),
  });

  if (!res.ok) {
    const txt = await res.text();
    console.error('[EMAIL] Brevo error:', txt);
    throw new Error(txt);
  }
  console.log(`[EMAIL] Sent to ${to}: ${subject}`);
  return { ok: true };
}

module.exports = { sendEmail };
