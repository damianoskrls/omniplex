'use strict';

const { v4: uuidv4 } = require('uuid');
const { createAdminNotification } = require('./notifications');
const { createUserNotification } = require('./user_notifications');
const { parseDateTimeParts } = require('./datetime');
const { assertSlotCapacity, assertStaffAvailable, findStaffForSlot } = require('./slots');
const { enrichBookingWithTips } = require('./booking_tips');
const { sendSms } = require('./sms');
const { getUserFcmTokens } = require('./push');

// ── Helpers ─────────────────────────────────────────────────────────────────

async function getWaitlistPosition(dbConn, businessId, serviceId, startsAt) {
  const [[row]] = await dbConn.query(`
    SELECT COALESCE(MAX(position), 0) + 1 AS next_pos
    FROM waitlist_entries
    WHERE business_id = ? AND service_id = ? AND starts_at = ?
      AND status IN ('waiting', 'offered')
  `, [businessId, serviceId, startsAt]);
  return row?.next_pos || 1;
}

async function getWaitlistConfig(conn, businessId) {
  const [[row]] = await conn.query(`
    SELECT waitlist_mode, waitlist_offer_minutes, waitlist_cutoff_hours, waitlist_sms
    FROM business_configs WHERE business_id = ?
  `, [businessId]);
  return {
    mode:         row?.waitlist_mode          || 'first_come',
    offerMinutes: row?.waitlist_offer_minutes ?? 15,
    cutoffHours:  row?.waitlist_cutoff_hours  ?? 2,
    smsEnabled:   !!row?.waitlist_sms,
  };
}

async function getUserPhone(conn, userId) {
  const [[row]] = await conn.query('SELECT phone FROM users WHERE id = ?', [userId]);
  return row?.phone || null;
}

async function logPromotion(conn, { businessId, waitlistEntryId, bookingId, serviceId, startsAt, method }) {
  await conn.query(`
    INSERT INTO waitlist_promotions
      (id, business_id, waitlist_entry_id, booking_id, service_id, starts_at, method)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `, [uuidv4(), businessId, waitlistEntryId, bookingId || null, serviceId, startsAt, method]);
}

// ── Notifications ────────────────────────────────────────────────────────────

async function notifyUserWaitlistOffered(conn, {
  businessId, userId, waitlistId, serviceId, serviceName, startsAt, smsEnabled,
}) {
  const { date: dateStr, time: timeStr } = parseDateTimeParts(startsAt);
  await createUserNotification(conn, {
    businessId,
    userId,
    type: 'waitlist_offered',
    title: `Θέση διαθέσιμη — ${serviceName}`,
    body: `Άνοιξε θέση για ${dateStr} στις ${timeStr}. Πάτα για να κλείσεις τη θέση σου.`,
    payload: { action: 'open_waitlist_offer', waitlist_id: waitlistId, service_id: serviceId, starts_at: startsAt },
    sendPush: true,
  });

  if (smsEnabled) {
    const phone = await getUserPhone(conn, userId);
    if (phone) {
      await sendSms(phone,
        `Άνοιξε θέση για ${serviceName} ${dateStr} ${timeStr}. Άνοιξε το app για να κλείσεις!`,
      );
    }
  }
}

// ── Auto-book ────────────────────────────────────────────────────────────────

async function autoBookWaitlistEntry(conn, bizId, entry, serviceName) {
  const { date, time } = parseDateTimeParts(entry.starts_at);
  const startsAt = new Date(entry.starts_at);
  const endsAt   = new Date(entry.ends_at);

  const { computed } = await assertSlotCapacity(
    conn, bizId, entry.service_id, date, time, startsAt, endsAt, null, false,
  );

  let staffId = entry.staff_id;
  if (!staffId) {
    staffId = await findStaffForSlot(conn, bizId, entry.service_id, computed, time, startsAt);
  }
  await assertStaffAvailable(conn, bizId, staffId, entry.service_id, startsAt, endsAt, null);

  const [memberships] = await conn.query(`
    SELECT id FROM user_memberships
    WHERE user_id = ? AND business_id = ?
      AND valid_until >= CURDATE()
      AND (total_sessions >= 9999 OR (total_sessions - used_sessions) > 0)
    LIMIT 1
  `, [entry.user_id, bizId]);
  const membershipId = memberships[0]?.id || null;

  const bookingId = uuidv4();
  await conn.query(`
    INSERT INTO bookings
      (id, business_id, user_id, staff_id, service_id, starts_at, ends_at, status, source, membership_id)
    VALUES (?, ?, ?, ?, ?, ?, ?, 'confirmed', 'waitlist', ?)
  `, [bookingId, bizId, entry.user_id, staffId, entry.service_id, startsAt, endsAt, membershipId]);

  if (membershipId) {
    await conn.query(
      'UPDATE user_memberships SET used_sessions = used_sessions + 1 WHERE id = ? AND total_sessions < 9999',
      [membershipId],
    );
  }

  await conn.query(
    `UPDATE waitlist_entries SET status = 'converted' WHERE id = ?`,
    [entry.id],
  );

  await createUserNotification(conn, {
    businessId: bizId,
    userId: entry.user_id,
    bookingId,
    type: 'waitlist_confirmed',
    title: `Κράτηση επιβεβαιώθηκε αυτόματα — ${serviceName}`,
    body: `${date} στις ${time}. Μπορείς να έρθεις στο γυμναστήριο!`,
    payload: { action: 'open_booking', booking_id: bookingId, waitlist_id: entry.id },
    sendPush: true,
  });

  return bookingId;
}

