import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import {
  Receipt, Plus, Edit2, Trash2, X, Check, CheckCircle, Clock, RotateCcw, Settings, CalendarCheck,
} from 'lucide-react';

const now = new Date();
const MONTHS = [
  'Ιανουάριος','Φεβρουάριος','Μάρτιος','Απρίλιος','Μάιος','Ιούνιος',
  'Ιούλιος','Αύγουστος','Σεπτέμβριος','Οκτώβριος','Νοέμβριος','Δεκέμβριος',
];
const CATEGORIES = ['Ενοίκιο','Ρεύμα','Νερό','Τηλεφωνία','Ασφάλιση','Λογιστής','Marketing','Συντήρηση','Εξοπλισμός','Άλλο'];

// ─── Recurring template modal ────────────────────────────────
function RecurringModal({ item, onClose, onSave }) {
  const [form, setForm] = useState(item || {
    category: CATEGORIES[0], description: '', amount_cents: 0, due_day: 1, notes: '',
  });
  const [amountStr, setAmountStr] = useState(item ? (item.amount_cents / 100).toFixed(2) : '');
  const [saving, setSaving] = useState(false);

  const save = async () => {
    const amount_cents = Math.round(parseFloat(amountStr || '0') * 100);
    if (!form.description || !amount_cents) return toast.error('Συμπλήρωσε περιγραφή και ποσό');
    setSaving(true);
    try { await onSave({ ...form, amount_cents }); onClose(); }
    catch (e) { toast.error(e.response?.data?.error || 'Σφάλμα'); }
    finally { setSaving(false); }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={e => e.stopPropagation()}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
          <h2 className="modal-title" style={{ margin: 0 }}>{item ? 'Επεξεργασία πάγιου' : 'Νέο πάγιο έξοδο'}</h2>
          <button onClick={onClose} style={{ border: 'none', background: '#f1f5f9', borderRadius: 8, padding: 6, cursor: 'pointer', color: '#64748b', display: 'flex' }}>
            <X size={16} />
          </button>
        </div>

        <div className="form-grid-2">
          <div className="form-group">
            <label className="form-label">Κατηγορία</label>
            <select className="form-select" value={form.category}
              onChange={e => setForm({ ...form, category: e.target.value })}>
              {CATEGORIES.map(c => <option key={c}>{c}</option>)}
            </select>
          </div>
          <div className="form-group">
            <label className="form-label">Ημέρα πληρωμής (1-31)</label>
            <input type="number" min={1} max={31} className="form-input"
              value={form.due_day}
              onChange={e => setForm({ ...form, due_day: Number(e.target.value) })} />
          </div>
        </div>

        <div className="form-group">
          <label className="form-label">Περιγραφή</label>
          <input className="form-input" value={form.description}
            onChange={e => setForm({ ...form, description: e.target.value })}
            placeholder="π.χ. Ενοίκιο χώρου" />
        </div>

        <div className="form-group">
          <label className="form-label">Ποσό (€)</label>
          <input type="number" min={0} step={0.01} className="form-input" style={{ maxWidth: 160 }}
            value={amountStr}
            onChange={e => setAmountStr(e.target.value)} />
        </div>

        <div className="form-group">
          <label className="form-label">Σημειώσεις <span className="text-muted">(προαιρ.)</span></label>
          <input className="form-input" value={form.notes || ''}
            onChange={e => setForm({ ...form, notes: e.target.value })} />
        </div>

        <div className="modal-footer">
          <button className="btn btn-secondary" onClick={onClose}>Άκυρο</button>
          <button className="btn btn-primary" onClick={save} disabled={saving}>
            {saving ? 'Αποθήκευση…' : 'Αποθήκευση'}
          </button>
        </div>
      </div>
    </div>
  );
}

