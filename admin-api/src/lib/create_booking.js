const { v4: uuidv4 } = require('uuid');
const {
  assertSlotCapacity,
  assertStaffAvailable,
  findStaffForSlot,
  isSlotBookableForDate,
  assertGymOpenOnDate,
} = require('./slots');
const { createAdminNotification } = require('./notifications');
const { enrichBookingWithTips } = require('./booking_tips');
const { createUserNotification } = require('./user_notifications');
const {
  resolveLocationId,
  assertServiceAtLocation,
  assertStaffAtLocation,
} = require('./locations');
const { resolveScheduleRoomId } = require('./rooms');
const {
  effectiveTotalSessions,
  membershipCredits,
  shouldDeductSession,
} = require('./membership_sessions');
const { trialBlockingInfo } = require('./trial_membership');
const {
  canBookWithMembership,
  bookingBlockMessage,
  getGracePeriodDays,
} = require('./membership_lifecycle');

async function loadPlanServiceMap(dbConn, memberships) {
  const planIds = [...new Set(memberships.map(m => m.plan_id).filter(Boolean))];
  if (!planIds.length) return new Map();
  const [rows] = await dbConn.query(
    'SELECT plan_id, service_id FROM service_plan_assignments WHERE plan_id IN (?)',
    [planIds]
  );
  return new Map(rows.map(r => [r.plan_id, String(r.service_id)]));
}

