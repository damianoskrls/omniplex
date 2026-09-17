// AI Agent route — per-tenant gym assistant
// POST /api/ai/:bizId/chat
// Body: { messages: [{role, content}], locale?: 'el'|'en' }
// Auth: mobile JWT (req.user.userId)

const express  = require('express');
const Anthropic = require('@anthropic-ai/sdk');
const db       = require('../db');
const { authenticate } = require('../middleware/auth');
const { createOneBooking } = require('../lib/create_booking');

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
  const [rows] = await db.query(
    `SELECT s.id, s.name, s.category, s.duration_minutes, s.color_hex,
            s.capacity, s.is_active,
            (SELECT COUNT(*) FROM memberships m
               JOIN plan_service_items psi ON psi.membership_plan_id = m.plan_id
               JOIN services s2 ON s2.id = psi.service_id AND s2.id = s.id
             WHERE m.user_id = ? AND m.business_id = ? AND m.status = 'active'
            ) AS has_plan_access
     FROM services s
     WHERE s.business_id = ? AND s.is_active = 1
     ${input.category ? 'AND s.category = ?' : ''}
     ORDER BY s.category, s.name`,
    input.category
      ? [userId, bizId, bizId, input.category]
      : [userId, bizId, bizId],
  );
  return rows.map(r => ({
    id: r.id,
    name: r.name,
    category: r.category,
    duration_minutes: r.duration_minutes,
    color: r.color_hex,
    has_plan_access: r.has_plan_access > 0,
  }));
}

async function execCheckAvailability(bizId, userId, input) {
  const date = dateFromRelative(input.date) || input.date;
  const [slots] = await db.query(
    `SELECT ss.id, ss.start_time, ss.end_time, ss.staff_id,
            CONCAT(st.first_name, ' ', st.last_name) AS staff_name,
            ss.capacity,
            (SELECT COUNT(*) FROM bookings b WHERE b.schedule_slot_id = ss.id AND b.status NOT IN ('cancelled','no_show')) AS booked_count
     FROM schedule_slots ss
     LEFT JOIN staff st ON st.id = ss.staff_id
     WHERE ss.business_id = ? AND ss.service_id = ? AND ss.slot_date = ?
       AND ss.is_active = 1
     ORDER BY ss.start_time`,
    [bizId, input.service_id, date],
  );

  const available = slots.filter(s => s.booked_count < s.capacity);
  return {
    date,
    service_id: input.service_id,
    slots: available.map(s => ({
      time: s.start_time.slice(0, 5),
      end_time: s.end_time.slice(0, 5),
      staff_id: s.staff_id,
      staff_name: s.staff_name,
      spots_left: s.capacity - s.booked_count,
    })),
    total_slots: slots.length,
    available_count: available.length,
  };
}

async function execCreateBooking(bizId, userId, input) {
  const date = dateFromRelative(input.date) || input.date;
  const conn = await db.getConnection();
  try {
    const result = await createOneBooking(conn, {
      businessId: bizId,
      userId,
      serviceId: input.service_id,
      date,
      time: input.time,
      staffId: input.staff_id || null,
      useCredit: input.use_credit !== false,
      source: 'ai_agent',
    });
    return { success: true, booking_id: result.bookingId, date, time: input.time };
  } finally {
    conn.release();
  }
}

async function execGetMyBookings(bizId, userId, input) {
  const limit = input.limit || 5;
  const [rows] = await db.query(
    `SELECT b.id, b.booking_date, b.booking_time, b.status,
            s.name AS service_name, s.duration_minutes,
            CONCAT(st.first_name, ' ', st.last_name) AS staff_name
     FROM bookings b
     JOIN services s ON s.id = b.service_id
     LEFT JOIN staff st ON st.id = b.staff_id
     WHERE b.user_id = ? AND b.business_id = ?
       AND b.booking_date >= CURDATE()
       AND b.status NOT IN ('cancelled','no_show')
     ORDER BY b.booking_date, b.booking_time
     LIMIT ?`,
    [userId, bizId, limit],
  );
  return rows.map(r => ({
    id: r.id,
    date: r.booking_date instanceof Date
      ? r.booking_date.toISOString().slice(0, 10)
      : String(r.booking_date).slice(0, 10),
    time: String(r.booking_time).slice(0, 5),
    service: r.service_name,
    duration: r.duration_minutes,
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
  const [rows] = await db.query(
    `SELECT b.name, b.address, b.phone, b.email, b.description,
            (SELECT JSON_ARRAYAGG(JSON_OBJECT('day', oh.day_of_week, 'open', oh.open_time, 'close', oh.close_time))
             FROM opening_hours oh WHERE oh.business_id = b.id) AS hours
     FROM businesses b WHERE b.id = ?`,
    [bizId],
  );
  if (!rows.length) return { error: 'Gym not found' };
  const r = rows[0];
  return {
    name: r.name,
    address: r.address,
    phone: r.phone,
    email: r.email,
    description: r.description,
    opening_hours: r.hours ? JSON.parse(r.hours) : [],
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
  return `You are the AI fitness assistant for ${gymName}. You help members with bookings, cancellations, schedules, and general gym questions.

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

router.post('/:bizId/chat', authenticate, async (req, res) => {

  const { bizId } = req.params;
  const { messages = [], locale = 'el' } = req.body;
  const userId = req.user.userId;

  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    return res.status(503).json({ error: 'AI service not configured' });
  }

  try {
    // Fetch gym name + user name
    const [[gymRow]] = await db.query(
      'SELECT name FROM businesses WHERE id = ?', [bizId],
    );
    const [[userRow]] = await db.query(
      'SELECT full_name FROM users WHERE id = ?', [userId],
    );
    const gymName  = gymRow?.name  || 'Gym';
    const userName = userRow?.full_name || '';

    const client = new Anthropic({ apiKey });

    // Agentic loop: keep going until no more tool_use blocks
    let currentMessages = messages.map(m => ({
      role: m.role,
      content: typeof m.content === 'string' ? m.content : m.content,
    }));

    let finalText = null;
    const MAX_ITERATIONS = 8;

    for (let i = 0; i < MAX_ITERATIONS; i++) {
      const response = await client.messages.create({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 1024,
        system: buildSystemPrompt(gymName, locale, userName),
        tools: TOOLS,
        messages: currentMessages,
      });

      if (response.stop_reason === 'end_turn') {
        // Collect text
        const textBlock = response.content.find(b => b.type === 'text');
        finalText = textBlock?.text || '';
        break;
      }

      if (response.stop_reason === 'tool_use') {
        // Add assistant message
        currentMessages.push({ role: 'assistant', content: response.content });

        // Execute all tool calls in parallel
        const toolResults = await Promise.all(
          response.content
            .filter(b => b.type === 'tool_use')
            .map(async (toolBlock) => {
              let result;
              try {
                result = await executeTool(toolBlock.name, toolBlock.input, bizId, userId);
              } catch (err) {
                result = { error: err.message || 'Tool execution failed' };
              }
              return {
                type: 'tool_result',
                tool_use_id: toolBlock.id,
                content: JSON.stringify(result),
              };
            }),
        );

        currentMessages.push({ role: 'user', content: toolResults });
        continue;
      }

      // Unexpected stop reason
      break;
    }

    res.json({ reply: finalText || '' });
  } catch (err) {
    console.error('[AI Agent]', err.message);
    res.status(500).json({ error: 'AI agent error', detail: err.message });
  }
});

module.exports = router;
