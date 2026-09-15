import { useEffect, useMemo, useState } from 'react';
import {
  Calendar, Check, CheckCircle, Clock, CreditCard, FlaskConical, Package, Receipt, Sparkles, X,
} from 'lucide-react';
import api from '../api/client';
import toast from 'react-hot-toast';
import ServiceIcon from './ui/ServiceIcon';
import { mediaUrl } from '../utils/media';
import {
  defaultSubscriptionForm,
  formatBillingMonth,
  monthOptions,
  optionKey,
  parseOption,
  periodEndPreview,
  sumOptionsPriceCents,
} from '../utils/payments';
import { isGymPackageOption, getPackageBlockReason, filterPackageOptionsForClient } from '../utils/payment_helpers';

const PAYMENT_TYPES = [
  { id: 'package', label: 'Πακέτο', sub: '3 / 6 / 12 μήνες', icon: Package },
  { id: 'monthly', label: 'Μηνιαία', sub: 'Μηνιαία χρέωση', icon: Calendar },
];

const PACKAGE_DURATIONS = [
  { months: 3, label: '3 μήνες' },
  { months: 6, label: '6 μήνες' },
  { months: 12, label: '12 μήνες' },
];

const GREEK_WEEKDAY = ['Κυρ', 'Δευ', 'Τρι', 'Τετ', 'Πεμ', 'Παρ', 'Σαβ'];
const GREEK_MONTH = ['Ιαν', 'Φεβ', 'Μαρ', 'Απρ', 'Μάι', 'Ιουν', 'Ιουλ', 'Αυγ', 'Σεπ', 'Οκτ', 'Νοε', 'Δεκ'];

function formatTrialDayLabel(dateStr) {
  const d = new Date(`${dateStr}T12:00:00`);
  const today = new Date();
  today.setHours(12, 0, 0, 0);
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);
  if (d.getTime() === today.getTime()) return 'Σήμερα';
  if (d.getTime() === tomorrow.getTime()) return 'Αύριο';
  return `${d.getDate()} ${GREEK_MONTH[d.getMonth()]}`;
}

