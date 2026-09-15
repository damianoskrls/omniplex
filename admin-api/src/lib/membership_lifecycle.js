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

module.exports = {
  todayStr,
  addDaysToDateStr,
  getMembershipAccessState,
  canBookWithMembership,
  bookingBlockMessage,
  computeRenewalPeriod,
  enrichMembershipLifecycle,
  getGracePeriodDays,
};
