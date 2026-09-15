import { useEffect, useMemo, useState } from 'react';
import { Calendar, CreditCard, Package, Receipt, Sparkles, X } from 'lucide-react';
import api from '../api/client';
import toast from 'react-hot-toast';
import ServiceIcon from './ui/ServiceIcon';
import { mediaUrl } from '../utils/media';
import { packageOptionsForPayment } from '../utils/payment_helpers';
import {
  buildPaymentPatchBody,
  formatBillingMonth,
  monthOptions,
  optionKey,
  parseOption,
  paymentToEditForm,
  periodEndPreview,
} from '../utils/payments';

const PAYMENT_TYPES = [
  { id: 'package', label: 'Πακέτο', sub: '3 / 6 / 12 μήνες', icon: Package },
  { id: 'monthly', label: 'Μηνιαία', sub: 'Μηνιαία χρέωση', icon: Calendar },
  { id: 'registration_fee', label: 'Εγγραφή', sub: 'Μόνο εγγραφή', icon: Sparkles },
];

const PACKAGE_DURATIONS = [
  { months: 3, label: '3 μήνες' },
  { months: 6, label: '6 μήνες' },
  { months: 12, label: '12 μήνες' },
];

export default function EditPaymentModal({
  open,
  onClose,
  onSuccess,
  payment,
  clientName = '',
  packageOptions = [],
}) {
  const [form, setForm] = useState(null);
  const [submitting, setSubmitting] = useState(false);
  const months = useMemo(() => monthOptions(), []);

  const editableOptions = useMemo(
    () => packageOptionsForPayment(payment, packageOptions),
    [payment, packageOptions],
  );

  useEffect(() => {
    if (!open || !payment) return;
    setForm(paymentToEditForm(payment, editableOptions));
  }, [open, payment, editableOptions]);

  const selectedOption = editableOptions.find(o => optionKey(o) === form?.service_option);

  const pickServicePlan = (opt) => {
    setForm(f => ({
      ...f,
      service_option: optionKey(opt),
      subtotal_eur: opt?.price_cents != null ? (opt.price_cents / 100).toFixed(2) : f.subtotal_eur,
    }));
  };

  const payTotalEur = () => {
    if (!form) return 0;
    const sub = Number(form.subtotal_eur) || 0;
    const disc = Number(form.discount_eur) || 0;
    const reg = form.includes_registration ? (Number(form.registration_fee_eur) || 0) : 0;
    return Math.max(0, sub - disc + reg);
  };

  const descriptionPreview = () => {
    if (!form) return '';
    const svc = selectedOption?.service_name || payment?.service_name;
    if (form.payment_type === 'registration_fee') {
      return svc ? `${svc} — Κόστος εγγραφής` : 'Κόστος εγγραφής';
    }
    const parts = [];
    if (svc) parts.push(svc);
    if (form.payment_type === 'package') parts.push(`Πακέτο ${form.package_months} μηνών`);
    else if (form.payment_type === 'monthly') parts.push(`Μήνας ${formatBillingMonth(form.billing_month)}`);
    if (form.includes_registration && form.registration_fee_eur) parts.push('+ εγγραφή');
    const end = periodEndPreview(form.payment_type, form.period_start, form.package_months);
    if (form.period_start && form.payment_type !== 'registration_fee') {
      return `${parts.join(' — ')} (${form.period_start} → ${end})`;
    }
    return parts.join(' — ') || 'Πληρωμή';
  };

  const submit = async (e) => {
    e.preventDefault();
    if (!form || !payment) return;

    const { service_id } = parseOption(form.service_option);
    const body = buildPaymentPatchBody(form);

    if (!body.amount_cents && form.payment_type !== 'registration_fee') {
      toast.error('Δώσε έγκυρο ποσό');
      return;
    }
    if (form.payment_type === 'registration_fee' && !body.registration_fee_cents) {
      toast.error('Δώσε ποσό εγγραφής');
      return;
    }
    if (!service_id && form.payment_type !== 'registration_fee') {
      toast.error('Επίλεξε υπηρεσία / πλάνο');
      return;
    }

    setSubmitting(true);
    try {
      await api.patch(`/client-admin/payments/${payment.id}`, body);
      toast.success('Η πληρωμή ενημερώθηκε');
      onSuccess?.();
      onClose();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSubmitting(false);
    }
  };

  if (!open || !payment || !form) return null;

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal cb-modal" onClick={e => e.stopPropagation()}>
        <div className="cb-modal-header">
          <div>
            <div className="cb-modal-title">Επεξεργασία πληρωμής</div>
            <div className="cb-modal-sub">
              {clientName ? `${clientName} · ` : ''}
              {payment.description || payment.service_name || 'Πληρωμή'}
            </div>
          </div>
          <button type="button" className="cb-icon-btn" onClick={onClose} aria-label="Κλείσιμο">
            <X size={18} />
          </button>
        </div>

        <form onSubmit={submit} className="cb-form">
          <section className="cb-section">
            <div className="cb-section-label">Υπηρεσία & πλάνο</div>
            {editableOptions.length > 0 ? (
            <div className="sub-option-grid">
              {editableOptions.map(opt => {
                const active = form.service_option === optionKey(opt);
                const sessions = opt.sessions == null ? '∞' : opt.sessions;
                const img = mediaUrl(opt.service_image_url);
                return (
                  <button
                    key={optionKey(opt)}
                    type="button"
                    className={`sub-option-card ${active ? 'active' : ''}`}
                    onClick={() => pickServicePlan(opt)}
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
                      <div className="sub-option-service">{opt.service_name}</div>
                      <div className="sub-option-plan">{opt.plan_name || 'Χειροκίνητο πακέτο'}</div>
                      <div className="sub-option-meta">
                        {opt.plan_id
                          ? `${sessions} συν. · €${((opt.price_cents || 0) / 100).toFixed(2)}`
                          : 'Χωρίς πλάνο'}
                      </div>
                    </div>
                    <div className={`cb-radio ${active ? 'on' : ''}`} />
                  </button>
                );
              })}
            </div>
            ) : (
              <div className="sub-summary-card">
                <div style={{ fontWeight: 600 }}>{payment.service_name || payment.description || 'Πληρωμή'}</div>
                {payment.plan_name && (
                  <div className="text-muted" style={{ fontSize: '0.85rem', marginTop: 4 }}>{payment.plan_name}</div>
                )}
              </div>
            )}
          </section>

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
                    onClick={() => setForm(f => ({
                      ...f,
                      payment_type: pt.id,
                      includes_registration: pt.id === 'registration_fee' ? true : f.includes_registration,
                    }))}
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

          {form.payment_type !== 'registration_fee' && (
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
          )}

          <section className="cb-section">
            <div className="cb-section-label">
              <CreditCard size={16} /> Ποσά
            </div>
            {form.payment_type !== 'registration_fee' && (
              <div className="form-grid-2">
                <div className="form-group">
                  <label className="form-label">Βασικό ποσό (€)</label>
                  <input
                    className="form-input"
                    type="number"
                    step="0.01"
                    min="0"
                    value={form.subtotal_eur}
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
            )}
            <label className="sub-toggle" style={{ marginTop: 10 }}>
              <input
                type="checkbox"
                checked={form.includes_registration || form.payment_type === 'registration_fee'}
                disabled={form.payment_type === 'registration_fee'}
                onChange={e => setForm(f => ({ ...f, includes_registration: e.target.checked }))}
              />
              Συμπεριλαμβάνει κόστος εγγραφής
            </label>
            {(form.includes_registration || form.payment_type === 'registration_fee') && (
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
              <div style={{ fontWeight: 600 }}>{descriptionPreview()}</div>
              <div className="sub-summary-total">Σύνολο: €{payTotalEur().toFixed(2)}</div>
            </div>
            <div className="form-grid-2">
              <div className="form-group">
                <label className="form-label">Πληρώθηκε (€)</label>
                <input
                  className="form-input"
                  type="number"
                  step="0.01"
                  min="0"
                  value={form.paid_eur}
                  onChange={e => setForm(f => ({ ...f, paid_eur: e.target.value }))}
                />
              </div>
              <div className="form-group">
                <label className="form-label">Ημ. πληρωμής</label>
                <input
                  className="form-input"
                  type="date"
                  value={form.payment_date}
                  onChange={e => setForm(f => ({ ...f, payment_date: e.target.value }))}
                />
              </div>
            </div>
            <div className="form-grid-2">
              <div className="form-group">
                <label className="form-label">Προθεσμία (αν εκκρεμές)</label>
                <input
                  className="form-input"
                  type="date"
                  value={form.due_date}
                  onChange={e => setForm(f => ({ ...f, due_date: e.target.value }))}
                />
              </div>
              <div className="form-group">
                <label className="form-label">Τρόπος</label>
                <select
                  className="form-select"
                  value={form.method}
                  onChange={e => setForm(f => ({ ...f, method: e.target.value }))}
                >
                  <option value="cash">Μετρητά</option>
                  <option value="card">Κάρτα</option>
                  <option value="transfer">Κατάθεση</option>
                </select>
              </div>
            </div>
          </section>

          <div className="form-group">
            <label className="form-label">Σημειώσεις</label>
            <input
              className="form-input"
              value={form.notes}
              onChange={e => setForm(f => ({ ...f, notes: e.target.value }))}
            />
          </div>

          <div className="cb-footer">
            <button type="button" className="btn btn-secondary" onClick={onClose}>Ακύρωση</button>
            <button type="submit" className="btn btn-primary" disabled={submitting}>
              {submitting ? 'Αποθήκευση...' : 'Αποθήκευση'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
