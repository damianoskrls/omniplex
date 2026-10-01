// AI Agent route — per-tenant gym assistant
// POST /api/ai/:bizId/chat
// Body: { messages: [{role, content}], locale?: 'el'|'en' }
// Auth: mobile JWT (req.user.userId)

const express  = require('express');
const Anthropic = require('@anthropic-ai/sdk');
const db       = require('../db');
const jwt = require('jsonwebtoken');

function mobileAuth(req, res, next) {
  const header = req.headers['authorization'];
  if (!header) return res.status(401).json({ error: 'No token' });
  const token = header.startsWith('Bearer ') ? header.slice(7) : header;
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'secret');
    req.user = decoded;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}
const { createOneBooking } = require('../lib/create_booking');
const { computeAvailableSlots, buildSlotsPayload } = require('../lib/slots');

const router = express.Router();

// ── helpers ──────────────────────────────────────────────────────────────────

function today() {
  return new Date().toISOString().slice(0, 10);
}

function dateFromRelative(expr) {
  // Parses "αύριο", "tomorrow", "σήμερα", "today", or YYYY-MM-DD
  const d = new Date();
  const lower = (expr || '').toLowerCase().trim();
  if (lower === 'αύριο' || lower === 'tomorrow') {
    d.setDate(d.getDate() + 1);
    return d.toISOString().slice(0, 10);
  }
  if (lower === 'σήμερα' || lower === 'today') {
    return d.toISOString().slice(0, 10);
  }
  // YYYY-MM-DD passthrough
  if (/^\d{4}-\d{2}-\d{2}$/.test(lower)) return lower;
  return null;
}

// ── tool definitions ──────────────────────────────────────────────────────────

const TOOLS = [
  {
    name: 'get_services',
    description: 'Returns all active services/classes the gym offers with their id, name, category, duration, and whether the user has credits for them.',
    input_schema: {
      type: 'object',
      properties: {
        category: { type: 'string', description: 'Optional category filter (e.g. "Group Fitness")' },
      },
      required: [],
    },
  },
  {
    name: 'check_availability',
    description: 'Returns available time slots for a given service on a given date. Use this before booking to show the user their options.',
    input_schema: {
      type: 'object',
      properties: {
        service_id: { type: 'string', description: 'The service id (from get_services)' },
        date: { type: 'string', description: 'ISO date YYYY-MM-DD. You may also pass "today" or "tomorrow" and the server resolves it.' },
      },
      required: ['service_id', 'date'],
    },
  },
  {
    name: 'create_booking',
    description: 'Creates a booking for the user. Only call this after the user has explicitly confirmed the slot they want.',
    input_schema: {
      type: 'object',
      properties: {
        service_id: { type: 'string', description: 'Service id' },
        date: { type: 'string', description: 'YYYY-MM-DD' },
        time: { type: 'string', description: 'HH:MM (24h)' },
        staff_id: { type: 'string', description: 'Optional staff/trainer id from the slot' },
        use_credit: { type: 'boolean', description: 'Whether to deduct a credit. Default true.' },
      },
      required: ['service_id', 'date', 'time'],
    },
  },
  {
    name: 'get_my_bookings',
    description: 'Returns the user\'s upcoming bookings.',
    input_schema: {
      type: 'object',
      properties: {
        limit: { type: 'integer', description: 'Max number of bookings to return (default 5)' },
      },
      required: [],
    },
  },
  {
    name: 'cancel_booking',
    description: 'Cancels a booking. Only call after the user confirms which booking to cancel.',
    input_schema: {
      type: 'object',
      properties: {
        booking_id: { type: 'string', description: 'The booking id to cancel' },
      },
      required: ['booking_id'],
    },
  },
  {
    name: 'get_gym_info',
    description: 'Returns general gym info: name, opening hours, address, contact.',
    input_schema: {
      type: 'object',
      properties: {},
      required: [],
    },
  },
];

// ── tool executors ─────────────────────────────────────────────────────────────