// ── Main promotion function ──────────────────────────────────────────────────

async function promoteFromWaitlist(conn, businessId, serviceId, startsAt, serviceName) {
  const cfg = await getWaitlistConfig(conn, businessId);

  // Stop promoting if class starts soon
  const classTime  = new Date(startsAt);
  const cutoffTime = new Date(classTime.getTime() - cfg.cutoffHours * 60 * 60 * 1000);
  if (new Date() >= cutoffTime) return null;

  // Find all eligible waiters in order
  const [waiters] = await conn.query(`
    SELECT w.id, w.user_id, w.auto_book, w.position, w.staff_id,
           w.starts_at, w.ends_at, w.service_id
    FROM waitlist_entries w
    WHERE w.business_id = ? AND w.service_id = ? AND w.starts_at = ?
      AND w.status = 'waiting'
    ORDER BY w.position ASC, w.created_at ASC
  `, [businessId, serviceId, startsAt]);

  if (!waiters.length) return null;

  // Check for auto_book first (regardless of mode)
  for (const waiter of waiters) {
    if (!waiter.auto_book) continue;

    const [[svc]] = await conn.query('SELECT name FROM services WHERE id = ?', [waiter.service_id]);
    const svcName = svc?.name || serviceName;
    try {
      const bookingId = await autoBookWaitlistEntry(conn, businessId, waiter, svcName);
      await logPromotion(conn, {
        businessId, waitlistEntryId: waiter.id, bookingId,
        serviceId, startsAt, method: 'auto_book',
      });
      await createAdminNotification(conn, {
        businessId,
        type: 'waitlist_auto_booked',
        title: 'Αυτόματη κράτηση από λίστα αναμονής',
        body: `Θέση κλείστηκε αυτόματα για ${svcName} (${parseDateTimeParts(startsAt).date}).`,
        payload: { booking_id: bookingId, waitlist_id: waiter.id },
      });
      return waiter;
    } catch (_) {
      // Slot filled between check and booking — continue to next
    }
  }

  const manualWaiters = waiters.filter(w => !w.auto_book);
  if (!manualWaiters.length) return null;

  if (cfg.mode === 'priority') {
    // Notify only the first waiter; give them offer_minutes to confirm
    const waiter = manualWaiters[0];
    await conn.query(
      `UPDATE waitlist_entries SET status = 'offered', offered_at = NOW() WHERE id = ?`,
      [waiter.id],
    );
    await notifyUserWaitlistOffered(conn, {
      businessId, userId: waiter.user_id, waitlistId: waiter.id,
      serviceId, serviceName, startsAt, smsEnabled: cfg.smsEnabled,
    });
    await createAdminNotification(conn, {
      businessId,
      type: 'waitlist_slot_opened',
      title: 'Θέση διαθέσιμη — λίστα αναμονής',
      body: `Προσφέρθηκε θέση για ${serviceName} στις ${parseDateTimeParts(startsAt).date} ${parseDateTimeParts(startsAt).time}. Εκκρεμεί επιβεβαίωση.`,
      payload: { waitlist_id: waiter.id, user_id: waiter.user_id, service_id: serviceId, starts_at: startsAt },
    });
    await logPromotion(conn, {
      businessId, waitlistEntryId: waiter.id, bookingId: null,
      serviceId, startsAt, method: 'priority',
    });
    return waiter;
  } else {
    // first_come: notify all, first to accept wins
    for (const waiter of manualWaiters) {
      await conn.query(
        `UPDATE waitlist_entries SET status = 'offered', offered_at = NOW() WHERE id = ?`,
        [waiter.id],
      );
      await notifyUserWaitlistOffered(conn, {
        businessId, userId: waiter.user_id, waitlistId: waiter.id,
        serviceId, serviceName, startsAt, smsEnabled: cfg.smsEnabled,
      });
      await logPromotion(conn, {
        businessId, waitlistEntryId: waiter.id, bookingId: null,
        serviceId, startsAt, method: 'first_come',
      });
    }
    return manualWaiters[0];
  }
}

