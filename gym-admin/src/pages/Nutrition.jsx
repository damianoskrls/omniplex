import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Save, ChevronLeft, ChevronRight, Bell, Plus, Trash2, Upload, X, Download, Calendar, ShoppingCart, BookCopy, History, Sparkles, Eye } from 'lucide-react';
import { TrendChart, VisitTimeline, BodyMeasurementsHero } from '../components/NutritionMeasurementCharts';

const BASE = 'http://localhost:3001';
const DAYS = ['Δευτέρα', 'Τρίτη', 'Τετάρτη', 'Πέμπτη', 'Παρασκευή', 'Σάββατο', 'Κυριακή'];
const DAY_SHORT = ['Δευ', 'Τρι', 'Τετ', 'Πεμ', 'Παρ', 'Σαβ', 'Κυρ'];
const MEALS = [
  { type: 'breakfast', label: 'Πρωινό' },
  { type: 'lunch', label: 'Μεσημεριανό' },
  { type: 'dinner', label: 'Βραδινό' },
  { type: 'snack', label: 'Σνακ' },
];
const UNITS = ['g', 'kg', 'ml', 'l', 'cup', 'κ.σ.', 'κ.γ.', 'τεμ', 'φέτες', 'scoops'];

function formatLocalDate(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function mondayOf(date = new Date()) {
  const d = new Date(date);
  const day = d.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  d.setDate(d.getDate() + diff);
  return formatLocalDate(d);
}

function addDays(iso, days) {
  const [y, m, dd] = iso.split('-').map(Number);
  const d = new Date(y, m - 1, dd);
  d.setDate(d.getDate() + days);
  return formatLocalDate(d);
}

function parseIso(iso) {
  const [y, m, d] = iso.split('-').map(Number);
  return new Date(y, m - 1, d);
}

function dayTitle(iso) {
  const d = parseIso(iso);
  const dow = d.getDay() === 0 ? 6 : d.getDay() - 1;
  return `${DAYS[dow]} ${d.getDate()}/${d.getMonth() + 1}/${d.getFullYear()}`;
}

function todayIso() {
  return formatLocalDate(new Date());
}

function emptyOption() {
  return { title: '', notes: '', portions: [{ ingredient: '', amount: '', unit: 'g' }], image_url: '', recipe_text: '' };
}

function emptySlotsMap() {
  const map = {};
  for (let day = 1; day <= 7; day += 1) {
    map[day] = {};
    for (const meal of MEALS) map[day][meal.type] = [];
  }
  return map;
}

function slotsFromApi(slots) {
  const map = emptySlotsMap();
  for (const slot of slots || []) {
    map[slot.day_of_week][slot.meal_type] = (slot.options || []).map(o => ({
      title: o.title || '',
      notes: o.notes || '',
      portions: o.portions?.length ? o.portions.map(p => ({ ...p, amount: p.amount ?? '' })) : [{ ingredient: '', amount: '', unit: 'g' }],
      image_url: o.image_url || '',
      recipe_text: o.recipe_text || '',
    }));
  }
  return map;
}

function slotsToPayload(slotMap) {
  const slots = [];
  for (let day = 1; day <= 7; day += 1) {
    for (const meal of MEALS) {
      const options = slotMap[day][meal.type];
      if (options?.length) slots.push({ day_of_week: day, meal_type: meal.type, options });
    }
  }
  return slots;
}

function ReadOnlyProgramTable({ slots }) {
  const slotMap = slotsFromApi(slots);
  return (
    <div style={{ overflowX: 'auto' }}>
      <table>
        <thead><tr><th>Γεύμα</th>{DAYS.map(d => <th key={d}>{d}</th>)}</tr></thead>
        <tbody>
          {MEALS.map(meal => (
            <tr key={meal.type}>
              <td style={{ fontWeight: 600 }}>{meal.label}</td>
              {DAYS.map((_, idx) => {
                const day = idx + 1;
                const opts = slotMap[day][meal.type];
                return (
                  <td key={day} style={{ verticalAlign: 'top', fontSize: '0.8rem', minWidth: 100 }}>
                    {!opts.length ? <span className="text-muted">—</span> : opts.map((o, i) => (
                      <div key={i} style={{ marginBottom: 8, padding: 6, background: '#f8fafc', borderRadius: 6 }}>
                        <strong>{o.title}</strong>
                        {o.notes && <div className="text-muted">{o.notes}</div>}
                        {(o.portions || []).filter(p => p.ingredient).map((p, j) => (
                          <div key={j} style={{ color: '#64748b' }}>• {p.ingredient}{p.amount ? `: ${p.amount} ${p.unit}` : ''}</div>
                        ))}
                      </div>
                    ))}
                  </td>
                );
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function PreviousProgramModal({ open, planId, clientId, onClose, onRestore }) {
  const [plan, setPlan] = useState(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!open || !planId || !clientId) return;
    setLoading(true);
    api.get(`/client-admin/nutrition/clients/${clientId}/meal-plan/versions/${planId}`)
      .then(res => setPlan(res.data))
      .catch(() => toast.error('Σφάλμα φόρτωσης'))
      .finally(() => setLoading(false));
  }, [open, planId, clientId]);

  if (!open) return null;

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal" style={{ maxWidth: 960, width: '96%', maxHeight: '90vh', overflow: 'auto' }}>
        <div className="modal-title" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span>Προηγούμενο πρόγραμμα {plan?.effective_from ? `(${plan.effective_from})` : ''}</span>
          <button type="button" className="btn btn-secondary btn-sm" onClick={onClose}><X size={14} /></button>
        </div>
        {loading ? <div className="loading">Φόρτωση...</div> : plan ? (
          <>
            {plan.notes && <p className="text-muted" style={{ fontSize: '0.85rem' }}>{plan.notes}</p>}
            <ReadOnlyProgramTable slots={plan.slots} />
            <div className="modal-footer" style={{ marginTop: 16 }}>
              <button type="button" className="btn btn-secondary" onClick={onClose}>Κλείσιμο</button>
              {onRestore && (
                <button type="button" className="btn btn-primary" onClick={() => onRestore(plan)}>
                  Φόρτωση στον επεξεργαστή
                </button>
              )}
            </div>
          </>
        ) : <div className="text-muted">Δεν βρέθηκε πρόγραμμα.</div>}
      </div>
    </div>
  );
}

function ShoppingListModal({ open, slots, onClose }) {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!open) return;
    setLoading(true);
    api.post('/client-admin/nutrition/shopping-list/smart', { slots })
      .then(res => setItems(res.data.items || []))
      .catch(() => toast.error('Σφάλμα λίστας'))
      .finally(() => setLoading(false));
  }, [open, slots]);

  if (!open) return null;

  const copyList = () => {
    const lines = items.map(i => {
      const need = i.needed_amount != null ? `${i.needed_amount} ${i.needed_unit}` : '—';
      const buy = i.buy_amount != null ? `${i.buy_amount} ${i.buy_unit}` : '—';
      return `• ${i.ingredient}: αγόρασε ${buy} (χρειάζεσαι ${need})`;
    });
    navigator.clipboard.writeText(`Λίστα αγορών\n\n${lines.join('\n')}`);
    toast.success('Αντιγράφηκε');
  };

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal" style={{ maxWidth: 720, width: '95%' }}>
        <div className="modal-title" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Sparkles size={18} /> Έξυπνη λίστα αγορών
        </div>
        <p className="text-muted" style={{ fontSize: '0.85rem' }}>
          Προτάσεις αγοράς σε πρακτικές συσκευασίες (π.χ. 450 ml γάλα → 1 λίτρο).
        </p>
        {loading ? <div className="loading">Υπολογισμός...</div> : !items.length ? (
          <div className="text-muted">Συμπλήρωσε μερίδες στο πρόγραμμα για αυτόματη λίστα.</div>
        ) : (
          <table>
            <thead>
              <tr><th>Υλικό</th><th>Χρειάζεσαι</th><th>Αγόρασε</th><th>Πρόταση</th></tr>
            </thead>
            <tbody>
              {items.map((item, i) => (
                <tr key={i}>
                  <td>{item.ingredient}</td>
                  <td>{item.needed_amount != null ? `${item.needed_amount} ${item.needed_unit}` : '—'}</td>
                  <td><strong>{item.buy_amount != null ? `${item.buy_amount} ${item.buy_unit}` : '—'}</strong></td>
                  <td style={{ fontSize: '0.8rem', color: '#64748b' }}>{item.suggestion || '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        <div className="modal-footer" style={{ marginTop: 16 }}>
          <button type="button" className="btn btn-secondary" onClick={onClose}>Κλείσιμο</button>
          {items.length > 0 && (
            <button type="button" className="btn btn-primary" onClick={copyList}>Αντιγραφή λίστας</button>
          )}
        </div>
      </div>
    </div>
  );
}

const TEMPLATE_META = {
  'tpl-seed-weight-loss': { badge: 'Έτοιμο', tone: 'loss', icon: '🔥' },
  'tpl-seed-muscle-gain': { badge: 'Έτοιμο', tone: 'muscle', icon: '💪' },
  'tpl-seed-mediterranean': { badge: 'Έτοιμο', tone: 'med', icon: '🫒' },
  'tpl-seed-vegetarian': { badge: 'Έτοιμο', tone: 'veg', icon: '🥗' },
};

function TemplatesModal({ open, onClose, onApply, clientId }) {
  const [templates, setTemplates] = useState([]);
  const [loading, setLoading] = useState(false);
  const [editing, setEditing] = useState(null);
  const [form, setForm] = useState({ name: '', notes: '' });

  const load = () => {
    setLoading(true);
    api.get('/client-admin/nutrition/templates')
      .then(res => setTemplates(res.data.templates || []))
      .catch(() => toast.error('Σφάλμα'))
      .finally(() => setLoading(false));
  };

  useEffect(() => { if (open) load(); }, [open]);

  const openEdit = async (id) => {
    const res = await api.get(`/client-admin/nutrition/templates/${id}`);
    setEditing(res.data);
    setForm({ name: res.data.name, notes: res.data.notes || '' });
  };

  const saveEdit = async () => {
    if (!editing) return;
    await api.put(`/client-admin/nutrition/templates/${editing.id}`, {
      name: form.name,
      notes: form.notes,
      slots: editing.slots,
    });
    toast.success('Αποθηκεύτηκε');
    setEditing(null);
    load();
  };

  const remove = async (id) => {
    if (!window.confirm('Διαγραφή προτύπου;')) return;
    await api.delete(`/client-admin/nutrition/templates/${id}`);
    toast.success('Διαγράφηκε');
    load();
  };

  if (!open) return null;

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal modal--wide" onClick={e => e.stopPropagation()}>
        <div className="modal-title" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <BookCopy size={18} /> Έτοιμα & αποθηκευμένα πρόγραμματα
        </div>
        <p className="text-muted" style={{ fontSize: '0.85rem', marginBottom: 16 }}>
          Επίλεξε έτοιμο πρόγραμμα για γρήγορη εισαγωγή στον πελάτη ή διαχειρίσου τα δικά σου πρότυπα.
        </p>
        {editing ? (
          <>
            <div className="form-group">
              <label className="form-label">Όνομα</label>
              <input className="form-input" value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} />
            </div>
            <div className="form-group">
              <label className="form-label">Σημειώσεις</label>
              <textarea className="form-input" rows={2} value={form.notes} onChange={e => setForm({ ...form, notes: e.target.value })} />
            </div>
            <p className="text-muted" style={{ fontSize: '0.85rem' }}>{editing.slots?.length || 0} γεύματα στο πρότυπο</p>
            <div className="modal-footer">
              <button type="button" className="btn btn-secondary" onClick={() => setEditing(null)}>Πίσω</button>
              <button type="button" className="btn btn-primary" onClick={saveEdit}>Αποθήκευση</button>
            </div>
          </>
        ) : (
          <>
            {loading ? <div className="loading">Φόρτωση...</div> : !templates.length ? (
              <div className="text-muted">Δεν υπάρχουν αποθηκευμένα πρόγραμματα. Αποθήκευσε το τρέχον ως πρότυπο.</div>
            ) : (
              <div className="template-grid">
                {templates.map(t => {
                  const meta = TEMPLATE_META[t.id];
                  return (
                    <div key={t.id} className={`template-card ${meta ? `template-card--${meta.tone}` : ''}`}>
                      <div className="template-card__top">
                        <div className="template-card__icon">{meta?.icon || '📋'}</div>
                        <div style={{ flex: 1, minWidth: 0 }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                            <strong>{t.name}</strong>
                            {meta && <span className="template-card__badge">{meta.badge}</span>}
                          </div>
                          {t.notes && <div className="template-card__notes">{t.notes}</div>}
                          <div className="template-card__meta">{t.item_count} γεύματα</div>
                        </div>
                      </div>
                      <div className="template-card__actions">
                        {clientId && (
                          <button type="button" className="btn btn-primary btn-sm" onClick={() => { onApply(t.id); onClose(); }}>
                            <Download size={12} /> Εισαγωγή
                          </button>
                        )}
                        <button type="button" className="btn btn-secondary btn-sm" onClick={() => openEdit(t.id)}>Επεξεργασία</button>
                        {!meta && (
                          <button type="button" className="btn btn-danger btn-sm" onClick={() => remove(t.id)}><Trash2 size={12} /></button>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
            <div className="modal-footer" style={{ marginTop: 16 }}>
              <button type="button" className="btn btn-secondary" onClick={onClose}>Κλείσιμο</button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

function MealSlotModal({ open, day, meal, options, onClose, onSave }) {
  const [local, setLocal] = useState([]);

  useEffect(() => {
    if (open) {
      setLocal(options?.length ? options.map(o => ({ ...o, portions: o.portions?.length ? o.portions : [{ ingredient: '', amount: '', unit: 'g' }] })) : [emptyOption()]);
    }
  }, [open, options]);

  if (!open) return null;

  const updateOption = (idx, patch) => {
    setLocal(prev => prev.map((o, i) => i === idx ? { ...o, ...patch } : o));
  };

  const updatePortion = (optIdx, portionIdx, patch) => {
    setLocal(prev => prev.map((o, i) => {
      if (i !== optIdx) return o;
      const portions = o.portions.map((p, j) => j === portionIdx ? { ...p, ...patch } : p);
      return { ...o, portions };
    }));
  };

  const uploadImage = async (idx, file) => {
    if (!file) return;
    const fd = new FormData();
    fd.append('image', file);
    try {
      const r = await api.post('/client-admin/nutrition/upload', fd, { headers: { 'Content-Type': 'multipart/form-data' } });
      updateOption(idx, { image_url: r.data.image_url });
      toast.success('Η εικόνα ανέβηκε');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα ανεβάσματος');
    }
  };

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal" style={{ maxWidth: 720, width: '95%' }}>
        <div className="modal-title">{DAYS[day - 1]} — {meal.label}</div>
        <p className="text-muted" style={{ fontSize: '0.85rem', marginBottom: 12 }}>
          Πρόσθεσε 2–3 επιλογές. Ο πελάτης διαλέγει μία. Συμπλήρωσε μερίδες για λίστα αγορών.
        </p>

        {local.map((opt, idx) => (
          <div key={idx} style={{ border: '1px solid #e2e8f0', borderRadius: 10, padding: 12, marginBottom: 12 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
              <strong>Επιλογή {idx + 1}</strong>
              {local.length > 1 && (
                <button type="button" className="btn btn-danger btn-sm" onClick={() => setLocal(prev => prev.filter((_, i) => i !== idx))}>
                  <Trash2 size={12} />
                </button>
              )}
            </div>
            <div className="form-group">
              <label className="form-label">Τίτλος *</label>
              <input className="form-input" value={opt.title} onChange={e => updateOption(idx, { title: e.target.value })} placeholder="π.χ. Μπάρα δημητριακών" />
            </div>
            <div className="form-group">
              <label className="form-label">Σχόλια / οδηγίες</label>
              <textarea className="form-input" rows={2} value={opt.notes} onChange={e => updateOption(idx, { notes: e.target.value })} placeholder="π.χ. Με 1 ποτήρι νερό πριν" />
            </div>
            <div className="form-group">
              <label className="form-label">Μερίδες / υλικά</label>
              {opt.portions.map((p, pIdx) => (
                <div key={pIdx} style={{ display: 'grid', gridTemplateColumns: '1fr 80px 90px 32px', gap: 6, marginBottom: 6 }}>
                  <input className="form-input" placeholder="Υλικό" value={p.ingredient} onChange={e => updatePortion(idx, pIdx, { ingredient: e.target.value })} />
                  <input className="form-input" type="number" placeholder="Ποσ." value={p.amount} onChange={e => updatePortion(idx, pIdx, { amount: e.target.value })} />
                  <select className="form-input" value={p.unit} onChange={e => updatePortion(idx, pIdx, { unit: e.target.value })}>
                    {UNITS.map(u => <option key={u} value={u}>{u}</option>)}
                  </select>
                  <button type="button" className="btn btn-secondary btn-sm" onClick={() => updateOption(idx, { portions: opt.portions.filter((_, j) => j !== pIdx) })}>×</button>
                </div>
              ))}
              <button type="button" className="btn btn-secondary btn-sm" onClick={() => updateOption(idx, { portions: [...opt.portions, { ingredient: '', amount: '', unit: 'g' }] })}>
                <Plus size={12} /> Υλικό
              </button>
            </div>
            <div className="form-group">
              <label className="form-label">Συνταγή (κείμενο)</label>
              <textarea className="form-input" rows={2} value={opt.recipe_text} onChange={e => updateOption(idx, { recipe_text: e.target.value })} />
            </div>
            <div className="form-group">
              <label className="form-label">Φωτογραφία / συνταγή</label>
              <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
                {opt.image_url ? (
                  <>
                    <img src={`${BASE}${opt.image_url}`} alt="" style={{ height: 56, borderRadius: 8 }} />
                    <button type="button" className="btn btn-secondary btn-sm" onClick={() => updateOption(idx, { image_url: '' })}><X size={12} /></button>
                  </>
                ) : (
                  <label className="btn btn-secondary btn-sm" style={{ cursor: 'pointer' }}>
                    <Upload size={12} /> Ανέβασμα
                    <input type="file" accept="image/*" style={{ display: 'none' }} onChange={e => uploadImage(idx, e.target.files?.[0])} />
                  </label>
                )}
              </div>
            </div>
          </div>
        ))}

        {local.length < 5 && (
          <button type="button" className="btn btn-secondary" onClick={() => setLocal(prev => [...prev, emptyOption()])}>
            <Plus size={14} /> Προσθήκη επιλογής
          </button>
        )}

        <div className="modal-footer" style={{ marginTop: 16 }}>
          <button type="button" className="btn btn-secondary" onClick={onClose}>Ακύρωση</button>
          <button type="button" className="btn btn-primary" onClick={() => onSave(local.filter(o => o.title.trim()))}>OK</button>
        </div>
      </div>
    </div>
  );
}

function MeasurementsPanel({ clientId }) {
  const [measurements, setMeasurements] = useState([]);
  const [progress, setProgress] = useState(null);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({
    measured_on: todayIso(),
    time_of_day: 'morning',
    measured_time: '',
    weight_kg: '',
    height_cm: '',
    body_fat_pct: '',
    muscle_mass_kg: '',
    fat_mass_kg: '',
    bone_mass_kg: '',
    bmi: '',
    visceral_fat_level: '',
    bmr_kcal: '',
    metabolic_age: '',
    notes: '',
  });

  const load = async (userId) => {
    const res = await api.get(`/client-admin/nutrition/clients/${userId}/measurements`);
    setMeasurements(res.data.measurements || []);
    setProgress(res.data.progress || null);
  };

  useEffect(() => {
    if (!clientId) return;
    setLoading(true);
    load(clientId).catch(() => toast.error('Σφάλμα φόρτωσης μετρήσεων')).finally(() => setLoading(false));
  }, [clientId]);

  const saveMeasurement = async () => {
    if (!clientId) return;
    setSaving(true);
    try {
      const res = await api.post(`/client-admin/nutrition/clients/${clientId}/measurements`, {
        ...form,
        time_of_day: form.measured_time ? undefined : (form.time_of_day || 'morning'),
        measured_time: form.measured_time || undefined,
      });
      setMeasurements(res.data.progress?.measurements || []);
      setProgress(res.data.progress || null);
      toast.success('Η μέτρηση καταχωρήθηκε');
      setForm(prev => ({ ...prev, weight_kg: '', body_fat_pct: '', muscle_mass_kg: '', fat_mass_kg: '', notes: '' }));
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };

  const chart = progress?.chart || {};
  const visits = progress?.visits || measurements;
  const prog = progress?.progress || {};

  return (
    <div className="card card--flush">
      <BodyMeasurementsHero
        latest={progress?.latest_measurement}
        goals={progress?.goals}
        progress={prog}
      />

      {!loading && (chart.weight?.length >= 2 || chart.body_fat_pct?.length >= 2) && (
        <div className="measurements-charts-grid">
          <div className="glass-inset">
            <TrendChart title="Βάρος (kg)" points={chart.weight} target={progress?.goals?.target_weight_kg} unit="kg" color="#818cf8" />
          </div>
          <div className="glass-inset">
            <TrendChart title="Λίπος %" points={chart.body_fat_pct} target={progress?.goals?.target_body_fat_pct} unit="%" color="#2dd4bf" />
          </div>
        </div>
      )}

      <div className="measurements-form-section">
        <div style={{ fontWeight: 600, marginBottom: 8 }}>Νέα μέτρηση (επίσκεψη)</div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(120px, 1fr))', gap: 8, marginBottom: 12 }}>
        <div className="form-group" style={{ margin: 0 }}>
          <label className="form-label">Ημερομηνία</label>
          <input className="form-input" type="date" value={form.measured_on} onChange={e => setForm({ ...form, measured_on: e.target.value })} />
        </div>
        <div className="form-group" style={{ margin: 0 }}>
          <label className="form-label">Στιγμή ημέρας</label>
          <select className="form-input" value={form.time_of_day} onChange={e => setForm({ ...form, time_of_day: e.target.value, measured_time: '' })}>
            <option value="morning">Πρωί</option>
            <option value="noon">Μεσημέρι</option>
            <option value="afternoon">Απόγευμα</option>
            <option value="evening">Βράδυ</option>
          </select>
        </div>
        <div className="form-group" style={{ margin: 0 }}>
          <label className="form-label">Ακριβής ώρα (προαιρ.)</label>
          <input className="form-input" type="time" value={form.measured_time} onChange={e => setForm({ ...form, measured_time: e.target.value, time_of_day: e.target.value ? '' : form.time_of_day })} />
        </div>
        <div className="form-group" style={{ margin: 0 }}>
          <label className="form-label">Βάρος (kg)</label>
          <input className="form-input" type="number" step="0.1" value={form.weight_kg} onChange={e => setForm({ ...form, weight_kg: e.target.value })} />
        </div>
        <div className="form-group" style={{ margin: 0 }}>
          <label className="form-label">Ύψος (cm)</label>
          <input className="form-input" type="number" step="0.1" value={form.height_cm} onChange={e => setForm({ ...form, height_cm: e.target.value })} />
        </div>
        <div className="form-group" style={{ margin: 0 }}>
          <label className="form-label">Λίπος %</label>
          <input className="form-input" type="number" step="0.1" value={form.body_fat_pct} onChange={e => setForm({ ...form, body_fat_pct: e.target.value })} />
        </div>
        <div className="form-group" style={{ margin: 0 }}>
          <label className="form-label">Μυϊκή μάζα</label>
          <input className="form-input" type="number" step="0.1" value={form.muscle_mass_kg} onChange={e => setForm({ ...form, muscle_mass_kg: e.target.value })} />
        </div>
        <div className="form-group" style={{ margin: 0 }}>
          <label className="form-label">Λιπώδης μάζα</label>
          <input className="form-input" type="number" step="0.1" value={form.fat_mass_kg} onChange={e => setForm({ ...form, fat_mass_kg: e.target.value })} />
        </div>
        <div className="form-group" style={{ margin: 0 }}>
          <label className="form-label">BMI</label>
          <input className="form-input" type="number" step="0.1" value={form.bmi} onChange={e => setForm({ ...form, bmi: e.target.value })} />
        </div>
        <div className="form-group" style={{ margin: 0 }}>
          <label className="form-label">Σπλαχνικό λίπος</label>
          <input className="form-input" type="number" value={form.visceral_fat_level} onChange={e => setForm({ ...form, visceral_fat_level: e.target.value })} />
        </div>
        </div>
        <div className="form-group">
          <label className="form-label">Σημειώσεις</label>
          <input className="form-input" value={form.notes} onChange={e => setForm({ ...form, notes: e.target.value })} placeholder="π.χ. Μετά από InBody" />
        </div>
        <button className="btn btn-primary btn-sm" type="button" onClick={saveMeasurement} disabled={saving}>
          {saving ? 'Αποθήκευση...' : 'Καταχώρηση μέτρησης'}
        </button>
      </div>

      {loading ? <div className="loading" style={{ marginTop: 12 }}>Φόρτωση...</div> : (
        <VisitTimeline visits={visits} />
      )}
    </div>
  );
}

function ClientGoalsPanel({ clientId }) {
  const [goals, setGoals] = useState({ target_weight_kg: '', target_body_fat_pct: '', height_cm: '' });
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!clientId) return;
    api.get(`/client-admin/nutrition/clients/${clientId}/goals`)
      .then(res => setGoals({
        target_weight_kg: res.data.target_weight_kg ?? '',
        target_body_fat_pct: res.data.target_body_fat_pct ?? '',
        height_cm: res.data.height_cm ?? '',
      }))
      .catch(() => {});
  }, [clientId]);

  const save = async () => {
    if (!clientId) return;
    setSaving(true);
    try {
      const res = await api.put(`/client-admin/nutrition/clients/${clientId}/goals`, goals);
      setGoals({
        target_weight_kg: res.data.target_weight_kg ?? '',
        target_body_fat_pct: res.data.target_body_fat_pct ?? '',
        height_cm: res.data.height_cm ?? '',
      });
      toast.success('Οι στόχοι αποθηκεύτηκαν');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="card">
      <h3 style={{ marginTop: 0 }}>Στόχοι ασκουμένου</h3>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: 10 }}>
        <div className="form-group" style={{ margin: 0 }}>
          <label className="form-label">Στόχος βάρους (kg)</label>
          <input className="form-input" type="number" step="0.1" value={goals.target_weight_kg}
            onChange={e => setGoals({ ...goals, target_weight_kg: e.target.value })} />
        </div>
        <div className="form-group" style={{ margin: 0 }}>
          <label className="form-label">Στόχος λίπους (%)</label>
          <input className="form-input" type="number" step="0.1" value={goals.target_body_fat_pct}
            onChange={e => setGoals({ ...goals, target_body_fat_pct: e.target.value })} />
        </div>
        <div className="form-group" style={{ margin: 0 }}>
          <label className="form-label">Ύψος (cm)</label>
          <input className="form-input" type="number" step="0.1" value={goals.height_cm}
            onChange={e => setGoals({ ...goals, height_cm: e.target.value })} />
        </div>
      </div>
      <button className="btn btn-primary btn-sm" type="button" onClick={save} disabled={saving} style={{ marginTop: 12 }}>
        {saving ? 'Αποθήκευση...' : 'Αποθήκευση στόχων'}
      </button>
    </div>
  );
}

function FoodDiaryPanel({ clientId, clientName }) {
  const [logDate, setLogDate] = useState(todayIso());
  const [calYear, setCalYear] = useState(new Date().getFullYear());
  const [calMonth, setCalMonth] = useState(new Date().getMonth() + 1);
  const [calendarDays, setCalendarDays] = useState([]);
  const [dayDetail, setDayDetail] = useState(null);
  const [loading, setLoading] = useState(false);

  const logCountByDate = useMemo(() => {
    const map = {};
    for (const d of calendarDays) map[d.date] = d.log_count;
    return map;
  }, [calendarDays]);

  const loadCalendar = async (userId, year, month) => {
    const res = await api.get(`/client-admin/nutrition/clients/${userId}/food-logs/calendar`, {
      params: { year, month },
    });
    setCalendarDays(res.data.days || []);
  };

  const loadDay = async (userId, date) => {
    const res = await api.get(`/client-admin/nutrition/clients/${userId}/day`, { params: { date } });
    setDayDetail(res.data);
  };

  useEffect(() => {
    if (!clientId) return;
    setLoading(true);
    Promise.all([loadCalendar(clientId, calYear, calMonth), loadDay(clientId, logDate)])
      .catch(() => toast.error('Σφάλμα φόρτωσης ημερολογίου'))
      .finally(() => setLoading(false));
  }, [clientId, calYear, calMonth, logDate]);

  const shiftDay = (delta) => {
    setLogDate(addDays(logDate, delta));
    const d = parseIso(addDays(logDate, delta));
    setCalYear(d.getFullYear());
    setCalMonth(d.getMonth() + 1);
  };

  const pickCalendarDay = (iso) => {
    setLogDate(iso);
    const d = parseIso(iso);
    setCalYear(d.getFullYear());
    setCalMonth(d.getMonth() + 1);
  };

  const shiftMonth = (delta) => {
    const d = new Date(calYear, calMonth - 1 + delta, 1);
    setCalYear(d.getFullYear());
    setCalMonth(d.getMonth() + 1);
  };

  const exportDay = async () => {
    try {
      const res = await api.get(`/client-admin/nutrition/clients/${clientId}/food-logs/export`, {
        params: { from: logDate, to: logDate },
        responseType: 'blob',
      });
      const url = window.URL.createObjectURL(new Blob([res.data]));
      const a = document.createElement('a');
      a.href = url;
      a.download = `food-logs-${clientName}-${logDate}.csv`;
      a.click();
      window.URL.revokeObjectURL(url);
      toast.success('Το export ολοκληρώθηκε');
    } catch {
      toast.error('Σφάλμα export');
    }
  };

  const exportMonth = async () => {
    const from = `${calYear}-${String(calMonth).padStart(2, '0')}-01`;
    const last = new Date(calYear, calMonth, 0).getDate();
    const to = `${calYear}-${String(calMonth).padStart(2, '0')}-${String(last).padStart(2, '0')}`;
    try {
      const res = await api.get(`/client-admin/nutrition/clients/${clientId}/food-logs/export`, {
        params: { from, to },
        responseType: 'blob',
      });
      const url = window.URL.createObjectURL(new Blob([res.data]));
      const a = document.createElement('a');
      a.href = url;
      a.download = `food-logs-${clientName}-${calYear}-${calMonth}.csv`;
      a.click();
      window.URL.revokeObjectURL(url);
      toast.success('Το export ολοκληρώθηκε');
    } catch {
      toast.error('Σφάλμα export');
    }
  };

  const monthLabel = new Date(calYear, calMonth - 1, 1).toLocaleDateString('el-GR', { month: 'long', year: 'numeric' });
  const firstOfMonth = new Date(calYear, calMonth - 1, 1);
  const startPad = (firstOfMonth.getDay() + 6) % 7;
  const daysInMonth = new Date(calYear, calMonth, 0).getDate();
  const cells = [];
  for (let i = 0; i < startPad; i += 1) cells.push(null);
  for (let d = 1; d <= daysInMonth; d += 1) {
    const iso = `${calYear}-${String(calMonth).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
    cells.push(iso);
  }

  return (
    <div className="card">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 10, marginBottom: 16 }}>
        <h3 style={{ margin: 0 }}>Ημερολόγιο διατροφής</h3>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <button type="button" className="btn btn-secondary btn-sm" onClick={exportDay}>
            <Download size={14} /> Export ημέρας
          </button>
          <button type="button" className="btn btn-secondary btn-sm" onClick={exportMonth}>
            <Download size={14} /> Export μήνα
          </button>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'minmax(220px, 280px) 1fr', gap: 20, alignItems: 'start' }}>
        <div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
            <button type="button" className="btn btn-secondary btn-sm" onClick={() => shiftMonth(-1)}><ChevronLeft size={14} /></button>
            <strong style={{ textTransform: 'capitalize', fontSize: '0.9rem' }}>{monthLabel}</strong>
            <button type="button" className="btn btn-secondary btn-sm" onClick={() => shiftMonth(1)}><ChevronRight size={14} /></button>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 4, fontSize: '0.7rem', color: '#64748b', marginBottom: 4 }}>
            {DAY_SHORT.map(d => <div key={d} style={{ textAlign: 'center' }}>{d}</div>)}
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 4 }}>
            {cells.map((iso, idx) => {
              if (!iso) return <div key={`pad-${idx}`} />;
              const d = parseIso(iso);
              const count = logCountByDate[iso] || 0;
              const selected = iso === logDate;
              const isToday = iso === todayIso();
              return (
                <button
                  key={iso}
                  type="button"
                  onClick={() => pickCalendarDay(iso)}
                  style={{
                    border: selected ? '2px solid #76C043' : isToday ? '1px solid #94a3b8' : '1px solid #e2e8f0',
                    borderRadius: 8,
                    padding: '6px 2px',
                    background: selected ? '#f0fdf4' : '#fff',
                    cursor: 'pointer',
                    fontSize: '0.8rem',
                  }}
                >
                  <div>{d.getDate()}</div>
                  {count > 0 && (
                    <div style={{ width: 6, height: 6, borderRadius: '50%', background: '#22c55e', margin: '2px auto 0' }} title={`${count} καταγραφές`} />
                  )}
                </button>
              );
            })}
          </div>
        </div>

        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12, flexWrap: 'wrap' }}>
            <button type="button" className="btn btn-secondary btn-sm" onClick={() => shiftDay(-1)}><ChevronLeft size={14} /></button>
            <div style={{ flex: 1, textAlign: 'center', fontWeight: 700 }}>
              {dayTitle(logDate)}
              {logDate === todayIso() && <span style={{ marginLeft: 8, fontSize: '0.75rem', color: '#76C043' }}>Σήμερα</span>}
            </div>
            <button type="button" className="btn btn-secondary btn-sm" onClick={() => shiftDay(1)}><ChevronRight size={14} /></button>
            <button type="button" className="btn btn-secondary btn-sm" onClick={() => pickCalendarDay(todayIso())}>
              <Calendar size={14} /> Σήμερα
            </button>
          </div>

          {loading ? <div className="loading">Φόρτωση...</div> : (
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
              <div>
                <div style={{ fontWeight: 600, marginBottom: 8 }}>Πρόγραμμα (τι έπρεπε να φάει)</div>
                {(dayDetail?.planned_slots || []).length === 0 ? (
                  <div className="text-muted" style={{ fontSize: '0.85rem' }}>Δεν υπάρχει πρόγραμμα για αυτή την ημέρα.</div>
                ) : (dayDetail?.planned_slots || []).map(slot => (
                  <div key={slot.meal_type} style={{ marginBottom: 14, padding: 10, background: '#f8fafc', borderRadius: 8 }}>
                    <div style={{ fontSize: '0.8rem', color: '#64748b', marginBottom: 4 }}>{slot.meal_type_label}</div>
                    {(slot.options || []).map((o, i) => (
                      <div key={i} style={{ marginTop: 6 }}>
                        <strong>{o.title}</strong>
                        {o.notes && <div className="text-muted" style={{ fontSize: '0.8rem' }}>{o.notes}</div>}
                        {(o.portions || []).map((p, j) => (
                          <div key={j} style={{ fontSize: '0.75rem', color: '#64748b' }}>• {p.ingredient}{p.amount != null ? `: ${p.amount} ${p.unit}` : ''}</div>
                        ))}
                        {o.image_url && <img src={`${BASE}${o.image_url}`} alt="" style={{ height: 48, marginTop: 4, borderRadius: 6 }} />}
                      </div>
                    ))}
                  </div>
                ))}
              </div>
              <div>
                <div style={{ fontWeight: 600, marginBottom: 8 }}>Καταγραφή (τι έφαγε)</div>
                {(dayDetail?.food_logs || []).length === 0 ? (
                  <div className="text-muted" style={{ fontSize: '0.85rem' }}>Δεν έχει καταγράψει γεύματα αυτή την ημέρα.</div>
                ) : (dayDetail?.food_logs || []).map(log => (
                  <div key={log.id} style={{ marginBottom: 12, padding: 10, background: '#f0fdf4', borderRadius: 8, border: '1px solid #bbf7d0' }}>
                    <div style={{ fontSize: '0.8rem', color: '#64748b' }}>{log.meal_type_label}</div>
                    <div style={{ marginTop: 4 }}>{log.description}</div>
                    {log.plan_option_id && <div style={{ fontSize: '0.75rem', color: '#16a34a', marginTop: 4 }}>✓ Από πρόγραμμα</div>}
                    {log.photo_url && <img src={`${BASE}${log.photo_url}`} alt="" style={{ height: 72, marginTop: 6, borderRadius: 6 }} />}
                    {log.logged_at && <div style={{ fontSize: '0.7rem', color: '#94a3b8', marginTop: 4 }}>{new Date(log.logged_at).toLocaleString('el-GR')}</div>}
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default function Nutrition() {
  const { id: selectedId } = useParams();
  const navigate = useNavigate();
  const [selectedClient, setSelectedClient] = useState(null);
  const [effectiveFrom, setEffectiveFrom] = useState(todayIso());
  const [planVersions, setPlanVersions] = useState([]);
  const [notes, setNotes] = useState('');
  const [slotMap, setSlotMap] = useState(emptySlotsMap);
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(true);
  const [editor, setEditor] = useState(null);
  const [notifyOpen, setNotifyOpen] = useState(false);
  const [notifyForm, setNotifyForm] = useState({ title: 'Υπενθύμιση διατροφής', body: '' });
  const [newVersionDate, setNewVersionDate] = useState('');
  const [shoppingOpen, setShoppingOpen] = useState(false);
  const [templatesOpen, setTemplatesOpen] = useState(false);
  const [previousPlanId, setPreviousPlanId] = useState(null);
  const [saveTemplateOpen, setSaveTemplateOpen] = useState(false);
  const [templateName, setTemplateName] = useState('');

  const loadClient = async (userId) => {
    const res = await api.get('/client-admin/nutrition/clients');
    const client = res.data.find(c => c.id === userId);
    if (!client) {
      toast.error('Ο πελάτης δεν έχει ενεργό πακέτο διατροφής');
      navigate('/nutrition/clients');
      return null;
    }
    setSelectedClient(client);
    return client;
  };

  const loadPlan = async (userId, refDate) => {
    const [planRes, versionsRes] = await Promise.all([
      api.get(`/client-admin/nutrition/clients/${userId}/meal-plan`, { params: { date: refDate } }),
      api.get(`/client-admin/nutrition/clients/${userId}/meal-plan/versions`),
    ]);
    setSlotMap(slotsFromApi(planRes.data.slots));
    setNotes(planRes.data.notes || '');
    setPlanVersions(versionsRes.data.versions || []);
    if (planRes.data.effective_from) setEffectiveFrom(planRes.data.effective_from);
  };

  useEffect(() => {
    if (!selectedId) {
      navigate('/nutrition/clients', { replace: true });
      return;
    }
    setLoading(true);
    loadClient(selectedId)
      .catch(() => toast.error('Σφάλμα φόρτωσης'))
      .finally(() => setLoading(false));
  }, [selectedId]);

  useEffect(() => {
    if (!selectedId) return;
    loadPlan(selectedId, effectiveFrom).catch(() => toast.error('Σφάλμα φόρτωσης'));
  }, [selectedId]);

  const savePlan = async () => {
    if (!selectedId) return;
    setSaving(true);
    try {
      const slots = slotsToPayload(slotMap);
      const res = await api.put(`/client-admin/nutrition/clients/${selectedId}/meal-plan`, {
        effective_from: effectiveFrom,
        notes,
        slots,
      });
      setSlotMap(slotsFromApi(res.data.slots));
      setEffectiveFrom(res.data.effective_from || effectiveFrom);
      const versionsRes = await api.get(`/client-admin/nutrition/clients/${selectedId}/meal-plan/versions`);
      setPlanVersions(versionsRes.data.versions || []);
      toast.success('Το πρόγραμμα αποθηκεύτηκε');
      setNewVersionDate('');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };

  const startNewVersion = () => {
    const date = newVersionDate || todayIso();
    setEffectiveFrom(date);
    toast.success(`Νέα έκδοση από ${date}. Αποθήκευσε για να ισχύσει.`);
  };

  const loadVersion = (date) => {
    setEffectiveFrom(date);
    loadPlan(selectedId, date).catch(() => toast.error('Σφάλμα φόρτωσης'));
  };

  const applyTemplate = async (templateId) => {
    if (!selectedId) return;
    try {
      const res = await api.post(`/client-admin/nutrition/clients/${selectedId}/meal-plan/apply-template`, {
        template_id: templateId,
        effective_from: effectiveFrom,
      });
      setSlotMap(slotsFromApi(res.data.slots));
      setNotes(res.data.notes || '');
      setEffectiveFrom(res.data.effective_from || effectiveFrom);
      const versionsRes = await api.get(`/client-admin/nutrition/clients/${selectedId}/meal-plan/versions`);
      setPlanVersions(versionsRes.data.versions || []);
      toast.success('Το πρόγραμμα εφαρμόστηκε στον πελάτη');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const saveAsTemplate = async () => {
    if (!templateName.trim()) {
      toast.error('Δώσε όνομα στο πρότυπο');
      return;
    }
    try {
      await api.post('/client-admin/nutrition/templates', {
        name: templateName.trim(),
        notes,
        slots: slotsToPayload(slotMap),
      });
      toast.success('Το πρότυπο αποθηκεύτηκε');
      setSaveTemplateOpen(false);
      setTemplateName('');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const restorePreviousPlan = (plan) => {
    setSlotMap(slotsFromApi(plan.slots));
    setNotes(plan.notes || '');
    setEffectiveFrom(plan.effective_from || effectiveFrom);
    setPreviousPlanId(null);
    toast.success('Φορτώθηκε στον επεξεργαστή — αποθήκευσε αν θέλεις να το εφαρμόσεις');
  };

  const currentSlots = useMemo(() => slotsToPayload(slotMap), [slotMap]);

  const sendNotify = async () => {
    if (!selectedId || !notifyForm.body.trim()) return;
    try {
      await api.post('/client-admin/nutrition/notify', {
        user_ids: [selectedId],
        title: notifyForm.title,
        body: notifyForm.body,
      });
      toast.success('Η ειδοποίηση στάλθηκε');
      setNotifyOpen(false);
      setNotifyForm({ title: 'Υπενθύμιση διατροφής', body: '' });
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  if (loading) return <Layout title="Διατροφή πελάτη" variant="nutrition"><div className="loading">Φόρτωση...</div></Layout>;

  return (
    <Layout title="Διατροφή πελάτη" variant="nutrition">
      <div style={{ marginBottom: 12 }}>
        <button type="button" className="btn btn-secondary btn-sm" onClick={() => navigate('/nutrition/clients')}>
          <ChevronLeft size={14} /> Πίσω στους πελάτες
        </button>
      </div>

      <div className="nutrition-main nutrition-main--full">
          {!selectedClient ? <div className="card loading">Ο πελάτης δεν βρέθηκε</div> : (
            <>
              <div className="card nutrition-hero-card">
                <div>
                  <h2 className="nutrition-hero-card__title">{selectedClient.full_name}</h2>
                  <div className="text-muted">{selectedClient.email}</div>
                </div>
                <button className="btn btn-secondary" type="button" onClick={() => setNotifyOpen(true)}>
                  <Bell size={14} /> Ειδοποίηση
                </button>
              </div>

              <FoodDiaryPanel clientId={selectedId} clientName={selectedClient.full_name} />

              <ClientGoalsPanel clientId={selectedId} />
              <MeasurementsPanel clientId={selectedId} />

              <div className="card program-editor-card">
                <div className="program-editor-card__head">
                  <div>
                    <h3 style={{ margin: 0 }}>Επαναλαμβανόμενο εβδομαδιαίο πρόγραμμα</h3>
                    <p className="text-muted" style={{ fontSize: '0.85rem', margin: '6px 0 0' }}>
                      Το πρόγραμμα επαναλαμβάνεται κάθε εβδομάδα. Ισχύει από την ημερομηνία που ορίζεις μέχρι νέα έκδοση.
                    </p>
                  </div>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 8, alignItems: 'flex-end' }}>
                    <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                      <label className="form-label" style={{ margin: 0 }}>Ισχύει από</label>
                      <input className="form-input" type="date" value={effectiveFrom} onChange={e => setEffectiveFrom(e.target.value)} style={{ width: 150 }} />
                    </div>
                    <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                      <input className="form-input" type="date" value={newVersionDate} onChange={e => setNewVersionDate(e.target.value)} style={{ width: 150 }} placeholder="Νέα έκδοση" />
                      <button className="btn btn-secondary btn-sm" type="button" onClick={startNewVersion}>Νέα έκδοση</button>
                    </div>
                  </div>
                </div>
                {planVersions.length > 0 && (
                  <div style={{ marginBottom: 12 }}>
                    <div style={{ fontWeight: 600, fontSize: '0.85rem', marginBottom: 6, display: 'flex', alignItems: 'center', gap: 6 }}>
                      <History size={14} /> Ιστορικό προγραμμάτων
                    </div>
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                      {planVersions.map(v => (
                        <div key={v.id} style={{ display: 'flex', gap: 4, alignItems: 'center' }}>
                          <button
                            type="button"
                            className={`btn btn-sm ${v.is_current ? 'btn-primary' : 'btn-secondary'}`}
                            onClick={() => loadVersion(v.effective_from)}
                          >
                            {v.effective_from}{v.is_current ? ' (τρέχον)' : ''}
                          </button>
                          <button type="button" className="btn btn-secondary btn-sm" title="Προβολή" onClick={() => setPreviousPlanId(v.id)}>
                            <Eye size={12} />
                          </button>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
                <div className="program-toolbar">
                  <button type="button" className="btn btn-primary btn-sm" onClick={() => setTemplatesOpen(true)}>
                    <BookCopy size={14} /> Εισαγωγή ετοίμου
                  </button>
                  <button type="button" className="btn btn-secondary btn-sm" onClick={() => setSaveTemplateOpen(true)}>
                    <Save size={14} /> Αποθήκευση ως πρότυπο
                  </button>
                  <button type="button" className="btn btn-secondary btn-sm" onClick={() => setShoppingOpen(true)}>
                    <ShoppingCart size={14} /> Λίστα αγορών
                  </button>
                </div>
                <p className="text-muted" style={{ fontSize: '0.85rem' }}>Κλικ σε κελί για επιλογές γεύματος (2–3 εναλλακτικές).</p>
                <textarea className="form-input" rows={2} value={notes} onChange={e => setNotes(e.target.value)} placeholder="Γενικές σημειώσεις εβδομάδας" style={{ marginBottom: 12 }} />
                <div style={{ overflowX: 'auto' }}>
                  <table>
                    <thead><tr><th>Γεύμα</th>{DAYS.map(d => <th key={d}>{d}</th>)}</tr></thead>
                    <tbody>
                      {MEALS.map(meal => (
                        <tr key={meal.type}>
                          <td style={{ fontWeight: 600 }}>{meal.label}</td>
                          {DAYS.map((_, idx) => {
                            const day = idx + 1;
                            const opts = slotMap[day][meal.type];
                            return (
                              <td key={day}>
                                <button type="button" className="btn btn-secondary btn-sm" style={{ width: '100%', minHeight: 52 }}
                                  onClick={() => setEditor({ day, meal, options: opts })}>
                                  {opts.length ? `${opts.length} επιλογή/ές` : '+ Προσθήκη'}
                                </button>
                              </td>
                            );
                          })}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                <button className="btn btn-primary" type="button" onClick={savePlan} disabled={saving} style={{ marginTop: 16 }}>
                  <Save size={14} /> {saving ? 'Αποθήκευση...' : 'Αποθήκευση'}
                </button>
              </div>
            </>
          )}
      </div>

      <div style={{ marginTop: 12 }}>
        <button type="button" className="btn btn-secondary btn-sm" onClick={() => setTemplatesOpen(true)}>
          <BookCopy size={14} /> Έτοιμα προγράμματα
        </button>
      </div>

      <TemplatesModal
        open={templatesOpen}
        onClose={() => setTemplatesOpen(false)}
        onApply={applyTemplate}
        clientId={selectedId}
      />

      <ShoppingListModal
        open={shoppingOpen}
        slots={currentSlots}
        onClose={() => setShoppingOpen(false)}
      />

      <PreviousProgramModal
        open={!!previousPlanId}
        planId={previousPlanId}
        clientId={selectedId}
        onClose={() => setPreviousPlanId(null)}
        onRestore={restorePreviousPlan}
      />

      {saveTemplateOpen && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setSaveTemplateOpen(false)}>
          <div className="modal">
            <div className="modal-title">Αποθήκευση ως πρότυπο</div>
            <div className="form-group">
              <label className="form-label">Όνομα προτύπου</label>
              <input className="form-input" value={templateName} onChange={e => setTemplateName(e.target.value)} placeholder="π.χ. Πρόγραμμα αδυνατίσματος" />
            </div>
            <div className="modal-footer">
              <button type="button" className="btn btn-secondary" onClick={() => setSaveTemplateOpen(false)}>Ακύρωση</button>
              <button type="button" className="btn btn-primary" onClick={saveAsTemplate}>Αποθήκευση</button>
            </div>
          </div>
        </div>
      )}

      <MealSlotModal
        open={!!editor}
        day={editor?.day}
        meal={editor?.meal}
        options={editor?.options}
        onClose={() => setEditor(null)}
        onSave={(options) => {
          setSlotMap(prev => ({ ...prev, [editor.day]: { ...prev[editor.day], [editor.meal.type]: options } }));
          setEditor(null);
        }}
      />

      {notifyOpen && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setNotifyOpen(false)}>
          <div className="modal">
            <div className="modal-title">Ειδοποίηση πελάτη</div>
            <div className="form-group">
              <label className="form-label">Τίτλος</label>
              <input className="form-input" value={notifyForm.title} onChange={e => setNotifyForm({ ...notifyForm, title: e.target.value })} />
            </div>
            <div className="form-group">
              <label className="form-label">Μήνυμα</label>
              <textarea className="form-input" rows={3} value={notifyForm.body} onChange={e => setNotifyForm({ ...notifyForm, body: e.target.value })} />
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setNotifyOpen(false)}>Ακύρωση</button>
              <button className="btn btn-primary" onClick={sendNotify}>Αποστολή</button>
            </div>
          </div>
        </div>
      )}
    </Layout>
  );
}
