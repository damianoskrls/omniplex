import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import { CalendarOff, Check, X, Settings, Clock } from 'lucide-react';

function fmtDate(iso) {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString('el-GR', { day: 'numeric', month: 'short', year: 'numeric' });
}

const STATUS_LABEL = { pending: 'Αναμονή', approved: 'Εγκρίθηκε', rejected: 'Απορρίφθηκε' };
const STATUS_COLOR = { pending: '#D97706', approved: '#16A34A', rejected: '#DC2626' };
const STATUS_BG = { pending: '#FEF3C7', approved: '#DCFCE7', rejected: '#FEE2E2' };

export default function StaffLeaves() {
  const [leaves, setLeaves] = useState([]);
  const [loading, setLoading] = useState(true);
  const [annualDays, setAnnualDays] = useState('');
  const [savingDays, setSavingDays] = useState(false);
  const [statusFilter, setStatusFilter] = useState('');
  const [actionNote, setActionNote] = useState({});
  const [acting, setActing] = useState(null);
  const [error, setError] = useState('');

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      const [leavesRes, settingsRes] = await Promise.all([
        api.get('/client-admin/staff-leaves', { params: statusFilter ? { status: statusFilter } : {} }),
        api.get('/client-admin/settings/annual-leave-days').catch(() => ({ data: { annual_leave_days: 20 } })),
      ]);
      setLeaves(leavesRes.data.leaves || leavesRes.data);
      setAnnualDays(settingsRes.data.annual_leave_days ?? 20);
    } catch (e) {
      setError(e?.response?.data?.error || e?.message || 'Σφάλμα φόρτωσης');
    }
    finally { setLoading(false); }
  };

  useEffect(() => { load(); }, [statusFilter]);

  const handleAction = async (leaveId, action) => {
    setActing(leaveId + action);
    try {
      await api.patch(`/client-admin/staff-leaves/${leaveId}`, { status: action, admin_note: actionNote[leaveId] || '' });
      await load();
    } catch { /* silent */ }
    finally { setActing(null); }
  };

  const saveAnnualDays = async () => {
    setSavingDays(true);
    try {
      await api.patch('/client-admin/settings/annual-leave-days', { annual_leave_days: Number(annualDays) });
    } catch { /* silent */ }
    finally { setSavingDays(false); }
  };

  return (
    <Layout>
      <div className="page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 44, height: 44, borderRadius: 14, background: 'linear-gradient(135deg,#f0fdf4,#bbf7d0)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#16A34A' }}>
            <CalendarOff size={22} />
          </div>
          <div>
            <h1 className="page-title">Άδειες Προσωπικού</h1>
            <div className="text-muted" style={{ marginTop: 2 }}>Αιτήματα και εγκρίσεις αδειών</div>
          </div>
        </div>

        {/* Annual leave setting */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Settings size={15} style={{ color: '#94a3b8' }} />
          <span style={{ fontSize: 13, color: '#64748b' }}>Ετήσιες ημέρες:</span>
          <input
            type="number"
            className="form-input"
            style={{ width: 70, padding: '4px 8px', fontSize: 13 }}
            value={annualDays}
            min={1}
            onChange={e => setAnnualDays(e.target.value)}
          />
          <button className="btn btn-secondary btn-sm" onClick={saveAnnualDays} disabled={savingDays}>
            {savingDays ? '…' : 'Αποθήκευση'}
          </button>
        </div>
      </div>

      {/* Filter */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 18 }}>
        {[['', 'Όλα'], ['pending', 'Αναμονή'], ['approved', 'Εγκεκριμένα'], ['rejected', 'Απορριφθέντα']].map(([val, label]) => (
          <button
            key={val}
            className={`btn ${statusFilter === val ? 'btn-primary' : 'btn-secondary'} btn-sm`}
            onClick={() => setStatusFilter(val)}
          >
            {label}
          </button>
        ))}
      </div>

      {error && (
        <div style={{ background: '#FEE2E2', color: '#DC2626', padding: '12px 16px', borderRadius: 8, marginBottom: 16, fontSize: 14 }}>
          {error}
        </div>
      )}
      {loading ? (
        <div className="loading">Φόρτωση…</div>
      ) : !leaves.length ? (
        <div className="bk-empty">
          <CalendarOff size={40} style={{ margin: '0 auto 12px', display: 'block', color: '#94a3b8' }} />
          <div>Δεν υπάρχουν αιτήματα αδειών</div>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {leaves.map(lv => (
            <div key={lv.id} className="bk-card" style={{ padding: '16px 20px' }}>
              <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 4 }}>
                    <span style={{ fontWeight: 700, fontSize: 15 }}>{lv.staff_name || 'Άγνωστο μέλος'}</span>
                    <span style={{
                      fontSize: 11, fontWeight: 700, padding: '2px 8px', borderRadius: 99,
                      background: STATUS_BG[lv.status], color: STATUS_COLOR[lv.status]
                    }}>
                      {STATUS_LABEL[lv.status] || lv.status}
                    </span>
                  </div>
                  <div className="text-muted" style={{ fontSize: 13 }}>
                    {fmtDate(lv.date_from)} – {fmtDate(lv.date_to)}
                    {' · '}
                    <strong>{lv.days_count} ημέρες</strong>
                  </div>
                  {lv.reason && (
                    <div style={{ fontSize: 13, color: '#475569', marginTop: 6 }}>"{lv.reason}"</div>
                  )}
                  {lv.admin_note && (
                    <div style={{ fontSize: 12, color: '#94A3B8', marginTop: 4 }}>Σημείωση: {lv.admin_note}</div>
                  )}
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexShrink: 0 }}>
                  {lv.status === 'pending' && (
                    <>
                      <input
                        className="form-input"
                        placeholder="Σημείωση (προαιρετικά)"
                        style={{ fontSize: 12, padding: '4px 8px', width: 180 }}
                        value={actionNote[lv.id] || ''}
                        onChange={e => setActionNote(n => ({ ...n, [lv.id]: e.target.value }))}
                      />
                      <button
                        className="btn btn-sm"
                        style={{ background: '#DCFCE7', color: '#16A34A', border: 'none' }}
                        disabled={acting === lv.id + 'approved'}
                        onClick={() => handleAction(lv.id, 'approved')}
                        title="Έγκριση"
                      >
                        <Check size={15} />
                      </button>
                      <button
                        className="btn btn-sm"
                        style={{ background: '#FEE2E2', color: '#DC2626', border: 'none' }}
                        disabled={acting === lv.id + 'rejected'}
                        onClick={() => handleAction(lv.id, 'rejected')}
                        title="Απόρριψη"
                      >
                        <X size={15} />
                      </button>
                    </>
                  )}
                  {lv.status !== 'pending' && lv.reviewed_at && (
                    <div style={{ fontSize: 11, color: '#94A3B8', display: 'flex', alignItems: 'center', gap: 4 }}>
                      <Clock size={11} />
                      {fmtDate(lv.reviewed_at)}
                    </div>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </Layout>
  );
}
