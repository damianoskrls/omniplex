import { useEffect, useMemo, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Plus, Trash2, Edit2, PlusCircle, X } from 'lucide-react';
import { buildPlanNamePreview } from '../lib/planNames';

const EMPTY_SINGLE = {
  mode: 'single',
  service_id: '',
  sessions: 10,
  duration_mins: 60,
  price_cents: '',
  billing_period: 'monthly',
};

const EMPTY_COMBO = {
  mode: 'combo',
  name: '',
  service_items: [{ service_id: '', sessions: '', duration_mins: '' }],
  price_cents: '',
  billing_period: 'monthly',
};

function SessionChip({ label, checked, onClick, unlimited }) {
  return (
    <button type="button" onClick={onClick} style={{
      padding: '5px 14px', borderRadius: 20,
      border: `1.5px solid ${checked ? (unlimited ? '#64748b' : '#76C043') : '#e2e8f0'}`,
      background: checked ? (unlimited ? '#f1f5f9' : '#f0fdf4') : '#fff',
      color: checked ? (unlimited ? '#475569' : '#76C043') : '#64748b',
      fontWeight: checked ? 700 : 400, fontSize: '0.85rem', cursor: 'pointer',
    }}>
      {label}
    </button>
  );
}

const PERIODS = [
  { v: 'monthly', label: 'Μηνιαία' },
  { v: 'quarterly', label: 'Τριμηνιαία' },
  { v: 'yearly', label: 'Ετήσια' },
  { v: 'once', label: 'Εφάπαξ' },
  { v: 'package', label: 'Πακέτο (οποτεδήποτε)' },
];