// Keep backward-compat alias used by booking_delete.js
async function notifyWaitlistOnCancel(conn, businessId, serviceId, startsAt, serviceName) {
  return promoteFromWaitlist(conn, businessId, serviceId, startsAt, serviceName);
}

// ── Priority mode: expire stale offers and promote next ──────────────────────

async function processExpiredWaitlistOffers(conn) {
  // Find all businesses using priority mode
  const [configs] = await conn.query(`
    SELECT business_id, waitlist_offer_minutes, waitlist_sms
    FROM business_configs
    WHERE waitlist_mode = 'priority' AND feature_waitlist = 1
  `);

  for (const cfg of configs) {
    const [expired] = await conn.query(`
      SELECT w.id, w.business_id, w.service_id, w.starts_at, w.ends_at,
             sv.name AS service_name
      FROM waitlist_entries w
      JOIN services sv ON sv.id = w.service_id
      WHERE w.business_id = ?
        AND w.status = 'offered'
        AND w.offered_at < DATE_SUB(NOW(), INTERVAL ? MINUTE)
        AND w.starts_at > NOW()
    `, [cfg.business_id, cfg.waitlist_offer_minutes]);

    for (const entry of expired) {
      // Expire this offer
      await conn.query(
        `UPDATE waitlist_entries SET status = 'expired' WHERE id = ?`,
        [entry.id],
      );
      // Promote next waiter
      await promoteFromWaitlist(
        conn, entry.business_id, entry.service_id, entry.starts_at, entry.service_name,
      );
    }
  }
}

// ── Join waitlist ────────────────────────────────────────────────────────────

async function joinWaitlist(conn, {
  businessId, userId, serviceId, staffId, startsAt, endsAt, serviceName, userName, autoBook = false,
}) {
  const position = await getWaitlistPosition(conn, businessId, serviceId, startsAt);
  const id = uuidv4();

  await conn.query(`
    INSERT INTO waitlist_entries
      (id, business_id, user_id, service_id, staff_id, starts_at, ends_at, status, position, auto_book)
    VALUES (?, ?, ?, ?, ?, ?, ?, 'waiting', ?, ?)
  `, [id, businessId, userId, serviceId, staffId || null, startsAt, endsAt, position, autoBook ? 1 : 0]);

  const { date: dateStr, time: timeStr } = parseDateTimeParts(startsAt);
  const autoNote = autoBook ? ' Η θέση θα κλειστεί αυτόματα αν ελευθερωθεί.' : '';

  await createAdminNotification(conn, {
    businessId,
    type: 'waitlist_joined',
    title: 'Νέα εγγραφή σε λίστα αναμονής',
    body: `${userName} μπήκε σε αναμονή για ${serviceName} στις ${dateStr} ${timeStr} (θέση #${position}).`,
    payload: { waitlist_id: id, user_id: userId, service_id: serviceId, starts_at: startsAt },
  });

  await createUserNotification(conn, {
    businessId,
    userId,
    type: 'waitlist_joined',
    title: `Σε αναμονή — ${serviceName}`,
    body: `${dateStr} στις ${timeStr} · θέση #${position}. Θα σε ενημερώσουμε αν ανοίξει θέση.${autoNote}`,
    payload: { action: 'open_bookings', waitlist_id: id },
    sendPush: true,
  });

  return { id, position };
}

// ── Load / convert / cancel ──────────────────────────────────────────────────

async function loadWaitlistEntry(conn, bizId, entryId) {
  const [[entry]] = await conn.query(`
    SELECT w.*, sv.name AS service_name, sv.duration_mins, sv.hide_staff_selection
    FROM waitlist_entries w
    JOIN services sv ON sv.id = w.service_id
    WHERE w.id = ? AND w.business_id = ?
      AND w.status IN ('waiting', 'offered')
  `, [entryId, bizId]);
  return entry || null;
}

