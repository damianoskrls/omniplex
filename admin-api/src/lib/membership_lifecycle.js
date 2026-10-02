const { addMonthsMinusOneDay, toDateString } = require('./payments');

function todayStr() {
  return new Date().toISOString().slice(0, 10);
}

function addDaysToDateStr(dateStr, days) {
  const d = new Date(`${dateStr}T12:00:00`);
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
}

function normalizeDate(value) {
  if (!value) return null;
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  return String(value).slice(0, 10);
}

/**
 * active   — valid_until >= today
 * grace    — expired but within grace_period_days
 * expired  — past grace, no booking
 * cancelled — user/admin cancelled
 * trial    — trial membership
 */
function getMembershipAccessState(membership, gracePeriodDays = 15, today = todayStr()) {
  const status = membership?.membership_status || 'active';
  if (status === 'cancelled') return 'cancelled';
  if (status === 'trial') return 'trial';

  const until = normalizeDate(membership?.valid_until);
  if (!until) return 'active';
  if (until >= today) return 'active';

  const graceEnd = addDaysToDateStr(until, gracePeriodDays);
  if (today <= graceEnd) return 'grace';
  return 'expired';
}

function canBookWithMembership(membership, gracePeriodDays = 15, today = todayStr()) {
  const state = getMembershipAccessState(membership, gracePeriodDays, today);
  return state === 'active' || state === 'grace' || state === 'trial';
}

function bookingBlockMessage(membership, gracePeriodDays = 15) {
  const state = getMembershipAccessState(membership, gracePeriodDays);
  const label = membership?.service_name || 'Η συνδρομή σου';
  if (state === 'cancelled') {
    return `${label} έχει διακοπεί. Επικοινώνησε με το γυμναστήριο για επανενεργοποίηση.`;
  }
  if (state === 'expired') {
    const until = normalizeDate(membership?.valid_until);
    return `${label} έληξε στις ${until}. Πέρασε την περίοδο χάριτος — επικοινώνησε με το γυμναστήριο για ανανέωση.`;
  }
  return null;
}

/** Επόμενη περίοδος ανανέωσης μετά το valid_until */
function computeRenewalPeriod(membership, months = 1) {
  const until = normalizeDate(membership?.valid_until);
  const from = until ? addDaysToDateStr(until, 1) : todayStr();
  const end = addMonthsMinusOneDay(from, months);
  const billingMonth = `${from.slice(0, 7)}-01`;
  return {
    period_start: from,
    period_end: end,
    billing_month: billingMonth,
    months,
  };
}

/** Τρέχουσα περίοδος — από valid_from έως valid_until */
function enrichMembershipLifecycle(membership, gracePeriodDays = 15, pendingRenewalPayment = null) {
  const until = normalizeDate(membership?.valid_until);
  const from = normalizeDate(membership?.valid_from);
  const accessState = getMembershipAccessState(membership, gracePeriodDays);
  const graceEnd = until ? addDaysToDateStr(until, gracePeriodDays) : null;
  const renewal = until && membership?.membership_status === 'active'
    ? computeRenewalPeriod(membership, 1)
    : null;

  return {
    ...membership,
    access_state: accessState,
    grace_until: accessState === 'grace' ? graceEnd : null,
    days_until_expiry: until ? Math.ceil((new Date(`${until}T12:00:00`) - new Date()) / 86400000) : null,
    days_in_grace_left: accessState === 'grace' && graceEnd
      ? Math.ceil((new Date(`${graceEnd}T12:00:00`) - new Date()) / 86400000)
      : null,
    current_period: from && until ? { from, until } : null,
    next_renewal: renewal,
    pending_renewal_payment: pendingRenewalPayment || null,
    can_prepay: membership?.membership_status === 'active' && !!renewal,
    can_book: canBookWithMembership(membership, gracePeriodDays),
  };
}

async function getGracePeriodDays(dbConn, bizId) {
  const [[row]] = await dbConn.query(
    'SELECT grace_period_days FROM business_configs WHERE business_id = ?',
    [bizId],
  );
  return row?.grace_period_days ?? 15;
}

/**
 * Sessions booked before the next package is paid (max 2) count against it
 * once that payment is marked paid. A new pack of 10 with 2 borrowed
 * sessions leaves 8.
 */
async function settleAdvanceBookings(conn, bizId, paymentId) {
  const [[payment]] = await conn.query(
    `SELECT user_id, service_id, membership_id, payment_type
     FROM payments WHERE id = ? AND business_id = ?`,
    [paymentId, bizId],
  );
  if (!payment?.user_id) return { applied: 0 };
  if (payment.payment_type === 'registration_fee') return { applied: 0 };

  let serviceId = payment.service_id;
  if (!serviceId && payment.membership_id) {
    const [[linked]] = await conn.query(
      'SELECT service_id FROM user_memberships WHERE id = ?',
      [payment.membership_id],
    );
    serviceId = linked?.service_id || null;
  }
  if (!serviceId) return { applied: 0 };

  const params = [payment.user_id, bizId, serviceId];
  const serviceSql = ' AND service_id = ?';
  const [rows] = await conn.query(
    `SELECT id FROM bookings
     WHERE user_id = ? AND business_id = ? AND is_advance = 1
       AND membership_id IS NULL
       AND status NOT IN ('cancelled')
       ${serviceSql}
     ORDER BY starts_at ASC
     LIMIT 2`,
    params,
  );
  if (!rows.length) return { applied: 0 };

  let membershipId = payment.membership_id;
  if (!membershipId) {
    const [[mem]] = await conn.query(
      `SELECT id FROM user_memberships
       WHERE user_id = ? AND business_id = ? AND service_id = ?
         AND membership_status <> 'cancelled'
       ORDER BY valid_until DESC
       LIMIT 1`,
      [payment.user_id, bizId, serviceId],
    );
    membershipId = mem?.id || null;
  }
  if (!membershipId) return { applied: 0 };

  const [[mem]] = await conn.query(
    'SELECT total_sessions, membership_status FROM user_memberships WHERE id = ?',
    [membershipId],
  );
  if (!mem || mem.membership_status === 'cancelled') return { applied: 0 };

  const total = Number(mem.total_sessions) || 0;
  const unlimited = total >= 9999 || total === 0;
  if (!unlimited) {
    const nextUsed = Math.min(total, rows.length);
    await conn.query(
      'UPDATE user_memberships SET used_sessions = ? WHERE id = ?',
      [nextUsed, membershipId],
    );
  }
  await conn.query(
    'UPDATE bookings SET membership_id = ?, is_advance = 0 WHERE id IN (?)',
    [membershipId, rows.map((row) => row.id)],
  );
  return { applied: rows.length, membership_id: membershipId };
}

module.exports = {
  todayStr,
  addDaysToDateStr,
  getMembershipAccessState,
  canBookWithMembership,
  bookingBlockMessage,
  computeRenewalPeriod,
  enrichMembershipLifecycle,
  getGracePeriodDays,
  settleAdvanceBookings,
};
