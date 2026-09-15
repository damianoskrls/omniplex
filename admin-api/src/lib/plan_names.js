const PERIOD_LABELS = {
  monthly: 'μηνιαία',
  quarterly: 'τριμηνιαία',
  yearly: 'ετήσια',
  once: 'εφάπαξ',
  package: 'πακέτο',
};

/** null/κενό/0 = απεριόριστες συνεδρίες στο πλάνο */
function normalizePlanSessions(sessions) {
  if (sessions === null || sessions === undefined || sessions === '') return null;
  const n = Number(sessions);
  if (!Number.isFinite(n) || n <= 0) return null;
  return n;
}

function buildServicePlanName(serviceName, { sessions, duration_mins, billing_period, price_cents }) {
  const parts = [serviceName || 'Πακέτο'];
  const normalized = normalizePlanSessions(sessions);
  if (normalized === null) {
    parts.push('απεριόριστες συνεδρίες');
  } else {
    parts.push(`${normalized} συνεδρίες/μήνα`);
    if (duration_mins) parts.push(`${duration_mins}λ`);
  }
  parts.push(PERIOD_LABELS[billing_period] || billing_period || 'μηνιαία');
  if (price_cents != null && price_cents !== '') {
    parts.push(`€${(Number(price_cents) / 100).toFixed(2)}`);
  }
  return parts.join(' · ');
}

function buildNutritionPlanName({
  monthly_price_cents,
  per_session_price_cents,
  package_sessions,
  package_price_cents,
  default_billing_period,
}) {
  const parts = ['Διατροφή'];
  if (monthly_price_cents) {
    parts.push(`μηνιαία €${(monthly_price_cents / 100).toFixed(2)}`);
  }
  if (per_session_price_cents) {
    parts.push(`ανά συνεδρία €${(per_session_price_cents / 100).toFixed(2)}`);
  }
  if (package_sessions && package_price_cents) {
    parts.push(`πακέτο ${package_sessions} συν. €${(package_price_cents / 100).toFixed(2)}`);
  }
  if (default_billing_period && default_billing_period !== 'monthly') {
    parts.push(PERIOD_LABELS[default_billing_period] || default_billing_period);
  }
  return parts.join(' · ');
}

function addMonthsToDate(isoDate, months) {
  const [y, m, d] = isoDate.split('-').map(Number);
  const dt = new Date(y, m - 1 + months, d);
  const yy = dt.getFullYear();
  const mm = String(dt.getMonth() + 1).padStart(2, '0');
  const dd = String(dt.getDate()).padStart(2, '0');
  return `${yy}-${mm}-${dd}`;
}

function defaultValidUntil(validFrom, billingPeriod) {
  switch (billingPeriod) {
    case 'quarterly': return addMonthsToDate(validFrom, 3);
    case 'yearly': return addMonthsToDate(validFrom, 12);
    case 'once':
    case 'package':
      return addMonthsToDate(validFrom, 12);
    default:
      return addMonthsToDate(validFrom, 1);
  }
}

module.exports = {
  PERIOD_LABELS,
  normalizePlanSessions,
  buildServicePlanName,
  buildNutritionPlanName,
  addMonthsToDate,
  defaultValidUntil,
};
