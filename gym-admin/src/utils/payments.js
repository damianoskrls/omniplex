export const GREEK_MONTHS = [
  'Ιανουάριος', 'Φεβρουάριος', 'Μάρτιος', 'Απρίλιος', 'Μάιος', 'Ιούνιος',
  'Ιούλιος', 'Αύγουστος', 'Σεπτέμβριος', 'Οκτώβριος', 'Νοέμβριος', 'Δεκέμβριος',
];

export function monthOptions() {
  const now = new Date();
  return Array.from({ length: 12 }, (_, i) => {
    const d = new Date(now.getFullYear(), now.getMonth() + i, 1);
    const value = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    return { value, label: `${GREEK_MONTHS[d.getMonth()]} ${d.getFullYear()}` };
  });
}

export function addMonthsMinusOneDay(startStr, months) {
  const d = new Date(`${startStr}T12:00:00`);
  d.setMonth(d.getMonth() + months);
  d.setDate(d.getDate() - 1);
  return d.toISOString().slice(0, 10);
}

export function periodEndPreview(paymentType, periodStart, packageMonths) {
  if (!periodStart) return '—';
  if (paymentType === 'registration_fee') return periodStart;
  if (paymentType === 'package' && packageMonths) {
    return addMonthsMinusOneDay(periodStart, Number(packageMonths));
  }
  return addMonthsMinusOneDay(periodStart, 1);
}

export function formatBillingMonth(ym) {
  if (!ym) return null;
  const [y, m] = ym.split('-').map(Number);
  return `${GREEK_MONTHS[m - 1]} ${y}`;
}

export function optionKey(opt) {
  return `${opt.service_id}:${opt.plan_id || 'manual'}`;
}

export function parseOption(key) {
  if (!key) return { service_id: undefined, plan_id: undefined };
  const [serviceId, planPart] = key.split(':');
  return {
    service_id: serviceId,
    plan_id: planPart === 'manual' ? undefined : planPart,
  };
}

export function sumOptionsPriceCents(options, keys) {
  return (keys || []).reduce((sum, key) => {
    const opt = options.find(o => optionKey(o) === key);
    return sum + (opt?.price_cents || 0);
  }, 0);
}

export const defaultSubscriptionForm = () => ({
  service_option: '',
  selected_service_options: [],
  membership_id: '',
  payment_type: 'package',
  billing_month: monthOptions()[0].value,
  package_months: 6,
  period_start: new Date().toISOString().slice(0, 10),
  subtotal_eur: '',
  discount_eur: '0',
  includes_registration: false,
  registration_fee_eur: '',
  paid_eur: '',
  payment_date: new Date().toISOString().slice(0, 10),
  due_date: '',
  notes: '',
  method: 'cash',
  pay_now: false,
  is_trial: false,
  trial_date: new Date().toISOString().slice(0, 10),
  trial_time: '',
  trial_staff_id: '',
  add_nutrition: false,
  nutrition_plan_id: '',
  nutrition_price_eur: '0',
  nutrition_promo_label: '',
});

export function eur(cents) {
  return `€${(Number(cents) / 100).toFixed(2)}`;
}

/** Δέχεται "55,00" ή "55.00" — όχι απλό Number() που δίνει NaN με κόμμα */
export function parseEurInput(value) {
  if (value == null || value === '') return NaN;
  const normalized = String(value).trim().replace(/\s/g, '').replace(',', '.');
  const n = Number(normalized);
  return Number.isFinite(n) ? n : NaN;
}

export const paymentTypeLabel = (t) => ({
  monthly: 'Μηνιαία',
  package: 'Πακέτο',
  registration_fee: 'Εγγραφή',
}[t] || t);

export const paymentStatusLabel = (s) => ({
  paid: 'Πληρωμένη',
  partial: 'Μερική',
  pending: 'Εκκρεμής',
  overdue: 'Ληξιπρόθεσμη',
}[s] || s);

export function paymentToEditForm(payment, packageOptions = []) {
  const match = packageOptions.find(o =>
    String(o.service_id) === String(payment.service_id)
    && (payment.plan_id ? String(o.plan_id) === String(payment.plan_id) : !o.plan_id)
  ) || packageOptions.find(o => String(o.service_id) === String(payment.service_id));

  const discount = payment.discount_cents || 0;
  const regFee = payment.registration_fee_cents || 0;
  const amount = payment.amount_cents || 0;
  const subtotalCents = payment.payment_type === 'registration_fee'
    ? 0
    : Math.max(0, amount + discount - regFee);

  return {
    service_option: match ? optionKey(match) : '',
    payment_type: payment.payment_type || 'monthly',
    billing_month: payment.billing_month
      ? String(payment.billing_month).slice(0, 7)
      : monthOptions()[0].value,
    package_months: payment.package_months || 6,
    period_start: payment.period_start ? String(payment.period_start).slice(0, 10) : '',
    subtotal_eur: (subtotalCents / 100).toFixed(2),
    discount_eur: (discount / 100).toFixed(2),
    includes_registration: regFee > 0,
    registration_fee_eur: regFee > 0 ? (regFee / 100).toFixed(2) : '',
    paid_eur: ((payment.paid_amount_cents || 0) / 100).toFixed(2),
    payment_date: payment.payment_date ? String(payment.payment_date).slice(0, 10) : '',
    due_date: payment.due_date ? String(payment.due_date).slice(0, 10) : '',
    notes: payment.notes || '',
    method: payment.method || 'cash',
  };
}

export function buildPaymentPatchBody(form) {
  const { service_id, plan_id } = parseOption(form.service_option);
  const subtotalCents = Math.round(Number(form.subtotal_eur || 0) * 100);
  const discountCents = Math.round(Number(form.discount_eur || 0) * 100);
  const regCents = form.includes_registration
    ? Math.round(Number(form.registration_fee_eur || 0) * 100)
    : 0;
  const totalCents = Math.max(0, subtotalCents - discountCents + regCents);

  return {
    service_id: service_id || undefined,
    plan_id: plan_id || undefined,
    payment_type: form.payment_type,
    billing_month: form.payment_type === 'monthly' ? form.billing_month : undefined,
    package_months: form.payment_type === 'package' ? Number(form.package_months) : undefined,
    period_start: form.period_start || undefined,
    subtotal_cents: form.payment_type === 'registration_fee' ? 0 : subtotalCents,
    discount_cents: discountCents,
    registration_fee_cents: regCents,
    amount_cents: form.payment_type === 'registration_fee' ? regCents : totalCents,
    paid_amount_cents: Math.round(Number(form.paid_eur || 0) * 100),
    payment_date: form.payment_date || null,
    due_date: form.due_date || null,
    notes: form.notes || null,
    method: form.method,
  };
}
