// ============================================================
// FILE: src/routes/booking.routes.js
// Smart booking endpoints:
//  - Available slots for a service on a date
//  - User credits check
//  - Create booking (deducts credit)
// ============================================================

const express = require('express');
const { v4: uuidv4 } = require('uuid');
const db = require('../db');
const {
  computeAvailableSlots,
  buildSlotsPayload,
  assertSlotCapacity,
  assertStaffAvailable,
  findStaffForSlot,
  isSlotBookableForDate,
  getOpeningHours,
} = require('../lib/slots');
const { joinWaitlist, notifyWaitlistOnCancel } = require('../lib/waitlist');
const { createAdminNotification } = require('../lib/notifications');
const { enrichBookingWithTips } = require('../lib/booking_tips');
const { normalizeWorkoutHealthPayload, mapBookingHealthFields, saveBookingWorkoutHealth } = require('../lib/workout_health');
const { createUserNotification } = require('../lib/user_notifications');
const {
  loadActiveOffer,
  businessHasDropinOffers,
  filterSlotsByOffer,
  buildDropinSlotMap,
  weekdayFromDate,
} = require('../lib/dropin_setup');
const {
  listClientThreads,
  listClientPeers,
  getClientThreadById,
  sendClientMessage,
  markClientThreadRead,
  getClientUnreadCount,
  openClientThread,
  parsePeerFromBody,
} = require('../lib/messages');
const {
  createMessageUpload,
  publicUploadPath,
  handleMessageUpload,
  saveMessageImageBuffer,
  parseBase64Image,
} = require('../lib/message_upload');
const { assertImageUploadAllowed } = require('../lib/message_attachments');
const { buildGymInfoPayload } = require('../lib/gym_info');
const { awardLoyaltyPoints, getUserStats, previewRewardPrice, applyRewardPrice } = require('../lib/loyalty');
const { mapPaymentRow } = require('../lib/payments');
const { createOneBooking, assertNoUserBookingConflict } = require('../lib/create_booking');
const {
  enrichMembershipLifecycle,
  getGracePeriodDays,
} = require('../lib/membership_lifecycle');
const { findAlternativeSlot } = require('../lib/slot_alternatives');
const {
  isMultiLocationEnabled,
  listLocations,
  listLocationsForService,
  resolveLocationId,
  getLocationOpeningHours,
} = require('../lib/locations');

const router = express.Router();

// ── Middleware: soft auth (attach user if token present) ──────
const jwt = require('jsonwebtoken');
function softAuth(req, res, next) {
  const header = req.headers['authorization'];
  if (header) {
    const token = header.startsWith('Bearer ') ? header.slice(7) : header;
    try {
      req.user = jwt.verify(token, process.env.JWT_SECRET);
    } catch (_) {}
  }
  next();
}

const { requireActiveCustomer } = require('../lib/customer_auth');

/**
 * Best matching active membership for a service.
 * planToServiceId: Map<plan_id, service_id> from service_plan_assignments.
 */
function findMembershipForService(memberships, service, planToServiceId = new Map(), planServiceItems = new Map()) {
  const sid = String(service.id);

  // Direct service_id match
  const byServiceId = memberships.find(m => m.service_id && String(m.service_id) === sid);
  if (byServiceId) return byServiceId;

  // Combo plan match via plan_service_items (multi-service plans)
  const byCombo = memberships.find(m => {
    if (!m.plan_id) return false;
    const items = planServiceItems.get(m.plan_id);
    return items ? items.some(i => String(i.service_id) === sid) : false;
  });
  if (byCombo) return byCombo;

  // Simple plan match via service_plan_assignments
  const byPlan = memberships.find(m => {
    if (!m.plan_id) return false;
    return planToServiceId.get(m.plan_id) === sid;
  });
  if (byPlan) return byPlan;

  const byCategory = memberships.find(m =>
    !m.service_id && !m.plan_id && m.service_category && m.service_category === service.category
  );
  if (byCategory) return byCategory;

  return memberships.find(m => !m.service_id && !m.plan_id && !m.service_category) || null;
}

async function loadPlanServiceMap(memberships) {
  const planIds = [...new Set(memberships.map(m => m.plan_id).filter(Boolean))];
  if (!planIds.length) return new Map();
  const [rows] = await db.query(
    'SELECT plan_id, service_id FROM service_plan_assignments WHERE plan_id IN (?)',
    [planIds]
  );
  return new Map(rows.map(r => [r.plan_id, String(r.service_id)]));
}

// Load per-service session limits for combo plans
async function loadPlanServiceItems(planIds) {
  if (!planIds.length) return new Map();
  const [rows] = await db.query(
    `SELECT psi.plan_id, psi.service_id, psi.sessions, s.name AS service_name
     FROM plan_service_items psi LEFT JOIN services s ON s.id = psi.service_id
     WHERE psi.plan_id IN (?) ORDER BY psi.sort_order`,
    [planIds]
  );
  const map = new Map();
  for (const r of rows) {
    if (!map.has(r.plan_id)) map.set(r.plan_id, []);
    map.get(r.plan_id).push({ service_id: String(r.service_id), sessions: r.sessions, service_name: r.service_name });
  }
  return map;
}

// Count bookings per service this calendar month for given membership ids
async function loadMonthlyUsage(userId, membershipIds) {
  if (!membershipIds.length) return {};
  const monthStart = new Date();
  monthStart.setDate(1);
  monthStart.setHours(0, 0, 0, 0);
  const [rows] = await db.query(
    `SELECT membership_id, service_id, COUNT(*) AS cnt FROM bookings
     WHERE user_id = ? AND membership_id IN (?) AND starts_at >= ?
     AND status NOT IN ('cancelled', 'no_show')
     GROUP BY membership_id, service_id`,
    [userId, membershipIds, monthStart]
  );
  const map = {};
  for (const r of rows) map[`${r.membership_id}:${r.service_id}`] = Number(r.cnt);
  return map;
}

function mapServiceWithCredits(s, memberships, planToServiceId, planServiceItems = new Map(), monthlyUsage = {}) {
  const credit = findMembershipForService(memberships, s, planToServiceId, planServiceItems);
  let { remaining, canBook, hasMembership, isUnlimited } = membershipCredits(credit);

  // Per-service session limit from combo plan
  if (credit && credit.plan_id && planServiceItems.has(credit.plan_id)) {
    const items = planServiceItems.get(credit.plan_id);
    const item = items.find(i => String(i.service_id) === String(s.id));
    if (item) {
      if (item.sessions === null) {
        isUnlimited = true;
        remaining = 9999;
        canBook = true;
      } else {
        const used = monthlyUsage[`${credit.id}:${s.id}`] || 0;
        remaining = Math.max(0, item.sessions - used);
        isUnlimited = false;
        canBook = remaining > 0;
      }
    }
  }

  return {
    ...s,
    hide_staff_selection: !!s.hide_staff_selection,
    credits_remaining:   remaining,
    credits_valid_until: credit ? credit.valid_until : null,
    membership_id:       credit ? credit.id : null,
    has_membership:      hasMembership,
    is_unlimited:        isUnlimited,
    can_book:            hasMembership && canBook,
  };
}

function membershipCredits(credit) {
  if (!credit) {
    return { remaining: 0, isUnlimited: false, canBook: false, hasMembership: false };
  }
  const isUnlimited = credit.total_sessions >= 9999;
  const remaining   = isUnlimited ? 9999 : Math.max(0, credit.remaining_sessions);
  const canBook     = isUnlimited || remaining > 0;
  return { remaining, isUnlimited, canBook, hasMembership: true };
}

function isMembershipActive(credit) {
  if (!credit) return false;
  if (credit.valid_until && new Date(credit.valid_until) < new Date()) return false;
  return true;
}

