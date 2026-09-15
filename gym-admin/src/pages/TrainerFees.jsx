import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { UserCog, Save, CheckCircle, Clock, RotateCcw, Settings, BarChart2 } from 'lucide-react';

const now = new Date();
const MONTHS = [
  'Ιανουάριος','Φεβρουάριος','Μάρτιος','Απρίλιος','Μάιος','Ιούνιος',
  'Ιούλιος','Αύγουστος','Σεπτέμβριος','Οκτώβριος','Νοέμβριος','Δεκέμβριος',
];

export default function TrainerFees() {
  const biz = JSON.parse(localStorage.getItem('gym_admin_business') || '{}');
  const bizId = biz.id;

  const [tab, setTab] = useState('payroll');   // 'payroll' | 'settings'
  const [year, setYear]   = useState(now.getFullYear());
  const [month, setMonth] = useState(now.getMonth() + 1);

  // Payroll state
  const [staff, setStaff]       = useState([]);
  const [loading, setLoading]   = useState(true);
  const [paying, setPaying]     = useState({});
  const [payNotes, setPayNotes] = useState({});

  // Settings state
  const [fees, setFees]         = useState([]);
  const [feeLoading, setFeeLoading] = useState(true);
  const [saving, setSaving]     = useState({});

  // --- Payroll load ---
  const loadPayroll = () => {
    setLoading(true);
    api.get(`/business/${bizId}/salary-payments`, { params: { year, month } })
      .then(r => setStaff(r.data.staff || []))
      .catch(() => toast.error('Σφάλμα φόρτωσης'))
      .finally(() => setLoading(false));
  };
  useEffect(() => { if (tab === 'payroll') loadPayroll(); }, [year, month, tab]);

  // --- Settings load ---
  useEffect(() => {
    if (tab !== 'settings') return;
    setFeeLoading(true);
    api.get(`/business/${bizId}/trainer-fees`)
      .then(r => setFees(r.data.fees || []))
      .catch(() => toast.error('Σφάλμα φόρτωσης'))
      .finally(() => setFeeLoading(false));
  }, [tab]);

  const updateFee = (staffId, field, value) =>
    setFees(fees.map(f => f.staff_id === staffId ? { ...f, [field]: value } : f));

  const saveFee = async (staffId) => {
    const fee = fees.find(f => f.staff_id === staffId);
    setSaving(s => ({ ...s, [staffId]: true }));
    try {
      await api.put(`/business/${bizId}/trainer-fees/${staffId}`, {
        monthly_gross: fee.monthly_gross == null || fee.monthly_gross === '' ? null : parseFloat(fee.monthly_gross),
        monthly_net:   fee.monthly_net   == null || fee.monthly_net   === '' ? null : parseFloat(fee.monthly_net),
        fee_per_class: fee.fee_per_class  == null || fee.fee_per_class  === '' ? null : parseFloat(fee.fee_per_class),
        notes: fee.notes || null,
      });
      toast.success('Αποθηκεύτηκε');
    } catch { toast.error('Σφάλμα'); }
    finally { setSaving(s => ({ ...s, [staffId]: false })); }
  };

  const markPaid = async (s) => {
    const amountEur = Number(s.monthly_net ?? s.monthly_gross ?? 0);
    const amountCents = Math.round(amountEur * 100);
    if (!amountCents) return toast.error('Δεν έχει οριστεί αμοιβή για αυτόν τον εκπαιδευτή');
    setPaying(p => ({ ...p, [s.staff_id]: true }));
    try {
      await api.post(`/business/${bizId}/salary-payments`, {
        staff_id: s.staff_id, year, month,
        amount_cents: amountCents,
        notes: payNotes[s.staff_id] || null,
      });
      toast.success(`${s.full_name} — πληρώθηκε €${amountEur.toFixed(2)}`);
      loadPayroll();
    } catch (e) { toast.error(e.response?.data?.error || 'Σφάλμα'); }
    finally { setPaying(p => ({ ...p, [s.staff_id]: false })); }
  };

  const undoPaid = async (s) => {
    if (!window.confirm('Αναίρεση πληρωμής;')) return;
    setPaying(p => ({ ...p, [s.staff_id]: true }));
    try {
      await api.delete(`/business/${bizId}/salary-payments/${s.payment_id}`);
      toast.success('Αναιρέθηκε');
      loadPayroll();
    } catch { toast.error('Σφάλμα'); }
    finally { setPaying(p => ({ ...p, [s.staff_id]: false })); }
  };

  const totalOwed = staff.reduce((s, r) => s + Number(r.monthly_net ?? r.monthly_gross ?? 0), 0);
  const totalPaid = staff.reduce((s, r) => s + (r.paid_amount_cents ? r.paid_amount_cents / 100 : 0), 0);
  const totalPending = totalOwed - totalPaid;

  const TABS = [
    { id: 'payroll', label: 'Μισθοδοσία', icon: BarChart2 },
    { id: 'settings', label: 'Ρυθμίσεις αμοιβών', icon: Settings },
  ];

  return (
    <Layout>
      <div className="page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{
            width: 44, height: 44, borderRadius: 14,
            background: 'linear-gradient(135deg,#eef2ff,#e0e7ff)',
            display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#4338ca',
          }}>
            <UserCog size={22} />
          </div>
          <div>
            <h1 className="page-title">Αμοιβές Εκπαιδευτών</h1>
            <div className="text-muted" style={{ marginTop: 2 }}>Μισθοδοσία και ρύθμιση αμοιβών</div>
          </div>
        </div>
        {tab === 'payroll' && (
          <div style={{ display: 'flex', gap: 8 }}>
            <select className="form-select" value={month} onChange={e => setMonth(Number(e.target.value))}>
              {MONTHS.map((m, i) => <option key={i} value={i + 1}>{m}</option>)}
            </select>
            <select className="form-select" style={{ width: 90 }} value={year} onChange={e => setYear(Number(e.target.value))}>
              {[now.getFullYear(), now.getFullYear() - 1].map(y => <option key={y}>{y}</option>)}
            </select>
          </div>
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

      {/* ── PAYROLL TAB ── */}
      {tab === 'payroll' && (
        <>
          {/* Summary KPIs */}
          <div style={{ display: 'flex', gap: 12, marginBottom: 20, flexWrap: 'wrap' }}>
            {[
              { label: 'Σύνολο οφειλής', value: `€${totalOwed.toFixed(2)}`, color: '#4338ca' },
              { label: 'Πληρώθηκαν', value: `€${totalPaid.toFixed(2)}`, color: '#16a34a' },
              { label: 'Εκκρεμεί', value: `€${totalPending.toFixed(2)}`, color: totalPending > 0 ? '#dc2626' : '#94a3b8' },
            ].map(k => (
              <div key={k.label} className="card" style={{ flex: '1 1 150px', padding: '16px 20px', minWidth: 140 }}>
                <div className="text-muted" style={{ fontSize: '0.75rem', marginBottom: 4 }}>{k.label}</div>
                <div style={{ fontSize: '1.5rem', fontWeight: 800, color: k.color }}>{k.value}</div>
              </div>
            ))}
          </div>

          {loading ? (
            <div className="loading">Φόρτωση…</div>
          ) : staff.length === 0 ? (
            <div className="bk-empty"><p>Δεν υπάρχουν εκπαιδευτές.</p></div>
          ) : (
            <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
              <div style={{ overflowX: 'auto' }}>
                <table>
                  <thead>
                    <tr>
                      <th>Εκπαιδευτής</th>
                      <th>Μικτά</th>
                      <th>Καθαρά (πληρωτέο)</th>
                      <th>Κατάσταση</th>
                      <th>Σημείωση πληρωμής</th>
                      <th></th>
                    </tr>
                  </thead>
                  <tbody>
                    {staff.map(s => {
                      const isPaid = !!s.payment_id;
                      const owedNet = Number(s.monthly_net ?? s.monthly_gross ?? 0);
                      return (
                        <tr key={s.staff_id}>
                          <td><strong>{s.full_name}</strong></td>
                          <td>{s.monthly_gross != null ? `€${Number(s.monthly_gross).toFixed(2)}` : <span className="text-muted">—</span>}</td>
                          <td>
                            <strong style={{ color: owedNet > 0 ? '#0f172a' : '#94a3b8' }}>
                              {owedNet > 0 ? `€${Number(owedNet).toFixed(2)}` : '—'}
                            </strong>
                            {s.fee_per_class && (
                              <div className="text-muted" style={{ fontSize: '0.75rem' }}>
                                + €{Number(s.fee_per_class).toFixed(2)}/μάθημα
                              </div>
                            )}
                          </td>
                          <td>
                            {isPaid ? (
                              <span className="badge badge-green" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                                <CheckCircle size={11} /> Πληρώθηκε
                              </span>
                            ) : owedNet > 0 ? (
                              <span className="badge badge-yellow" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                                <Clock size={11} /> Εκκρεμεί
                              </span>
                            ) : (
                              <span className="badge badge-gray">Χωρίς αμοιβή</span>
                            )}
                          </td>
                          <td>
                            {isPaid ? (
                              <span className="text-muted" style={{ fontSize: '0.82rem' }}>
                                {s.payment_notes || '—'}
                                <br />
                                <span style={{ fontSize: '0.72rem' }}>
                                  {new Date(s.paid_at).toLocaleDateString('el-GR')}
                                </span>
                              </span>
                            ) : (
                              <input className="form-input" style={{ width: 160 }}
                                placeholder="Σημείωση (προαιρ.)"
                                value={payNotes[s.staff_id] || ''}
                                onChange={e => setPayNotes(n => ({ ...n, [s.staff_id]: e.target.value }))} />
                            )}
                          </td>
                          <td>
                            {isPaid ? (
                              <button className="btn btn-secondary btn-sm"
                                onClick={() => undoPaid(s)} disabled={paying[s.staff_id]}
                                title="Αναίρεση πληρωμής">
                                <RotateCcw size={13} />
                              </button>
                            ) : owedNet > 0 ? (
                              <button className="btn btn-primary btn-sm"
                                onClick={() => markPaid(s)} disabled={paying[s.staff_id]}>
                                <CheckCircle size={13} /> {paying[s.staff_id] ? '…' : 'Πληρώθηκε'}
                              </button>
                            ) : null}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </>
      )}

      {/* ── SETTINGS TAB ── */}
      {tab === 'settings' && (
        feeLoading ? <div className="loading">Φόρτωση…</div> :
        fees.length === 0 ? <div className="bk-empty"><p>Δεν υπάρχουν εκπαιδευτές.</p></div> : (
          <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
            <div style={{ overflowX: 'auto' }}>
              <table>
                <thead>
                  <tr>
                    <th>Εκπαιδευτής</th>
                    <th>Μικτά / μήνα (€)</th>
                    <th>Καθαρά / μήνα (€)</th>
                    <th>Ανά μάθημα (€) <span className="text-muted" style={{ fontWeight: 400 }}>προαιρ.</span></th>
                    <th>Σημειώσεις</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  {fees.map(f => (
                    <tr key={f.staff_id}>
                      <td><strong>{f.full_name}</strong></td>
                      {['monthly_gross','monthly_net','fee_per_class'].map(field => (
                        <td key={field}>
                          <input type="number" min={0} step={0.01} className="form-input" style={{ width: 110 }}
                            placeholder="—" value={f[field] ?? ''}
                            onChange={e => updateFee(f.staff_id, field, e.target.value === '' ? null : e.target.value)} />
                        </td>
                      ))}
                      <td>
                        <input type="text" className="form-input" style={{ width: 180 }}
                          value={f.notes || ''} placeholder="Σημειώσεις"
                          onChange={e => updateFee(f.staff_id, 'notes', e.target.value)} />
                      </td>
                      <td>
                        <button className="btn btn-primary btn-sm"
                          onClick={() => saveFee(f.staff_id)} disabled={saving[f.staff_id]}>
                          <Save size={13} /> {saving[f.staff_id] ? '…' : 'Αποθήκευση'}
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )
      )}
    </Layout>
  );
}
