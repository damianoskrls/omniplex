const crypto = require('crypto');
const db = require('../db');

const GREEK = /[\u0370-\u03FF\u1F00-\u1FFF]/;

function hasGreek(text) {
  return GREEK.test(String(text || ''));
}

function hashText(text) {
  return crypto.createHash('sha256').update(String(text), 'utf8').digest('hex');
}

const SYSTEM = `You translate a gym and fitness mobile app from Greek to English.
The user sends JSON: {"items":["..."]}.
Reply with JSON only, no markdown: {"items":["..."]} with the same length and order.
Write natural, concise English a gym member would read.
Keep emoji, numbers, prices, dates, phone numbers, emails, and text that is already English unchanged.
Write Greek place names and people's names in Latin letters (Κηφισιά → Kifisia).
Do not add notes or extra items.`;

async function completeJson(userPayload) {
  const openaiKey = process.env.OPENAI_API_KEY;
  const anthropicKey = process.env.ANTHROPIC_API_KEY;
  if (!openaiKey && !anthropicKey) {
    const err = new Error('NO_AI_KEY');
    err.code = 'NO_AI_KEY';
    throw err;
  }

  if (openaiKey) {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${openaiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        temperature: 0.2,
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: SYSTEM },
          { role: 'user', content: JSON.stringify({ items: userPayload }) },
        ],
      }),
    });
    const data = await response.json();
    if (!response.ok) {
      throw new Error(data?.error?.message || 'OpenAI error');
    }
    return parseItems(data.choices?.[0]?.message?.content || '', userPayload.length);
  }

  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': anthropicKey,
      'anthropic-version': '2023-06-01',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 4096,
      temperature: 0.2,
      system: SYSTEM,
      messages: [{ role: 'user', content: JSON.stringify({ items: userPayload }) }],
    }),
  });
  const data = await response.json();
  if (!response.ok) {
    throw new Error(data?.error?.message || 'Anthropic error');
  }
  const text = (data.content || []).map((b) => b.text || '').join('');
  return parseItems(text, userPayload.length);
}

function parseItems(raw, expected) {
  let cleaned = String(raw || '').trim();
  cleaned = cleaned.replace(/^```(?:json)?/i, '').replace(/```$/, '').trim();
  const parsed = JSON.parse(cleaned);
  const items = Array.isArray(parsed) ? parsed : parsed.items;
  if (!Array.isArray(items) || items.length !== expected) {
    throw new Error('Translation response length mismatch');
  }
  return items.map((item) => (item == null ? '' : String(item)));
}

async function loadCached(texts) {
  const found = new Map();
  if (!texts.length) return found;
  const hashes = texts.map(hashText);
  const marks = hashes.map(() => '?').join(',');
  const [rows] = await db.query(
    `SELECT source_hash, translated_text FROM ai_translations
     WHERE target_lang = 'en' AND source_hash IN (${marks})`,
    hashes,
  );
  const byHash = new Map(rows.map((row) => [row.source_hash, row.translated_text]));
  texts.forEach((text) => {
    const hit = byHash.get(hashText(text));
    if (hit) found.set(text, hit);
  });
  return found;
}

async function storeTranslation(source, translated) {
  await db.query(
    `INSERT INTO ai_translations (source_hash, target_lang, source_text, translated_text)
     VALUES (?, 'en', ?, ?)
     ON DUPLICATE KEY UPDATE translated_text = VALUES(translated_text)`,
    [hashText(source), source, translated],
  );
}

async function translateToEnglish(texts) {
  const unique = [];
  const seen = new Set();
  for (const value of texts) {
    const text = String(value ?? '');
    if (!text || !hasGreek(text) || seen.has(text)) continue;
    seen.add(text);
    unique.push(text.slice(0, 2000));
  }

  const out = new Map();
  if (!unique.length) return out;

  const cached = await loadCached(unique);
  cached.forEach((value, key) => out.set(key, value));
  const missing = unique.filter((text) => !out.has(text));

  const chunkSize = 20;
  for (let i = 0; i < missing.length; i += chunkSize) {
    const chunk = missing.slice(i, i + chunkSize);
    const translated = await completeJson(chunk);
    for (let n = 0; n < chunk.length; n += 1) {
      const source = chunk[n];
      const value = (translated[n] || '').trim() || source;
      out.set(source, value);
      if (value && value !== source) {
        await storeTranslation(source, value);
      }
    }
  }
  return out;
}

module.exports = { translateToEnglish, hasGreek };