async function execGetServices(bizId, userId, input) {
  const params = [bizId];
  let categorySql = '';
  if (input.category) {
    categorySql = 'AND s.category = ?';
    params.push(input.category);
  }
  const [rows] = await db.query(
    `SELECT s.id, s.name, s.category, s.duration_mins, s.description
     FROM services s
     WHERE s.business_id = ? AND s.is_active = 1
       AND (s.category IS NULL OR s.category NOT IN ('nutrition', 'nutrition_consultation'))
       ${categorySql}
     ORDER BY s.category, s.name`,
    params,
  );
  let accessIds = new Set();
  try {
    const [access] = await db.query(
      `SELECT DISTINCT s.id
       FROM services s
       JOIN user_memberships um ON um.user_id = ? AND um.business_id = ?
         AND (um.valid_until IS NULL OR um.valid_until >= CURDATE())
         AND (um.membership_status IS NULL OR um.membership_status IN ('active', 'trial'))
       LEFT JOIN plan_service_items psi ON (psi.plan_id COLLATE utf8mb4_unicode_ci) = (um.plan_id COLLATE utf8mb4_unicode_ci)
       LEFT JOIN service_plan_assignments spa ON (spa.plan_id COLLATE utf8mb4_unicode_ci) = (um.plan_id COLLATE utf8mb4_unicode_ci)
       WHERE s.business_id = ?
         AND (
           (um.service_id COLLATE utf8mb4_unicode_ci) = (s.id COLLATE utf8mb4_unicode_ci)
           OR (psi.service_id COLLATE utf8mb4_unicode_ci) = (s.id COLLATE utf8mb4_unicode_ci)
           OR (spa.service_id COLLATE utf8mb4_unicode_ci) = (s.id COLLATE utf8mb4_unicode_ci)
         )`,
      [userId, bizId, bizId],
    );
    accessIds = new Set(access.map((row) => row.id));
  } catch (err) {
    console.error('ai get_services access skipped:', err.message);
  }
  return rows.map(r => ({
    id: r.id,
    name: r.name,
    category: r.category,
    duration_minutes: r.duration_mins,
    description: r.description,
    has_plan_access: accessIds.has(r.id),
  }));
}

async function execCheckAvailability(bizId, userId, input) {
  const date = dateFromRelative(input.date) || input.date;
  try {
    const computed = await computeAvailableSlots(db, bizId, input.service_id, date, null, null);
    if (!computed) return { date, slots: [], error: 'Service not found' };
    if (computed.closedReason) return { date, slots: [], message: 'Gym is closed on this day.' };

    const payload = buildSlotsPayload(computed, { featureWaitlist: false, date });
    const durationMins = payload.duration_mins;
    return {
      date,
      service_id: input.service_id,
      slots: (payload.slots || []).map(s => {
        const firstStaff = s.available_staff?.[0] || null;
        return {
          time: s.time,
          end_time: s.time && durationMins
            ? (() => {
                const [h, m] = s.time.split(':').map(Number);
                const endMins = h * 60 + m + durationMins;
                return `${String(Math.floor(endMins / 60)).padStart(2, '0')}:${String(endMins % 60).padStart(2, '0')}`;
              })()
            : null,
          staff_id: firstStaff?.id || null,
          staff_name: firstStaff?.name || null,
          spots_left: s.remaining_spots ?? s.capacity,
        };
      }),
      available_count: (payload.slots || []).length,
    };
  } catch (err) {
    return { date, slots: [], error: err.message };
  }
}

async function execCreateBooking(bizId, userId, input) {
  const date = dateFromRelative(input.date) || input.date;
  const conn = await db.getConnection();
  try {
    const result = await createOneBooking(conn, {
      bizId,
      userId,
      service_id: input.service_id,
      date,
      time: input.time,
      staff_id: input.staff_id || null,
      use_credit: input.use_credit !== false,
      source: 'ai_agent',
    });
    return { success: true, booking_id: result.booking_id, service: result.service, date, time: input.time };
  } finally {
    conn.release();
  }
}