export default function SubscriptionModal({
  open,
  onClose,
  onSuccess,
  clientId,
  clientName = '',
  packageOptions = [],
  memberships = [],
  activateTrialMembership = null,
  onOpenNutrition,
  canAddNutrition = false,
}) {
  const [form, setForm] = useState(defaultSubscriptionForm());
  const [paidNow, setPaidNow] = useState(false);
  const [paymentDate, setPaymentDate] = useState(new Date().toISOString().slice(0, 10));
  const [paymentMethod, setPaymentMethod] = useState('cash');
  const [submitting, setSubmitting] = useState(false);
  const [slots, setSlots] = useState([]);
  const [slotsLoading, setSlotsLoading] = useState(false);
  const [slotsMessage, setSlotsMessage] = useState('');
  const [availableDates, setAvailableDates] = useState([]);
  const [datesLoading, setDatesLoading] = useState(false);
  const months = useMemo(() => monthOptions(), []);
  const isActivate = !!activateTrialMembership;

  const options = useMemo(() => {
    const gymOptions = packageOptions.filter(isGymPackageOption);
    if (!isActivate || !activateTrialMembership) return gymOptions;
    const sid = activateTrialMembership.service_id != null
      ? String(activateTrialMembership.service_id)
      : '';
    const sname = activateTrialMembership.service_name;
    const match = gymOptions.filter(o =>
      (sid && String(o.service_id) === sid)
      || (sname && o.service_name === sname),
    );
    if (match.length) return match;
    if (sid || sname) {
      return [{
        service_id: activateTrialMembership.service_id,
        service_name: activateTrialMembership.service_name,
        service_category: activateTrialMembership.service_category,
        service_image_url: activateTrialMembership.service_image_url,
        plan_id: activateTrialMembership.plan_id || null,
        plan_name: null,
        sessions: activateTrialMembership.total_sessions,
        price_cents: null,
        billing_period: null,
      }];
    }
    return gymOptions;
  }, [packageOptions, activateTrialMembership, isActivate]);

  const selectableOptions = useMemo(
    () => filterPackageOptionsForClient(options, memberships),
    [options, memberships],
  );

  const selectedOption = options.find(o => optionKey(o) === form.service_option);
  const multiSelectMode = !isActivate && !form.is_trial;

  const selectionKeys = () => {
    if (isActivate || form.is_trial) {
      return form.service_option ? [form.service_option] : [];
    }
    if (form.selected_service_options?.length) return form.selected_service_options;
    return form.service_option ? [form.service_option] : [];
  };

  const multiSelected = multiSelectMode && selectionKeys().length > 1;

  const loadAvailableDates = async (serviceId) => {
    if (!serviceId) {
      setAvailableDates([]);
      return null;
    }
    setDatesLoading(true);
    try {
      const r = await api.get('/client-admin/booking-available-dates', {
        params: { service_id: serviceId, days: 21 },
      });
      const dates = r.data.dates || [];
      setAvailableDates(dates);
      return dates;
    } catch {
      setAvailableDates([]);
      toast.error('Δεν φορτώθηκαν οι διαθέσιμες ημέρες');
      return null;
    } finally {
      setDatesLoading(false);
    }
  };

  const loadSlots = async (serviceId, date) => {
    if (!serviceId || !date) {
      setSlots([]);
      setSlotsMessage('');
      return;
    }
    setSlotsLoading(true);
    try {
      const r = await api.get('/client-admin/booking-slots', {
        params: { service_id: serviceId, date },
      });
      setSlots(r.data.slots || []);
      setSlotsMessage(r.data.message || '');
    } catch {
      setSlots([]);
      setSlotsMessage('');
      toast.error('Δεν φορτώθηκαν οι διαθέσιμες ώρες');
    } finally {
      setSlotsLoading(false);
    }
  };

  const pickTrialDate = (date) => {
    const { service_id } = parseOption(form.service_option);
    setForm(f => ({ ...f, trial_date: date, trial_time: '', trial_staff_id: '' }));
    if (service_id) loadSlots(service_id, date);
  };

  useEffect(() => {
    if (!open) return;
    const initial = defaultSubscriptionForm();
    initial.is_trial = false;

    const pick = isActivate ? (options[0] || selectableOptions[0]) : null;
    if (isActivate && activateTrialMembership) {
      const sid = activateTrialMembership.service_id != null
        ? String(activateTrialMembership.service_id)
        : '';
      const pid = activateTrialMembership.plan_id != null
        ? String(activateTrialMembership.plan_id)
        : null;
      const match = options.find(o =>
        String(o.service_id) === sid
        && (pid ? String(o.plan_id) === pid : true),
      ) || options.find(o => String(o.service_id) === sid)
        || options.find(o => o.service_name === activateTrialMembership.service_name)
        || pick;
      if (match) {
        const key = optionKey(match);
        initial.service_option = key;
        initial.selected_service_options = [key];
        if (match.price_cents) initial.subtotal_eur = (match.price_cents / 100).toFixed(2);
        if (match.billing_period === 'monthly') initial.payment_type = 'monthly';
      }
    } else {
      // No auto-selection — user picks explicitly
      initial.selected_service_options = [];
      initial.service_option = '';
    }

    setForm(initial);
    setSlots([]);
    setSlotsMessage('');
    setAvailableDates([]);
  }, [open, options, selectableOptions, isActivate, activateTrialMembership]);

  useEffect(() => {
    if (!open || !form.is_trial || isActivate) return;
    const { service_id } = parseOption(form.service_option);
    if (!service_id) return;

    let cancelled = false;
    (async () => {
      const dates = await loadAvailableDates(service_id);
      if (cancelled) return;
      const selectable = (dates || []).filter(d => d.selectable);
      if (!selectable.length) {
        setForm(f => ({ ...f, trial_date: '', trial_time: '', trial_staff_id: '' }));
        setSlots([]);
        return;
      }
      const currentOk = selectable.some(d => d.date === form.trial_date);
      const nextDate = currentOk ? form.trial_date : selectable[0].date;
      if (!currentOk) {
        setForm(f => ({ ...f, trial_date: nextDate, trial_time: '', trial_staff_id: '' }));
      }
      loadSlots(service_id, nextDate);
    })();

    return () => { cancelled = true; };
  }, [open, form.is_trial, form.service_option, isActivate]);

  const pickServicePlan = (opt) => {
    const key = optionKey(opt);
    setForm(f => {
      const next = {
        ...f,
        service_option: key,
        selected_service_options: [key],
        subtotal_eur: opt.price_cents != null ? (opt.price_cents / 100).toFixed(2) : f.subtotal_eur,
        trial_time: '',
        trial_staff_id: '',
      };
      if (opt.billing_period === 'monthly') next.payment_type = 'monthly';
      return next;
    });
  };

  const toggleServicePlan = (opt) => {
    const key = optionKey(opt);
    setForm(f => {
      const current = f.selected_service_options || [];
      const nextKeys = current.includes(key)
        ? current.filter(k => k !== key)
        : [...current, key];
      const sumCents = sumOptionsPriceCents(options, nextKeys);
      const next = {
        ...f,
        selected_service_options: nextKeys,
        service_option: nextKeys[0] || '',
        subtotal_eur: sumCents ? (sumCents / 100).toFixed(2) : '',
      };
      if (opt.billing_period === 'monthly' && nextKeys.includes(key)) next.payment_type = 'monthly';
      return next;
    });
  };

  const onServicePlanClick = (opt) => {
    if (isActivate) return;
    const blockReason = getPackageBlockReason(memberships, opt);
    if (blockReason) {
      toast.error(`${opt.service_name}: ${blockReason}`);
      return;
    }
    if (form.is_trial) pickServicePlan(opt);
    else toggleServicePlan(opt);
  };

  const payTotalEur = () => {
    const sub = Number(form.subtotal_eur) || 0;
    const disc = Number(form.discount_eur) || 0;
    const reg = form.includes_registration ? (Number(form.registration_fee_eur) || 0) : 0;
    return Math.max(0, sub - disc + reg);
  };

  const descriptionPreview = () => {
    const keys = selectionKeys();
    const serviceNames = [...new Set(
      keys
        .map(k => options.find(o => optionKey(o) === k)?.service_name)
        .filter(Boolean),
    )];
    const parts = [];
    if (serviceNames.length) parts.push(serviceNames.join(' + '));
    if (form.payment_type === 'package') parts.push(`Πακέτο ${form.package_months} μηνών`);
    else if (form.payment_type === 'monthly') parts.push(`Μήνας ${formatBillingMonth(form.billing_month)}`);
    if (form.includes_registration && form.registration_fee_eur) parts.push('+ εγγραφή');
    const end = periodEndPreview(form.payment_type, form.period_start, form.package_months);
    if (form.period_start) return `${parts.join(' — ')} (${form.period_start} → ${end})`;
    return parts.join(' — ') || 'Πακέτο';
  };

  const pickTrialTime = (time) => {
    const slot = slots.find(s => s.time === time);
    if (!slot || slot.is_full || !slot.available_staff?.length) return;
    const staffList = slot.available_staff;
    setForm(f => ({
      ...f,
      trial_time: time,
      trial_staff_id: staffList[0]?.id || '',
    }));
  };

  const bookableSlots = useMemo(
    () => slots.filter(s => s.available_staff?.length > 0 && !s.is_full),
    [slots],
  );

  const submitTrial = async () => {
    const { service_id, plan_id } = parseOption(form.service_option);
    if (!service_id) {
      toast.error('Επίλεξε υπηρεσία');
      return;
    }
    if (!form.trial_date || !form.trial_time || !form.trial_staff_id) {
      toast.error('Επίλεξε ημερομηνία, ώρα και γυμναστή για το δοκιμαστικό');
      return;
    }
    setSubmitting(true);
    try {
      await api.post(`/client-admin/clients/${clientId}/trial-program`, {
        service_id,
        plan_id: plan_id || undefined,
        trial_date: form.trial_date,
        trial_time: form.trial_time,
        staff_id: form.trial_staff_id,
        notes: form.notes || undefined,
      });
      toast.success('Το δοκιμαστικό προγραμματίστηκε');
      onSuccess?.();
      onClose();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSubmitting(false);
    }
  };

  const submitPackage = async (e) => {
    e.preventDefault();
    const keys = selectionKeys();
    if (!isActivate) {
      const blockedKey = keys.find((key) => {
        const opt = options.find(o => optionKey(o) === key);
        return opt && getPackageBlockReason(memberships, opt);
      });
      if (blockedKey) {
        const opt = options.find(o => optionKey(o) === blockedKey);
        toast.error(opt ? `${opt.service_name}: ${getPackageBlockReason(memberships, opt)}` : 'Η υπηρεσία έχει ήδη ενεργό πακέτο');
        return;
      }
    }

    const discountCents = Math.round(Number(form.discount_eur || 0) * 100);
    const regCents = form.includes_registration
      ? Math.round(Number(form.registration_fee_eur || 0) * 100)
      : 0;

    if (!keys.length) {
      toast.error('Επίλεξε τουλάχιστον μία υπηρεσία / πλάνο');
      return;
    }
    if (!form.period_start) {
      toast.error('Δώσε ημερομηνία έναρξης');
      return;
    }

    const lines = keys.map((key) => {
      const { service_id, plan_id } = parseOption(key);
      const opt = options.find(o => optionKey(o) === key);
      return {
        service_id,
        plan_id: plan_id || undefined,
        subtotal_cents: opt?.price_cents ?? Math.round(Number(form.subtotal_eur || 0) * 100),
        label: opt ? `${opt.service_name} — ${opt.plan_name}` : undefined,
      };
    });

    const subtotalCents = lines.reduce((sum, line) => sum + line.subtotal_cents, 0);
    const totalCents = Math.max(0, subtotalCents - discountCents + regCents);

    if (!totalCents) {
      toast.error('Δώσε έγκυρο κόστος');
      return;
    }

    setSubmitting(true);
    try {
      const baseBody = {
        payment_type: form.payment_type,
        billing_month: form.payment_type === 'monthly' ? form.billing_month : undefined,
        package_months: form.payment_type === 'package' ? Number(form.package_months) : undefined,
        period_start: form.period_start,
        discount_cents: discountCents,
        registration_fee_cents: regCents,
        amount_cents: totalCents,
        paid_amount_cents: paidNow ? totalCents : 0,
        payment_date: paidNow ? paymentDate : null,
        due_date: form.due_date || null,
        notes: form.notes || null,
        method: paidNow ? paymentMethod : form.method,
        create_membership: !isActivate,
      };

      if (isActivate) {
        const { service_id, plan_id } = parseOption(keys[0]);
        await api.post(`/client-admin/clients/${clientId}/payments`, {
          ...baseBody,
          service_id,
          plan_id: plan_id || undefined,
          membership_id: activateTrialMembership.id,
          subtotal_cents: lines[0].subtotal_cents,
        });
      } else {
        await api.post(`/client-admin/clients/${clientId}/payments`, {
          ...baseBody,
          lines,
        });
      }

      toast.success(
        isActivate
          ? 'Το πακέτο ενεργοποιήθηκε — η πληρωμή είναι εκκρεμής'
          : keys.length > 1
            ? `${keys.length} υπηρεσίες — μία εκκρεμής πληρωμή €${(totalCents / 100).toFixed(2)}`
            : 'Το πακέτο προστέθηκε — η πληρωμή είναι εκκρεμής',
      );
      onSuccess?.();
      onClose();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSubmitting(false);
    }
  };

  const submit = (e) => {
    if (form.is_trial && !isActivate) {
      e.preventDefault();
      submitTrial();
      return;
    }
    submitPackage(e);
  };

  if (!open) return null;

  const staffOptions = slots.find(s => s.time === form.trial_time)?.available_staff || [];
  const showBilling = !form.is_trial || isActivate;

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal cb-modal" onClick={e => e.stopPropagation()}>
        <div className="cb-modal-header">
          <div>
            <div className="cb-modal-title">
              {isActivate ? 'Ενεργοποίηση πακέτου' : (form.is_trial ? 'Δοκιμαστικό μάθημα' : 'Πακέτο γυμναστηρίου')}
            </div>
            <div className="cb-modal-sub">
              {clientName ? `${clientName} · ` : ''}
              {isActivate
                ? 'Μετά το δοκιμαστικό — ορισμός χρέωσης & προγράμματος'
                : form.is_trial
                  ? 'Προγραμματισμός δοκιμαστικού χωρίς χρέωση'
                  : 'Ενεργοποίηση προγράμματος — η πληρωμή γίνεται ξεχωριστά'}
            </div>
          </div>
          <button type="button" className="cb-icon-btn" onClick={onClose} aria-label="Κλείσιμο">
            <X size={18} />
          </button>
        </div>

        {options.length === 0 && !isActivate ? (
          <div className="cb-form" style={{ padding: '24px 0', textAlign: 'center' }}>
            <p className="text-muted" style={{ marginBottom: 16 }}>
              Δεν υπάρχουν διαθέσιμα πακέτα γυμναστηρίου. Ρύθμισε πλάνα στις Υπηρεσίες.
            </p>
            <button type="button" className="btn btn-secondary" onClick={onClose}>Κλείσιμο</button>
          </div>
        ) : selectableOptions.length === 0 && !isActivate ? (
          <div className="cb-form" style={{ padding: '8px 0 24px' }}>
            <p className="text-muted" style={{ marginBottom: 12 }}>
              Ο πελάτης έχει ήδη ενεργό πακέτο για όλες τις υπηρεσίες γυμναστηρίου ({options.length}).
              Το πακέτο διατροφής είναι ξεχωριστό και δεν προστίθεται από εδώ.
            </p>
            <div className="sub-option-grid" style={{ marginBottom: 16 }}>
              {options.map(opt => (
                <div key={optionKey(opt)} className="sub-option-card is-blocked" style={{ cursor: 'default' }}>
                  <div className="sub-option-text">
                    <div className="sub-option-service">{opt.plan_name || opt.service_name}</div>
                    <div className="sub-option-plan">{opt.service_name}</div>
                    <div className="sub-option-meta text-muted" style={{ fontSize: '0.78rem', marginTop: 4 }}>
                      {getPackageBlockReason(memberships, opt)}
                    </div>
                  </div>
                </div>
              ))}
            </div>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              {canAddNutrition && onOpenNutrition && (
                <button type="button" className="btn btn-primary" onClick={onOpenNutrition}>
                  Πακέτο διατροφής
                </button>
              )}
              <button type="button" className="btn btn-secondary" onClick={onClose}>Κλείσιμο</button>
            </div>
          </div>
        ) : (
        <form onSubmit={submit} className="cb-form">
          {!isActivate && (
            <section className="cb-section">
              <label className="sub-toggle">
                <input
                  type="checkbox"
                  checked={form.is_trial}
                  onChange={e => setForm(f => {
                    const isTrial = e.target.checked;
                    const next = {
                      ...f,
                      is_trial: isTrial,
                      trial_time: '',
                      trial_staff_id: '',
                    };
                    if (isTrial && (f.selected_service_options?.length || 0) > 1) {
                      const first = f.selected_service_options[0];
                      const opt = options.find(o => optionKey(o) === first);
                      next.service_option = first;
                      next.selected_service_options = [first];
                      if (opt?.price_cents != null) {
                        next.subtotal_eur = (opt.price_cents / 100).toFixed(2);
                      }
                    }
                    return next;
                  })}
                />
                <FlaskConical size={16} style={{ marginRight: 6, verticalAlign: -3 }} />
                Δοκιμαστικό μάθημα (χωρίς χρέωση — ενεργοποίηση αργότερα)
              </label>
            </section>
          )}

          <section className="cb-section">
            <div className="cb-section-label">Υπηρεσία & πλάνο</div>
            {isActivate && activateTrialMembership?.service_name ? (
              <p className="text-muted" style={{ fontSize: '0.82rem', marginBottom: 10 }}>
                Από δοκιμαστικό: <strong>{activateTrialMembership.service_name}</strong>
                {activateTrialMembership.plan_id ? '' : ' — επίλεξε πλάνο χρέωσης'}
              </p>
            ) : !isActivate && (
              <p className="text-muted" style={{ fontSize: '0.82rem', marginBottom: 10 }}>
                {form.is_trial
                  ? 'Επίλεξε μία υπηρεσία για το δοκιμαστικό'
                  : 'Επίλεξε τις υπηρεσίες γυμναστηρίου — το σύνολο υπολογίζεται αυτόματα σε μία πληρωμή.'}
              </p>
            )}
            <div className="sub-option-grid">
              {options.map(opt => {
                const key = optionKey(opt);
                const blockReason = isActivate ? null : getPackageBlockReason(memberships, opt);
                const active = multiSelectMode
                  ? (form.selected_service_options || []).includes(key)
                  : form.service_option === key;
                const img = mediaUrl(opt.service_image_url);
                return (
                  <button
                    key={key}
                    type="button"
                    className={`sub-option-card ${active ? 'active' : ''} ${blockReason ? 'is-blocked' : ''}`}
                    onClick={() => onServicePlanClick(opt)}
                    disabled={isActivate}
                    title={blockReason || undefined}
                  >
                    <div className={`cb-service-visual ${img ? 'has-photo' : 'has-icon'}`}>
                      {img ? (
                        <img src={img} alt="" className="cb-service-photo" />
                      ) : (
                        <div className="cb-service-icon-wrap">
                          <ServiceIcon service={opt} size={28} />
                        </div>
                      )}
                    </div>
                    <div className="sub-option-text">
                      <div className="sub-option-service">{opt.plan_name || opt.service_name}</div>
                      <div className="sub-option-plan">{opt.service_name}</div>
                      <div className="sub-option-meta">
                        {`${opt.sessions == null ? '∞' : opt.sessions} συν. · €${((opt.price_cents || 0) / 100).toFixed(2)}`}
                      </div>
                      {blockReason && (
                        <div className="sub-option-meta" style={{ color: '#b45309', marginTop: 4 }}>
                          {blockReason}
                        </div>
                      )}
                    </div>
                    {multiSelectMode ? (
                      <div className={`cb-radio ${active ? 'on' : ''}`} style={active ? { background: '#76C043', borderColor: '#76C043' } : undefined}>
                        {active && <Check size={12} color="#fff" strokeWidth={3} />}
                      </div>
                    ) : (
                      <div className={`cb-radio ${active ? 'on' : ''}`} />
                    )}
                  </button>
                );
              })}
            </div>
          </section>

          {form.is_trial && !isActivate && (
            <>
              <section className="cb-section">
                <div className="cb-section-label">
                  <Calendar size={16} /> Ημερομηνία δοκιμαστικού
                </div>
                {!selectedOption ? (
                  <div className="text-muted">Επίλεξε πρώτα υπηρεσία</div>
                ) : datesLoading ? (
                  <div className="text-muted">Φόρτωση ημερών...</div>
                ) : availableDates.length === 0 ? (
                  <div className="text-muted">Δεν βρέθηκαν διαθέσιμες ημέρες</div>
                ) : (
                  <div className="cb-day-row">
                    {availableDates.map(d => {
                      const active = form.trial_date === d.date;
                      const dObj = new Date(`${d.date}T12:00:00`);
                      return (
                        <button
                          key={d.date}
                          type="button"
                          disabled={!d.selectable}
                          title={!d.selectable ? (d.message || 'Μη διαθέσιμο') : undefined}
                          className={`cb-day-pill ${active ? 'active' : ''}`}
                          onClick={() => d.selectable && pickTrialDate(d.date)}
                        >
                          <span className="cb-day-main">{formatTrialDayLabel(d.date)}</span>
                          <span className="cb-day-week">{GREEK_WEEKDAY[dObj.getDay()]}</span>
                        </button>
                      );
                    })}
                  </div>
                )}
              </section>
              <section className="cb-section">
                <div className="cb-section-label">Ώρα</div>
                {!form.trial_date ? (
                  <div className="text-muted">Δεν υπάρχουν διαθέσιμες ημέρες για δοκιμαστικό</div>
                ) : slotsLoading ? (
                  <div className="text-muted">Φόρτωση ωρών...</div>
                ) : bookableSlots.length === 0 ? (
                  <div className="text-muted">
                    {slotsMessage || 'Δεν υπάρχουν διαθέσιμες ώρες αυτή την ημέρα'}
                  </div>
                ) : (
                  <div className="cb-time-grid">
                    {slots.map(s => {
                      const disabled = s.is_full || !s.available_staff?.length;
                      const active = form.trial_time === s.time;
                      return (
                        <button
                          key={s.time}
                          type="button"
                          disabled={disabled}
                          className={`cb-time-pill ${active ? 'active' : ''} ${s.is_full ? 'full' : ''}`}
                          onClick={() => pickTrialTime(s.time)}
                        >
                          <span className="cb-time-main">{s.time}</span>
                          {s.label && <span className="cb-time-sub">{s.label}</span>}
                          {s.is_full && <span className="cb-time-badge">Πλήρες</span>}
                          {!s.is_full && s.booked_count != null && (
                            <span className="cb-time-sub">{s.booked_count}/{s.capacity}</span>
                          )}
                        </button>
                      );
                    })}
                  </div>
                )}
              </section>
              {form.trial_time && staffOptions.length > 0 && (
                <section className="cb-section">
                  <div className="cb-section-label">Γυμναστής</div>
                  <div className="cb-staff-row">
                    {staffOptions.map(s => (
                      <button
                        key={s.id}
                        type="button"
                        className={`cb-staff-card ${form.trial_staff_id === s.id ? 'active' : ''}`}
                        onClick={() => setForm(f => ({ ...f, trial_staff_id: s.id }))}
                      >
                        <div className="cb-staff-name">{s.full_name}</div>
                      </button>
                    ))}
                  </div>
                </section>
              )}
            </>
          )}

          {showBilling && (
            <>
              <section className="cb-section">
                <div className="cb-section-label">
                  <Receipt size={16} /> Τύπος χρέωσης
                </div>
                <div className="sub-type-row">
                  {PAYMENT_TYPES.map(pt => {
                    const Icon = pt.icon;
                    const active = form.payment_type === pt.id;
                    return (
                      <button
                        key={pt.id}
                        type="button"
                        className={`sub-type-card ${active ? 'active' : ''}`}
                        onClick={() => setForm(f => ({ ...f, payment_type: pt.id }))}
                      >
                        <Icon size={20} />
                        <div>
                          <div className="sub-type-label">{pt.label}</div>
                          <div className="sub-type-sub">{pt.sub}</div>
                        </div>
                      </button>
                    );
                  })}
                </div>
              </section>

              {form.payment_type === 'package' && (
                <section className="cb-section">
                  <div className="cb-section-label">Διάρκεια πακέτου</div>
                  <div className="cb-time-grid">
                    {PACKAGE_DURATIONS.map(d => (
                      <button
                        key={d.months}
                        type="button"
                        className={`cb-time-pill ${Number(form.package_months) === d.months ? 'active' : ''}`}
                        onClick={() => setForm(f => ({ ...f, package_months: d.months }))}
                      >
                        <span className="cb-time-main">{d.months}</span>
                        <span className="cb-time-sub">μήνες</span>
                      </button>
                    ))}
                  </div>
                </section>
              )}

              {form.payment_type === 'monthly' && (
                <section className="cb-section">
                  <div className="cb-section-label">Μήνας χρέωσης</div>
                  <select
                    className="form-select"
                    value={form.billing_month}
                    onChange={e => setForm(f => ({ ...f, billing_month: e.target.value }))}
                  >
                    {months.map(m => (
                      <option key={m.value} value={m.value}>{m.label}</option>
                    ))}
                  </select>
                </section>
              )}

              <section className="cb-section cb-section-row">
                <div className="cb-date-wrap" style={{ flex: 1 }}>
                  <div className="cb-section-label">
                    <Calendar size={16} /> Έναρξη προγράμματος
                  </div>
                  <input
                    className="cb-date-input"
                    type="date"
                    value={form.period_start}
                    onChange={e => setForm(f => ({ ...f, period_start: e.target.value }))}
                    required
                  />
                  <div className="text-muted" style={{ fontSize: '0.8rem', marginTop: 6 }}>
                    Λήξη: {periodEndPreview(form.payment_type, form.period_start, form.package_months)}
                  </div>
                </div>
              </section>

              <section className="cb-section">
                <div className="cb-section-label">
                  <CreditCard size={16} /> Κόστος πακέτου
                </div>
                <div className="form-grid-2" style={{ marginTop: 0 }}>
                  <div className="form-group">
                    <label className="form-label">
                      Βασικό ποσό (€){multiSelected ? ' — σύνολο επιλογών' : ''}
                    </label>
                    <input
                      className="form-input"
                      type="number"
                      step="0.01"
                      min="0"
                      value={form.subtotal_eur}
                      readOnly={multiSelected}
                      onChange={e => setForm(f => ({ ...f, subtotal_eur: e.target.value }))}
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Έκπτωση (€)</label>
                    <input
                      className="form-input"
                      type="number"
                      step="0.01"
                      min="0"
                      value={form.discount_eur}
                      onChange={e => setForm(f => ({ ...f, discount_eur: e.target.value }))}
                    />
                  </div>
                </div>

                <label className="sub-toggle" style={{ marginTop: 10 }}>
                  <input
                    type="checkbox"
                    checked={form.includes_registration}
                    onChange={e => setForm(f => ({ ...f, includes_registration: e.target.checked }))}
                  />
                  Συμπεριλαμβάνει κόστος εγγραφής
                </label>
                {form.includes_registration && (
                  <div className="form-group" style={{ marginTop: 8 }}>
                    <label className="form-label">Κόστος εγγραφής (€)</label>
                    <input
                      className="form-input"
                      type="number"
                      step="0.01"
                      min="0"
                      value={form.registration_fee_eur}
                      onChange={e => setForm(f => ({ ...f, registration_fee_eur: e.target.value }))}
                    />
                  </div>
                )}
                <div className="sub-summary-card">
                  {multiSelected && (
                    <div style={{ fontSize: '0.85rem', marginBottom: 8, color: '#64748b' }}>
                      {selectionKeys().map((key) => {
                        const opt = options.find(o => optionKey(o) === key);
                        if (!opt) return null;
                        return (
                          <div key={key}>
                            {opt.service_name} — {opt.plan_name}: €{((opt.price_cents || 0) / 100).toFixed(2)}
                          </div>
                        );
                      })}
                    </div>
                  )}
                  <div style={{ fontWeight: 600 }}>{descriptionPreview()}</div>
                  <div className="sub-summary-total">Χρέωση: €{payTotalEur().toFixed(2)}</div>
                </div>

                {/* Payment status toggle */}
                <div style={{ marginTop: 12 }}>
                  <div style={{ fontSize: '0.75rem', fontWeight: 700, textTransform: 'uppercase', color: '#94a3b8', marginBottom: 8 }}>Πληρωμή τώρα ή αργότερα;</div>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                    <button type="button" onClick={() => setPaidNow(true)} style={{
                      padding: '12px 10px', borderRadius: 10,
                      border: `2px solid ${paidNow ? '#22c55e' : '#e2e8f0'}`,
                      background: paidNow ? '#f0fdf4' : '#fafafa',
                      cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 8, textAlign: 'left',
                    }}>
                      <CheckCircle size={20} color={paidNow ? '#16a34a' : '#cbd5e1'} />
                      <div>
                        <div style={{ fontWeight: 700, fontSize: '0.85rem', color: paidNow ? '#15803d' : '#64748b' }}>Πλήρωσε τώρα</div>
                        <div style={{ fontSize: '0.72rem', color: '#94a3b8' }}>Καταχώρησε πληρωμή</div>
                      </div>
                    </button>
                    <button type="button" onClick={() => setPaidNow(false)} style={{
                      padding: '12px 10px', borderRadius: 10,
                      border: `2px solid ${!paidNow ? '#f59e0b' : '#e2e8f0'}`,
                      background: !paidNow ? '#fffbeb' : '#fafafa',
                      cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 8, textAlign: 'left',
                    }}>
                      <Clock size={20} color={!paidNow ? '#d97706' : '#cbd5e1'} />
                      <div>
                        <div style={{ fontWeight: 700, fontSize: '0.85rem', color: !paidNow ? '#92400e' : '#64748b' }}>Εκκρεμεί</div>
                        <div style={{ fontSize: '0.72rem', color: '#94a3b8' }}>Θα πληρώσει αργότερα</div>
                      </div>
                    </button>
                  </div>
                </div>

                {paidNow && (
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginTop: 10 }}>
                    <div className="form-group" style={{ marginBottom: 0 }}>
                      <label className="form-label">Ημ. πληρωμής</label>
                      <input className="form-input" type="date" value={paymentDate} onChange={e => setPaymentDate(e.target.value)} />
                    </div>
                    <div className="form-group" style={{ marginBottom: 0 }}>
                      <label className="form-label">Τρόπος</label>
                      <select className="form-input" value={paymentMethod} onChange={e => setPaymentMethod(e.target.value)}>
                        <option value="cash">Μετρητά</option>
                        <option value="card">Κάρτα</option>
                        <option value="bank_transfer">Τραπεζική μεταφορά</option>
                      </select>
                    </div>
                  </div>
                )}

                {!paidNow && (
                  <div className="form-group" style={{ marginTop: 10 }}>
                    <label className="form-label">Προθεσμία πληρωμής (προαιρετικά)</label>
                    <input
                      className="form-input"
                      type="date"
                      value={form.due_date}
                      onChange={e => setForm(f => ({ ...f, due_date: e.target.value }))}
                    />
                  </div>
                )}
              </section>
            </>
          )}

          <div className="form-group">
            <label className="form-label">Σημειώσεις</label>
            <input
              className="form-input"
              value={form.notes}
              onChange={e => setForm(f => ({ ...f, notes: e.target.value }))}
              placeholder="Προαιρετικά"
            />
          </div>

          <div className="cb-footer">
            <button type="button" className="btn btn-secondary" onClick={onClose}>Ακύρωση</button>
            <button type="submit" className="btn btn-primary" disabled={submitting}>
              {submitting ? 'Αποθήκευση...' : (
                form.is_trial && !isActivate
                  ? 'Προγραμματισμός δοκιμαστικού'
                  : (isActivate ? 'Ενεργοποίηση πακέτου' : 'Προσθήκη πακέτου')
              )}
            </button>
          </div>
        </form>
        )}
      </div>
    </div>
  );
}
