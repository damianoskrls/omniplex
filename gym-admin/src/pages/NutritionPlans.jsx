import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Plus, Trash2, Edit2 } from 'lucide-react';

const PERIODS = [
  { v: 'monthly', label: 'Μηνιαία' },
  { v: 'quarterly', label: 'Τριμηνιαία' },
  { v: 'yearly', label: 'Ετήσια' },
  { v: 'once', label: 'Εφάπαξ' },
  { v: 'package', label: 'Πακέτο συνεδριών' },
];

const BILLING_TRIGGERS = [
  { v: '', label: 'Οποιοδήποτε πακέτο γυμναστηρίου' },
  { v: 'monthly', label: 'Μηνιαίο πρόγραμμα' },
  { v: 'quarterly', label: 'Τριμηνιαίο πρόγραμμα' },
  { v: 'yearly', label: 'Ετήσιο πρόγραμμα' },
];

const EFFECTS = [
  { v: 'free', label: 'Δωρεάν' },
  { v: 'free_months', label: 'Επιπλέον δωρεάν μήνες' },
  { v: 'discount_percent', label: 'Έκπτωση %' },
];

const EMPTY_RULE = {
  when_service_plan_billing_period: 'yearly',
  when_package_months_min: 12,
  effect: 'free_months',
  free_months: 3,
  discount_percent: 100,
  description: '',
};

const EMPTY = {
  name: '',
  price_cents: '',
  billing_period: 'monthly',
  nutrition_includes_meal_plan: true,
  nutrition_includes_measurements: false,
  nutrition_includes_food_diary: true,
  nutrition_includes_consultations: false,
  nutrition_consultation_sessions: '',
  promo_rules: { rules: [] },
};

