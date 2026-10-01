function photoPrompt(svc) {
  const name = String(svc.name || 'gym class').slice(0, 80);
  const category = String(svc.category || 'training').slice(0, 40);
  const description = String(svc.description || '').slice(0, 180);
  return [
    'Photorealistic photograph of adult athletes training in a bright modern gym.',
    `Class: ${name}.`,
    `Category: ${category}.`,
    description ? `Details: ${description}.` : '',
    'Real people with natural skin, realistic lighting, and a sharp candid fitness-photo look.',
    'No text, letters, numbers, logos, watermarks, cartoons, or illustrations.',
  ].filter(Boolean).join(' ');
}

function extFor(contentType) {
  if (contentType === 'image/jpeg') return 'jpg';
  if (contentType === 'image/webp') return 'webp';
  return 'png';
}

async function readError(res) {
  const text = await res.text();
  try {
    const body = JSON.parse(text);
    return body.error?.message || body.error || text.slice(0, 240);
  } catch {
    return text.slice(0, 240);
  }
}

async function generateWithGemini(prompt, apiKey) {
  const res = await fetch(
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { responseModalities: ['IMAGE'] },
      }),
    },
  );
  if (!res.ok) throw new Error(await readError(res));
  const data = await res.json();
  const parts = data.candidates?.[0]?.content?.parts || [];
  const image = parts.find(p => p.inlineData?.data || p.inline_data?.data);
  const b64 = image?.inlineData?.data || image?.inline_data?.data;
  if (!b64) throw new Error('Το AI δεν επέστρεψε φωτογραφία');
  const contentType = image.inlineData?.mimeType || image.inline_data?.mime_type || 'image/png';
  return { buffer: Buffer.from(b64, 'base64'), contentType, ext: extFor(contentType) };
}

async function generateWithOpenAI(prompt, apiKey) {
  const res = await fetch('https://api.openai.com/v1/images/generations', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-image-1',
      prompt,
      size: '1024x1024',
      n: 1,
    }),
  });
  if (!res.ok) throw new Error(await readError(res));
  const data = await res.json();
  const item = data.data?.[0] || {};
  if (item.b64_json) {
    return { buffer: Buffer.from(item.b64_json, 'base64'), contentType: 'image/png', ext: 'png' };
  }
  if (item.url) {
    const img = await fetch(item.url);
    if (!img.ok) throw new Error('Η φωτογραφία δεν κατέβηκε');
    const contentType = img.headers.get('content-type') || 'image/png';
    return { buffer: Buffer.from(await img.arrayBuffer()), contentType, ext: extFor(contentType) };
  }
  throw new Error('Το AI δεν επέστρεψε φωτογραφία');
}

async function generateServicePhoto(svc) {
  const prompt = photoPrompt(svc);
  const gemini = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY;
  if (gemini) return generateWithGemini(prompt, gemini);
  if (process.env.OPENAI_API_KEY) return generateWithOpenAI(prompt, process.env.OPENAI_API_KEY);
  const err = new Error('Για κανονική φωτογραφία χρειάζεται GEMINI_API_KEY στο API.');
  err.status = 400;
  throw err;
}

module.exports = { generateServicePhoto };
