const GREEK_MONTHS = [
  'Ιανουάριος', 'Φεβρουάριος', 'Μάρτιος', 'Απρίλιος', 'Μάιος', 'Ιούνιος',
  'Ιούλιος', 'Αύγουστος', 'Σεπτέμβριος', 'Οκτώβριος', 'Νοέμβριος', 'Δεκέμβριος',
];

/** MySQL DATE columns often arrive as JS Date — never use String(date).slice() */
function toDateString(value) {
  if (value == null || value === '') return null;
  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) return null;
    const y = value.getFullYear();
    const m = String(value.getMonth() + 1).padStart(2, '0');
    const d = String(value.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }
  const s = String(value).trim();
  if (/^\d{4}-\d{2}-\d{2}/.test(s)) return s.slice(0, 10);
  if (/^\d{4}-\d{2}$/.test(s)) return `${s}-01`;
  return null;
}

function toBillingMonthDate(value) {
  const ymd = toDateString(value);
  if (!ymd) return null;
  return `${ymd.slice(0, 7)}-01`;
}

function paymentBalance(totalCents, paidCents) {
  return Math.max(0, totalCents - paidCents);
}

function deriveStatus(totalCents, paidCents, dueDate) {
  if (paidCents >= totalCents) return 'paid';
  if (paidCents > 0) return 'partial';
  if (dueDate && new Date(dueDate) < new Date()) return 'overdue';
  return 'pending';
}

function formatBillingMonth(dateStr) {
  const ymd = toDateString(dateStr);
  if (!ymd) return null;
  const d = new Date(`${ymd}T12:00:00`);
  if (Number.isNaN(d.getTime())) return null;
  return `${GREEK_MONTHS[d.getMonth()]} ${d.getFullYear()}`;
}

function addMonthsMinusOneDay(startDateStr, months) {
  const d = new Date(`${startDateStr}T12:00:00`);
  d.setMonth(d.getMonth() + months);
  d.setDate(d.getDate() - 1);
  return d.toISOString().slice(0, 10);
}

function computePeriodEnd(periodStart, paymentType, packageMonths, billingMonth) {
  if (!periodStart) return null;
  if (paymentType === 'package' && packageMonths) {
    return addMonthsMinusOneDay(periodStart, packageMonths);
  }
  if (paymentType === 'monthly') {
    return addMonthsMinusOneDay(periodStart, 1);
  }
  if (paymentType === 'registration_fee') {
    return periodStart;
  }
  if (billingMonth) {
    return addMonthsMinusOneDay(periodStart, 1);
  }
  return null;
}

function buildPaymentDescription({
  serviceName,
  serviceNames,
  paymentType,
  billingMonth,
  packageMonths,
  periodStart,
  periodEnd,
  registrationFeeCents = 0,
}) {
  const parts = [];
  const names = (serviceNames && serviceNames.length)
    ? serviceNames
    : (serviceName ? [serviceName] : []);
  if (names.length) parts.push(names.join(' + '));

  if (paymentType === 'registration_fee') {
    parts.push('Κόστος εγγραφής');
  } else if (paymentType === 'package' && packageMonths) {
    parts.push(`Πακέτο ${packageMonths} μηνών`);
  } else if (paymentType === 'monthly' && billingMonth) {
    parts.push(`Μήνας ${formatBillingMonth(billingMonth)}`);
  }

  if (registrationFeeCents > 0 && paymentType !== 'registration_fee') {
    parts.push('+ εγγραφή');
  }

  let desc = parts.join(' — ') || 'Πληρωμή';

  if (periodStart && periodEnd && paymentType !== 'registration_fee') {
    desc += ` (${periodStart} → ${periodEnd})`;
  }

  return desc;
}

function computePaymentTotal({ subtotalCents, discountCents = 0, registrationFeeCents = 0 }) {
  const subtotal = Number(subtotalCents) || 0;
  const discount = Math.max(0, Number(discountCents) || 0);
  const regFee = Math.max(0, Number(registrationFeeCents) || 0);
  return Math.max(0, subtotal - discount + regFee);
}