function PlanForm({ form, setForm, onSubmit, onCancel, submitLabel }) {
  const addRule = () => {
    setForm({
      ...form,
      promo_rules: {
        rules: [...(form.promo_rules?.rules || []), { ...EMPTY_RULE }],
      },
    });
  };

  const updateRule = (idx, patch) => {
    const rules = [...(form.promo_rules?.rules || [])];
    rules[idx] = { ...rules[idx], ...patch };
    setForm({ ...form, promo_rules: { rules } });
  };

  const removeRule = (idx) => {
    const rules = (form.promo_rules?.rules || []).filter((_, i) => i !== idx);
    setForm({ ...form, promo_rules: { rules } });
  };

  return (
    <form onSubmit={onSubmit}>
      <div className="form-group">
        <label className="form-label">Όνομα πακέτου *</label>
        <input className="form-input" value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} required />
      </div>
      <div className="form-grid-2">
        <div className="form-group">
          <label className="form-label">Τιμή (€) *</label>
          <input className="form-input" type="number" step="0.01" min="0" value={form.price_cents} onChange={e => setForm({ ...form, price_cents: e.target.value })} required />
        </div>
        <div className="form-group">
          <label className="form-label">Περίοδος χρέωσης</label>
          <select className="form-input" value={form.billing_period} onChange={e => setForm({ ...form, billing_period: e.target.value })}>
            {PERIODS.map(p => <option key={p.v} value={p.v}>{p.label}</option>)}
          </select>
        </div>
      </div>

      <div className="form-group">
        <label className="form-label">Τι περιλαμβάνει</label>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {[
            { key: 'nutrition_includes_meal_plan', label: 'Πρόγραμμα / αποστολή διατροφής' },
            { key: 'nutrition_includes_food_diary', label: 'Ημερολόγιο διατροφής' },
            { key: 'nutrition_includes_measurements', label: 'Μετρήσεις σώματος' },
            { key: 'nutrition_includes_consultations', label: 'Συνεδρίες με διατροφολόγο' },
          ].map(item => (
            <label key={item.key} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <input type="checkbox" checked={!!form[item.key]} onChange={e => setForm({ ...form, [item.key]: e.target.checked })} />
              {item.label}
            </label>
          ))}
        </div>
        {form.nutrition_includes_consultations && (
          <div className="form-group" style={{ marginTop: 10 }}>
            <label className="form-label">Αριθμός συνεδριών</label>
            <input className="form-input" type="number" min="1" value={form.nutrition_consultation_sessions} onChange={e => setForm({ ...form, nutrition_consultation_sessions: e.target.value })} placeholder="π.χ. 4" />
          </div>
        )}
      </div>

      <div className="form-group">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
          <label className="form-label" style={{ margin: 0 }}>Συνθήκες / προσφορές</label>
          <button type="button" className="btn btn-secondary btn-sm" onClick={addRule}><Plus size={12} /> Κανόνας</button>
        </div>
        <p className="text-muted" style={{ fontSize: '0.8rem', marginBottom: 10 }}>
          π.χ. με ετήσιο πρόγραμμα γυμναστηρίου → δωρεάν 3 μήνες διατροφής
        </p>
        {(form.promo_rules?.rules || []).map((rule, idx) => (
          <div key={idx} style={{ border: '1px solid #e2e8f0', borderRadius: 10, padding: 12, marginBottom: 10, background: '#fafbfd' }}>
            <div className="form-grid-2">
              <div className="form-group">
                <label className="form-label">Όταν ο πελάτης πάρει</label>
                <select className="form-input" value={rule.when_service_plan_billing_period || ''} onChange={e => updateRule(idx, { when_service_plan_billing_period: e.target.value || null })}>
                  {BILLING_TRIGGERS.map(t => <option key={t.v} value={t.v}>{t.label}</option>)}
                </select>
              </div>
              <div className="form-group">
                <label className="form-label">Ελάχ. μήνες πακέτου (προαιρ.)</label>
                <input className="form-input" type="number" min="1" value={rule.when_package_months_min ?? ''} onChange={e => updateRule(idx, { when_package_months_min: e.target.value ? Number(e.target.value) : null })} placeholder="π.χ. 12" />
              </div>
            </div>
            <div className="form-grid-2">
              <div className="form-group">
                <label className="form-label">Αποτέλεσμα</label>
                <select className="form-input" value={rule.effect} onChange={e => updateRule(idx, { effect: e.target.value })}>
                  {EFFECTS.map(e => <option key={e.v} value={e.v}>{e.label}</option>)}
                </select>
              </div>
              {rule.effect === 'free_months' && (
                <div className="form-group">
                  <label className="form-label">Δωρεάν μήνες</label>
                  <input className="form-input" type="number" min="1" value={rule.free_months ?? ''} onChange={e => updateRule(idx, { free_months: Number(e.target.value) })} />
                </div>
              )}
              {rule.effect === 'discount_percent' && (
                <div className="form-group">
                  <label className="form-label">Έκπτωση %</label>
                  <input className="form-input" type="number" min="0" max="100" value={rule.discount_percent ?? ''} onChange={e => updateRule(idx, { discount_percent: Number(e.target.value) })} />
                </div>
              )}
            </div>
            <div className="form-group">
              <label className="form-label">Περιγραφή (εμφανίζεται στον admin)</label>
              <input className="form-input" value={rule.description || ''} onChange={e => updateRule(idx, { description: e.target.value })} placeholder="π.χ. Δωρεάν 3 μήνες με ετήσιο πρόγραμμα" />
            </div>
            <button type="button" className="btn btn-danger btn-sm" onClick={() => removeRule(idx)}><Trash2 size={12} /> Αφαίρεση</button>
          </div>
        ))}
      </div>

      <div className="modal-footer">
        <button type="button" className="btn btn-secondary" onClick={onCancel}>Ακύρωση</button>
        <button type="submit" className="btn btn-primary">{submitLabel}</button>
      </div>
    </form>
  );
}

function planToForm(plan) {
  return {
    name: plan.name,
    price_cents: (plan.price_cents / 100).toFixed(2),
    billing_period: plan.billing_period || 'monthly',
    nutrition_includes_meal_plan: !!plan.nutrition_includes_meal_plan,
    nutrition_includes_measurements: !!plan.nutrition_includes_measurements,
    nutrition_includes_food_diary: !!plan.nutrition_includes_food_diary,
    nutrition_includes_consultations: !!plan.nutrition_includes_consultations,
    nutrition_consultation_sessions: plan.nutrition_consultation_sessions ?? '',
    promo_rules: plan.promo_rules?.rules ? plan.promo_rules : { rules: [] },
  };
}