// ============================================================
// GET /api/booking/:bizId/locations?service_id=
// ============================================================
router.get('/:bizId/locations', softAuth, async (req, res) => {
  try {
    const multi = await isMultiLocationEnabled(db, req.params.bizId);
    const userId = req.user?.userId || null;
    const { service_id } = req.query;

    let locations;
    if (service_id) {
      locations = await listLocationsForService(db, req.params.bizId, service_id, { userId });
    } else {
      locations = await listLocations(db, req.params.bizId, { activeOnly: true, userId });
    }

    return res.json({
      multi_location: multi,
      locations,
    });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// GET /api/booking/:bizId/services
// Returns services with credit info for logged-in user
// ============================================================
router.get('/:bizId/services', softAuth, async (req, res) => {
  try {
    const [services] = await db.query(
      'SELECT * FROM services WHERE business_id = ? AND is_active = 1 ORDER BY category, name',
      [req.params.bizId]
    );

    if (req.user) {
      const userId = req.user.userId;
      const [memberships] = await db.query(`
        SELECT id, plan_id, service_id, service_category,
               total_sessions, used_sessions,
               (total_sessions - used_sessions) AS remaining_sessions,
               valid_until
        FROM user_memberships
        WHERE user_id = ? AND business_id = ?
          AND valid_until >= CURDATE()
      `, [userId, req.params.bizId]);

      const activeMemberships = memberships.filter(isMembershipActive);
      const planToServiceId = await loadPlanServiceMap(activeMemberships);

      // Per-service limits for combo plans
      const planIds = [...new Set(activeMemberships.map(m => m.plan_id).filter(Boolean))];
      const planServiceItems = await loadPlanServiceItems(planIds);
      const comboMembershipIds = activeMemberships.filter(m => m.plan_id && planServiceItems.has(m.plan_id)).map(m => m.id);
      const monthlyUsage = await loadMonthlyUsage(userId, comboMembershipIds);

      return res.json(
        services
          .filter(s => s.category !== 'nutrition_consultation' && s.category !== 'nutrition')
          .map(s => mapServiceWithCredits(s, activeMemberships, planToServiceId, planServiceItems, monthlyUsage))
          .filter(s => s.has_membership)
      );
    }

    return res.json([]);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
});

const {
  listExtraServices,
  loadPlanForBusiness,
  grantPlanMembership,
  memberCoveredServiceIds,
} = require('../lib/member_plan_purchase');

function requireCustomer(req, res) {
  if (!req.user?.userId || req.user.role === 'trainer') {
    res.status(401).json({ error: 'Συνδέσου ως μέλος για να προσθέσεις υπηρεσία' });
    return false;
  }
  if (req.user.businessId && req.user.businessId !== req.params.bizId) {
    res.status(403).json({ error: 'Λάθος γυμναστήριο' });
    return false;
  }
  return true;
}

// Services the member does not already have, with packages they can buy.
router.get('/:bizId/extra-services', softAuth, async (req, res) => {
  if (!requireCustomer(req, res)) return;
  try {
    const bizId = req.params.bizId;
    const userId = req.user.userId;
    const services = await listExtraServices(db, bizId, userId);
    const [pending] = await db.query(
      `SELECT plan_id, kind FROM plan_purchase_requests
       WHERE business_id = ? AND user_id = ? AND status = 'pending'`,
      [bizId, userId],
    ).catch(() => [[]]);
    const pendingByPlan = new Map((pending || []).map((row) => [row.plan_id, row.kind]));
    for (const service of services) {
      for (const plan of service.plans || []) {
        plan.pending_kind = pendingByPlan.get(plan.id) || null;
      }
    }
    const [[prov]] = await db.query(
      'SELECT config FROM payment_providers WHERE business_id = ? AND is_active = 1 LIMIT 1',
      [bizId],
    );
    let stripeReady = false;
    if (prov?.config) {
      const cfg = typeof prov.config === 'string' ? JSON.parse(prov.config) : prov.config;
      stripeReady = !!(cfg.secret_key && cfg.publishable_key);
    }
    return res.json({ services, stripe_ready: stripeReady });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

function athensParts(now = new Date()) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Europe/Athens',
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
  }).formatToParts(now);
  const get = (type) => parts.find((p) => p.type === type)?.value || '00';
  return {
    date: `${get('year')}-${get('month')}-${get('day')}`,
    minutes: Number(get('hour')) * 60 + Number(get('minute')),
  };
}

function addYmd(ymd, days) {
  const [y, m, d] = ymd.split('-').map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d + days));
  return dt.toISOString().slice(0, 10);
}

router.get('/:bizId/next-slot', softAuth, async (req, res) => {
  const serviceId = req.query.service_id;
  if (!serviceId) return res.status(400).json({ error: 'Λείπει η υπηρεσία' });
  const bizId = req.params.bizId;
  const dropin = req.query.dropin === '1';
  try {
    let locationId = req.query.location_id || null;
    try {
      locationId = await resolveLocationId(db, bizId, locationId, {
        userId: req.user?.userId || null,
        requireExplicit: false,
      });
    } catch (_) {}
    const today = athensParts();
    for (let i = 0; i < 14; i++) {
      const date = addYmd(today.date, i);
      const computed = await computeAvailableSlots(db, bizId, serviceId, date, null, locationId);
      if (!computed || computed.closedReason) continue;
      if (dropin) {
        const offer = await loadActiveOffer(db, bizId, serviceId, locationId);
        if (!offer) return res.status(404).json({ error: 'Δεν υπάρχει διαθέσιμο drop-in' });
        computed.slotMap = await buildDropinSlotMap(db, bizId, offer, date, computed.duration);
      }
      const times = Object.keys(computed.slotMap || {})
        .filter((t) => (computed.slotMap[t] || []).length)
        .sort();
      const open = times.find((t) => {
        if (date !== today.date) return true;
        const [h, m] = t.split(':').map(Number);
        return h * 60 + (m || 0) > today.minutes + 20;
      });
      if (!open) continue;
      const staff = computed.slotMap[open][0];
      return res.json({
        date,
        time: String(open).slice(0, 5),
        staff_name: staff?.full_name || null,
      });
    }
    return res.status(404).json({ error: 'Δεν βρέθηκε διαθέσιμο ραντεβού τις επόμενες 2 εβδομάδες' });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.post('/:bizId/plan-request', softAuth, async (req, res) => {
  if (!requireCustomer(req, res)) return;
  const { plan_id, kind, service_id, trial_date, trial_time } = req.body || {};
  if (!plan_id) return res.status(400).json({ error: 'Διάλεξε πακέτο' });
  if (kind !== 'trial' && kind !== 'enroll') {
    return res.status(400).json({ error: 'Διάλεξε δοκιμαστικό ή εγγραφή στο πακέτο' });
  }
  const bizId = req.params.bizId;
  const userId = req.user.userId;
  try {
    const plan = await loadPlanForBusiness(db, bizId, plan_id);
    if (!plan) return res.status(404).json({ error: 'Το πακέτο δεν βρέθηκε' });
    const [[existing]] = await db.query(
      `SELECT id FROM plan_purchase_requests
       WHERE business_id = ? AND user_id = ? AND plan_id = ? AND status = 'pending'`,
      [bizId, userId, plan_id],
    );
    if (existing) return res.status(400).json({ error: 'Υπάρχει ήδη εκκρεμές αίτημα για αυτό το πακέτο' });
    const id = uuidv4();
    const proposedDate = kind === 'trial' && trial_date ? String(trial_date).slice(0, 10) : null;
    const proposedTime = kind === 'trial' && trial_time ? String(trial_time).slice(0, 5) : null;
    await db.query(
      `INSERT INTO plan_purchase_requests
        (id, business_id, user_id, plan_id, service_id, kind, trial_date, trial_time)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [id, bizId, userId, plan_id, service_id || plan.service_ids?.[0] || null, kind, proposedDate, proposedTime],
    );
    const [[user]] = await db.query('SELECT full_name FROM users WHERE id = ?', [userId]);
    const label = kind === 'trial' ? 'δοκιμαστικό' : 'εγγραφή στο πακέτο';
    const when = proposedDate ? ` στις ${proposedDate} ${proposedTime || ''}`.trimEnd() : '';
    try {
      const { createAdminNotification } = require('../lib/notifications');
      await createAdminNotification(db, {
        businessId: bizId,
        type: 'plan_request',
        title: kind === 'trial' ? 'Αίτημα δοκιμαστικού' : 'Αίτημα πακέτου',
        body: `${user?.full_name || 'Πελάτης'} ζήτησε ${label}: ${plan.name}${when}.`,
        payload: { request_id: id, user_id: userId, plan_id, kind },
      });
    } catch (_) {}
    return res.json({
      ok: true,
      id,
      message: kind === 'trial'
        ? 'Το αίτημα στάλθηκε. Θα λάβεις ειδοποίηση έγκρισης πριν κλειστεί το ραντεβού.'
        : 'Το αίτημα εγγραφής στάλθηκε. Το γυμναστήριο θα το δει και θα περάσει την πληρωμή.',
    });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.post('/:bizId/buy-plan', softAuth, async (req, res) => {
  if (!requireCustomer(req, res)) return;
  const { plan_id } = req.body || {};
  if (!plan_id) return res.status(400).json({ error: 'Διάλεξε πακέτο' });
  const bizId = req.params.bizId;
  const userId = req.user.userId;
  try {
    const plan = await loadPlanForBusiness(db, bizId, plan_id);
    if (!plan) return res.status(404).json({ error: 'Το πακέτο δεν βρέθηκε' });
    if (!plan.service_ids.length) {
      return res.status(400).json({ error: 'Το πακέτο δεν είναι συνδεδεμένο με υπηρεσία' });
    }
    const covered = await memberCoveredServiceIds(db, bizId, userId);
    const fresh = plan.service_ids.filter((id) => !covered.has(id));
    if (!fresh.length) {
      return res.status(400).json({ error: 'Έχεις ήδη αυτή την υπηρεσία' });
    }

    const [[provRow]] = await db.query(
      'SELECT * FROM payment_providers WHERE business_id = ? AND is_active = 1 LIMIT 1',
      [bizId],
    );
    if (provRow && Number(plan.price_cents) > 0) {
      const cfg = typeof provRow.config === 'string' ? JSON.parse(provRow.config) : (provRow.config || {});
      if (cfg.secret_key && cfg.publishable_key) {
        const stripe = require('stripe')(cfg.secret_key);
        const intent = await stripe.paymentIntents.create({
          amount: Number(plan.price_cents),
          currency: 'eur',
          metadata: { type: 'member_extra_plan', biz_id: bizId, plan_id: plan.id, user_id: userId },
          automatic_payment_methods: { enabled: true },
        });
        return res.json({
          mode: 'stripe',
          client_secret: intent.client_secret,
          intent_id: intent.id,
          publishable_key: cfg.publishable_key,
          plan_name: plan.name,
        });
      }
    }

    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();
      const granted = await grantPlanMembership(conn, { bizId, userId, plan, paid: false });
      await conn.commit();
      return res.json({
        mode: 'granted',
        ...granted,
        message: 'Η υπηρεσία προστέθηκε. Η πληρωμή του πακέτου εκκρεμεί στο γυμναστήριο.',
      });
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.post('/:bizId/buy-plan/confirm', softAuth, async (req, res) => {
  if (!requireCustomer(req, res)) return;
  const { plan_id, intent_id } = req.body || {};
  if (!plan_id || !intent_id) return res.status(400).json({ error: 'Απαιτούνται πακέτο και πληρωμή' });
  const bizId = req.params.bizId;
  const userId = req.user.userId;
  const conn = await db.getConnection();
  try {
    const [[provRow]] = await conn.query(
      'SELECT * FROM payment_providers WHERE business_id = ? AND is_active = 1 LIMIT 1',
      [bizId],
    );
    const cfg = typeof provRow?.config === 'string' ? JSON.parse(provRow.config) : (provRow?.config || {});
    if (!cfg.secret_key) return res.status(400).json({ error: 'Οι online πληρωμές δεν είναι διαθέσιμες' });
    const stripe = require('stripe')(cfg.secret_key);
    const intent = await stripe.paymentIntents.retrieve(intent_id);
    if (intent.status !== 'succeeded') return res.status(402).json({ error: 'Η πληρωμή δεν ολοκληρώθηκε' });
    if (intent.metadata?.plan_id !== plan_id || intent.metadata?.user_id !== userId) {
      return res.status(400).json({ error: 'Η πληρωμή δεν ταιριάζει με το πακέτο' });
    }
    const [existing] = await conn.query(
      'SELECT id FROM payments WHERE business_id = ? AND user_id = ? AND notes = ? LIMIT 1',
      [bizId, userId, `stripe:${intent_id}`],
    );
    if (existing.length) return res.json({ ok: true, already: true });

    const plan = await loadPlanForBusiness(conn, bizId, plan_id);
    if (!plan) return res.status(404).json({ error: 'Το πακέτο δεν βρέθηκε' });
    await conn.beginTransaction();
    const granted = await grantPlanMembership(conn, { bizId, userId, plan, paid: true, intentId: intent_id });
    await conn.commit();
    return res.json({ mode: 'granted', ...granted, message: 'Το πακέτο αγοράστηκε.' });
  } catch (err) {
    try { await conn.rollback(); } catch (_) {}
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// ============================================================
// GET /api/booking/:bizId/opening-hours
// Weekly gym schedule (0=Mon … 6=Sun)
// ============================================================
router.get('/:bizId/opening-hours', async (req, res) => {
  try {
    const { location_id } = req.query;
    const opening_hours = location_id
      ? await getLocationOpeningHours(db, req.params.bizId, location_id)
      : await getOpeningHours(db, req.params.bizId);
    return res.json({ opening_hours, location_id: location_id || null });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// GET /api/booking/:bizId/gym-info
// Public gym contact details for the mobile app
// ============================================================
router.get('/:bizId/gym-info', async (req, res) => {
  const { bizId } = req.params;
  try {
    const payload = await buildGymInfoPayload(db, bizId);
    if (!payload) return res.status(404).json({ error: 'Το γυμναστήριο δεν βρέθηκε' });
    return res.json(payload);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// GET /api/booking/:bizId/service-days?service_id=&location_id=
// Weekdays the service actually runs (Dart: 1=Mon … 7=Sun). Empty = no class program.
// ============================================================
router.get('/:bizId/service-days', softAuth, async (req, res) => {
  const { service_id, location_id } = req.query;
  if (!service_id) return res.status(400).json({ error: 'Απαιτείται υπηρεσία' });
  const params = [service_id, req.params.bizId];
  let locationSql = '';
  if (location_id) {
    locationSql = 'AND (location_id IS NULL OR location_id = ?)';
    params.push(location_id);
  }
  try {
    const [rows] = await db.query(
      `SELECT DISTINCT weekday
       FROM service_slot_schedules
       WHERE service_id = ? AND business_id = ? AND is_active = 1
         ${locationSql}`,
      params,
    );
    return res.json({ weekdays: rows.map((row) => Number(row.weekday) + 1) });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// GET /api/booking/:bizId/slots?service_id=x&date=YYYY-MM-DD
// Returns available time slots with available staff per slot
// ============================================================
router.get('/:bizId/slots', softAuth, async (req, res) => {
  const { service_id, date, exclude_booking_id, location_id } = req.query;
  if (!service_id || !date) {
    return res.status(400).json({ error: 'Απαιτούνται υπηρεσία και ημερομηνία' });
  }

  try {
    const resolvedLocationId = await resolveLocationId(
      db,
      req.params.bizId,
      location_id || null,
      { userId: req.user?.userId || null, requireExplicit: true },
    );

    const computed = await computeAvailableSlots(
      db,
      req.params.bizId,
      service_id,
      date,
      exclude_booking_id,
      resolvedLocationId,
    );
    if (!computed) return res.status(404).json({ error: 'Η υπηρεσία δεν βρέθηκε' });

    if (req.query.dropin === '1') {
      const offer = await loadActiveOffer(db, req.params.bizId, service_id, resolvedLocationId);
      if (!offer) {
        return res.json({
          slots: [],
          day_status: 'no_availability',
          message: 'Δεν υπάρχει drop-in για αυτό το κατάστημα και αυτή την υπηρεσία.',
        });
      }
      computed.slotMap = await buildDropinSlotMap(
        db,
        req.params.bizId,
        offer,
        date,
        computed.duration,
      );
      computed.scheduleByTime = new Map();
      computed.staffPoolNames = [...new Set(Object.values(computed.slotMap).flat().map((s) => s.full_name))];
    }

    const { staffPoolNames } = computed;
    if (computed.closedReason) {
      return res.json({
        slots: [],
        day_status: 'closed',
        message: 'Το γυμναστήριο είναι κλειστό αυτή την ημέρα.',
      });
    }
    if (!staffPoolNames.length && !computed.scheduleByTime?.size) {
      return res.json({
        slots: [],
        day_status: 'no_availability',
        message: 'Δεν υπάρχουν διαθέσιμες ώρες για αυτή την υπηρεσία αυτή την ημέρα.',
      });
    }

    const [[cfg]] = await db.query(
      'SELECT feature_waitlist FROM business_configs WHERE business_id = ?',
      [req.params.bizId]
    );

    const payload = buildSlotsPayload(computed, {
      featureWaitlist: !!cfg?.feature_waitlist,
      date,
    });

    if (req.user?.userId) {
      const conflictParams = [req.user.userId, req.params.bizId, date];
      let conflictSql = `
        SELECT TIME_FORMAT(b.starts_at, '%H:%i') AS slot_time,
               b.service_id, s.name AS service_name
        FROM bookings b
        JOIN services s ON s.id = b.service_id
        WHERE b.user_id = ? AND b.business_id = ?
          AND DATE(b.starts_at) = ?
          AND b.status IN ('confirmed', 'pending')
      `;
      if (exclude_booking_id) {
        conflictSql += ' AND b.id != ?';
        conflictParams.push(exclude_booking_id);
      }
      const [userBookings] = await db.query(conflictSql, conflictParams);

      const conflictByTime = new Map();
      for (const row of userBookings) {
        if (!row.slot_time) continue;
        conflictByTime.set(row.slot_time, {
          service_name: row.service_name,
          same_service: String(row.service_id) === String(service_id),
        });
      }

      payload.slots = payload.slots.map((slot) => {
        const conflict = conflictByTime.get(slot.time);
        if (!conflict) return slot;
        return {
          ...slot,
          user_has_booking: true,
          user_conflict_service: conflict.service_name,
          user_same_service: conflict.same_service,
          available_staff: [],
          available_count: 0,
          is_full: true,
          waitlist_available: false,
        };
      });
    }

    const response = {
      ...payload,
      date,
      service_id,
      location_id: resolvedLocationId,
      feature_waitlist: !!cfg?.feature_waitlist,
    };

    if (!payload.slots.length) {
      response.day_status = 'no_slots';
      response.message = 'Δεν υπάρχουν διαθέσιμες ώρες για αυτή την ημέρα.';
    }

    return res.json(response);
  } catch (err) {
    if (err.code === 'LOCATION_REQUIRED') {
      const locations = await listLocationsForService(
        db,
        req.params.bizId,
        service_id,
        { userId: req.user?.userId || null },
      );
      return res.status(400).json({
        error: err.message,
        code: err.code,
        locations,
      });
    }
    if (err.status) {
      return res.status(err.status).json({ error: err.message, code: err.code || null });
    }
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// POST /api/booking/:bizId/create
// Body: { service_id, staff_id, date, time, use_credit }
// ============================================================
router.post('/:bizId/create', softAuth, requireActiveCustomer, async (req, res) => {
  const { service_id, staff_id, date, time, use_credit = true, location_id } = req.body;

  if (!service_id || !date || !time) {
    return res.status(400).json({ error: 'Απαιτούνται υπηρεσία, ημερομηνία και ώρα' });
  }
  if (!isSlotBookableForDate(date, time)) {
    return res.status(400).json({ error: 'Αυτή η ώρα έχει ήδη περάσει. Επίλεξε μεταγενέστερη ώρα.' });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const result = await createOneBooking(conn, {
      bizId: req.params.bizId,
      userId: req.user.userId,
      service_id,
      staff_id: staff_id || null,
      date,
      time,
      location_id: location_id || null,
      use_credit: !!use_credit,
      source: 'app',
    });
    await conn.commit();

    return res.status(201).json({
      booking_id: result.booking_id,
      service: result.service,
      starts_at: result.starts_at,
      ends_at: result.ends_at,
      status: result.status,
      credit_used: result.credit_used,
      preparation_tips: result.preparation_tips,
      post_workout_tips: result.post_workout_tips,
      schedule_label: result.schedule_label,
    });
  } catch (err) {
    await conn.rollback();
    console.error(err);
    if (err.code === 'SLOT_FULL') {
      return res.status(409).json({ error: err.message, code: 'SLOT_FULL', waitlist_available: true });
    }
    if (err.code === 'TIME_CONFLICT' || err.code === 'DUPLICATE_BOOKING') {
      return res.status(409).json({
        error: err.message,
        code: err.code,
        conflicting_service: err.conflicting_service || null,
      });
    }
    return res.status(400).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// ============================================================
// POST /api/booking/:bizId/create-bulk
// Body: { service_id, staff_id?, use_credit?, slots: [{ date, time }] }
// Books each slot independently; returns created + failed with alternatives.
// ============================================================
router.post('/:bizId/create-bulk', softAuth, requireActiveCustomer, async (req, res) => {
  const { service_id, staff_id, use_credit = true, slots, location_id } = req.body;

  if (!service_id || !Array.isArray(slots) || !slots.length) {
    return res.status(400).json({ error: 'Απαιτούνται υπηρεσία και λίστα ημερομηνιών' });
  }

  const normalized = slots
    .map(s => ({ date: s.date, time: String(s.time).slice(0, 5) }))
    .filter(s => s.date && s.time)
    .sort((a, b) => `${a.date}T${a.time}`.localeCompare(`${b.date}T${b.time}`));

  if (!normalized.length) {
    return res.status(400).json({ error: 'Δεν βρέθηκαν έγκυρες ημερομηνίες' });
  }

  const created = [];
  const failed = [];

  for (const slot of normalized) {
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();
      const result = await createOneBooking(conn, {
        bizId: req.params.bizId,
        userId: req.user.userId,
        service_id,
        staff_id,
        date: slot.date,
        time: slot.time,
        location_id: location_id || null,
        use_credit,
        skipNotifications: true,
      });
      await conn.commit();
      created.push(result);
    } catch (err) {
      await conn.rollback();
      const alternative = await findAlternativeSlot(
        conn, req.params.bizId, service_id, slot.date, slot.time, staff_id
      );
      failed.push({
        date: slot.date,
        time: slot.time,
        reason: err.message,
        code: err.code || null,
        alternative,
      });
    } finally {
      conn.release();
    }
  }

  if (created.length) {
    const [[service]] = await db.query(
      'SELECT name FROM services WHERE id = ? AND business_id = ?',
      [service_id, req.params.bizId]
    );
    const serviceName = service?.name || 'Υπηρεσία';
    const summaryBody = created.length === 1
      ? `Στις ${created[0].date} ${created[0].time}.`
      : `Κλείστηκαν ${created.length} ραντεβού για ${serviceName}.`;

    await createUserNotification(db, {
      businessId: req.params.bizId,
      userId: req.user.userId,
      bookingId: created[0].booking_id,
      type: 'booking_confirmed',
      title: created.length === 1
        ? `Κράτηση επιβεβαιώθηκε — ${serviceName}`
        : `${created.length} κρατήσεις επιβεβαιώθηκαν`,
      body: summaryBody,
      payload: { action: 'open_bookings' },
      sendPush: true,
    });
  }

  const status = created.length
    ? (failed.length ? 207 : 201)
    : (failed.length ? 200 : 400);
  return res.status(status).json({
    created,
    failed,
    summary: {
      total: normalized.length,
      created_count: created.length,
      failed_count: failed.length,
    },
    message: failed.length
      ? `Κλείστηκαν ${created.length} από ${normalized.length}. ${failed.length} δεν ήταν διαθέσιμα.`
      : `Κλείστηκαν ${created.length} ραντεβού.`,
  });
});

async function getOwnedBooking(bookingId, userId, bizId, executor = db) {
  const [[booking]] = await executor.query(`
    SELECT b.*, sv.name AS service_name, sv.duration_mins
    FROM bookings b
    JOIN services sv ON sv.id = b.service_id
    WHERE b.id = ? AND b.user_id = ? AND b.business_id = ?
  `, [bookingId, userId, bizId]);
  return booking || null;
}

const CANCEL_LEAD_MINUTES = 45;

function assertBookingModifiable(booking) {
  const allowed = ['pending', 'confirmed'];
  if (!allowed.includes(booking.status)) {
    throw new Error('Αυτή η κράτηση δεν μπορεί να τροποποιηθεί.');
  }
  const cutoff = new Date(booking.starts_at);
  cutoff.setMinutes(cutoff.getMinutes() - CANCEL_LEAD_MINUTES);
  if (new Date() >= cutoff) {
    throw new Error(`Η ακύρωση επιτρέπεται μόνο ${CANCEL_LEAD_MINUTES} λεπτά πριν το μάθημα.`);
  }
}

async function refundBookingCredit(conn, userId, bizId, service) {
  const [memberships] = await conn.query(`
    SELECT id, plan_id, service_id, service_category, total_sessions, used_sessions
    FROM user_memberships
    WHERE user_id = ? AND business_id = ? AND valid_until >= CURDATE()
  `, [userId, bizId]);
  const planToServiceId = await loadPlanServiceMap(memberships);
  const credit = findMembershipForService(memberships, service, planToServiceId);
  if (credit && credit.total_sessions < 9999 && credit.used_sessions > 0) {
    await conn.query(
      'UPDATE user_memberships SET used_sessions = used_sessions - 1 WHERE id = ?',
      [credit.id]
    );
  }
}

// ============================================================
// GET /api/booking/:bizId/my-bookings
// Returns upcoming bookings for the logged-in user
// ============================================================
router.get('/:bizId/my-bookings', softAuth, requireActiveCustomer, async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT
        b.id, b.service_id, b.staff_id, b.location_id, b.starts_at, b.ends_at, b.status,
        b.feedback_rating, b.feedback_note, b.attendance_confirmed,
        sv.name  AS service_name, sv.duration_mins, sv.category AS service_category,
        st.full_name AS staff_name, st.color_hex, st.avatar_url,
        loc.name AS location_name
      FROM bookings b
      JOIN services sv ON sv.id = b.service_id
      LEFT JOIN staff st ON st.id = b.staff_id
      LEFT JOIN locations loc ON loc.id = b.location_id
      WHERE b.user_id = ? AND b.business_id = ?
      ORDER BY b.starts_at DESC
      LIMIT 30
    `, [req.user.userId, req.params.bizId]);

    const enriched = [];
    for (const row of rows) {
      enriched.push(await enrichBookingWithTips(db, {
        ...row,
        business_id: req.params.bizId,
      }));
    }
    return res.json(enriched);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.get('/:bizId/my-bookings/:bookingId', softAuth, requireActiveCustomer, async (req, res) => {
  try {
    const [[row]] = await db.query(`
      SELECT
        b.id, b.service_id, b.staff_id, b.location_id, b.business_id, b.starts_at, b.ends_at, b.status,
        b.feedback_rating, b.feedback_note, b.attendance_confirmed,
        sv.name AS service_name, sv.duration_mins, sv.category AS service_category,
        st.full_name AS staff_name
      FROM bookings b
      JOIN services sv ON sv.id = b.service_id
      LEFT JOIN staff st ON st.id = b.staff_id
      WHERE b.id = ? AND b.user_id = ? AND b.business_id = ?
    `, [req.params.bookingId, req.user.userId, req.params.bizId]);
    if (!row) return res.status(404).json({ error: 'Η κράτηση δεν βρέθηκε' });
    return res.json(await enrichBookingWithTips(db, row));
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.post('/:bizId/my-bookings/:bookingId/complete', softAuth, requireActiveCustomer, async (req, res) => {
  const { rating, note, attended } = req.body;
  if (!attended) {
    return res.status(400).json({ error: 'Πρέπει να επιβεβαιώσεις ότι πήγες στην προπόνηση.' });
  }

  let workoutHealth = null;
  try {
    workoutHealth = normalizeWorkoutHealthPayload(req.body);
  } catch (err) {
    return res.status(400).json({ error: err.message });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const booking = await getOwnedBooking(req.params.bookingId, req.user.userId, req.params.bizId, conn);
    if (!booking) throw new Error('Η κράτηση δεν βρέθηκε.');
    if (assertCanConfirmAttendance(booking) === 'already_confirmed') {
      if (rating || note) {
        await conn.query(
          `UPDATE bookings SET feedback_rating = COALESCE(?, feedback_rating), feedback_note = COALESCE(?, feedback_note) WHERE id = ?`,
          [rating || null, note || null, booking.id],
        );
      }
      const stats = await getUserStats(conn, req.user.userId, req.params.bizId);
      await conn.commit();
      return res.json({ message: 'Η παρουσία σου έχει ήδη καταχωρηθεί!', already_confirmed: true, stats });
    }

    await conn.query(`
      UPDATE bookings SET
        status = 'completed',
        attendance_confirmed = 1,
        attendance_confirmed_at = NOW(),
        feedback_rating = COALESCE(?, feedback_rating),
        feedback_note = COALESCE(?, feedback_note),
        post_notified = 1
      WHERE id = ?
    `, [rating || null, note || null, booking.id]);

    if (workoutHealth) {
      await saveBookingWorkoutHealth(conn, booking.id, workoutHealth);
    }

    const loyalty = await awardLoyaltyPoints(
      conn, req.user.userId, req.params.bizId, booking.id, Number(rating) || 0
    );
    const stats = await getUserStats(conn, req.user.userId, req.params.bizId);

    const enriched = await enrichBookingWithTips(conn, {
      ...booking,
      business_id: req.params.bizId,
    });

    const [[healthRow]] = await conn.query(
      `SELECT health_external_id, health_activity_type, health_activity_label,
              health_workout_started_at, health_workout_ended_at, health_duration_mins,
              health_calories_kcal, health_avg_heart_rate, health_distance_m, health_source, health_synced_at
       FROM bookings WHERE id = ?`,
      [booking.id]
    );

    await conn.commit();
    return res.json({
      message: 'Η παρουσία σου καταχωρήθηκε!',
      post_workout_tips: enriched.post_workout_tips,
      points_earned: loyalty.pointsEarned,
      loyalty_points: loyalty.totalPoints,
      loyalty_reasons: loyalty.reasons,
      stats,
      health_workout: mapBookingHealthFields(healthRow),
    });
  } catch (err) {
    await conn.rollback();
    return res.status(400).json({ error: err.message });
  } finally {
    conn.release();
  }
});

router.get('/:bizId/my-workout-metrics', softAuth, requireActiveCustomer, async (req, res) => {
  const days = Math.min(90, Math.max(7, Number(req.query.days) || 30));
  const since = new Date();
  since.setDate(since.getDate() - days);

  try {
    const [rows] = await db.query(`
      SELECT b.id, b.starts_at, b.ends_at, sv.name AS service_name,
        b.health_workout_started_at, b.health_workout_ended_at, b.health_duration_mins,
        b.health_calories_kcal, b.health_avg_heart_rate, b.health_distance_m,
        b.health_activity_type, b.health_activity_label, b.health_source
      FROM bookings b
      JOIN services sv ON sv.id = b.service_id
      WHERE b.user_id = ? AND b.business_id = ?
        AND b.status = 'completed'
        AND (b.health_calories_kcal IS NOT NULL OR b.health_duration_mins IS NOT NULL)
        AND b.starts_at >= ?
      ORDER BY COALESCE(b.health_workout_started_at, b.starts_at) DESC
    `, [req.user.userId, req.params.bizId, since]);

    const workouts = rows.map((r) => ({
      id: r.id,
      service_name: r.service_name,
      starts_at: r.starts_at,
      ended_at: r.health_workout_ended_at || r.ends_at,
      started_at: r.health_workout_started_at || r.starts_at,
      duration_mins: r.health_duration_mins,
      calories_kcal: r.health_calories_kcal,
      avg_heart_rate: r.health_avg_heart_rate,
      distance_m: r.health_distance_m != null ? Number(r.health_distance_m) : null,
      activity_type: r.health_activity_type,
      activity_label: r.health_activity_label || r.health_activity_type,
      source: r.health_source,
    }));

    const totalSessions = workouts.length;
    const totalDuration = workouts.reduce((s, w) => s + (w.duration_mins || 0), 0);
    const totalCalories = workouts.reduce((s, w) => s + (w.calories_kcal || 0), 0);
    const hrValues = workouts.map((w) => w.avg_heart_rate).filter((v) => v != null);
    const avgHeartRate = hrValues.length
      ? Math.round(hrValues.reduce((a, b) => a + b, 0) / hrValues.length)
      : null;

    const byActivityMap = {};
    for (const w of workouts) {
      const key = w.activity_label || w.activity_type || 'Άλλο';
      if (!byActivityMap[key]) {
        byActivityMap[key] = { label: key, sessions: 0, calories: 0, duration_mins: 0 };
      }
      byActivityMap[key].sessions += 1;
      byActivityMap[key].calories += w.calories_kcal || 0;
      byActivityMap[key].duration_mins += w.duration_mins || 0;
    }

    const byWeek = [];
    const now = new Date();
    for (let i = 6; i >= 0; i -= 1) {
      const weekEnd = new Date(now);
      weekEnd.setDate(weekEnd.getDate() - i * 7);
      const weekStart = new Date(weekEnd);
      weekStart.setDate(weekStart.getDate() - 6);
      weekStart.setHours(0, 0, 0, 0);
      weekEnd.setHours(23, 59, 59, 999);

      const inWeek = workouts.filter((w) => {
        const d = new Date(w.started_at);
        return d >= weekStart && d <= weekEnd;
      });

      byWeek.push({
        week_start: weekStart.toISOString().slice(0, 10),
        sessions: inWeek.length,
        calories: inWeek.reduce((s, w) => s + (w.calories_kcal || 0), 0),
        duration_mins: inWeek.reduce((s, w) => s + (w.duration_mins || 0), 0),
      });
    }

    return res.json({
      days,
      is_demo: false,
      workouts,
      summary: {
        total_sessions: totalSessions,
        total_duration_mins: totalDuration,
        total_calories: totalCalories,
        avg_duration_mins: totalSessions ? Math.round(totalDuration / totalSessions) : 0,
        avg_heart_rate: avgHeartRate,
      },
      by_activity: Object.values(byActivityMap),
      by_week: byWeek,
    });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.get('/:bizId/my-stats', softAuth, requireActiveCustomer, async (req, res) => {
  try {
    const stats = await getUserStats(db, req.user.userId, req.params.bizId);
    return res.json(stats);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.put('/:bizId/my-goal', softAuth, requireActiveCustomer, async (req, res) => {
  const { target_sessions, period = 'monthly' } = req.body;
  const target = Number(target_sessions);
  if (!target || target < 1 || target > 60) {
    return res.status(400).json({ error: 'Ο στόχος πρέπει να είναι 1–60 προπονήσεις' });
  }
  try {
    await db.query(`
      INSERT INTO user_goals (id, user_id, business_id, target_sessions, period)
      VALUES (?, ?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE target_sessions = VALUES(target_sessions), period = VALUES(period), is_active = 1
    `, [uuidv4(), req.user.userId, req.params.bizId, target, period]);
    const stats = await getUserStats(db, req.user.userId, req.params.bizId);
    return res.json(stats);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.get('/:bizId/my-payments', softAuth, requireActiveCustomer, async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT id, description, amount_cents, paid_amount_cents, status,
             payment_date, due_date, notes, method, created_at
      FROM payments
      WHERE user_id = ? AND business_id = ?
      ORDER BY COALESCE(payment_date, due_date, created_at) DESC
    `, [req.user.userId, req.params.bizId]);

    const mapped = rows.map(mapPaymentRow);
    const totalDue = mapped.reduce((s, p) => s + p.balance_cents, 0);
    return res.json({ payments: mapped, total_balance_cents: totalDue });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// PATCH /api/booking/:bizId/my-bookings/:bookingId/cancel
// ============================================================
router.patch('/:bizId/my-bookings/:bookingId/cancel', softAuth, requireActiveCustomer, async (req, res) => {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const booking = await getOwnedBooking(req.params.bookingId, req.user.userId, req.params.bizId, conn);
    if (!booking) throw new Error('Η κράτηση δεν βρέθηκε.');
    assertBookingModifiable(booking);

    const [[service]] = await conn.query('SELECT * FROM services WHERE id = ?', [booking.service_id]);

    await conn.query(
      `UPDATE bookings SET status = 'cancelled' WHERE id = ?`,
      [booking.id]
    );
    await refundBookingCredit(conn, req.user.userId, req.params.bizId, service);

    const waiter = await notifyWaitlistOnCancel(
      conn, req.params.bizId, booking.service_id, booking.starts_at, booking.service_name
    );

    await conn.commit();
    return res.json({
      message: 'Η κράτηση ακυρώθηκε.',
      status: 'cancelled',
      waitlist_notified: !!waiter,
    });
  } catch (err) {
    await conn.rollback();
    return res.status(400).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// ============================================================
// PATCH /api/booking/:bizId/my-bookings/:bookingId
// Reschedule: { date, time, staff_id }
// ============================================================
router.patch('/:bizId/my-bookings/:bookingId', softAuth, requireActiveCustomer, async (req, res) => {
  const { date, time, staff_id } = req.body;
  if (!date || !time) {
    return res.status(400).json({ error: 'Απαιτούνται ημερομηνία και ώρα' });
  }
  if (!isSlotBookableForDate(date, time)) {
    return res.status(400).json({ error: 'Αυτή η ώρα έχει ήδη περάσει. Επίλεξε μεταγενέστερη ώρα.' });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const booking = await getOwnedBooking(req.params.bookingId, req.user.userId, req.params.bizId, conn);
    if (!booking) throw new Error('Η κράτηση δεν βρέθηκε.');
    assertBookingModifiable(booking);

    const [[service]] = await conn.query(
      'SELECT hide_staff_selection FROM services WHERE id = ? AND business_id = ?',
      [booking.service_id, req.params.bizId]
    );

    const startsAt = new Date(`${date}T${time}:00`);
    const endsAt   = new Date(startsAt.getTime() + booking.duration_mins * 60000);

    const { computed } = await assertSlotCapacity(
      conn, req.params.bizId, booking.service_id, date, time, startsAt, endsAt, booking.id, false
    );

    let finalStaffId = staff_id;
    if (!finalStaffId) {
      if (!service?.hide_staff_selection) {
        throw new Error('Απαιτείται επιλογή γυμναστή');
      }
      finalStaffId = await findStaffForSlot(
        conn, req.params.bizId, booking.service_id, computed, time, startsAt
      );
    } else {
      const pool = computed.slotMap[time] || [];
      if (!pool.some(s => s.id === finalStaffId)) {
        throw new Error('Ο γυμναστής δεν είναι διαθέσιμος αυτή την ώρα');
      }
    }

    await assertStaffAvailable(
      conn, req.params.bizId, finalStaffId, booking.service_id, startsAt, endsAt, booking.id
    );

    await assertNoUserBookingConflict(conn, {
      bizId: req.params.bizId,
      userId: req.user.userId,
      startsAt,
      serviceId: booking.service_id,
      date,
      time,
      excludeBookingId: booking.id,
    });

    await conn.query(
      `UPDATE bookings SET staff_id = ?, starts_at = ?, ends_at = ? WHERE id = ?`,
      [finalStaffId, startsAt, endsAt, booking.id]
    );

    await conn.commit();
    return res.json({
      message: 'Η κράτηση ενημερώθηκε.',
      starts_at: startsAt,
      ends_at:   endsAt,
    });
  } catch (err) {
    await conn.rollback();
    const status = (err.code === 'TIME_CONFLICT' || err.code === 'DUPLICATE_BOOKING') ? 409 : 400;
    return res.status(status).json({
      error: err.message,
      code: err.code || null,
      conflicting_service: err.conflicting_service || null,
    });
  } finally {
    conn.release();
  }
});

// ============================================================
// GET /api/booking/:bizId/my-credits
// Returns user's active memberships/credits
// ============================================================
router.get('/:bizId/my-credits', softAuth, requireActiveCustomer, async (req, res) => {
  try {
    const bizId = req.params.bizId;
    const userId = req.user.userId;
    const graceDays = await getGracePeriodDays(db, bizId);
    const [rows] = await db.query(`
      SELECT
        m.id, m.plan_id, m.service_id, m.service_category, m.total_sessions, m.used_sessions,
        (m.total_sessions - m.used_sessions) AS remaining,
        m.valid_from, m.valid_until, m.notes, m.membership_status,
        m.cancelled_at, m.cancellation_reason,
        s.name AS service_name, s.description AS service_description,
        bp.name AS plan_name, bp.billing_period, bp.price_cents AS plan_price_cents,
        bp.plan_type,
        bp.nutrition_includes_meal_plan, bp.nutrition_includes_measurements,
        bp.nutrition_includes_food_diary, bp.nutrition_includes_consultations,
        bp.nutrition_consultation_sessions,
        (SELECT p.payment_date FROM payments p WHERE p.membership_id = m.id AND p.payment_type != 'registration_fee' ORDER BY p.payment_date DESC LIMIT 1) AS last_payment_date
      FROM user_memberships m
      LEFT JOIN services s ON s.id = m.service_id
      LEFT JOIN business_plans bp ON bp.id = m.plan_id
      WHERE m.user_id = ? AND m.business_id = ?
        AND m.membership_status NOT IN ('trial', 'cancelled')
        AND (
          m.valid_until >= CURDATE()
          OR DATE_ADD(m.valid_until, INTERVAL ? DAY) >= CURDATE()
        )
      ORDER BY
        CASE
          WHEN bp.plan_type = 'nutrition' OR m.service_category = 'nutrition' THEN 0
          WHEN m.service_category = 'nutrition_consultation' THEN 1
          ELSE 2
        END,
        m.valid_until ASC
    `, [userId, bizId, graceDays]);

    // Load plan_service_items for combo plans
    const planIds = [...new Set(rows.map(r => r.plan_id).filter(Boolean))];
    const planServiceItems = await loadPlanServiceItems(planIds);

    // Monthly usage for combo memberships
    const comboMembershipIds = rows.filter(r => r.plan_id && planServiceItems.has(r.plan_id)).map(r => r.id);
    const monthlyUsage = await loadMonthlyUsage(userId, comboMembershipIds);

    return res.json(rows.map((m) => {
      const base = enrichMembershipLifecycle(m, graceDays);
      base.last_payment_date = m.last_payment_date
        ? (m.last_payment_date instanceof Date ? m.last_payment_date.toISOString().slice(0, 10) : String(m.last_payment_date).slice(0, 10))
        : null;

      // Per-service breakdown for combo plans
      const items = m.plan_id ? planServiceItems.get(m.plan_id) : null;
      if (items && items.length > 1) {
        base.plan_services = items.map(item => {
          const isUnlimited = item.sessions === null;
          const used = monthlyUsage[`${m.id}:${item.service_id}`] || 0;
          const remaining = isUnlimited ? null : Math.max(0, item.sessions - used);
          return {
            service_id: item.service_id,
            service_name: item.service_name,
            sessions_per_period: item.sessions,
            is_unlimited: isUnlimited,
            used_this_month: used,
            remaining,
          };
        });
      }
      return base;
    }));
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// PATCH /api/booking/:bizId/my-credits/:membershipId/cancel
router.patch('/:bizId/my-credits/:membershipId/cancel', softAuth, requireActiveCustomer, async (req, res) => {
  const { reason } = req.body || {};
  const bizId = req.params.bizId;
  const userId = req.user.userId;
  try {
    const [[mem]] = await db.query(
      `SELECT id, membership_status FROM user_memberships
       WHERE id = ? AND user_id = ? AND business_id = ?`,
      [req.params.membershipId, userId, bizId],
    );
    if (!mem) return res.status(404).json({ error: 'Το πακέτο δεν βρέθηκε' });
    if (mem.membership_status === 'cancelled') {
      return res.status(400).json({ error: 'Η συνδρομή είναι ήδη διακομμένη' });
    }
    if (mem.membership_status === 'trial') {
      return res.status(400).json({ error: 'Για δοκιμαστικό επικοινώνησε με το γυμναστήριο' });
    }

    await db.query(`
      UPDATE user_memberships SET
        membership_status = 'cancelled',
        cancelled_at = NOW(),
        cancellation_reason = ?
      WHERE id = ? AND business_id = ?
    `, [reason?.trim() || null, req.params.membershipId, bizId]);

    await createAdminNotification(db, {
      businessId: bizId,
      type: 'membership_cancelled',
      title: 'Αίτημα διακοπής συνδρομής',
      body: `Πελάτης ζήτησε διακοπή συνδρομής${reason ? `: ${reason.trim()}` : ''}.`,
      payload: { membership_id: req.params.membershipId, user_id: userId },
    });

    return res.json({ ok: true, message: 'Η συνδρομή διακόπηκε' });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// POST /api/booking/:bizId/waitlist
// Body: { service_id, date, time, staff_id? }
// ============================================================
router.post('/:bizId/waitlist', softAuth, requireActiveCustomer, async (req, res) => {
  const { service_id, staff_id, date, time, location_id, auto_book = false } = req.body;
  if (!service_id || !date || !time) {
    return res.status(400).json({ error: 'Απαιτούνται υπηρεσία, ημερομηνία και ώρα' });
  }
  if (!isSlotBookableForDate(date, time)) {
    return res.status(400).json({ error: 'Αυτή η ώρα έχει ήδη περάσει.' });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const [[cfg]] = await conn.query(
      'SELECT feature_waitlist FROM business_configs WHERE business_id = ?',
      [req.params.bizId]
    );
    if (!cfg?.feature_waitlist) {
      throw new Error('Η λίστα αναμονής δεν είναι ενεργή για αυτό το γυμναστήριο.');
    }

    const [[service]] = await conn.query(
      'SELECT * FROM services WHERE id = ? AND business_id = ?',
      [service_id, req.params.bizId]
    );
    if (!service) throw new Error('Η υπηρεσία δεν βρέθηκε');

    const startsAt = new Date(`${date}T${time}:00`);
    const endsAt   = new Date(startsAt.getTime() + service.duration_mins * 60000);

    try {
      await assertSlotCapacity(conn, req.params.bizId, service_id, date, time, startsAt, endsAt, null, false, location_id || null);
      throw new Error('Η θέση είναι ακόμα διαθέσιμη — κάνε κανονική κράτηση.');
    } catch (err) {
      if (err.code !== 'SLOT_FULL') throw err;
    }

    const [[existing]] = await conn.query(`
      SELECT id FROM waitlist_entries
      WHERE user_id = ? AND service_id = ? AND starts_at = ?
        AND status IN ('waiting', 'offered')
    `, [req.user.userId, service_id, startsAt]);
    if (existing) throw new Error('Είσαι ήδη στη λίστα αναμονής για αυτή την ώρα.');

    const [[user]] = await conn.query(
      'SELECT full_name FROM users WHERE id = ?',
      [req.user.userId]
    );

    const result = await joinWaitlist(conn, {
      businessId: req.params.bizId,
      userId: req.user.userId,
      serviceId: service_id,
      staffId: staff_id || null,
      startsAt,
      endsAt,
      serviceName: service.name,
      userName: user?.full_name || 'Πελάτης',
      autoBook: !!auto_book,
    });

    await conn.commit();
    return res.status(201).json({
      waitlist_id: result.id,
      position: result.position,
      message: `Μπήκες στη λίστα αναμονής (θέση #${result.position}). Θα ενημερωθείς όταν ανοίξει θέση.`,
    });
  } catch (err) {
    await conn.rollback();
    return res.status(400).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// ============================================================
// GET /api/booking/:bizId/my-waitlist
// ============================================================
router.get('/:bizId/my-waitlist', softAuth, requireActiveCustomer, async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT w.id, w.service_id, w.starts_at, w.ends_at, w.status, w.position,
             sv.name AS service_name, st.full_name AS staff_name,
             sss.label AS schedule_label
      FROM waitlist_entries w
      JOIN services sv ON sv.id = w.service_id
      LEFT JOIN staff st ON st.id = w.staff_id
      LEFT JOIN service_slot_schedules sss ON sss.service_id = w.service_id
        AND sss.business_id = w.business_id
        AND sss.weekday = WEEKDAY(w.starts_at)
        AND sss.start_time = TIME(w.starts_at)
        AND sss.is_active = 1
      WHERE w.user_id = ? AND w.business_id = ?
        AND w.status IN ('waiting', 'offered')
      ORDER BY w.starts_at ASC
    `, [req.user.userId, req.params.bizId]);
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// DELETE /api/booking/:bizId/waitlist/:id
// ============================================================
router.delete('/:bizId/waitlist/:id', softAuth, requireActiveCustomer, async (req, res) => {
  try {
    const [r] = await db.query(`
      UPDATE waitlist_entries SET status = 'cancelled'
      WHERE id = ? AND user_id = ? AND business_id = ?
        AND status IN ('waiting', 'offered')
    `, [req.params.id, req.user.userId, req.params.bizId]);
    if (!r.affectedRows) return res.status(404).json({ error: 'Η εγγραφή δεν βρέθηκε' });
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

const QR_CHECKIN_BEFORE_MINS = 30;
const QR_CHECKIN_AFTER_MINS = 180;
const LATE_SELF_CONFIRM_HOURS = 48;

function qrCheckinWindowEnd(booking) {
  if (booking.ends_at) return new Date(booking.ends_at);
  const mins = Number(booking.duration_mins) || 60;
  return new Date(new Date(booking.starts_at).getTime() + mins * 60 * 1000);
}

function isQrCheckinWindowOpen(booking, now = new Date()) {
  const starts = new Date(booking.starts_at);
  const windowStart = new Date(starts.getTime() - QR_CHECKIN_BEFORE_MINS * 60 * 1000);
  const windowEnd = new Date(qrCheckinWindowEnd(booking).getTime() + QR_CHECKIN_AFTER_MINS * 60 * 1000);
  return now >= windowStart && now <= windowEnd;
}

function formatQrBookingTime(dt) {
  return new Date(dt).toLocaleTimeString('el-GR', { hour: '2-digit', minute: '2-digit' });
}

function formatQrBookingDateTime(dt) {
  const d = new Date(dt);
  const date = d.toLocaleDateString('el-GR', { weekday: 'short', day: '2-digit', month: '2-digit' });
  const time = formatQrBookingTime(d);
  return `${date} στις ${time}`;
}

function isSameCalendarDay(a, b = new Date()) {
  const left = new Date(a);
  return left.getFullYear() === b.getFullYear()
    && left.getMonth() === b.getMonth()
    && left.getDate() === b.getDate();
}

function assertCanConfirmAttendance(booking) {
  if (booking.attendance_confirmed) return 'already_confirmed';
  const allowed = ['pending', 'confirmed', 'in_progress', 'completed'];
  if (!allowed.includes(booking.status)) {
    throw new Error('Αυτή η κράτηση δεν μπορεί να επιβεβαιωθεί.');
  }
  const endsAt = booking.ends_at ? new Date(booking.ends_at) : qrCheckinWindowEnd(booking);
  const now = new Date();
  if (endsAt > now) {
    throw new Error('Η προπόνηση δεν έχει ολοκληρωθεί ακόμα.');
  }
  const cutoff = new Date(now.getTime() - LATE_SELF_CONFIRM_HOURS * 60 * 60 * 1000);
  if (endsAt < cutoff) {
    throw new Error('Η περίοδος επιβεβαίωσης έχει λήξει. Επικοινώνησε με το γυμναστήριο.');
  }
}

async function fetchQrCheckinCandidates(dbConn, userId, bizId) {
  const [rows] = await dbConn.query(
    `SELECT b.id, b.service_id, b.business_id, b.starts_at, b.ends_at, b.attendance_confirmed,
            s.name AS service_name, s.duration_mins,
            st.full_name AS staff_name
     FROM bookings b
     LEFT JOIN services s ON s.id = b.service_id
     LEFT JOIN staff st ON st.id = b.staff_id
     WHERE b.user_id = ? AND b.business_id = ?
       AND b.attendance_confirmed = 0
       AND (
         b.status IN ('confirmed','pending','in_progress')
         OR (b.status = 'completed' AND b.ends_at >= DATE_SUB(NOW(), INTERVAL ? HOUR))
       )
       AND (
         DATE(b.starts_at) = CURDATE()
         OR b.starts_at > NOW()
         OR b.ends_at >= DATE_SUB(NOW(), INTERVAL ? HOUR)
       )
     ORDER BY b.starts_at ASC`,
    [userId, bizId, LATE_SELF_CONFIRM_HOURS, LATE_SELF_CONFIRM_HOURS]
  );
  return rows;
}

async function mapQrCheckinBooking(dbConn, booking) {
  const enriched = await enrichBookingWithTips(dbConn, booking);
  const endsAt = booking.ends_at || qrCheckinWindowEnd(booking);
  return {
    id: booking.id,
    serviceName: booking.service_name,
    staffName: booking.staff_name || null,
    startsAt: booking.starts_at,
    endsAt,
    scheduleLabel: enriched.schedule_label || null,
    roomName: enriched.schedule_room || null,
    roomPhotoUrl: enriched.room_photo_url || null,
    roomShortInfo: enriched.room_short_info || null,
    attendanceConfirmed: !!booking.attendance_confirmed,
  };
}

function splitQrCheckinCandidates(candidateBookings, now = new Date()) {
  const inWindow = candidateBookings.filter((b) => isQrCheckinWindowOpen(b, now));
  return {
    inWindow,
    alreadyCheckedIn: inWindow.filter((b) => b.attendance_confirmed),
    eligible: inWindow.filter((b) => !b.attendance_confirmed),
  };
}

async function buildQrCheckinUnavailableResponse(dbConn, candidateBookings, now = new Date()) {
  const pendingAttendance = candidateBookings.filter((b) => {
    if (b.attendance_confirmed) return false;
    const end = qrCheckinWindowEnd(b);
    return end <= now;
  });

  const todayBookings = candidateBookings.filter((b) => isSameCalendarDay(b.starts_at, now));
  const referencePool = pendingAttendance.length > 0 ? pendingAttendance : todayBookings;

  if (referencePool.length > 0) {
    const reference = referencePool.reduce((best, b) => {
      const end = qrCheckinWindowEnd(b).getTime();
      const bestEnd = qrCheckinWindowEnd(best).getTime();
      if (pendingAttendance.length > 0) {
        return end > bestEnd ? b : best;
      }
      const diff = Math.abs(new Date(b.starts_at).getTime() - now.getTime());
      const bestDiff = Math.abs(new Date(best.starts_at).getTime() - now.getTime());
      return diff < bestDiff ? b : best;
    });
    const inWindow = isQrCheckinWindowOpen(reference, now);
    return {
      status: 400,
      body: {
        error: inWindow
          ? `Δεν ήταν δυνατό το check-in για ${formatQrBookingTime(reference.starts_at)}.`
          : `Το check-in είναι διαθέσιμο από ${QR_CHECKIN_BEFORE_MINS} λεπτά πριν έως ${QR_CHECKIN_AFTER_MINS} λεπτά μετά το μάθημα (${formatQrBookingTime(reference.starts_at)}).`,
        code: inWindow ? 'checkin_failed' : 'outside_checkin_window',
        booking: await mapQrCheckinBooking(dbConn, reference),
        canManualConfirm: !reference.attendance_confirmed && qrCheckinWindowEnd(reference) <= now,
      },
    };
  }

  const nextBooking = candidateBookings.find((b) => new Date(b.starts_at) > now)
    || candidateBookings[candidateBookings.length - 1]
    || null;
  if (nextBooking) {
    return {
      status: 400,
      body: {
        error: `Πρέπει να κάνεις check-in την ημέρα και ώρα της κράτησής σου (${formatQrBookingDateTime(nextBooking.starts_at)}).`,
        code: 'wrong_day_or_time',
        booking: await mapQrCheckinBooking(dbConn, nextBooking),
      },
    };
  }

  return {
    status: 404,
    body: { error: 'Δεν έχεις κράτηση για check-in.', code: 'no_booking' },
  };
}

// ── QR Walk-in Check-in ──────────────────────────────────────
router.get('/:bizId/qr-checkin/options', softAuth, requireActiveCustomer, async (req, res) => {
  const { bizId } = req.params;
  const userId = req.user.userId;

  try {
    const candidateBookings = await fetchQrCheckinCandidates(db, userId, bizId);
    const { alreadyCheckedIn, eligible } = splitQrCheckinCandidates(candidateBookings);

    if (eligible.length > 0) {
      const bookings = await Promise.all(eligible.map((b) => mapQrCheckinBooking(db, b)));
      return res.json({ eligible: bookings });
    }

    if (alreadyCheckedIn.length > 0) {
      const checked = await Promise.all(alreadyCheckedIn.map((b) => mapQrCheckinBooking(db, b)));
      return res.status(409).json({
        error: alreadyCheckedIn.length === 1
          ? 'Έχεις ήδη κάνει check-in για αυτό το μάθημα.'
          : 'Έχεις ήδη κάνει check-in για τα μαθήματα αυτής της ώρας.',
        code: 'already_checked_in',
        booking: checked[0],
        checkedIn: checked,
      });
    }

    const unavailable = await buildQrCheckinUnavailableResponse(db, candidateBookings);
    return res.status(unavailable.status).json(unavailable.body);
  } catch (err) {
    console.error('qr-checkin options error', err);
    return res.status(500).json({ error: err.message });
  }
});

router.post('/:bizId/qr-checkin', softAuth, requireActiveCustomer, async (req, res) => {
  const { bizId } = req.params;
  const userId = req.user.userId;
  const { bookingId } = req.body || {};

  if (!bookingId) {
    return res.status(400).json({ error: 'Επίλεξε για ποια κράτηση θέλεις να κάνεις check-in.' });
  }

  try {
    const [[user]] = await db.query('SELECT full_name FROM users WHERE id = ?', [userId]);
    const candidateBookings = await fetchQrCheckinCandidates(db, userId, bizId);
    const { alreadyCheckedIn, eligible } = splitQrCheckinCandidates(candidateBookings);

    const matchedBooking = eligible.find((b) => String(b.id) === String(bookingId)) || null;
    if (!matchedBooking) {
      const already = alreadyCheckedIn.find((b) => String(b.id) === String(bookingId));
      if (already) {
        return res.status(409).json({
          error: 'Έχεις ήδη κάνει check-in για αυτό το μάθημα.',
          code: 'already_checked_in',
          booking: await mapQrCheckinBooking(db, already),
        });
      }

      const unavailable = await buildQrCheckinUnavailableResponse(db, candidateBookings);
      return res.status(unavailable.status).json(unavailable.body);
    }

    // ── Step 2: find active membership ────────────────────────────────
    const [memberships] = await db.query(
      `SELECT * FROM user_memberships
       WHERE user_id = ? AND business_id = ?
         AND valid_from <= CURDATE() AND valid_until >= CURDATE()
       ORDER BY
         CASE WHEN total_sessions >= 9999 THEN 1 ELSE 0 END ASC,
         valid_until ASC`,
      [userId, bizId]
    );

    const membership = memberships.find(m =>
      (m.service_id && String(m.service_id) === String(matchedBooking.service_id)) ||
      m.total_sessions >= 9999 ||
      m.used_sessions < m.total_sessions
    ) || memberships.find(m => m.total_sessions >= 9999 || m.used_sessions < m.total_sessions);

    if (!membership) {
      return res.status(403).json({ error: 'Δεν έχεις ενεργή συνδρομή.' });
    }

    const isUnlimited = membership.total_sessions >= 9999;
    let remaining = null;

    // ── Step 3: deduct session if needed ──────────────────────────────
    if (!isUnlimited) {
      await db.query(
        'UPDATE user_memberships SET used_sessions = used_sessions + 1 WHERE id = ?',
        [membership.id]
      );
      remaining = membership.total_sessions - membership.used_sessions - 1;
    }

    // ── Step 4: mark attendance on the matched booking ────────────────
    await db.query(
      `UPDATE bookings
       SET attendance_confirmed = 1, attendance_confirmed_at = NOW(), status = 'completed'
       WHERE id = ? AND attendance_confirmed = 0`,
      [matchedBooking.id]
    );

    // ── Step 5: record qr_checkin ─────────────────────────────────────
    await db.query(
      `INSERT INTO qr_checkins (id, business_id, user_id, membership_id, session_deducted)
       VALUES (?, ?, ?, ?, ?)`,
      [uuidv4(), bizId, userId, membership.id, isUnlimited ? 0 : 1]
    );

    const bookingPayload = await mapQrCheckinBooking(db, matchedBooking);

    return res.json({
      success: true,
      userName: user?.full_name || '',
      isUnlimited,
      remaining,
      membershipId: membership.id,
      booking: bookingPayload,
    });
  } catch (err) {
    console.error('qr-checkin error', err);
    return res.status(500).json({ error: err.message });
  }
});

// ── Recent QR check-ins for kiosk display (admin) ─────────────
router.get('/:bizId/qr-checkins', async (req, res) => {
  const { bizId } = req.params;
  try {
    const [rows] = await db.query(
      `SELECT qc.id, qc.checked_in_at, qc.session_deducted, qc.membership_id,
              u.full_name, u.email,
              um.total_sessions, um.used_sessions
       FROM qr_checkins qc
       JOIN users u ON u.id = qc.user_id
       LEFT JOIN user_memberships um ON um.id = qc.membership_id
       WHERE qc.business_id = ?
         AND DATE(qc.checked_in_at) = CURDATE()
       ORDER BY qc.checked_in_at DESC
       LIMIT 20`,
      [bizId]
    );
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ── Client messaging ─────────────────────────────────────────
router.get('/:bizId/messages/threads', softAuth, requireActiveCustomer, async (req, res) => {
  try {
    const threads = await listClientThreads(db, req.params.bizId, req.user.userId);
    return res.json({ threads });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.get('/:bizId/messages/peers', softAuth, requireActiveCustomer, async (req, res) => {
  try {
    const peers = await listClientPeers(db, req.params.bizId, req.user.userId);
    return res.json({ peers });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.get('/:bizId/messages/threads/:threadId', softAuth, requireActiveCustomer, async (req, res) => {
  try {
    const data = await getClientThreadById(db, req.params.bizId, req.user.userId, req.params.threadId);
    if (!data) return res.status(404).json({ error: 'Η συνομιλία δεν βρέθηκε' });
    return res.json(data);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.post('/:bizId/messages/threads', softAuth, requireActiveCustomer, async (req, res) => {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const peer = parsePeerFromBody(req.body || {});
    const data = await openClientThread(conn, req.params.bizId, req.user.userId, peer);
    await conn.commit();
    return res.status(201).json(data);
  } catch (err) {
    await conn.rollback();
    return res.status(err.status || 500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

const clientMessageUpload = createMessageUpload((req) => ({
  businessId: req.params.bizId,
  threadId: req.params.threadId,
}));

router.post('/:bizId/messages/threads/:threadId/upload', softAuth, requireActiveCustomer, handleMessageUpload(clientMessageUpload), async (req, res) => {
  try {
    const data = await getClientThreadById(db, req.params.bizId, req.user.userId, req.params.threadId);
    if (!data) return res.status(404).json({ error: 'Η συνομιλία δεν βρέθηκε' });
    if (!req.file) return res.status(400).json({ error: 'Απαιτείται εικόνα' });

    await assertImageUploadAllowed(db, {
      businessId: req.params.bizId,
      senderRole: 'client',
      senderClientUserId: req.user.userId,
    });

    const attachment_url = publicUploadPath(req.params.bizId, req.params.threadId, req.file.filename);
    return res.json({ attachment_url });
  } catch (err) {
    return res.status(err.status || 500).json({ error: err.message });
  }
});

router.post('/:bizId/messages/threads/:threadId/messages', softAuth, requireActiveCustomer, async (req, res) => {
  const conn = await db.getConnection();
  try {
    let attachment_url = req.body?.attachment_url;
    let message_type = req.body?.message_type;
    const imageBuf = parseBase64Image(req.body?.image_base64);
    if (imageBuf) {
      if (imageBuf.length > 8 * 1024 * 1024) {
        return res.status(413).json({ error: 'Η εικόνα είναι πολύ μεγάλη (μέγιστο 8MB)' });
      }
      await assertImageUploadAllowed(db, {
        businessId: req.params.bizId,
        senderRole: 'client',
        senderClientUserId: req.user.userId,
      });
      attachment_url = saveMessageImageBuffer(req.params.bizId, req.params.threadId, imageBuf);
      message_type = 'image';
    }

    await conn.beginTransaction();
    const result = await sendClientMessage(conn, {
      role: 'client',
      businessId: req.params.bizId,
      userId: req.user.userId,
    }, {
      body: req.body?.body,
      threadId: req.params.threadId,
      attachment_url,
      message_type,
    });
    await conn.commit();
    return res.status(201).json(result);
  } catch (err) {
    await conn.rollback();
    return res.status(err.status || 500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

router.post('/:bizId/messages/threads/:threadId/read', softAuth, requireActiveCustomer, async (req, res) => {
  try {
    const result = await markClientThreadRead(db, req.params.bizId, req.user.userId, req.params.threadId);
    return res.json(result);
  } catch (err) {
    return res.status(err.status || 500).json({ error: err.message });
  }
});

router.get('/:bizId/messages/unread-count', softAuth, requireActiveCustomer, async (req, res) => {
  try {
    const count = await getClientUnreadCount(db, req.params.bizId, req.user.userId);
    return res.json({ unread_count: count });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

/** @deprecated use GET /messages/threads */
router.get('/:bizId/messages', softAuth, requireActiveCustomer, async (req, res) => {
  try {
    const threads = await listClientThreads(db, req.params.bizId, req.user.userId);
    if (threads.length === 0) {
      return res.json({ thread: null, messages: [], threads: [] });
    }
    const data = await getClientThreadById(db, req.params.bizId, req.user.userId, threads[0].id);
    return res.json({ ...data, threads });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.post('/:bizId/messages', softAuth, requireActiveCustomer, async (req, res) => {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const peer = req.body?.peer_role ? parsePeerFromBody(req.body) : { peer_role: 'admin', peer_staff_id: null, peer_nutritionist_id: null };
    const result = await sendClientMessage(conn, {
      role: 'client',
      businessId: req.params.bizId,
      userId: req.user.userId,
    }, { body: req.body?.body, peer: peer });
    await conn.commit();
    return res.status(201).json(result);
  } catch (err) {
    await conn.rollback();
    return res.status(err.status || 500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// ============================================================
// DROP-IN ENDPOINTS
// ============================================================

// GET /:bizId/dropin/services — services available for drop-in (price > 0)
router.get('/:bizId/dropin/services', async (req, res) => {
  try {
    const hasOffers = await businessHasDropinOffers(db, req.params.bizId);
    if (hasOffers) {
      const params = [req.params.bizId];
      let locSql = '';
      if (req.query.location_id) {
        locSql = ' AND o.location_id = ?';
        params.push(req.query.location_id);
      }
      const [rows] = await db.query(
        `SELECT s.id, s.name, s.description, s.duration_mins, o.price_cents AS drop_in_price_cents,
                s.category, s.color, o.location_id
         FROM dropin_offers o
         JOIN services s ON s.id = o.service_id
         WHERE o.business_id = ? AND o.is_active = 1 AND s.is_active = 1 ${locSql}
         ORDER BY s.category, s.name`,
        params,
      );
      return res.json(rows);
    }
    const [rows] = await db.query(
      `SELECT id, name, description, duration_mins, drop_in_price_cents, category, color
       FROM services
       WHERE business_id = ? AND is_active = 1 AND drop_in_price_cents > 0
       ORDER BY category, name`,
      [req.params.bizId],
    );
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /:bizId/dropin/payment-intent — create Stripe payment intent for drop-in
router.post('/:bizId/dropin/payment-intent', softAuth, async (req, res) => {
  const { service_id, guest_name } = req.body;
  const conn = await db.getConnection();
  try {
    const [[svc]] = await conn.query(
      'SELECT id, name, drop_in_price_cents FROM services WHERE id = ? AND business_id = ? AND is_active = 1',
      [service_id, req.params.bizId],
    );
    if (!svc) return res.status(404).json({ error: 'Υπηρεσία δεν βρέθηκε ή δεν έχει drop-in τιμή' });

    const offer = await loadActiveOffer(conn, req.params.bizId, service_id, req.body.location_id || null);
    const amountCents = offer?.price_cents || svc.drop_in_price_cents;
    if (!(amountCents > 0)) return res.status(404).json({ error: 'Υπηρεσία δεν βρέθηκε ή δεν έχει drop-in τιμή' });

    const priced = await previewRewardPrice(conn, req.user?.userId, req.params.bizId, amountCents);
    const { createPaymentIntent } = require('../lib/online_payments');
    const intent = await createPaymentIntent(conn, req.params.bizId, {
      amountCents: priced.priceCents,
      metadata: { service_id, service_name: svc.name },
      userId: req.user?.userId || null,
      userEmail: req.user?.email || null,
      userName: req.user?.fullName || guest_name || null,
    });
    return res.json(intent);
  } catch (err) {
    return res.status(err.status || 500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// POST /:bizId/dropin/book — create drop-in booking (member or guest)
router.post('/:bizId/dropin/book', softAuth, async (req, res) => {
  const bizId = req.params.bizId;
  const {
    service_id, date, time,
    payment_method = 'venue', payment_intent_id,
    guest_name, guest_email, guest_phone,
    staff_id, location_id,
  } = req.body;

  if (!service_id || !date || !time) {
    return res.status(400).json({ error: 'Απαιτούνται υπηρεσία, ημερομηνία και ώρα' });
  }
  const isGuest = !req.user;
  if (isGuest && !guest_name) {
    return res.status(400).json({ error: 'Απαιτείται όνομα για guests' });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const [[svc]] = await conn.query(
      'SELECT id, name, drop_in_price_cents, duration_mins, max_capacity FROM services WHERE id = ? AND business_id = ? AND is_active = 1',
      [service_id, bizId],
    );
    if (!svc) { await conn.rollback(); return res.status(404).json({ error: 'Υπηρεσία δεν βρέθηκε' }); }

    const offer = await loadActiveOffer(conn, bizId, service_id, location_id || null);
    const usesOffers = await businessHasDropinOffers(conn, bizId);
    if (usesOffers && !offer) {
      await conn.rollback();
      return res.status(400).json({ error: 'Δεν υπάρχει drop-in για αυτό το κατάστημα και αυτή την υπηρεσία' });
    }
    if (offer) {
      const allowed = filterSlotsByOffer(
        { [String(time).slice(0, 5)]: [{ id: staff_id || [...offer.staffIds][0] }] },
        offer,
        weekdayFromDate(date),
        svc.duration_mins || 0,
      );
      if (!Object.keys(allowed).length || (staff_id && !offer.staffIds.has(staff_id))) {
        await conn.rollback();
        return res.status(400).json({ error: 'Αυτή η ώρα δεν είναι διαθέσιμη για drop-in' });
      }
      svc.drop_in_price_cents = offer.price_cents;
    } else if (!(svc.drop_in_price_cents > 0)) {
      await conn.rollback();
      return res.status(404).json({ error: 'Υπηρεσία δεν βρέθηκε' });
    }

    if (req.user?.userId) {
      const priced = await applyRewardPrice(conn, req.user.userId, bizId, svc.drop_in_price_cents);
      svc.drop_in_price_cents = priced.priceCents;
    }

    // Capacity check: count bookings + dropin_bookings for this slot
    const [[capRow]] = await conn.query(`
      SELECT
        COALESCE((SELECT COUNT(*) FROM bookings
                  WHERE business_id=? AND service_id=? AND booking_date=? AND TIME_FORMAT(starts_at,'%H:%i')=? AND status='confirmed'), 0)
        + COALESCE((SELECT COUNT(*) FROM dropin_bookings
                    WHERE business_id=? AND service_id=? AND booking_date=? AND TIME_FORMAT(booking_time,'%H:%i')=? AND status IN ('confirmed','attended')), 0)
        AS total_booked
    `, [bizId, service_id, date, time, bizId, service_id, date, time]);
    if (svc.max_capacity && capRow.total_booked >= svc.max_capacity) {
      await conn.rollback();
      return res.status(409).json({ error: 'Η κλάση είναι πλήρης', code: 'SLOT_FULL' });
    }

    let paymentStatus = 'pending';
    if (payment_method === 'card') {
      if (!payment_intent_id) {
        await conn.rollback();
        return res.status(402).json({ error: 'Η πληρωμή με κάρτα δεν ολοκληρώθηκε' });
      }
      const { confirmPayment } = require('../lib/online_payments');
      const result = await confirmPayment(conn, bizId, payment_intent_id);
      if (result.status !== 'succeeded') {
        await conn.rollback();
        return res.status(402).json({ error: 'Η πληρωμή δεν ολοκληρώθηκε' });
      }
      paymentStatus = 'paid';
    }

    // Find staff name for this slot
    let staffName = null;
    if (staff_id) {
      const [[st]] = await conn.query('SELECT full_name FROM staff WHERE id = ? AND business_id = ?', [staff_id, bizId]);
      staffName = st?.full_name || null;
    }

    // Create dropin_bookings record
    const dropinId = uuidv4();
    const qrToken  = uuidv4();
    await conn.query(`
      INSERT INTO dropin_bookings
        (id, business_id, user_id, guest_name, guest_email, guest_phone,
         service_id, service_name, booking_date, booking_time, staff_name,
         price_cents, payment_method, payment_status, payment_intent_id, status, qr_token)
      VALUES (?,?,?,?,?,?, ?,?,?,?,?, ?,?,?,?,'confirmed',?)
    `, [
      dropinId, bizId,
      req.user?.userId || null, guest_name || null, guest_email || null, guest_phone || null,
      service_id, svc.name, date, time, staffName,
      svc.drop_in_price_cents, payment_method, paymentStatus, payment_intent_id || null,
      qrToken,
    ]);

    // For registered members, also create a bookings entry so trainers can see them
    let bookingId = null;
    if (req.user?.userId) {
      try {
        const { createOneBooking } = require('../lib/create_booking');
        const bookingResult = await createOneBooking(conn, {
          bizId, userId: req.user.userId, service_id,
          staff_id: staff_id || null, date, time,
          location_id: location_id || null,
          use_credit: false, source: 'dropin',
        });
        bookingId = bookingResult.bookingId || bookingResult.id;
        if (bookingId) {
          await conn.query('UPDATE dropin_bookings SET booking_id=? WHERE id=?', [bookingId, dropinId]);
        }
      } catch (_) { /* slot might conflict — dropin booking still stands */ }
    }

    await conn.commit();
    return res.status(201).json({
      id: dropinId,
      qr_token: qrToken,
      service_name: svc.name,
      booking_date: date,
      booking_time: time,
      price_cents: svc.drop_in_price_cents,
      payment_method,
      payment_status: paymentStatus,
      status: 'confirmed',
    });
  } catch (err) {
    await conn.rollback();
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// GET /:bizId/dropin/:bookingId — get dropin booking details (for QR display)
router.get('/:bizId/dropin/:bookingId', async (req, res) => {
  try {
    const [[row]] = await db.query(
      `SELECT db.*, s.description AS service_description
       FROM dropin_bookings db
       LEFT JOIN services s ON s.id = db.service_id
       WHERE db.id = ? AND db.business_id = ?`,
      [req.params.bookingId, req.params.bizId],
    );
    if (!row) return res.status(404).json({ error: 'Κράτηση δεν βρέθηκε' });
    return res.json(row);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// GET /:bizId/dropin/my-bookings — member's own dropin bookings
router.get('/:bizId/dropin/my-bookings', softAuth, requireActiveCustomer, async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT * FROM dropin_bookings
       WHERE user_id = ? AND business_id = ?
       ORDER BY booking_date DESC, booking_time DESC
       LIMIT 30`,
      [req.user.userId, req.params.bizId],
    );
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.post('/:bizId/messages/read', softAuth, requireActiveCustomer, async (req, res) => {
  try {
    const threadId = req.body?.thread_id;
    if (!threadId) {
      const threads = await listClientThreads(db, req.params.bizId, req.user.userId);
      for (const t of threads) {
        await markClientThreadRead(db, req.params.bizId, req.user.userId, t.id);
      }
      return res.json({ ok: true });
    }
    const result = await markClientThreadRead(db, req.params.bizId, req.user.userId, threadId);
    return res.json(result);
  } catch (err) {
    return res.status(err.status || 500).json({ error: err.message });
  }
});

// ============================================================
// GET /api/booking/:bizId/gym-occupancy  — live occupancy (public, no auth)
// Returns current check-in count vs capacity + a status label
// "currently in gym" = checked in within the last 3 hours
// ============================================================
router.get('/:bizId/gym-occupancy', async (req, res) => {
  try {
    const [[biz]] = await db.query(
      'SELECT gym_capacity FROM businesses WHERE id = ? AND is_active = 1',
      [req.params.bizId],
    );
    if (!biz) return res.status(404).json({ error: 'Gym not found' });

    const [[{ count }]] = await db.query(`
      SELECT COUNT(*) AS count
      FROM entrance_checkins
      WHERE business_id = ?
        AND checked_in_at >= DATE_SUB(NOW(), INTERVAL 3 HOUR)
    `, [req.params.bizId]);

    const current  = Number(count);
    const capacity = biz.gym_capacity ? Number(biz.gym_capacity) : null;

    let status = 'unknown';
    if (capacity) {
      const ratio = current / capacity;
      if (ratio >= 0.9)      status = 'full';
      else if (ratio >= 0.5) status = 'busy';
      else                   status = 'quiet';
    }

    return res.json({ current, capacity, status });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// GET /api/booking/:bizId/open-access-services  — open-access services (no booking needed)
// ============================================================
router.get('/:bizId/open-access-services', async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT id, name, description, color_hex, image_url
      FROM services
      WHERE business_id = ? AND is_open_access = 1 AND is_active = 1
      ORDER BY name ASC
    `, [req.params.bizId]);
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

module.exports = router;
