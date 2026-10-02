const express = require('express');
const { translateToEnglish, hasGreek } = require('../lib/translate');

const router = express.Router();

const hits = new Map();

function rateLimit(ip) {
  const now = Date.now();
  const recent = (hits.get(ip) || []).filter((t) => now - t < 60_000);
  if (recent.length >= 40) return false;
  recent.push(now);
  hits.set(ip, recent);
  return true;
}

// POST /api/i18n/translate  { texts: string[], target?: 'en' }
router.post('/translate', async (req, res) => {
  const ip = req.ip || req.headers['x-forwarded-for'] || 'local';
  if (!rateLimit(String(ip))) {
    return res.status(429).json({ error: 'Too many translation requests' });
  }

  const target = req.body?.target || 'en';
  const texts = Array.isArray(req.body?.texts) ? req.body.texts : null;
  if (!texts || target !== 'en') {
    return res.status(400).json({ error: 'Send { target: "en", texts: [...] }' });
  }
  if (texts.length > 40) {
    return res.status(400).json({ error: 'At most 40 texts per request' });
  }

  const clean = texts.map((item) => String(item ?? '').slice(0, 2000));
  const translations = {};
  clean.forEach((text) => {
    if (!hasGreek(text)) translations[text] = text;
  });

  try {
    const mapped = await translateToEnglish(clean);
    mapped.forEach((value, key) => {
      translations[key] = value;
    });
    res.json({ translations });
  } catch (err) {
    if (err.code === 'NO_AI_KEY') {
      return res.status(503).json({ error: 'Translation is not configured' });
    }
    console.error('[i18n]', err.message);
    res.status(500).json({ error: 'Translation failed' });
  }
});

module.exports = router;
