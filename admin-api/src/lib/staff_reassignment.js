const { v4: uuidv4 } = require('uuid');
const { createAdminNotification } = require('./notifications');

const REASON_LABELS = {
  no_service: 'Δεν έχει την υπηρεσία',
  no_availability: 'Χωρίς διαθεσιμότητα',
  on_leave: 'Σε άδεια',
  conflict: 'Σύγκρουση ωραρίου',
  invalid_staff: 'Μη έγκυρος γυμναστής',
  staff_inactive: 'Ανενεργός γυμναστής',
};

async function getOrCreateGeneralPoolStaff(conn, bizId) {
  const [[existing]] = await conn.query(
    'SELECT id, full_name FROM staff WHERE business_id = ? AND is_general_pool = 1 LIMIT 1',
    [bizId],
  );
  if (existing) return existing;

  const id = uuidv4();
  await conn.query(
    `INSERT INTO staff (id, business_id, full_name, role, bio, color_hex, is_active, is_general_pool)
     VALUES (?, ?, ?, ?, ?, ?, 1, 1)`,
    [
      id,
      bizId,
      'Γενικό προσωπικό',
      'General Gym',
      'Κρατήσεις που χρειάζονται χειροκίνητη ανάθεση γυμναστή',
      '#94a3b8',
    ],
  );
  return { id, full_name: 'Γενικό προσωπικό' };
}

async function staffCanCoverBooking(conn, bizId, staffId, booking, excludeStaffId = null) {
  if (!staffId || staffId === excludeStaffId) {
    return { ok: false, reason: 'invalid_staff' };
  }

  const [[staff]] = await conn.query(
    'SELECT id FROM staff WHERE id = ? AND business_id = ? AND is_active = 1 AND is_general_pool = 0',
    [staffId, bizId],
  );
  if (!staff) return { ok: false, reason: 'staff_inactive' };

  const [[svc]] = await conn.query(
    'SELECT 1 FROM staff_services WHERE staff_id = ? AND service_id = ?',
    [staffId, booking.service_id],
  );
  if (!svc) return { ok: false, reason: 'no_service' };

  const [[leave]] = await conn.query(
    `SELECT 1 FROM staff_leaves
     WHERE staff_id = ? AND business_id = ?
       AND date_from <= DATE(?) AND date_to >= DATE(?)
     LIMIT 1`,
    [staffId, bizId, booking.starts_at, booking.starts_at],
  );
  if (leave) return { ok: false, reason: 'on_leave' };

  const [[avail]] = await conn.query(
    `SELECT 1 FROM staff_availability sa
     WHERE sa.staff_id = ? AND sa.weekday = WEEKDAY(?) AND sa.is_active = 1
       AND sa.start_time <= TIME(?) AND sa.end_time >= TIME(?)
       AND (
         sa.service_id = ?
         OR (
           sa.service_id IS NULL
           AND NOT EXISTS (
             SELECT 1 FROM staff_availability sa2
             WHERE sa2.staff_id = sa.staff_id
               AND sa2.service_id = ?
               AND sa2.weekday = sa.weekday
               AND sa2.is_active = 1
           )
         )
       )
     LIMIT 1`,
    [staffId, booking.starts_at, booking.starts_at, booking.ends_at, booking.service_id, booking.service_id],
  );
  if (!avail) return { ok: false, reason: 'no_availability' };

  const [[conflict]] = await conn.query(
    `SELECT id FROM bookings
     WHERE business_id = ? AND staff_id = ? AND id != ?
       AND status NOT IN ('cancelled', 'no_show')
       AND starts_at < ? AND ends_at > ?
       AND NOT (service_id = ? AND starts_at = ? AND ends_at = ?)
     LIMIT 1`,
    [
      bizId,
      staffId,
      booking.id,
      booking.ends_at,
      booking.starts_at,
      booking.service_id,
      booking.starts_at,
      booking.ends_at,
    ],
  );
  if (conflict) return { ok: false, reason: 'conflict' };

  return { ok: true };
}

async function getFutureBookings(conn, bizId, staffId) {
  const [rows] = await conn.query(
    `SELECT b.id, b.service_id, b.user_id, b.staff_id, b.starts_at, b.ends_at, b.status,
            b.staff_assignment_status,
            u.full_name AS user_name, sv.name AS service_name
     FROM bookings b
     JOIN users u ON u.id = b.user_id
     JOIN services sv ON sv.id = b.service_id
     WHERE b.business_id = ? AND b.staff_id = ?
       AND b.ends_at >= NOW()
       AND b.status NOT IN ('cancelled', 'no_show', 'completed')
     ORDER BY b.starts_at ASC`,
    [bizId, staffId],
  );
  return rows;
}