const DUPLICATE_PAYMENT_MSG = 'Υπάρχει ήδη πληρωμή για αυτή την υπηρεσία και τον ίδιο μήνα';

async function findDuplicatePayment(dbConn, {
  bizId,
  userId,
  serviceId,
  paymentType,
  billingMonth,
  periodStart,
  excludePaymentId,
}) {
  if (!userId || !serviceId || paymentType === 'registration_fee') return null;

  const monthYM = billingMonth
    ? toDateString(billingMonth)?.slice(0, 7)
    : periodStart
      ? toDateString(periodStart)?.slice(0, 7)
      : null;
  if (!monthYM) return null;

  const billingMonthDate = `${monthYM}-01`;
  const params = [bizId, userId, serviceId, billingMonthDate, monthYM];
  let sql = `
    SELECT p.id FROM payments p
    WHERE p.business_id = ? AND p.user_id = ? AND p.service_id = ?
      AND p.payment_type != 'registration_fee'
      AND (
        (p.payment_type = 'monthly' AND p.billing_month = ?)
        OR DATE_FORMAT(p.period_start, '%Y-%m') = ?
      )
      AND (p.membership_id IS NULL OR EXISTS (SELECT 1 FROM user_memberships m WHERE m.id = p.membership_id))
  `;
  if (excludePaymentId) {
    sql += ' AND p.id != ?';
    params.push(excludePaymentId);
  }
  sql += ' LIMIT 1';

  const [rows] = await dbConn.query(sql, params);
  if (rows[0]) return rows[0];

  let lineSql = `
    SELECT p.id FROM payments p
    INNER JOIN payment_line_items pli ON pli.payment_id = p.id
    WHERE p.business_id = ? AND p.user_id = ? AND pli.service_id = ?
      AND p.payment_type != 'registration_fee'
      AND (
        (p.payment_type = 'monthly' AND p.billing_month = ?)
        OR DATE_FORMAT(p.period_start, '%Y-%m') = ?
      )
      AND (p.membership_id IS NULL OR EXISTS (SELECT 1 FROM user_memberships m WHERE m.id = p.membership_id))
  `;
  const lineParams = [bizId, userId, serviceId, billingMonthDate, monthYM];
  if (excludePaymentId) {
    lineSql += ' AND p.id != ?';
    lineParams.push(excludePaymentId);
  }
  lineSql += ' LIMIT 1';

  const [lineRows] = await dbConn.query(lineSql, lineParams);
  return lineRows[0] || null;
}

async function assertNoDuplicatePayment(dbConn, opts) {
  const dup = await findDuplicatePayment(dbConn, opts);
  if (dup) {
    const err = new Error(DUPLICATE_PAYMENT_MSG);
    err.code = 'DUPLICATE_PAYMENT';
    throw err;
  }
}

function mapPaymentRow(row) {
  const total = Number(row.amount_cents) || 0;
  const paid = Number(row.paid_amount_cents) || 0;
  const dueDate = toDateString(row.due_date);
  return {
    ...row,
    amount_cents: total,
    paid_amount_cents: paid,
    payment_date: toDateString(row.payment_date),
    due_date: dueDate,
    billing_month: toDateString(row.billing_month),
    period_start: toDateString(row.period_start),
    period_end: toDateString(row.period_end),
    balance_cents: paymentBalance(total, paid),
    status: deriveStatus(total, paid, dueDate),
    billing_month_label: formatBillingMonth(row.billing_month),
    service_name: row.service_name || null,
    plan_name: row.plan_name || null,
    referrer_name: row.referrer_name || null,
  };
}

module.exports = {
  toDateString,
  toBillingMonthDate,
  paymentBalance,
  deriveStatus,
  mapPaymentRow,
  formatBillingMonth,
  addMonthsMinusOneDay,
  computePeriodEnd,
  buildPaymentDescription,
  computePaymentTotal,
  findDuplicatePayment,
  assertNoDuplicatePayment,
  DUPLICATE_PAYMENT_MSG,
  GREEK_MONTHS,
};