export default function Expenses() {
  const biz = JSON.parse(localStorage.getItem('gym_admin_business') || '{}');
  const bizId = biz.id;

  const [tab, setTab] = useState('monthly');
  const [year, setYear]   = useState(now.getFullYear());
  const [month, setMonth] = useState(now.getMonth() + 1);

  // Monthly view state
  const [recurring, setRecurring]   = useState([]);  // recurring + payment status
  const [oneOff, setOneOff]         = useState([]);   // one-time expenses this month
  const [loading, setLoading]       = useState(true);
  const [paying, setPaying]         = useState({});

  // New one-off form
  const [newExp, setNewExp] = useState({ category: CATEGORIES[0], description: '', amountStr: '' });
  const [addingOneOff, setAddingOneOff] = useState(false);

  // Recurring templates state
  const [templates, setTemplates]   = useState([]);
  const [tplLoading, setTplLoading] = useState(true);
  const [modal, setModal]           = useState(null); // null | 'new' | item

  // ── Load monthly view ──
  const loadMonthly = () => {
    setLoading(true);
    Promise.all([
      api.get(`/business/${bizId}/recurring-expenses/month`, { params: { year, month } }),
      api.get(`/business/${bizId}/expenses`, { params: { year, month } }),
    ]).then(([r1, r2]) => {
      setRecurring(r1.data.items || []);
      setOneOff(r2.data.expenses || []);
    }).catch(() => toast.error('Σφάλμα φόρτωσης'))
      .finally(() => setLoading(false));
  };
  useEffect(() => { if (tab === 'monthly') loadMonthly(); }, [year, month, tab]);

  // ── Load templates ──
  useEffect(() => {
    if (tab !== 'recurring') return;
    setTplLoading(true);
    api.get(`/business/${bizId}/recurring-expenses`)
      .then(r => setTemplates(r.data.recurring || []))
      .catch(() => toast.error('Σφάλμα φόρτωσης'))
      .finally(() => setTplLoading(false));
  }, [tab]);

  // ── Pay / unpay recurring ──
  const markPaid = async (item) => {
    setPaying(p => ({ ...p, [item.id]: true }));
    try {
      await api.post(`/business/${bizId}/recurring-expenses/${item.id}/pay`, { year, month });
      setRecurring(prev => prev.map(r => r.id === item.id
        ? { ...r, payment_id: 'paid', paid_at: new Date().toISOString() } : r));
    } catch (e) { toast.error(e.response?.data?.error || 'Σφάλμα'); }
    finally { setPaying(p => ({ ...p, [item.id]: false })); }
  };

  const undoPaid = async (item) => {
    setPaying(p => ({ ...p, [item.id]: true }));
    try {
      await api.delete(`/business/${bizId}/recurring-expenses/${item.id}/pay`, { params: { year, month } });
      setRecurring(prev => prev.map(r => r.id === item.id
        ? { ...r, payment_id: null, paid_at: null } : r));
    } catch (e) { toast.error(e.response?.data?.error || 'Σφάλμα'); }
    finally { setPaying(p => ({ ...p, [item.id]: false })); }
  };

  // ── One-off add/delete ──
  const addOneOff = async () => {
    const amount_cents = Math.round(parseFloat(newExp.amountStr || '0') * 100);
    if (!newExp.description || !amount_cents) return toast.error('Συμπλήρωσε περιγραφή και ποσό');
    setAddingOneOff(true);
    try {
      const r = await api.post(`/business/${bizId}/expenses`, { ...newExp, amount_cents, year, month });
      setOneOff(prev => [...prev, { ...newExp, amount_cents, id: r.data.id }]);
      setNewExp({ category: CATEGORIES[0], description: '', amountStr: '' });
    } catch (e) { toast.error(e.response?.data?.error || 'Σφάλμα'); }
    finally { setAddingOneOff(false); }
  };

  const deleteOneOff = async (id) => {
    if (!window.confirm('Διαγραφή;')) return;
    await api.delete(`/business/${bizId}/expenses/${id}`);
    setOneOff(prev => prev.filter(e => e.id !== id));
  };

  // ── Template CRUD ──
  const saveTpl = async (form) => {
    if (form.id) {
      await api.put(`/business/${bizId}/recurring-expenses/${form.id}`, { ...form, is_active: 1 });
      setTemplates(prev => prev.map(t => t.id === form.id ? { ...t, ...form } : t));
    } else {
      const r = await api.post(`/business/${bizId}/recurring-expenses`, form);
      setTemplates(prev => [...prev, { ...form, id: r.data.id, is_active: 1 }]);
    }
    toast.success('Αποθηκεύτηκε');
  };

  const toggleActive = async (tpl) => {
    await api.put(`/business/${bizId}/recurring-expenses/${tpl.id}`, { ...tpl, is_active: tpl.is_active ? 0 : 1 });
    setTemplates(prev => prev.map(t => t.id === tpl.id ? { ...t, is_active: t.is_active ? 0 : 1 } : t));
  };

  const deleteTpl = async (id) => {
    if (!window.confirm('Διαγραφή πάγιου; Θα χαθεί το ιστορικό πληρωμών.')) return;
    await api.delete(`/business/${bizId}/recurring-expenses/${id}`);
    setTemplates(prev => prev.filter(t => t.id !== id));
    toast.success('Διαγράφηκε');
  };

  // ── Totals ──
  const totalRecurring = recurring.reduce((s, r) => s + r.amount_cents, 0);
  const paidRecurring  = recurring.filter(r => r.payment_id).reduce((s, r) => s + r.amount_cents, 0);
  const pendingRecurring = totalRecurring - paidRecurring;
  const totalOneOff    = oneOff.reduce((s, e) => s + (e.amount_cents || 0), 0);
  const grandTotal     = totalRecurring + totalOneOff;

  const TABS = [
    { id: 'monthly',   label: 'Μηνιαία εκτέλεση', icon: CalendarCheck },
    { id: 'recurring', label: 'Πάγια έξοδα',       icon: Settings },
  ];

  return (
    <Layout>
      <div className="page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{
            width: 44, height: 44, borderRadius: 14,
            background: 'linear-gradient(135deg,#fef3c7,#fde68a)',
            display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#d97706',
          }}>
            <Receipt size={22} />
          </div>
          <div>
            <h1 className="page-title">Γενικά Έξοδα</h1>
            <div className="text-muted" style={{ marginTop: 2 }}>Πάγια και έκτακτα λειτουργικά έξοδα</div>
          </div>
        </div>
        {tab === 'monthly' && (
          <div style={{ display: 'flex', gap: 8 }}>
            <select className="form-select" value={month} onChange={e => setMonth(Number(e.target.value))}>
              {MONTHS.map((m, i) => <option key={i} value={i + 1}>{m}</option>)}
            </select>
            <select className="form-select" style={{ width: 90 }} value={year} onChange={e => setYear(Number(e.target.value))}>
              {[now.getFullYear(), now.getFullYear() - 1].map(y => <option key={y}>{y}</option>)}
            </select>
          </div>
        )}
        {tab === 'recurring' && (
          <button className="btn btn-primary" onClick={() => setModal('new')}>
            <Plus size={15} /> Νέο πάγιο
          </button>
        )}
      </div>

      {/* Tabs */}
      <div style={{ display: 'flex', gap: 4, borderBottom: '2px solid #e2e8f0', marginBottom: 20 }}>
        {TABS.map(t => (
          <button key={t.id} onClick={() => setTab(t.id)} style={{
            display: 'flex', alignItems: 'center', gap: 6, padding: '10px 18px',
            border: 'none', background: 'none', cursor: 'pointer',
            borderBottom: `2px solid ${tab === t.id ? 'var(--hs-primary)' : 'transparent'}`,
            marginBottom: -2,
            color: tab === t.id ? 'var(--hs-primary)' : '#64748b',
            fontWeight: tab === t.id ? 700 : 500, fontSize: '0.875rem',
          }}>
            <t.icon size={15} /> {t.label}
          </button>
        ))}
      </div>

      {/* ── MONTHLY TAB ── */}
      {tab === 'monthly' && (
        <>
          {/* KPI tiles */}
          <div style={{ display: 'flex', gap: 12, marginBottom: 20, flexWrap: 'wrap' }}>
            {[
              { label: 'Πάγια συνολικά', value: `€${(totalRecurring/100).toFixed(2)}`, color: '#d97706' },
              { label: 'Πάγια πληρωμένα', value: `€${(paidRecurring/100).toFixed(2)}`, color: '#16a34a' },
              { label: 'Πάγια εκκρεμή', value: `€${(pendingRecurring/100).toFixed(2)}`, color: pendingRecurring > 0 ? '#dc2626' : '#94a3b8' },
              { label: 'Έκτακτα', value: `€${(totalOneOff/100).toFixed(2)}`, color: '#64748b' },
              { label: 'Σύνολο μήνα', value: `€${(grandTotal/100).toFixed(2)}`, color: '#0f172a' },
            ].map(k => (
              <div key={k.label} className="card" style={{ flex: '1 1 130px', minWidth: 120, padding: '14px 18px' }}>
                <div className="text-muted" style={{ fontSize: '0.72rem', marginBottom: 3 }}>{k.label}</div>
                <div style={{ fontSize: '1.25rem', fontWeight: 800, color: k.color }}>{k.value}</div>
              </div>
            ))}
          </div>

          {loading ? <div className="loading">Φόρτωση…</div> : (
            <>
              {/* Recurring section */}
              {recurring.length > 0 && (
                <div className="card" style={{ padding: 0, overflow: 'hidden', marginBottom: 16 }}>
                  <div style={{ padding: '14px 20px', borderBottom: '1px solid #e2e8f0', fontWeight: 700, fontSize: '0.875rem', color: '#475569' }}>
                    Πάγια έξοδα
                  </div>
                  <div style={{ overflowX: 'auto' }}>
                    <table>
                      <thead>
                        <tr>
                          <th style={{ width: 50 }}>Ημέρα</th>
                          <th style={{ width: 140 }}>Κατηγορία</th>
                          <th>Περιγραφή</th>
                          <th style={{ width: 120 }}>Ποσό</th>
                          <th style={{ width: 130 }}>Κατάσταση</th>
                          <th style={{ width: 110 }}></th>
                        </tr>
                      </thead>
                      <tbody>
                        {recurring.map(r => (
                          <tr key={r.id} style={{ opacity: paying[r.id] ? 0.6 : 1 }}>
                            <td className="text-muted" style={{ fontWeight: 700 }}>{r.due_day}</td>
                            <td><span className="badge badge-blue">{r.category}</span></td>
                            <td>{r.description}</td>
                            <td><strong>€{(r.amount_cents / 100).toFixed(2)}</strong></td>
                            <td>
                              {r.payment_id ? (
                                <span className="badge badge-green" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                                  <CheckCircle size={11} /> Πληρώθηκε
                                </span>
                              ) : (
                                <span className="badge badge-yellow" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                                  <Clock size={11} /> Εκκρεμεί
                                </span>
                              )}
                            </td>
                            <td>
                              {r.payment_id ? (
                                <button className="btn btn-secondary btn-sm"
                                  onClick={() => undoPaid(r)} disabled={paying[r.id]} title="Αναίρεση">
                                  <RotateCcw size={13} />
                                </button>
                              ) : (
                                <button className="btn btn-primary btn-sm"
                                  onClick={() => markPaid(r)} disabled={paying[r.id]}>
                                  <Check size={13} /> Πληρώθηκε
                                </button>
                              )}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}

              {recurring.length === 0 && (
                <div style={{ padding: '12px 0', marginBottom: 16 }}>
                  <div className="text-muted" style={{ fontSize: '0.85rem' }}>
                    Δεν έχουν οριστεί πάγια έξοδα. <button className="btn btn-secondary btn-sm" onClick={() => setTab('recurring')}>Πρόσθεσε από εδώ</button>
                  </div>
                </div>
              )}

              {/* One-off section */}
              <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
                <div style={{ padding: '14px 20px', borderBottom: '1px solid #e2e8f0', fontWeight: 700, fontSize: '0.875rem', color: '#475569' }}>
                  Έκτακτα έξοδα
                </div>
                <div style={{ overflowX: 'auto' }}>
                  <table>
                    <thead>
                      <tr>
                        <th style={{ width: 150 }}>Κατηγορία</th>
                        <th>Περιγραφή</th>
                        <th style={{ width: 130 }}>Ποσό (€)</th>
                        <th style={{ width: 60 }}></th>
                      </tr>
                    </thead>
                    <tbody>
                      {oneOff.map(e => (
                        <tr key={e.id}>
                          <td><span className="badge badge-gray">{e.category}</span></td>
                          <td>{e.description}</td>
                          <td><strong>€{(e.amount_cents / 100).toFixed(2)}</strong></td>
                          <td>
                            <button className="btn btn-danger btn-sm" onClick={() => deleteOneOff(e.id)}>
                              <Trash2 size={13} />
                            </button>
                          </td>
                        </tr>
                      ))}
                      {/* Add row */}
                      <tr style={{ background: '#f8fafc' }}>
                        <td>
                          <select className="form-select" style={{ width: 130 }}
                            value={newExp.category} onChange={e => setNewExp({ ...newExp, category: e.target.value })}>
                            {CATEGORIES.map(c => <option key={c}>{c}</option>)}
                          </select>
                        </td>
                        <td>
                          <input className="form-input" placeholder="Περιγραφή…"
                            value={newExp.description}
                            onChange={e => setNewExp({ ...newExp, description: e.target.value })}
                            onKeyDown={e => e.key === 'Enter' && addOneOff()} />
                        </td>
                        <td>
                          <input type="number" min={0} step={0.01} className="form-input" style={{ width: 110 }}
                            placeholder="0.00"
                            value={newExp.amountStr}
                            onChange={e => setNewExp({ ...newExp, amountStr: e.target.value })} />
                        </td>
                        <td>
                          <button className="btn btn-primary btn-sm" onClick={addOneOff} disabled={addingOneOff}>
                            <Plus size={13} />
                          </button>
                        </td>
                      </tr>
                    </tbody>
                    {oneOff.length > 0 && (
                      <tfoot>
                        <tr style={{ background: '#f8fafc' }}>
                          <td colSpan={2}><strong>Σύνολο έκτακτα</strong></td>
                          <td><strong>€{(totalOneOff/100).toFixed(2)}</strong></td>
                          <td></td>
                        </tr>
                      </tfoot>
                    )}
                  </table>
                </div>
              </div>
            </>
          )}
        </>
      )}

      {/* ── RECURRING TEMPLATES TAB ── */}
      {tab === 'recurring' && (
        tplLoading ? <div className="loading">Φόρτωση…</div> : (
          <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
            {templates.length === 0 ? (
              <div className="bk-empty">
                <Receipt size={40} style={{ margin: '0 auto 12px', display: 'block', color: '#94a3b8' }} />
                <div style={{ fontWeight: 700, color: '#1e293b' }}>Δεν υπάρχουν πάγια έξοδα</div>
                <div style={{ marginTop: 12 }}>
                  <button className="btn btn-primary" onClick={() => setModal('new')}><Plus size={15} /> Νέο πάγιο</button>
                </div>
              </div>
            ) : (
              <div style={{ overflowX: 'auto' }}>
                <table>
                  <thead>
                    <tr>
                      <th style={{ width: 70 }}>Ημ. πλ.</th>
                      <th style={{ width: 140 }}>Κατηγορία</th>
                      <th>Περιγραφή</th>
                      <th style={{ width: 130 }}>Ποσό</th>
                      <th style={{ width: 100 }}>Κατάσταση</th>
                      <th style={{ width: 90 }}></th>
                    </tr>
                  </thead>
                  <tbody>
                    {templates.map(t => (
                      <tr key={t.id} style={{ opacity: t.is_active ? 1 : 0.5 }}>
                        <td style={{ fontWeight: 700 }}>{t.due_day}</td>
                        <td><span className="badge badge-blue">{t.category}</span></td>
                        <td>
                          <strong>{t.description}</strong>
                          {t.notes && <div className="text-muted" style={{ fontSize: '0.78rem' }}>{t.notes}</div>}
                        </td>
                        <td><strong>€{(t.amount_cents / 100).toFixed(2)}</strong></td>
                        <td>
                          <span className={`badge ${t.is_active ? 'badge-green' : 'badge-gray'}`}
                            style={{ cursor: 'pointer' }} onClick={() => toggleActive(t)}>
                            {t.is_active ? 'Ενεργό' : 'Ανενεργό'}
                          </span>
                        </td>
                        <td>
                          <div style={{ display: 'flex', gap: 4 }}>
                            <button className="btn btn-secondary btn-sm" onClick={() => setModal(t)}><Edit2 size={13} /></button>
                            <button className="btn btn-danger btn-sm" onClick={() => deleteTpl(t.id)}><Trash2 size={13} /></button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                  <tfoot>
                    <tr style={{ background: '#f8fafc' }}>
                      <td colSpan={3}><strong>Μηνιαίο σύνολο (ενεργά)</strong></td>
                      <td>
                        <strong>€{(templates.filter(t => t.is_active).reduce((s, t) => s + t.amount_cents, 0) / 100).toFixed(2)}</strong>
                      </td>
                      <td colSpan={2}></td>
                    </tr>
                  </tfoot>
                </table>
              </div>
            )}
          </div>
        )
      )}

      {modal && (
        <RecurringModal
          item={modal === 'new' ? null : modal}
          onClose={() => setModal(null)}
          onSave={saveTpl}
        />
      )}
    </Layout>
  );
}