async function execGetMyBookings(bizId, userId, input) {
  const limit = input.limit || 5;
  const [rows] = await db.query(
    `SELECT b.id, b.starts_at, b.ends_at, b.status,
            s.name AS service_name, s.duration_mins AS duration_mins,
            st.full_name AS staff_name
     FROM bookings b
     JOIN services s ON s.id = b.service_id
     LEFT JOIN staff st ON st.id = b.staff_id
     WHERE b.user_id = ? AND b.business_id = ?
       AND b.starts_at >= NOW()
       AND b.status NOT IN ('cancelled','no_show')
     ORDER BY b.starts_at
     LIMIT ?`,
    [userId, bizId, limit],
  );
  return rows.map(r => ({
    id: r.id,
    date: r.starts_at instanceof Date
      ? r.starts_at.toISOString().slice(0, 10)
      : String(r.starts_at).slice(0, 10),
    time: r.starts_at instanceof Date
      ? r.starts_at.toTimeString().slice(0, 5)
      : String(r.starts_at).slice(11, 16),
    service: r.service_name,
    duration: r.duration_mins,
    staff: r.staff_name,
    status: r.status,
  }));
}

async function execCancelBooking(bizId, userId, input) {
  const [rows] = await db.query(
    'SELECT id FROM bookings WHERE id = ? AND user_id = ? AND business_id = ? AND status NOT IN (\'cancelled\',\'no_show\')',
    [input.booking_id, userId, bizId],
  );
  if (!rows.length) return { success: false, error: 'Booking not found or already cancelled.' };
  await db.query(
    'UPDATE bookings SET status = \'cancelled\' WHERE id = ?',
    [input.booking_id],
  );
  return { success: true, booking_id: input.booking_id };
}

async function execGetGymInfo(bizId) {
  const [[biz]] = await db.query('SELECT name FROM businesses WHERE id = ?', [bizId]);
  if (!biz) return { error: 'Gym not found' };
  let hours = [];
  try {
    const [rows] = await db.query(
      'SELECT day_of_week, open_time, close_time, is_closed FROM opening_hours WHERE business_id = ? ORDER BY day_of_week',
      [bizId],
    );
    hours = rows;
  } catch (_) {}
  let locations = [];
  try {
    const [rows] = await db.query(
      'SELECT name, address FROM locations WHERE business_id = ? AND is_active = 1',
      [bizId],
    );
    locations = rows;
  } catch (_) {}
  return {
    name: biz.name,
    locations,
    opening_hours: hours,
  };
}

async function executeTool(name, input, bizId, userId) {
  switch (name) {
    case 'get_services':       return execGetServices(bizId, userId, input);
    case 'check_availability': return execCheckAvailability(bizId, userId, input);
    case 'create_booking':     return execCreateBooking(bizId, userId, input);
    case 'get_my_bookings':    return execGetMyBookings(bizId, userId, input);
    case 'cancel_booking':     return execCancelBooking(bizId, userId, input);
    case 'get_gym_info':       return execGetGymInfo(bizId);
    default:                   return { error: `Unknown tool: ${name}` };
  }
}

// ── system prompt ─────────────────────────────────────────────────────────────

function buildSystemPrompt(gymName, locale, userName) {
  const lang = locale === 'en' ? 'English' : 'Greek';
  const today_str = today();
  const agentName = `${gymName} Βοηθός`;
  return `You are ${agentName}, the AI assistant for ${gymName}. You help members with bookings, cancellations, schedules, and general questions.

TODAY'S DATE: ${today_str}
MEMBER NAME: ${userName || 'Member'}
LANGUAGE: Always reply in ${lang}.

PERSONALITY:
- Friendly, energetic, concise.
- Use short paragraphs. Never write walls of text.
- For bookings: always confirm the specific slot before creating it.
- If multiple slots are available, present them as a numbered list and ask the user to choose.
- After creating or cancelling a booking, confirm with a brief summary.
- If an action fails, explain clearly and suggest alternatives.

IMPORTANT:
- Never invent slots or services — always call the relevant tool first.
- Do not call create_booking until the user explicitly picks a time/slot.
- When presenting slots, use a clean readable format: "1. 10:00 – 11:00 (με τον/την Γιώργο, 3 θέσεις)"
`;
}

// ── route ─────────────────────────────────────────────────────────────────────