async function convertWaitlistEntry(conn, bizId, entryId, { force = false, use_credit = true } = {}) {
  const entry = await loadWaitlistEntry(conn, bizId, entryId);
  if (!entry) throw Object.assign(new Error('Η εγγραφή αναμονής δεν βρέθηκε'), { status: 404 });

  const { date, time } = parseDateTimeParts(entry.starts_at);
  const startsAt = new Date(entry.starts_at);
  const endsAt   = new Date(entry.ends_at);

  const { computed } = await assertSlotCapacity(
    conn, bizId, entry.service_id, date, time, startsAt, endsAt, null, force,
  );

  let staffId = entry.staff_id;
  if (!staffId) {
    staffId = await findStaffForSlot(conn, bizId, entry.service_id, computed, time, startsAt);
  }
  await assertStaffAvailable(conn, bizId, staffId, entry.service_id, startsAt, endsAt, null);

  let membershipId = null;
  if (use_credit) {
    const [memberships] = await conn.query(`
      SELECT id, total_sessions, used_sessions
      FROM user_memberships
      WHERE user_id = ? AND business_id = ?
        AND valid_until >= CURDATE()
        AND (total_sessions >= 9999 OR (total_sessions - used_sessions) > 0)
    `, [entry.user_id, bizId]);
    const credit = memberships[0];
    if (!credit) throw new Error('Ο πελάτης δεν έχει διαθέσιμο πακέτο');
    membershipId = credit.id;
  }

  const bookingId = uuidv4();
  await conn.query(`
    INSERT INTO bookings
      (id, business_id, user_id, staff_id, service_id, starts_at, ends_at, status, source, membership_id)
    VALUES (?, ?, ?, ?, ?, ?, ?, 'confirmed', 'waitlist', ?)
  `, [bookingId, bizId, entry.user_id, staffId, entry.service_id, startsAt, endsAt, membershipId]);

  if (membershipId) {
    await conn.query(
      'UPDATE user_memberships SET used_sessions = used_sessions + 1 WHERE id = ? AND total_sessions < 9999',
      [membershipId],
    );
  }

  await conn.query(
    `UPDATE waitlist_entries SET status = 'converted' WHERE id = ?`,
    [entry.id],
  );

  // Cancel any other 'offered' entries for the same slot (first_come race)
  await conn.query(`
    UPDATE waitlist_entries SET status = 'cancelled'
    WHERE business_id = ? AND service_id = ? AND starts_at = ?
      AND status = 'offered' AND id != ?
  `, [bizId, entry.service_id, entry.starts_at, entry.id]);

  const enriched = await enrichBookingWithTips(conn, {
    id: bookingId, business_id: bizId,
    service_id: entry.service_id, staff_id: staffId,
    starts_at: startsAt, ends_at: endsAt, service_name: entry.service_name,
  });

  const label = enriched.schedule_label || entry.service_name;
  await createUserNotification(conn, {
    businessId: bizId,
    userId: entry.user_id,
    bookingId,
    type: 'waitlist_confirmed',
    title: `Κράτηση επιβεβαιώθηκε — ${label}`,
    body: `${date} στις ${time}. Μπορείς να έρθεις στο γυμναστήριο!`,
    payload: { action: 'open_booking', booking_id: bookingId, waitlist_id: entry.id },
    sendPush: true,
  });

  await logPromotion(conn, {
    businessId: bizId, waitlistEntryId: entry.id, bookingId,
    serviceId: entry.service_id, startsAt: entry.starts_at, method: 'first_come',
  });

  return { booking_id: bookingId, entry, enriched };
}

async function cancelWaitlistEntry(conn, bizId, entryId) {
  const [r] = await conn.query(
    `UPDATE waitlist_entries SET status = 'cancelled'
     WHERE id = ? AND business_id = ? AND status IN ('waiting', 'offered')`,
    [entryId, bizId],
  );
  if (!r.affectedRows) {
    throw Object.assign(new Error('Η εγγραφή αναμονής δεν βρέθηκε'), { status: 404 });
  }
  return { ok: true };
}

module.exports = {
  getWaitlistPosition,
  getWaitlistConfig,
  promoteFromWaitlist,
  notifyWaitlistOnCancel,        // backward-compat alias
  processExpiredWaitlistOffers,
  joinWaitlist,
  loadWaitlistEntry,
  convertWaitlistEntry,
  cancelWaitlistEntry,
};
