import { useEffect, useMemo, useState } from 'react';
import { Save, X } from 'lucide-react';
import api from '../api/client';
import toast from 'react-hot-toast';
import { monthOptions } from '../utils/payments';

function formatLocalDate(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function addMonths(iso, months) {
  const [y, m, d] = iso.split('-').map(Number);
  const dt = new Date(y, m - 1 + months, d);
  return formatLocalDate(dt);
}

const defaultForm = (clientId = '') => ({
  user_id: clientId,
  plan_id: '',
  valid_from: formatLocalDate(new Date()),
  valid_until: addMonths(formatLocalDate(new Date()), 1),
  payment_type: 'package',
  package_months: 1,
  billing_month: monthOptions()[0].value,
  price_eur: '',
  discount_eur: '0',
  due_date: '',
  notes: '',
});

export default function NutritionEnrollModal({
  open,
  onClose,
  onSuccess,
  clientId = '',
  clientName = '',
  hasActiveNutrition = false,
}) {
  const [nutritionPlans, setNutritionPlans] = useState([]);
  const [form, setForm] = useState(defaultForm(clientId));
  const [loading, setLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const months = useMemo(() => monthOptions(), []);

  const selectedPlan = nutritionPlans.find(p => p.id === form.plan_id);

  useEffect(() => {
    if (!open) return;
    setForm(defaultForm(clientId));
    setLoading(true);
    api.get('/client-admin/nutrition/plans')
      .then(r => setNutritionPlans(r.data || []))
      .catch(() => toast.error('Δεν φορτώθηκαν τα πακέτα διατροφής'))
      .finally(() => setLoading(false));
  }, [open, clientId]);

  const applyPlan = (planId) => {
    const plan = nutritionPlans.find(p => p.id === planId);
    if (!plan) return;
    const from = form.valid_from || formatLocalDate(new Date());
    const pkgMonths = plan.billing_period === 'monthly' ? 1 : 3;
    setForm(f => ({
      ...f,
      plan_id: planId,
      payment_type: plan.billing_period === 'monthly' ? 'monthly' : 'package',
      package_months: pkgMonths,
      valid_until: addMonths(from, pkgMonths),
      price_eur: ((plan.price_cents || 0) / 100).toFixed(2),
    }));
  };

  const totalEur = () => {
    const price = Number(form.price_eur) || 0;
    const disc = Number(form.discount_eur) || 0;
    return Math.max(0, price - disc);
  };

  const submit = async (e) => {
    e.preventDefault();
    if (!clientId || !form.plan_id) return;
    setSubmitting(true);
    try {
      const subtotalCents = Math.round((Number(form.price_eur) || 0) * 100);
      const discountCents = Math.round((Number(form.discount_eur) || 0) * 100);
      await api.post(`/client-admin/nutrition/clients/${clientId}/enroll`, {
        plan_id: form.plan_id,
        valid_from: form.valid_from,
        valid_until: form.valid_until,
        payment_type: form.payment_type,
        package_months: form.payment_type === 'package' ? Number(form.package_months) : undefined,
        billing_month: form.payment_type === 'monthly' ? form.billing_month : undefined,
        subtotal_cents: subtotalCents,
        discount_cents: discountCents,
        due_date: form.due_date || null,
        notes: form.notes || null,
      });
      toast.success('Το πακέτο διατροφής προστέθηκε');
      onSuccess?.();
      onClose();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSubmitting(false);
    }
  };

  if (!open) return null;

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal cb-modal" onClick={e => e.stopPropagation()}>
        <div className="cb-modal-header">
          <div>
            <div className="cb-modal-title">Πακέτο διατροφής</div>
            <div className="cb-modal-sub">
              {clientName ? `${clientName} · ` : ''}
              Ξεχωριστό από τα πακέτα γυμναστηρίου
            </div>
          </div>
          <button type="button" className="cb-icon-btn" onClick={onClose} aria-label="Κλείσιμο">
            <X size={18} />
          </button>
        </div>

        {loading ? (
          <div className="loading">Φόρτωση...</div>
        ) : hasActiveNutrition ? (
          <div className="cb-form" style={{ paddingBottom: 8 }}>
            <p className="text-muted">
              Ο πελάτης έχει ήδη ενεργό πακέτο διατροφής. Επεξεργάσου το από τη λίστα πακέτων ή το τμήμα Διατροφή.
            </p>
            <button type="button" className="btn btn-secondary" onClick={onClose}>Κλείσιμο</button>
          </div>
        ) : nutritionPlans.length === 0 ? (
          <div className="cb-form" style={{ paddingBottom: 8 }}>
            <p className="text-muted">Δεν υπάρχουν πακέτα διατροφής. Δημιούργησέ τα στο Διατροφή → Πακέτα.</p>
            <button type="button" className="btn btn-secondary" onClick={onClose}>Κλείσιμο</button>
          </div>
        ) : (
          <form onSubmit={submit} className="cb-form">
            <section className="cb-section">
              <div className="cb-section-label">Πακέτο</div>
              <div className="sub-option-grid">
                {nutritionPlans.map(plan => (
                  <button
                    key={plan.id}
                    type="button"
                    className={`sub-option-card ${form.plan_id === plan.id ? 'active' : ''}`}
                    onClick={() => applyPlan(plan.id)}
                  >
                    <div className="sub-option-text">
                      <div className="sub-option-service">{plan.name}</div>
                      <div className="sub-option-meta">
                        €{((plan.price_cents || 0) / 100).toFixed(2)}
                        {plan.includes_summary ? ` · ${plan.includes_summary}` : ''}
                      </div>
                    </div>
                  </button>
                ))}
              </div>
            </section>

            <div className="form-grid-2">
              <div className="form-group">
                <label className="form-label">Από</label>
                <input
                  className="form-input"
                  type="date"
                  value={form.valid_from}
                  onChange={e => setForm({ ...form, valid_from: e.target.value })}
                  required
                />
              </div>
              <div className="form-group">
                <label className="form-label">Έως</label>
                <input
                  className="form-input"
                  type="date"
                  value={form.valid_until}
                  onChange={e => setForm({ ...form, valid_until: e.target.value })}
                  required
                />
              </div>
            </div>

            <div className="form-grid-2">
              <div className="form-group">
                <label className="form-label">Κόστος (€)</label>
                <input
                  className="form-input"
                  type="number"
                  step="0.01"
                  min="0"
                  value={form.price_eur}
                  onChange={e => setForm({ ...form, price_eur: e.target.value })}
                  required
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
                  onChange={e => setForm({ ...form, discount_eur: e.target.value })}
                />
              </div>
            </div>

            {selectedPlan && (
              <p className="text-muted" style={{ fontSize: '0.85rem' }}>
                Χρέωση: €{totalEur().toFixed(2)} (εκκρεμής πληρωμή)
              </p>
            )}

            <div className="cb-footer">
              <button type="button" className="btn btn-secondary" onClick={onClose}>Ακύρωση</button>
              <button type="submit" className="btn btn-primary" disabled={submitting || !form.plan_id}>
                <Save size={14} /> {submitting ? 'Αποθήκευση...' : 'Προσθήκη πακέτου'}
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}