function ServiceItemRow({ item, idx, services, onChange, onRemove, canRemove }) {
  return (
    <div style={{ display: 'flex', gap: 8, alignItems: 'flex-start', padding: '10px', background: '#f8fafc', borderRadius: 10, border: '1px solid #e2e8f0', marginBottom: 8 }}>
      <div style={{ flex: 2 }}>
        <label style={{ fontSize: '0.75rem', color: '#64748b', display: 'block', marginBottom: 4 }}>Υπηρεσία</label>
        <select className="form-input" value={item.service_id} onChange={e => onChange(idx, 'service_id', e.target.value)} required style={{ padding: '6px 10px' }}>
          <option value="">Επίλεξε...</option>
          {services.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
        </select>
      </div>
      <div style={{ flex: 1 }}>
        <label style={{ fontSize: '0.75rem', color: '#64748b', display: 'block', marginBottom: 4 }}>Συνεδρίες</label>
        <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
          <button type="button" onClick={() => onChange(idx, 'sessions', '')} style={{
            padding: '4px 10px', borderRadius: 16, fontSize: '0.8rem', cursor: 'pointer',
            border: `1.5px solid ${item.sessions === '' ? '#64748b' : '#e2e8f0'}`,
            background: item.sessions === '' ? '#f1f5f9' : '#fff',
            color: item.sessions === '' ? '#475569' : '#64748b', fontWeight: item.sessions === '' ? 700 : 400,
          }}>∞</button>
          {[1,2,3,4,5,6,7,8,10,12].map(n => (
            <button key={n} type="button" onClick={() => onChange(idx, 'sessions', n)} style={{
              padding: '4px 10px', borderRadius: 16, fontSize: '0.8rem', cursor: 'pointer',
              border: `1.5px solid ${String(item.sessions) === String(n) ? '#76C043' : '#e2e8f0'}`,
              background: String(item.sessions) === String(n) ? '#f0fdf4' : '#fff',
              color: String(item.sessions) === String(n) ? '#76C043' : '#64748b',
              fontWeight: String(item.sessions) === String(n) ? 700 : 400,
            }}>{n}</button>
          ))}
          <input type="number" min="1" placeholder="Άλλο" value={item.sessions !== '' && Number(item.sessions) > 12 ? item.sessions : ''}
            onChange={e => onChange(idx, 'sessions', e.target.value)}
            style={{ width: 60, padding: '4px 6px', borderRadius: 16, border: '1.5px solid #e2e8f0', fontSize: '0.8rem', textAlign: 'center' }} />
        </div>
      </div>
      {canRemove && (
        <button type="button" onClick={() => onRemove(idx)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#ef4444', marginTop: 20 }}>
          <X size={18} />
        </button>
      )}
    </div>
  );
}

function PlanForm({ form, setForm, services, onSubmit, onCancel, submitLabel }) {
  const selectedService = services.find(s => s.id === form.service_id);
  const previewName = useMemo(() => {
    if (form.mode !== 'single' || !selectedService) return '';
    return buildPlanNamePreview(selectedService.name, form);
  }, [selectedService, form]);

  const updateItem = (idx, field, value) => {
    const items = [...form.service_items];
    items[idx] = { ...items[idx], [field]: value };
    setForm({ ...form, service_items: items });
  };
  const addItem = () => setForm({ ...form, service_items: [...form.service_items, { service_id: '', sessions: '', duration_mins: '' }] });
  const removeItem = (idx) => setForm({ ...form, service_items: form.service_items.filter((_, i) => i !== idx) });

  return (
    <form onSubmit={onSubmit}>
      {/* Mode toggle */}
      <div className="form-group">
        <label className="form-label">Τύπος πακέτου</label>
        <div style={{ display: 'flex', gap: 8 }}>
          {[{ v: 'single', label: 'Απλό (1 υπηρεσία)' }, { v: 'combo', label: 'Συνδυαστικό (πολλές υπηρεσίες)' }].map(opt => (
            <label key={opt.v} style={{
              display: 'flex', alignItems: 'center', gap: 6, padding: '6px 14px',
              borderRadius: 20, border: `1.5px solid ${form.mode === opt.v ? '#76C043' : '#e2e8f0'}`,
              background: form.mode === opt.v ? '#f0fdf4' : '#fff',
              cursor: 'pointer', fontSize: '0.85rem', fontWeight: form.mode === opt.v ? 600 : 400,
            }}>
              <input type="radio" name="mode" value={opt.v} checked={form.mode === opt.v}
                onChange={() => setForm(opt.v === 'single' ? { ...EMPTY_SINGLE } : { ...EMPTY_COMBO })}
                style={{ display: 'none' }} />
              {opt.label}
            </label>
          ))}
        </div>
      </div>

      {form.mode === 'single' ? (
        <>
          <div className="form-group">
            <label className="form-label">Υπηρεσία *</label>
            <select className="form-input" value={form.service_id} onChange={e => setForm({ ...form, service_id: e.target.value })} required autoFocus>
              <option value="">Επίλεξε υπηρεσία...</option>
              {services.map(s => <option key={s.id} value={s.id}>{s.name}{s.category ? ` (${s.category})` : ''}</option>)}
            </select>
          </div>
          {previewName && (
            <div className="form-group">
              <label className="form-label">Όνομα πακέτου (αυτόματα)</label>
              <div style={{ padding: '10px 14px', background: '#f8fafc', borderRadius: 8, border: '1px solid #e2e8f0', fontWeight: 600, color: '#334155' }}>{previewName}</div>
            </div>
          )}
          <div className="form-group">
            <label className="form-label">Συνεδρίες / μήνα</label>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
              <SessionChip label="Απεριόριστες" checked={form.sessions === ''} onClick={() => setForm({ ...form, sessions: '', duration_mins: '' })} unlimited />
              {[1,2,3,4,5,6,7,8,9,10,11,12].map(n => (
                <SessionChip key={n} label={String(n)} checked={String(form.sessions) === String(n)} onClick={() => setForm({ ...form, sessions: n })} />
              ))}
              <input type="number" min="13" placeholder="Άλλο"
                value={form.sessions !== '' && Number(form.sessions) > 12 ? form.sessions : ''}
                onChange={e => setForm({ ...form, sessions: e.target.value })}
                style={{ width: 72, padding: '5px 8px', borderRadius: 20, border: '1.5px solid #e2e8f0', fontSize: '0.85rem', textAlign: 'center' }} />
            </div>
          </div>
          {form.sessions !== '' && (
            <div className="form-group">
              <label className="form-label">Διάρκεια συνεδρίας (λεπτά)</label>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                <SessionChip label="Απεριόριστες" checked={form.duration_mins === ''} onClick={() => setForm({ ...form, duration_mins: '' })} unlimited />
                {[30,45,60,90,120].map(n => (
                  <SessionChip key={n} label={n < 60 ? `${n}′` : n === 60 ? '1ώρα' : n === 90 ? '1.5ώρα' : '2ώρες'}
                    checked={String(form.duration_mins) === String(n)} onClick={() => setForm({ ...form, duration_mins: n })} />
                ))}
                <input type="number" min="1" placeholder="Άλλο"
                  value={form.duration_mins !== '' && ![30,45,60,90,120].includes(Number(form.duration_mins)) ? form.duration_mins : ''}
                  onChange={e => setForm({ ...form, duration_mins: e.target.value })}
                  style={{ width: 72, padding: '5px 8px', borderRadius: 20, border: '1.5px solid #e2e8f0', fontSize: '0.85rem', textAlign: 'center' }} />
              </div>
            </div>
          )}
        </>
      ) : (
        <>
          <div className="form-group">
            <label className="form-label">Όνομα πακέτου *</label>
            <input className="form-input" type="text" value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} required placeholder="π.χ. Fitness + Pilates 4x" />
          </div>
          <div className="form-group">
            <label className="form-label">Υπηρεσίες πακέτου *</label>
            {form.service_items.map((item, idx) => (
              <ServiceItemRow key={idx} item={item} idx={idx} services={services}
                onChange={updateItem} onRemove={removeItem} canRemove={form.service_items.length > 1} />
            ))}
            <button type="button" onClick={addItem} style={{
              display: 'flex', alignItems: 'center', gap: 6, background: 'none', border: '1.5px dashed #76C043',
              borderRadius: 10, padding: '8px 14px', color: '#76C043', cursor: 'pointer', fontSize: '0.85rem', width: '100%', justifyContent: 'center',
            }}>
              <PlusCircle size={16} /> Προσθήκη υπηρεσίας
            </button>
          </div>
        </>
      )}

      <div className="form-grid-2">
        <div className="form-group">
          <label className="form-label">Τιμή (€) *</label>
          <input className="form-input" type="number" step="0.01" min="0" value={form.price_cents}
            onChange={e => setForm({ ...form, price_cents: e.target.value })} required placeholder="π.χ. 85.00" />
        </div>
      </div>
      <div className="form-group">
        <label className="form-label">Περίοδος χρέωσης</label>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {PERIODS.map(p => (
            <label key={p.v} style={{
              display: 'flex', alignItems: 'center', gap: 6, padding: '6px 14px',
              borderRadius: 20, border: `1.5px solid ${form.billing_period === p.v ? '#76C043' : '#e2e8f0'}`,
              background: form.billing_period === p.v ? '#f0fdf4' : '#fff',
              cursor: 'pointer', fontSize: '0.85rem', fontWeight: form.billing_period === p.v ? 600 : 400,
            }}>
              <input type="radio" name="billing_period" value={p.v} checked={form.billing_period === p.v}
                onChange={() => setForm({ ...form, billing_period: p.v })} style={{ display: 'none' }} />
              {p.label}
            </label>
          ))}
        </div>
      </div>
      <div className="modal-footer">
        <button type="button" className="btn btn-secondary" onClick={onCancel}>Ακύρωση</button>
        <button type="submit" className="btn btn-primary"
          disabled={form.mode === 'single' ? !form.service_id : (!form.name || form.service_items.some(i => !i.service_id))}>
          {submitLabel}
        </button>
      </div>
    </form>
  );
}

export default function Plans() {
  const [plans, setPlans] = useState([]);
  const [services, setServices] = useState([]);
  const [modal, setModal] = useState(false);
  const [form, setForm] = useState(EMPTY_SINGLE);
  const [editingId, setEditingId] = useState(null);

  const load = async () => {
    const [plansRes, servicesRes] = await Promise.all([
      api.get('/client-admin/plans'),
      api.get('/client-admin/services'),
    ]);
    setPlans(plansRes.data);
    setServices(servicesRes.data.filter(s => s.is_active));
  };

  useEffect(() => { load().catch(() => {}); }, []);

  const openCreate = () => { setForm(EMPTY_SINGLE); setEditingId(null); setModal('create'); };

  const openEdit = (plan) => {
    const isCombo = plan.service_items && plan.service_items.length > 0;
    if (isCombo) {
      setForm({
        mode: 'combo',
        name: plan.name,
        service_items: plan.service_items.map(i => ({ service_id: i.service_id, sessions: i.sessions ?? '', duration_mins: i.duration_mins ?? '' })),
        price_cents: (plan.price_cents / 100).toFixed(2),
        billing_period: plan.billing_period || 'monthly',
      });
    } else {
      setForm({
        mode: 'single',
        service_id: plan.service_id || '',
        sessions: plan.sessions == null || Number(plan.sessions) <= 0 ? '' : plan.sessions,
        duration_mins: plan.duration_mins ?? '',
        price_cents: (plan.price_cents / 100).toFixed(2),
        billing_period: plan.billing_period || 'monthly',
      });
    }
    setEditingId(plan.id);
    setModal('edit');
  };

  const closeModal = () => { setModal(false); setEditingId(null); setForm(EMPTY_SINGLE); };

  const payloadFromForm = () => {
    if (form.mode === 'combo') {
      return {
        name: form.name,
        service_items: form.service_items.map(i => ({
          service_id: i.service_id,
          sessions: i.sessions === '' ? null : Number(i.sessions),
          duration_mins: i.duration_mins === '' ? null : Number(i.duration_mins),
        })),
        price_cents: Math.round(Number(form.price_cents) * 100),
        billing_period: form.billing_period,
      };
    }
    let sessions = null;
    if (form.sessions !== '' && form.sessions != null) {
      const n = Number(form.sessions);
      if (Number.isFinite(n) && n > 0) sessions = n;
    }
    return {
      service_id: form.service_id,
      sessions,
      duration_mins: form.sessions === '' || form.duration_mins === '' ? null : Number(form.duration_mins),
      price_cents: Math.round(Number(form.price_cents) * 100),
      billing_period: form.billing_period,
    };
  };

  const handleCreate = async (e) => {
    e.preventDefault();
    try {
      await api.post('/client-admin/plans', payloadFromForm());
      toast.success('Πακέτο δημιουργήθηκε');
      closeModal(); load();
    } catch (err) { toast.error(err.response?.data?.error || 'Σφάλμα'); }
  };

  const handleEdit = async (e) => {
    e.preventDefault();
    try {
      await api.patch(`/client-admin/plans/${editingId}`, payloadFromForm());
      toast.success('Αποθηκεύτηκε');
      closeModal(); load();
    } catch (err) { toast.error(err.response?.data?.error || 'Σφάλμα'); }
  };

  const remove = async (id) => {
    if (!window.confirm('Διαγραφή πακέτου;')) return;
    await api.delete(`/client-admin/plans/${id}`);
    toast.success('Διαγράφηκε'); load();
  };

  const periodLabel = (v) => PERIODS.find(p => p.v === v)?.label || v;

  return (
    <Layout title="Πακέτα / Πλάνα">
      <div className="page-header">
        <h1 className="page-title">Πακέτα τιμολόγησης</h1>
        <button className="btn btn-primary" onClick={openCreate} disabled={!services.length}>
          <Plus size={16} /> Νέο πακέτο
        </button>
      </div>

      {!services.length && (
        <div className="card" style={{ marginBottom: 16, padding: 16, color: '#64748b' }}>
          Δημιούργησε πρώτα τουλάχιστον μία υπηρεσία για να ορίσεις πακέτα.
        </div>
      )}

      <div className="card">
        <table>
          <thead>
            <tr><th>Υπηρεσία</th><th>Πακέτο</th><th>Συνεδρίες</th><th>Διάρκεια</th><th>Τιμή</th><th>Περίοδος</th><th></th></tr>
          </thead>
          <tbody>
            {plans.map(p => {
              const isCombo = p.service_items && p.service_items.length > 0;
              return (
                <tr key={p.id}>
                  <td style={{ fontWeight: 600 }}>
                    {isCombo
                      ? p.service_items.map(i => i.service_name).join(' + ')
                      : (p.service_name || '—')}
                  </td>
                  <td>{p.name}</td>
                  <td>
                    {isCombo
                      ? p.service_items.map(i => i.sessions == null ? '∞' : i.sessions).join(' / ')
                      : (p.sessions == null || Number(p.sessions) <= 0 ? '∞' : p.sessions)}
                  </td>
                  <td>{p.sessions && p.duration_mins ? `${p.duration_mins}′` : '—'}</td>
                  <td>€{(p.price_cents / 100).toFixed(2)}</td>
                  <td>{periodLabel(p.billing_period)}</td>
                  <td style={{ display: 'flex', gap: 6 }}>
                    <button className="btn btn-secondary btn-sm" onClick={() => openEdit(p)}><Edit2 size={14} /></button>
                    <button className="btn btn-danger btn-sm" onClick={() => remove(p.id)}><Trash2 size={14} /></button>
                  </td>
                </tr>
              );
            })}
            {!plans.length && <tr><td colSpan={7} className="loading">Δεν υπάρχουν πακέτα</td></tr>}
          </tbody>
        </table>
      </div>

      {modal && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && closeModal()}>
          <div className="modal">
            <div className="modal-title">{modal === 'edit' ? 'Επεξεργασία πακέτου' : 'Νέο πακέτο'}</div>
            <PlanForm form={form} setForm={setForm} services={services}
              onSubmit={modal === 'edit' ? handleEdit : handleCreate}
              onCancel={closeModal}
              submitLabel={modal === 'edit' ? 'Αποθήκευση' : 'Δημιουργία'} />
          </div>
        </div>
      )}
    </Layout>
  );
}