function formToPayload(form) {
  return {
    name: form.name.trim(),
    price_cents: Math.round(Number(form.price_cents) * 100),
    billing_period: form.billing_period,
    nutrition_includes_meal_plan: form.nutrition_includes_meal_plan ? 1 : 0,
    nutrition_includes_measurements: form.nutrition_includes_measurements ? 1 : 0,
    nutrition_includes_food_diary: form.nutrition_includes_food_diary ? 1 : 0,
    nutrition_includes_consultations: form.nutrition_includes_consultations ? 1 : 0,
    nutrition_consultation_sessions: form.nutrition_includes_consultations && form.nutrition_consultation_sessions !== ''
      ? Number(form.nutrition_consultation_sessions) : null,
    promo_rules: form.promo_rules,
  };
}

export default function NutritionPlans() {
  const [plans, setPlans] = useState([]);
  const [modal, setModal] = useState(false);
  const [form, setForm] = useState(EMPTY);
  const [editingId, setEditingId] = useState(null);

  const load = () => api.get('/client-admin/nutrition/plans').then(r => setPlans(r.data)).catch(() => {});
  useEffect(() => { load(); }, []);

  const openCreate = () => { setForm(EMPTY); setEditingId(null); setModal('create'); };
  const openEdit = (plan) => { setForm(planToForm(plan)); setEditingId(plan.id); setModal('edit'); };
  const closeModal = () => { setModal(false); setEditingId(null); setForm(EMPTY); };

  const handleCreate = async (e) => {
    e.preventDefault();
    try {
      await api.post('/client-admin/nutrition/plans', formToPayload(form));
      toast.success('Πακέτο διατροφής δημιουργήθηκε');
      closeModal();
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const handleEdit = async (e) => {
    e.preventDefault();
    try {
      await api.patch(`/client-admin/nutrition/plans/${editingId}`, formToPayload(form));
      toast.success('Αποθηκεύτηκε');
      closeModal();
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const remove = async (id) => {
    if (!window.confirm('Διαγραφή πακέτου διατροφής;')) return;
    await api.delete(`/client-admin/nutrition/plans/${id}`);
    toast.success('Διαγράφηκε');
    load();
  };

  const periodLabel = (v) => PERIODS.find(p => p.v === v)?.label || v;

  return (
    <Layout title="Πακέτα διατροφής" variant="nutrition">
      <div className="page-header">
        <div>
          <h1 className="page-title">Πακέτα διατροφής</h1>
          <p className="text-muted" style={{ margin: '6px 0 0' }}>Ξεχωριστά πακέτα με περιεχόμενο και συνθήκες προσφοράς</p>
        </div>
        <button className="btn btn-primary" onClick={openCreate}><Plus size={16} /> Νέο πακέτο</button>
      </div>

      <div className="card">
        <table>
          <thead>
            <tr><th>Πακέτο</th><th>Τιμή</th><th>Περίοδος</th><th>Περιλαμβάνει</th><th>Συνθήκες</th><th></th></tr>
          </thead>
          <tbody>
            {plans.map(p => (
              <tr key={p.id}>
                <td style={{ fontWeight: 600 }}>{p.name}</td>
                <td>€{(p.price_cents / 100).toFixed(2)}</td>
                <td>{periodLabel(p.billing_period)}</td>
                <td style={{ fontSize: '0.85rem' }}>{(p.includes_summary || []).join(', ') || '—'}</td>
                <td style={{ fontSize: '0.85rem' }}>{(p.promo_rules?.rules || []).length ? `${p.promo_rules.rules.length} κανόνες` : '—'}</td>
                <td style={{ display: 'flex', gap: 6 }}>
                  <button className="btn btn-secondary btn-sm" onClick={() => openEdit(p)}><Edit2 size={14} /></button>
                  <button className="btn btn-danger btn-sm" onClick={() => remove(p.id)}><Trash2 size={14} /></button>
                </td>
              </tr>
            ))}
            {!plans.length && <tr><td colSpan={6} className="loading">Δεν υπάρχουν πακέτα διατροφής</td></tr>}
          </tbody>
        </table>
      </div>

      {modal && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && closeModal()}>
          <div className="modal" style={{ maxWidth: 640, maxHeight: '90vh', overflow: 'auto' }}>
            <div className="modal-title">{modal === 'edit' ? 'Επεξεργασία πακέτου' : 'Νέο πακέτο διατροφής'}</div>
            <PlanForm form={form} setForm={setForm} onSubmit={modal === 'edit' ? handleEdit : handleCreate} onCancel={closeModal} submitLabel={modal === 'edit' ? 'Αποθήκευση' : 'Δημιουργία'} />
          </div>
        </div>
      )}
    </Layout>
  );
}
