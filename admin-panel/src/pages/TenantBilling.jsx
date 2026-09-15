import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import {
  ArrowLeft, Save, Plus, Check, X, Euro,
  Users, CalendarDays, ShoppingCart, TrendingUp,
  FileText, AlertCircle, Clock,
} from 'lucide-react';

const fmt    = (n) => new Intl.NumberFormat('el-GR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(Number(n) || 0);
const fmtDate = (d) => d ? new Date(d).toLocaleDateString('el-GR') : '—';
const toInput = (d) => d ? new Date(d).toISOString().slice(0,10) : '';

const BILLING_MODELS = [
  { value:'monthly_fee',    label:'Μηνιαία Αμοιβή (Fixed)' },
  { value:'annual_fee',     label:'Ετήσια Αμοιβή' },
  { value:'per_booking',    label:'Ανά Κράτηση' },
  { value:'revenue_share',  label:'Revenue Share (%)' },
  { value:'custom',         label:'Custom / Συνδυασμός' },
];
const SUB_STATUSES = [
  { value:'trial',      label:'Trial',           color:'#d97706' },
  { value:'active',     label:'Ενεργό',           color:'#16a34a' },
  { value:'suspended',  label:'Ανασταλμένο',      color:'#dc2626' },
  { value:'cancelled',  label:'Ακυρωμένο',        color:'#64748b' },
];
const INV_STATUSES = [
  { value:'draft',     label:'Draft',         badge:'badge-gray' },
  { value:'pending',   label:'Εκκρεμεί',      badge:'badge-yellow' },
  { value:'paid',      label:'Πληρώθηκε',     badge:'badge-green' },
  { value:'overdue',   label:'Ληξιπρόθεσμο', badge:'badge-red' },
  { value:'cancelled', label:'Ακυρωμένο',     badge:'badge-gray' },
];

const EMPTY_INV = { amount:'', due_date:'', period_start:'', period_end:'', description:'', status:'pending' };

export default function TenantBilling() {
  const { id }   = useParams();
  const navigate = useNavigate();

  const [tenant, setTenant]     = useState(null);
  const [sub, setSub]           = useState(null);
  const [invoices, setInvoices] = useState([]);
  const [stats, setStats]       = useState(null);
  const [subForm, setSubForm]   = useState({});
  const [savingSub, setSavingSub] = useState(false);
  const [showNewInv, setShowNewInv] = useState(false);
  const [newInv, setNewInv]     = useState(EMPTY_INV);
  const [savingInv, setSavingInv] = useState(false);
  const [tab, setTab]           = useState('subscription');

  const loadAll = async () => {
    const [t, s, inv, st] = await Promise.allSettled([
      api.get(`/tenants/${id}`),
      api.get(`/tenants/${id}/subscription`),
      api.get(`/tenants/${id}/invoices`),
      api.get(`/tenants/${id}/stats`),
    ]);
    if (t.status === 'fulfilled') setTenant(t.value.data);
    if (s.status === 'fulfilled') {
      const data = s.value.data || {};
      setSub(data);
      setSubForm({
        billing_model: data.billing_model || 'monthly_fee',
        monthly_fee:   data.monthly_fee   || 0,
        annual_fee:    data.annual_fee    || 0,
        revenue_share_pct: data.revenue_share_pct || 0,
        per_booking_fee:   data.per_booking_fee   || 0,
        billing_cycle: data.billing_cycle || 'monthly',
        status:        data.status        || 'trial',
        setup_fee:     data.setup_fee     || 0,
        payment_method: data.payment_method || '',
        trial_ends_at:       toInput(data.trial_ends_at),
        current_period_start: toInput(data.current_period_start),
        current_period_end:   toInput(data.current_period_end),
        next_renewal_at:      toInput(data.next_renewal_at),
        contract_start: toInput(data.contract_start),
        contract_end:   toInput(data.contract_end),
        notes: data.notes || '',
      });
    }
    if (inv.status === 'fulfilled') setInvoices(inv.value.data || []);
    if (st.status === 'fulfilled')  setStats(st.value.data);
  };

  useEffect(() => { loadAll(); }, [id]);

  const saveSub = async () => {
    setSavingSub(true);
    try {
      await api.put(`/tenants/${id}/subscription`, subForm);
      toast.success('Αποθηκεύτηκε');
      await loadAll();
    } catch (e) { toast.error(e.response?.data?.error || 'Σφάλμα'); }
    finally { setSavingSub(false); }
  };

  const createInvoice = async (e) => {
    e.preventDefault();
    setSavingInv(true);
    try {
      await api.post(`/tenants/${id}/invoices`, newInv);
      toast.success('Τιμολόγιο δημιουργήθηκε');
      setShowNewInv(false);
      setNewInv(EMPTY_INV);
      await loadAll();
    } catch (e) { toast.error(e.response?.data?.error || 'Σφάλμα'); }
    finally { setSavingInv(false); }
  };

  const markPaid = async (invId) => {
    try {
      await api.patch(`/tenants/${id}/invoices/${invId}`, { status: 'paid' });
      toast.success('Σημειώθηκε ως πληρωμένο');
      setInvoices(i => i.map(x => x.id === invId ? { ...x, status:'paid', paid_at: new Date().toISOString() } : x));
    } catch (e) { toast.error('Σφάλμα'); }
  };

  const markOverdue = async (invId) => {
    try {
      await api.patch(`/tenants/${id}/invoices/${invId}`, { status: 'overdue' });
      setInvoices(i => i.map(x => x.id === invId ? { ...x, status:'overdue' } : x));
    } catch (e) { toast.error('Σφάλμα'); }
  };

  const sf = (k, v) => setSubForm(f => ({ ...f, [k]: v }));
  const model = subForm.billing_model;
  const subStatus = SUB_STATUSES.find(s => s.value === subForm.status);

  const totalPaid     = invoices.filter(i => i.status === 'paid').reduce((s, i) => s + Number(i.amount), 0);
  const totalPending  = invoices.filter(i => ['pending','overdue'].includes(i.status)).reduce((s, i) => s + Number(i.amount), 0);
  const totalOverdue  = invoices.filter(i => i.status === 'overdue').reduce((s, i) => s + Number(i.amount), 0);

  if (!tenant) return <Layout title="Billing"><div className="loading">Φόρτωση…</div></Layout>;

  return (
    <Layout title={`${tenant.name} — Billing`}>
      <div className="page-header">
        <div style={{ display:'flex', alignItems:'center', gap:10 }}>
          <button className="btn btn-secondary btn-sm" onClick={() => navigate(`/tenants/${id}`)}>
            <ArrowLeft size={14}/> {tenant.name}
          </button>
          <span style={{ fontWeight:700, color:'#1e293b' }}>Billing & Στατιστικά</span>
        </div>
      </div>

      {/* Tabs */}
      <div style={{ display:'flex', gap:4, borderBottom:'2px solid #e2e8f0', marginBottom:20 }}>
        {[
          { key:'subscription', label:'Μοντέλο Συνεργασίας' },
          { key:'invoices',     label:`Τιμολόγια (${invoices.length})` },
          { key:'stats',        label:'Στατιστικά Χρήσης' },
        ].map(t => (
          <button key={t.key} onClick={() => setTab(t.key)}
            style={{
              padding:'10px 18px', border:'none', background:'none', cursor:'pointer',
              fontWeight: tab === t.key ? 700 : 500,
              color: tab === t.key ? '#6366f1' : '#64748b',
              borderBottom: tab === t.key ? '2px solid #6366f1' : '2px solid transparent',
              marginBottom: -2, fontSize:'0.875rem',
            }}>
            {t.label}
          </button>
        ))}
      </div>

      {/* ── TAB: SUBSCRIPTION ── */}
      {tab === 'subscription' && (
        <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:16 }}>
          <div className="card">
            <div className="card-header">
              <span className="card-title">Μοντέλο & Αμοιβή</span>
              <span style={{ padding:'4px 12px', borderRadius:20, background: subStatus?.color + '20', color: subStatus?.color, fontSize:'0.8rem', fontWeight:700 }}>
                {subStatus?.label || 'Χωρίς'}
              </span>
            </div>

            <div className="form-group">
              <label className="form-label">Status Συνδρομής</label>
              <select className="form-select" value={subForm.status || ''} onChange={e => sf('status', e.target.value)}>
                {SUB_STATUSES.map(s => <option key={s.value} value={s.value}>{s.label}</option>)}
              </select>
            </div>

            <div className="form-group">
              <label className="form-label">Μοντέλο Τιμολόγησης</label>
              <select className="form-select" value={subForm.billing_model || ''} onChange={e => sf('billing_model', e.target.value)}>
                {BILLING_MODELS.map(m => <option key={m.value} value={m.value}>{m.label}</option>)}
              </select>
            </div>

            {(model === 'monthly_fee' || model === 'custom') && (
              <div className="form-group">
                <label className="form-label">Μηνιαία Αμοιβή (€)</label>
                <input className="form-input" type="number" step="0.01" min="0"
                  value={subForm.monthly_fee || ''} onChange={e => sf('monthly_fee', e.target.value)}/>
              </div>
            )}
            {(model === 'annual_fee' || model === 'custom') && (
              <div className="form-group">
                <label className="form-label">Ετήσια Αμοιβή (€)</label>
                <input className="form-input" type="number" step="0.01" min="0"
                  value={subForm.annual_fee || ''} onChange={e => sf('annual_fee', e.target.value)}/>
              </div>
            )}
            {(model === 'revenue_share' || model === 'custom') && (
              <div className="form-group">
                <label className="form-label">Revenue Share (%)</label>
                <input className="form-input" type="number" step="0.1" min="0" max="100"
                  value={subForm.revenue_share_pct || ''} onChange={e => sf('revenue_share_pct', e.target.value)}/>
              </div>
            )}
            {(model === 'per_booking' || model === 'custom') && (
              <div className="form-group">
                <label className="form-label">Αμοιβή ανά Κράτηση (€)</label>
                <input className="form-input" type="number" step="0.01" min="0"
                  value={subForm.per_booking_fee || ''} onChange={e => sf('per_booking_fee', e.target.value)}/>
              </div>
            )}

            <div className="form-group">
              <label className="form-label">Setup Fee (€)</label>
              <input className="form-input" type="number" step="0.01" min="0"
                value={subForm.setup_fee || ''} onChange={e => sf('setup_fee', e.target.value)}/>
            </div>
            <div className="form-group">
              <label className="form-label">Billing Cycle</label>
              <select className="form-select" value={subForm.billing_cycle || 'monthly'} onChange={e => sf('billing_cycle', e.target.value)}>
                <option value="monthly">Μηνιαίο</option>
                <option value="annual">Ετήσιο</option>
              </select>
            </div>
            <div className="form-group">
              <label className="form-label">Τρόπος Πληρωμής</label>
              <input className="form-input" placeholder="π.χ. Τραπεζική μεταφορά, Stripe, Μετρητά"
                value={subForm.payment_method || ''} onChange={e => sf('payment_method', e.target.value)}/>
            </div>
          </div>

          <div style={{ display:'flex', flexDirection:'column', gap:16 }}>
            <div className="card">
              <div className="card-header"><span className="card-title">Ημερομηνίες</span></div>
              {[
                { key:'trial_ends_at',         label:'Λήξη Trial' },
                { key:'contract_start',        label:'Έναρξη Σύμβασης' },
                { key:'contract_end',          label:'Λήξη Σύμβασης' },
                { key:'current_period_start',  label:'Τρέχουσα Περίοδος (Αρχή)' },
                { key:'current_period_end',    label:'Τρέχουσα Περίοδος (Τέλος)' },
                { key:'next_renewal_at',       label:'Επόμενη Ανανέωση' },
              ].map(({ key, label }) => (
                <div className="form-group" key={key}>
                  <label className="form-label">{label}</label>
                  <input className="form-input" type="date" value={subForm[key] || ''}
                    onChange={e => sf(key, e.target.value)}/>
                </div>
              ))}
            </div>

            <div className="card">
              <div className="card-header"><span className="card-title">Σημειώσεις</span></div>
              <textarea className="form-input" rows={4} placeholder="Ιδιαίτεροι όροι, εκπτώσεις, συμφωνίες…"
                value={subForm.notes || ''} onChange={e => sf('notes', e.target.value)}
                style={{ resize:'vertical' }}/>
            </div>
          </div>

          <div style={{ gridColumn:'1/-1', display:'flex', justifyContent:'flex-end' }}>
            <button className="btn btn-primary" onClick={saveSub} disabled={savingSub}>
              <Save size={14}/> {savingSub ? 'Αποθήκευση…' : 'Αποθήκευση Συνδρομής'}
            </button>
          </div>
        </div>
      )}

      {/* ── TAB: INVOICES ── */}
      {tab === 'invoices' && (
        <div>
          {/* Summary */}
          <div className="stats-grid" style={{ marginBottom:16 }}>
            {[
              { label:'Σύνολο Πληρωμένα', value:`€${fmt(totalPaid)}`,   color:'#16a34a' },
              { label:'Εκκρεμή',          value:`€${fmt(totalPending)}`, color:'#d97706' },
              { label:'Ληξιπρόθεσμα',     value:`€${fmt(totalOverdue)}`, color: totalOverdue > 0 ? '#dc2626' : '#64748b' },
            ].map(s => (
              <div className="stat-card" key={s.label}>
                <div className="stat-label">{s.label}</div>
                <div className="stat-value" style={{ color: s.color }}>{s.value}</div>
              </div>
            ))}
          </div>

          <div className="card">
            <div className="card-header">
              <span className="card-title">Τιμολόγια</span>
              <button className="btn btn-primary btn-sm" onClick={() => setShowNewInv(true)}>
                <Plus size={13}/> Νέο Τιμολόγιο
              </button>
            </div>

            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Αρ. Τιμολογίου</th>
                    <th>Περιγραφή</th>
                    <th>Περίοδος</th>
                    <th>Ποσό</th>
                    <th>Λήξη</th>
                    <th>Status</th>
                    <th>Πληρώθηκε</th>
                    <th>Ενέργειες</th>
                  </tr>
                </thead>
                <tbody>
                  {invoices.map(inv => {
                    const st = INV_STATUSES.find(s => s.value === inv.status) || INV_STATUSES[0];
                    return (
                      <tr key={inv.id}>
                        <td><code style={{ fontSize:'0.8rem' }}>{inv.invoice_number || '—'}</code></td>
                        <td style={{ maxWidth:180 }}>{inv.description || '—'}</td>
                        <td className="text-muted" style={{ fontSize:'0.8rem', whiteSpace:'nowrap' }}>
                          {inv.period_start ? `${fmtDate(inv.period_start)} – ${fmtDate(inv.period_end)}` : '—'}
                        </td>
                        <td style={{ fontWeight:700 }}>€{fmt(inv.amount)}</td>
                        <td style={{ color: inv.status === 'overdue' ? '#dc2626' : undefined, fontWeight: inv.status === 'overdue' ? 700 : undefined }}>
                          {fmtDate(inv.due_date)}
                        </td>
                        <td><span className={`badge ${st.badge}`}>{st.label}</span></td>
                        <td className="text-muted" style={{ fontSize:'0.8rem' }}>{inv.paid_at ? fmtDate(inv.paid_at) : '—'}</td>
                        <td>
                          <div style={{ display:'flex', gap:6 }}>
                            {inv.status === 'pending' && (
                              <button className="btn btn-primary btn-sm" onClick={() => markPaid(inv.id)}>
                                <Check size={12}/> Πληρώθηκε
                              </button>
                            )}
                            {inv.status === 'pending' && (
                              <button className="btn btn-danger btn-sm" onClick={() => markOverdue(inv.id)}>
                                <AlertCircle size={12}/>
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                  {!invoices.length && <tr><td colSpan={8} className="loading">Δεν υπάρχουν τιμολόγια</td></tr>}
                </tbody>
              </table>
            </div>
          </div>

          {/* New Invoice Modal */}
          {showNewInv && (
            <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setShowNewInv(false)}>
              <div className="modal">
                <div className="modal-title">Νέο Τιμολόγιο</div>
                <form onSubmit={createInvoice}>
                  <div className="form-group">
                    <label className="form-label">Περιγραφή</label>
                    <input className="form-input" value={newInv.description}
                      onChange={e => setNewInv(i => ({ ...i, description: e.target.value }))}
                      placeholder="π.χ. Μηνιαία αμοιβή Ιανουάριος 2025"/>
                  </div>
                  <div className="form-grid-2">
                    <div className="form-group">
                      <label className="form-label">Ποσό (€) *</label>
                      <input className="form-input" type="number" step="0.01" min="0.01" required
                        value={newInv.amount} onChange={e => setNewInv(i => ({ ...i, amount: e.target.value }))}/>
                    </div>
                    <div className="form-group">
                      <label className="form-label">Ημ/νία Λήξης *</label>
                      <input className="form-input" type="date" required
                        value={newInv.due_date} onChange={e => setNewInv(i => ({ ...i, due_date: e.target.value }))}/>
                    </div>
                  </div>
                  <div className="form-grid-2">
                    <div className="form-group">
                      <label className="form-label">Περίοδος Από</label>
                      <input className="form-input" type="date"
                        value={newInv.period_start} onChange={e => setNewInv(i => ({ ...i, period_start: e.target.value }))}/>
                    </div>
                    <div className="form-group">
                      <label className="form-label">Περίοδος Έως</label>
                      <input className="form-input" type="date"
                        value={newInv.period_end} onChange={e => setNewInv(i => ({ ...i, period_end: e.target.value }))}/>
                    </div>
                  </div>
                  <div className="form-group">
                    <label className="form-label">Status</label>
                    <select className="form-select" value={newInv.status} onChange={e => setNewInv(i => ({ ...i, status: e.target.value }))}>
                      {INV_STATUSES.filter(s => s.value !== 'overdue').map(s => <option key={s.value} value={s.value}>{s.label}</option>)}
                    </select>
                  </div>
                  <div className="modal-footer">
                    <button type="button" className="btn btn-secondary" onClick={() => setShowNewInv(false)}>Άκυρο</button>
                    <button type="submit" className="btn btn-primary" disabled={savingInv}>
                      {savingInv ? 'Δημιουργία…' : 'Δημιουργία'}
                    </button>
                  </div>
                </form>
              </div>
            </div>
          )}
        </div>
      )}

      {/* ── TAB: STATS ── */}
      {tab === 'stats' && (
        <div>
          {!stats ? (
            <div className="loading">Φόρτωση στατιστικών…</div>
          ) : (
            <>
              <div className="stats-grid" style={{ marginBottom:16 }}>
                {[
                  { icon:Users,        label:'Σύνολο Χρήστες',    value: stats.users,          color:'#6366f1' },
                  { icon:Users,        label:'Ενεργοί (30 μέρες)', value: stats.active_users_30d, color:'#16a34a' },
                  { icon:CalendarDays, label:'Κρατήσεις Σύνολο',  value: stats.bookings_total, color:'#0284c7' },
                  { icon:CalendarDays, label:'Κρατήσεις (30 μέρες)', value: stats.bookings_30d, color:'#7c3aed' },
                  { icon:Euro,         label:'Έσοδα (30 μέρες)',  value:`€${fmt(stats.revenue_30d)}`,   color:'#16a34a' },
                  { icon:Euro,         label:'Έσοδα Σύνολο',      value:`€${fmt(stats.revenue_total)}`, color:'#0284c7' },
                  { icon:ShoppingCart, label:'Marketplace Προϊόντα', value: stats.products,    color:'#d97706' },
                  { icon:ShoppingCart, label:'Παραγγελίες (30 μέρες)', value: stats.orders_30d, color:'#d97706' },
                  { icon:TrendingUp,   label:'Ενεργές Συνδρομές', value: stats.active_members, color:'#16a34a' },
                ].map(({ icon: Icon, label, value, color }) => (
                  <div className="stat-card" key={label} style={{ display:'flex', alignItems:'center', gap:12 }}>
                    <div style={{ width:38, height:38, borderRadius:10, background: color + '18', display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0 }}>
                      <Icon size={18} style={{ color }}/>
                    </div>
                    <div>
                      <div className="stat-label">{label}</div>
                      <div className="stat-value" style={{ color, fontSize:'1.4rem' }}>{value}</div>
                    </div>
                  </div>
                ))}
              </div>

              {/* Monthly bookings chart (simple bars) */}
              {stats.monthly_bookings?.length > 0 && (
                <div className="card">
                  <div className="card-header"><span className="card-title">Κρατήσεις ανά Μήνα (τελ. 6 μήνες)</span></div>
                  <div style={{ padding:'8px 0 4px' }}>
                    {(() => {
                      const max = Math.max(...stats.monthly_bookings.map(m => m.bookings), 1);
                      return stats.monthly_bookings.map(m => (
                        <div key={m.month} style={{ display:'flex', alignItems:'center', gap:10, marginBottom:8 }}>
                          <div style={{ width:65, fontSize:'0.78rem', color:'#64748b', textAlign:'right', flexShrink:0 }}>{m.month}</div>
                          <div style={{ flex:1, height:24, background:'#f1f5f9', borderRadius:4, overflow:'hidden' }}>
                            <div style={{
                              height:'100%', borderRadius:4,
                              width: `${(m.bookings / max) * 100}%`,
                              background:'linear-gradient(90deg,#6366f1,#818cf8)',
                              display:'flex', alignItems:'center', paddingLeft:8,
                              minWidth:30,
                            }}>
                              <span style={{ fontSize:'0.72rem', color:'#fff', fontWeight:700 }}>{m.bookings}</span>
                            </div>
                          </div>
                        </div>
                      ));
                    })()}
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      )}
    </Layout>
  );
}
