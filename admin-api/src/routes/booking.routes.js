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
const { awardLoyaltyPoints, getUserStats } = require('../lib/loyalty');
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
        st.full_name AS staff_name, st.color_hex, st.avatar_url
      FROM bookings b
      JOIN services sv ON sv.id = b.service_id
      JOIN staff    st ON st.id = b.staff_id
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
      JOIN staff st ON st.id = b.staff_id
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

module.exports = router;