function openaiTools() {
  return TOOLS.map((tool) => ({
    type: 'function',
    function: {
      name: tool.name,
      description: tool.description,
      parameters: tool.input_schema,
    },
  }));
}

async function runAnthropic(apiKey, { system, messages, bizId, userId }) {
  const client = new Anthropic({ apiKey });
  let currentMessages = messages.map((m) => ({
    role: m.role === 'assistant' ? 'assistant' : 'user',
    content: typeof m.content === 'string' ? m.content : String(m.content || ''),
  }));
  for (let i = 0; i < 8; i++) {
    const response = await client.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 1024,
      system,
      tools: TOOLS,
      messages: currentMessages,
    });
    if (response.stop_reason !== 'tool_use') {
      return response.content.find((b) => b.type === 'text')?.text || '';
    }
    currentMessages.push({ role: 'assistant', content: response.content });
    const toolResults = await Promise.all(
      response.content.filter((b) => b.type === 'tool_use').map(async (toolBlock) => {
        let result;
        try {
          result = await executeTool(toolBlock.name, toolBlock.input || {}, bizId, userId);
        } catch (err) {
          result = { error: err.message || 'Tool execution failed' };
        }
        return { type: 'tool_result', tool_use_id: toolBlock.id, content: JSON.stringify(result) };
      }),
    );
    currentMessages.push({ role: 'user', content: toolResults });
  }
  return '';
}

async function runOpenAI(apiKey, { system, messages, bizId, userId }) {
  const chat = [
    { role: 'system', content: system },
    ...messages.map((m) => ({
      role: m.role === 'assistant' ? 'assistant' : 'user',
      content: typeof m.content === 'string' ? m.content : String(m.content || ''),
    })),
  ];
  for (let i = 0; i < 8; i++) {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: chat,
        tools: openaiTools(),
        tool_choice: 'auto',
      }),
    });
    const data = await response.json();
    if (!response.ok) {
      throw new Error(data?.error?.message || 'OpenAI error');
    }
    const message = data.choices?.[0]?.message;
    const calls = message?.tool_calls || [];
    if (!calls.length) return message?.content || '';
    chat.push(message);
    for (const call of calls) {
      let args = {};
      try { args = JSON.parse(call.function?.arguments || '{}'); } catch (_) {}
      let result;
      try {
        result = await executeTool(call.function?.name, args, bizId, userId);
      } catch (err) {
        result = { error: err.message || 'Tool execution failed' };
      }
      chat.push({
        role: 'tool',
        tool_call_id: call.id,
        content: JSON.stringify(result),
      });
    }
  }
  return '';
}

router.post('/:bizId/chat', mobileAuth, async (req, res) => {

  const { bizId } = req.params;
  const { messages = [], locale = 'el' } = req.body;
  const userId = req.user.userId;
  const openaiKey = process.env.OPENAI_API_KEY;
  const anthropicKey = process.env.ANTHROPIC_API_KEY;
  if (!openaiKey && !anthropicKey) {
    return res.status(503).json({ error: 'Ο βοηθός δεν είναι ρυθμισμένος. Λείπει το OPENAI_API_KEY.' });
  }

  try {
    const [[gymRow]] = await db.query('SELECT name FROM businesses WHERE id = ?', [bizId]);
    const [[userRow]] = await db.query(
      'SELECT full_name FROM users WHERE id = ?', [userId],
    );
    const gymName  = gymRow?.name || 'Gym';
    const userName = userRow?.full_name || '';
    const system = buildSystemPrompt(gymName, locale, userName);
    const history = (Array.isArray(messages) ? messages : []).filter((m) => m && m.content);
    const reply = openaiKey
      ? await runOpenAI(openaiKey, { system, messages: history, bizId, userId })
      : await runAnthropic(anthropicKey, { system, messages: history, bizId, userId });

    res.json({ reply: reply || 'Δεν έχω απάντηση αυτή τη στιγμή. Δοκίμασε ξανά.' });
  } catch (err) {
    console.error('[AI Agent]', err.message);
    res.status(500).json({ error: err.message || 'Ο βοηθός δεν απάντησε.' });
  }
});

module.exports = router;