async function classifyBookingsForTransfer(conn, bizId, staffId, bookings, transferToStaffId) {
  const pool = await getOrCreateGeneralPoolStaff(conn, bizId);
  const transferable = [];
  const pending = [];

  for (const b of bookings) {
    if (transferToStaffId) {
      const check = await staffCanCoverBooking(conn, bizId, transferToStaffId, b, staffId);
      if (check.ok) {
        transferable.push({ ...b, transfer_to: transferToStaffId });
        continue;
      }
      pending.push({
        ...b,
        reason: check.reason,
        reason_label: REASON_LABELS[check.reason] || check.reason,
        suggested_pool_id: pool.id,
      });
    } else {
      pending.push({
        ...b,
        reason: 'no_target',
        reason_label: 'Δεν επιλέχθηκε γυμναστής',
        suggested_pool_id: pool.id,
      });
    }
  }

  return { transferable, pending, general_pool: pool };
}

async function previewStaffDeletion(conn, bizId, staffId, transferToStaffId = null) {
  const [[staff]] = await conn.query(
    'SELECT id, full_name, is_general_pool, is_nutritionist FROM staff WHERE id = ? AND business_id = ?',
    [staffId, bizId],
  );
  if (!staff) return { error: 'Ο γυμναστής δεν βρέθηκε' };
  if (staff.is_general_pool) {
    return { error: 'Δεν μπορείτε να διαγράψετε το γενικό προσωπικό του γυμναστηρίου' };
  }
  if (staff.is_nutritionist) {
    return { error: 'Ο διατροφολόγος διαχειρίζεται από το μενού Διατροφολόγος, όχι από το Προσωπικό' };
  }

  const bookings = await getFutureBookings(conn, bizId, staffId);
  const [[{ total_bookings: historyCount }]] = await conn.query(
    'SELECT COUNT(*) AS total_bookings FROM bookings WHERE business_id = ? AND staff_id = ?',
    [bizId, staffId],
  );

  const [candidates] = await conn.query(
    `SELECT id, full_name, role, color_hex FROM staff
     WHERE business_id = ? AND is_active = 1 AND id != ?
       AND COALESCE(is_general_pool, 0) = 0 AND COALESCE(is_nutritionist, 0) = 0
     ORDER BY full_name`,
    [bizId, staffId],
  );

  const classified = await classifyBookingsForTransfer(
    conn,
    bizId,
    staffId,
    bookings,
    transferToStaffId || null,
  );

  return {
    staff,
    future_bookings_count: bookings.length,
    history_bookings_count: Number(historyCount),
    future_bookings: bookings,
    candidates,
    transfer_to: transferToStaffId || null,
    ...classified,
    reason_labels: REASON_LABELS,
  };
}

async function deleteStaffWithReassignment(conn, bizId, staffId, { transferToStaffId }) {
  const preview = await previewStaffDeletion(conn, bizId, staffId, transferToStaffId || null);
  if (preview.error) throw new Error(preview.error);

  const pool = preview.general_pool;
  const transferred = [];
  const pending = [];

  for (const b of preview.future_bookings) {
    const check = transferToStaffId
      ? await staffCanCoverBooking(conn, bizId, transferToStaffId, b, staffId)
      : { ok: false };

    if (check.ok) {
      await conn.query(
        `UPDATE bookings SET staff_id = ?, staff_assignment_status = 'assigned'
         WHERE id = ? AND business_id = ?`,
        [transferToStaffId, b.id, bizId],
      );
      transferred.push(b);
    } else {
      await conn.query(
        `UPDATE bookings SET staff_id = ?, staff_assignment_status = 'pending_reassignment'
         WHERE id = ? AND business_id = ?`,
        [pool.id, b.id, bizId],
      );
      pending.push({ ...b, reason: check.reason || 'no_availability' });
    }
  }

  await conn.query(
    'DELETE FROM staff_passwords WHERE staff_id = ?',
    [staffId],
  );
  await conn.query(
    'UPDATE staff SET portal_email = NULL WHERE id = ? AND business_id = ?',
    [staffId, bizId],
  );

  if (Number(preview.history_bookings_count) > 0) {
    await conn.query(
      'UPDATE staff SET is_active = 0 WHERE id = ? AND business_id = ?',
      [staffId, bizId],
    );
  } else {
    await conn.query(
      'DELETE FROM staff WHERE id = ? AND business_id = ?',
      [staffId, bizId],
    );
  }

  if (pending.length) {
    await createAdminNotification(conn, {
      businessId: bizId,
      type: 'staff_reassignment_pending',
      title: `${pending.length} κράτηση/εις χρειάζονται ανάθεση γυμναστή`,
      body: `Μετά την αφαίρεση του ${preview.staff.full_name}, ${pending.length} κρατήσεις τοποθετήθηκαν στο «${pool.full_name}» μέχρι να ανατεθούν σε διαθέσιμο γυμναστή.`,
      payload: {
        booking_ids: pending.map((p) => p.id),
        deleted_staff_id: staffId,
        deleted_staff_name: preview.staff.full_name,
        general_pool_staff_id: pool.id,
      },
    });
  }

  return {
    mode: Number(preview.history_bookings_count) > 0 ? 'deactivated' : 'deleted',
    transferred: transferred.length,
    pending: pending.length,
    pending_bookings: pending,
    general_pool: pool,
  };
}

module.exports = {
  REASON_LABELS,
  getOrCreateGeneralPoolStaff,
  staffCanCoverBooking,
  previewStaffDeletion,
  deleteStaffWithReassignment,
};