function findMembershipForService(memberships, service, planToServiceId = new Map()) {
  const sid = String(service.id);

  const byServiceId = memberships.find(m => m.service_id && String(m.service_id) === sid);
  if (byServiceId) return byServiceId;

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

/**
 * Block duplicate bookings: same user cannot book the same slot twice
 * (same service or different service at the same starts_at).
 */
async function assertNoUserBookingConflict(conn, {
  bizId,
  userId,
  startsAt,
  serviceId,
  date,
  time,
  excludeBookingId,
}) {
  const params = [userId, bizId, startsAt];
  let sql = `
    SELECT b.id, b.service_id, s.name AS service_name
    FROM bookings b
    JOIN services s ON s.id = b.service_id
    WHERE b.user_id = ? AND b.business_id = ?
      AND b.status IN ('confirmed', 'pending')
      AND b.starts_at = ?
  `;
  if (excludeBookingId) {
    sql += ' AND b.id != ?';
    params.push(excludeBookingId);
  }
  sql += ' LIMIT 1';

  const [[existing]] = await conn.query(sql, params);
  if (!existing) return;

  const sameService = String(existing.service_id) === String(serviceId);
  const when = date && time ? `${date} ${time}` : String(startsAt).slice(0, 16);
  const err = new Error(
    sameService
      ? `Έχεις ήδη κράτηση για αυτή την υπηρεσία στις ${when}. Επίλεξε άλλη ώρα.`
      : `Έχεις ήδη κράτηση για «${existing.service_name}» στις ${when}. Επίλεξε άλλη ώρα.`
  );
  err.code = sameService ? 'DUPLICATE_BOOKING' : 'TIME_CONFLICT';
  err.conflicting_service = existing.service_name;
  throw err;
}

/**
 * Create a single booking inside an open transaction.
 * @returns {Promise<object>}
 */
async function createOneBooking(conn, {
  bizId,
  userId,
  service_id,
  staff_id,
  date,
  time,
  location_id = null,
  use_credit = true,
  is_trial = false,
  skipNotifications = false,
  source = 'app',
  force = false,
  status = 'confirmed',
  defer_credit_charge = false,
  excluded_staff_ids = [],
  override_membership_id = null,
}) {
  const trial = !!is_trial;
  let isAdvanceBooking = false;
  const bookingStatus = status === 'pending' ? 'pending' : 'confirmed';
  const chargeCredit = use_credit && !trial && !defer_credit_charge && bookingStatus !== 'pending';
  const reserveCredit = use_credit && !trial && (defer_credit_charge || bookingStatus === 'pending');
  const [[service]] = await conn.query(
    'SELECT * FROM services WHERE id = ? AND business_id = ?',
    [service_id, bizId]
  );
  if (!service) throw new Error('Η υπηρεσία δεν βρέθηκε');

  const isNutritionConsult = service.category === 'nutrition_consultation';
  let finalLocationId = null;
  let slotLocationId = null;
  let slotStaffId = null;

  if (isNutritionConsult) {
    slotStaffId = staff_id || null;
    if (staff_id) {
      const [[nut]] = await conn.query(
        'SELECT location_id FROM nutritionists WHERE staff_id = ? AND business_id = ? AND is_active = 1',
        [staff_id, bizId],
      );
      finalLocationId = nut?.location_id || null;
    }
  } else {
    finalLocationId = await resolveLocationId(conn, bizId, location_id, {
      userId,
      requireExplicit: source === 'app',
    });
    slotLocationId = finalLocationId;
    await assertServiceAtLocation(conn, service_id, finalLocationId, bizId);
  }

  await assertGymOpenOnDate(conn, bizId, date);
  if (!isSlotBookableForDate(date, time)) {
    throw new Error('Αυτή η ώρα έχει ήδη περάσει. Επίλεξε μεταγενέστερη ώρα.');
  }

  const startsAt = new Date(`${date}T${time}:00`);
  const endsAt = new Date(startsAt.getTime() + service.duration_mins * 60000);

  await assertNoUserBookingConflict(conn, {
    bizId,
    userId,
    startsAt,
    serviceId: service_id,
    date,
    time,
    excludeBookingId: null,
  });

  const { computed } = await assertSlotCapacity(
    conn, bizId, service_id, date, time, startsAt, endsAt, null, force, slotLocationId, slotStaffId,
  );

  let finalStaffId = staff_id;
  if (!finalStaffId) {
    if (!service.hide_staff_selection) {
      throw new Error('Απαιτείται επιλογή γυμναστή');
    }
    finalStaffId = await findStaffForSlot(
      conn, bizId, service_id, computed, time, startsAt, { excludedStaffIds: excluded_staff_ids },
    );
  } else {
    const pool = computed.slotMap[time] || [];
    if (!pool.some(s => s.id === finalStaffId)) {
      throw new Error(isNutritionConsult
        ? 'Ο διατροφολόγος δεν είναι διαθέσιμος αυτή την ώρα'
        : 'Ο γυμναστής δεν είναι διαθέσιμος αυτή την ώρα');
    }
  }

  await assertStaffAvailable(conn, bizId, finalStaffId, service_id, startsAt, endsAt, null);
  if (!isNutritionConsult) {
    await assertStaffAtLocation(conn, finalStaffId, finalLocationId, bizId);
  }

  const [[user]] = await conn.query(
    'SELECT id, full_name, account_status, deleted_at FROM users WHERE id = ? AND business_id = ?',
    [userId, bizId]
  );
  if (!user) throw new Error('Ο χρήστης δεν βρέθηκε');
  if (user.deleted_at) throw new Error('Ο πελάτης είναι στον κάδο — επανέφερέ τον για νέες κρατήσεις.');
  const allowPendingTrial = trial && source === 'admin';
  if (user.account_status && user.account_status !== 'active' && !allowPendingTrial) {
    throw new Error('Ο πελάτης δεν είναι ενεργός — απαιτείται έγκριση ή επανενεργοποίηση.');
  }

  let membershipId = null;
  if (override_membership_id) {
    membershipId = override_membership_id;
    if (chargeCredit) {
      await conn.query(
        'UPDATE user_memberships SET used_sessions = used_sessions + 1 WHERE id = ?',
        [membershipId],
      );
    }
  } else if (chargeCredit || reserveCredit) {
    const graceDays = await getGracePeriodDays(conn, bizId);
    const [memberships] = await conn.query(`
      SELECT id, plan_id, service_id, service_category, membership_status,
             total_sessions, used_sessions,
             (total_sessions - used_sessions) AS remaining_sessions,
             valid_until, valid_from, trial_booking_id
      FROM user_memberships
      WHERE user_id = ? AND business_id = ?
        AND membership_status IN ('active', 'trial')
        AND membership_status != 'cancelled'
        AND (
          valid_until >= CURDATE()
          OR DATE_ADD(valid_until, INTERVAL ? DAY) >= CURDATE()
        )
    `, [userId, bizId, graceDays]);

    const planToServiceId = await loadPlanServiceMap(conn, memberships);
    const bookableMemberships = memberships.filter((m) =>
      canBookWithMembership(m, graceDays) && membershipCredits(m).canBook,
    );
    const credit = findMembershipForService(bookableMemberships, service, planToServiceId);
    if (!credit) {
      const trialMem = findMembershipForService(
        memberships.filter(m => m.membership_status === 'trial'),
        service,
        planToServiceId,
      );
      if (trialMem) {
        let trialStartsAt = null;
        if (trialMem.trial_booking_id) {
          const [rows] = await conn.query(
            'SELECT starts_at FROM bookings WHERE id = ?',
            [trialMem.trial_booking_id],
          );
          trialStartsAt = rows[0]?.starts_at || null;
        }
        const block = trialBlockingInfo({
          ...trialMem,
          service_name: service.name,
          trial_starts_at: trialStartsAt,
        });
        throw new Error(block?.message || 'Ο πελάτης έχει μόνο δοκιμαστικό — ενεργοποίησε πρώτα ενεργό πακέτο.');
      }
      // Allow up to 2 advance bookings when membership is expired/exhausted
      const hadMembership = memberships.length > 0 || !!findMembershipForService(memberships, service, planToServiceId);
      const anyPastMembership = hadMembership || (await (async () => {
        const [[row]] = await conn.query(
          `SELECT id FROM user_memberships WHERE user_id = ? AND business_id = ? AND service_id = ? LIMIT 1`,
          [userId, bizId, service_id]
        );
        return !!row;
      })());

      if (anyPastMembership) {
        const [[{ cnt }]] = await conn.query(
          `SELECT COUNT(*) AS cnt FROM bookings
           WHERE user_id = ? AND business_id = ? AND service_id = ?
             AND is_advance = 1 AND status NOT IN ('cancelled')`,
          [userId, bizId, service_id]
        );
        if (cnt >= 2) {
          throw new Error('Έχεις ήδη 2 προκαταβολικές κρατήσεις χωρίς ανανέωση. Ανανέωσε το πακέτο σου για να κλείσεις νέο μάθημα.');
        }
        isAdvanceBooking = true;
        membershipId = null;
      } else {
        const expiredMem = findMembershipForService(memberships, service, planToServiceId);
        const blockMsg = expiredMem
          ? bookingBlockMessage({ ...expiredMem, service_name: service.name }, graceDays)
          : null;
        throw new Error(blockMsg || 'Δεν έχεις ενεργό πακέτο για αυτή την υπηρεσία.');
      }
    } else {
      membershipId = credit.id;
      const credits = membershipCredits(credit);
      if ((chargeCredit || reserveCredit) && !credits.canBook) {
        throw new Error('Ο πελάτης δεν έχει διαθέσιμες συνεδρίες στο πακέτο του.');
      }
    }
  }

  if (trial && source === 'admin') {
    const [[existingTrial]] = await conn.query(`
      SELECT id FROM user_memberships
      WHERE user_id = ? AND business_id = ? AND service_id = ?
        AND membership_status = 'trial' AND valid_until >= CURDATE()
      LIMIT 1
    `, [userId, bizId, service_id]);
    if (existingTrial) {
      throw new Error('Ο πελάτης έχει ήδη δοκιμαστικό για αυτή την υπηρεσία. Χρησιμοποίησε «Πακέτο γυμναστηρίου» από το προφίλ του.');
    }
  }

  const bookingId = uuidv4();
  const roomId = await resolveScheduleRoomId(conn, {
    bizId,
    serviceId: service_id,
    startsAt,
    locationId: finalLocationId,
    staffId: finalStaffId,
  });

  await conn.query(`
    INSERT INTO bookings (id, business_id, location_id, room_id, user_id, staff_id, service_id, membership_id, starts_at, ends_at, status, source, is_trial, is_advance)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `, [bookingId, bizId, finalLocationId, roomId, userId, finalStaffId, service_id, membershipId, startsAt, endsAt, bookingStatus, source, trial ? 1 : 0, isAdvanceBooking ? 1 : 0]);

  if (membershipId && chargeCredit) {
    const [[mem]] = await conn.query(
      'SELECT id, total_sessions, used_sessions, membership_status FROM user_memberships WHERE id = ?',
      [membershipId],
    );
    if (mem && shouldDeductSession(mem)) {
      await conn.query(
        'UPDATE user_memberships SET used_sessions = used_sessions + 1 WHERE id = ?',
        [membershipId],
      );
    }
  }

  const tipsRow = await enrichBookingWithTips(conn, {
    id: bookingId,
    service_id,
    business_id: bizId,
    starts_at: startsAt,
  });

  if (!skipNotifications) {
    await createAdminNotification(conn, {
      businessId: bizId,
      type: bookingStatus === 'pending' ? 'booking_pending' : 'booking_created',
      title: bookingStatus === 'pending' ? 'Αίτημα κράτησης διατροφής' : 'Νέα κράτηση',
      body: `${user.full_name} — ${service.name} στις ${date} ${time}`,
      payload: { booking_id: bookingId, user_id: userId, service_id, starts_at: startsAt },
    });

    if (bookingStatus === 'pending') {
      await createUserNotification(conn, {
        businessId: bizId,
        userId,
        bookingId,
        type: 'booking_pending',
        title: `Αίτημα κράτησης — ${service.name}`,
        body: `Στις ${date} ${time}. Αναμένει επιβεβαίωση από τον διατροφολόγο.`,
        payload: { action: 'open_booking', booking_id: bookingId },
        sendPush: true,
      });
    } else {
      await createUserNotification(conn, {
        businessId: bizId,
        userId,
        bookingId,
        type: 'booking_confirmed',
        title: `Κράτηση επιβεβαιώθηκε — ${service.name}`,
        body: `Στις ${date} ${time}. Δες τα tips προετοιμασίας στην εφαρμογή.`,
        payload: { action: 'open_booking', booking_id: bookingId },
        sendPush: true,
      });
    }
  }

  return {
    booking_id: bookingId,
    service: service.name,
    date,
    time,
    starts_at: startsAt,
    ends_at: endsAt,
    status: bookingStatus,
    credit_used: !!membershipId,
    preparation_tips: tipsRow.preparation_tips,
    post_workout_tips: tipsRow.post_workout_tips,
    schedule_label: tipsRow.schedule_label,
  };
}

async function chargeBookingMembershipOnConfirm(conn, booking) {
  if (!booking?.membership_id) return;
  const [[mem]] = await conn.query(
    'SELECT id, total_sessions, used_sessions, membership_status FROM user_memberships WHERE id = ?',
    [booking.membership_id],
  );
  if (mem && shouldDeductSession(mem)) {
    await conn.query(
      'UPDATE user_memberships SET used_sessions = used_sessions + 1 WHERE id = ?',
      [booking.membership_id],
    );
  }
}

/** Επιστροφή πιστωτικής επίσκεψης όταν ακυρώνεται/διαγράφεται κράτηση */
async function refundBookingMembershipOnRemove(conn, booking) {
  if (!booking?.membership_id) return;
  const chargedStatuses = ['confirmed', 'completed', 'in_progress', 'no_show'];
  if (!chargedStatuses.includes(booking.status)) return;

  const [[mem]] = await conn.query(
    'SELECT id, total_sessions, used_sessions, membership_status FROM user_memberships WHERE id = ?',
    [booking.membership_id],
  );
  if (mem && shouldDeductSession(mem) && mem.used_sessions > 0) {
    await conn.query(
      'UPDATE user_memberships SET used_sessions = used_sessions - 1 WHERE id = ?',
      [booking.membership_id],
    );
  }
}

module.exports = {
  createOneBooking,
  assertNoUserBookingConflict,
  findMembershipForService,
  loadPlanServiceMap,
  membershipCredits,
  chargeBookingMembershipOnConfirm,
  refundBookingMembershipOnRemove,
};
