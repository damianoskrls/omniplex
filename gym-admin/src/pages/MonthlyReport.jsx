import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { TrendingUp, TrendingDown, Minus, RefreshCw, Calendar, Users, ListChecks, ShoppingBag, Euro } from 'lucide-react';

const MONTHS = [
  'Ιανουάριος','Φεβρουάριος','Μάρτιος','Απρίλιος','Μάιος','Ιούνιος',
  'Ιούλιος','Αύγουστος','Σεπτέμβριος','Οκτώβριος','Νοέμβριος','Δεκέμβριος',
];

function pct(value, prev) {
  if (!prev || prev === 0) return null;
  const d = value - prev;
  return { d, p: Math.round((d / prev) * 100) };
}

function Delta({ value, prev }) {
  const r = pct(value, prev);
  if (!r) return null;
  if (r.d > 0) return <span style={{ display:'inline-flex',alignItems:'center',gap:2,fontSize:'0.72rem',fontWeight:700,color:'#16a34a' }}><TrendingUp size={11} />+{r.p}%</span>;
  if (r.d < 0) return <span style={{ display:'inline-flex',alignItems:'center',gap:2,fontSize:'0.72rem',fontWeight:700,color:'#dc2626' }}><TrendingDown size={11} />{r.p}%</span>;
  return <span style={{ display:'inline-flex',alignItems:'center',gap:2,fontSize:'0.72rem',color:'#94a3b8' }}><Minus size={11} />0%</span>;
}

function KpiTile({ icon: Icon, label, value, prev, color = '#76C043' }) {
  return (
    <div className="dashboard-kpi" style={{ cursor: 'default' }}>
      <div className="dashboard-kpi__glow" style={{ background: color }} />
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
        <div style={{
          width: 40, height: 40, borderRadius: 12, display: 'flex', alignItems: 'center',
          justifyContent: 'center', background: `${color}20`, color,
        }}>
          <Icon size={20} />
        </div>
        <span className="dashboard-kpi__label">{label}</span>
      </div>
      <div className="dashboard-kpi__value">{value ?? '—'}</div>
      <div style={{ marginTop: 6 }}><Delta value={value} prev={prev} /></div>
    </div>
  );
}

export default function MonthlyReport() {
  const biz = JSON.parse(localStorage.getItem('gym_admin_business') || '{}');
  const bizId = biz.id;
  const now = new Date();

  const [year, setYear] = useState(now.getMonth() === 0 ? now.getFullYear() - 1 : now.getFullYear());
  const [month, setMonth] = useState(now.getMonth() === 0 ? 12 : now.getMonth());
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [generating, setGenerating] = useState(false);

  const load = async () => {
    setLoading(true);
    try {
      const r = await api.get(`/business/${bizId}/report/monthly`, { params: { year, month } });
      setData(r.data);
    } catch (err) { toast.error('Σφάλμα: ' + (err?.response?.data?.error || err.message || 'Άγνωστο σφάλμα')); }
    finally { setLoading(false); }
  };

  useEffect(() => { load(); }, [year, month]);

  const generate = async () => {
    setGenerating(true);
    try {
      const r = await api.post(`/business/${bizId}/report/monthly/generate`, { year, month });
      setData(r.data);
      toast.success('Αναφορά δημιουργήθηκε');
    } catch { toast.error('Σφάλμα'); }
    finally { setGenerating(false); }
  };

  const d = data;

  return (
    <Layout>
      <div className="page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{
            width: 44, height: 44, borderRadius: 14,
            background: 'linear-gradient(135deg,#eef2ff,#e0e7ff)',
            display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#4338ca',
          }}>
            <Calendar size={22} />
          </div>
          <div>
            <h1 className="page-title">Μηνιαία Αναφορά Αξίας</h1>
            <div className="text-muted" style={{ marginTop: 2 }}>Τι πρόσφερε η πλατφόρμα αυτόν τον μήνα</div>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
          <select className="form-select" style={{ width: 150 }}
            value={month} onChange={e => setMonth(Number(e.target.value))}>
            {MONTHS.map((m, i) => <option key={i} value={i + 1}>{m}</option>)}
          </select>
          <select className="form-select" style={{ width: 90 }}
            value={year} onChange={e => setYear(Number(e.target.value))}>
            {[now.getFullYear(), now.getFullYear() - 1, now.getFullYear() - 2].map(y =>
              <option key={y} value={y}>{y}</option>)}
          </select>
          <button className="btn btn-secondary" onClick={generate} disabled={generating}>
            <RefreshCw size={15} style={generating ? { animation: 'spin 1s linear infinite' } : {}} />
            {generating ? 'Δημιουργία…' : 'Ανανέωση'}
          </button>
        </div>
      </div>

      {loading ? (
        <div className="loading">Φόρτωση…</div>
      ) : !d ? (
        <div className="bk-empty">
          <Calendar size={48} style={{ margin: '0 auto 12px', display: 'block', color: '#94a3b8' }} />
          <div style={{ fontWeight: 700, color: '#1e293b' }}>Δεν υπάρχει αναφορά για αυτόν τον μήνα</div>
          <div style={{ marginTop: 12 }}>
            <button className="btn btn-primary" onClick={generate}>Δημιουργία τώρα</button>
          </div>
        </div>
      ) : (
        <>
          <div className="dashboard-kpi-grid" style={{ marginBottom: 24 }}>
            <KpiTile icon={Users} label="Ενεργά μέλη"
              value={d.active_members?.value} prev={d.active_members?.prev} color="#76C043" />
            <KpiTile icon={ListChecks} label="Check-ins"
              value={d.check_ins?.value} prev={d.check_ins?.prev} color="#3B82F6" />
            <KpiTile icon={ShoppingBag} label="App κρατήσεις"
              value={d.app_bookings?.value} prev={d.app_bookings?.prev} color="#8B5CF6" />
            <KpiTile icon={Euro} label="Εκτιμώμενη αξία (€)"
              value={(d.reception_saved_eur_estimate || 0) + (d.waitlist_value_eur_estimate || 0)}
              color="#F59E0B" />
          </div>

          <div className="reports-panel">
            <div className="reports-panel__head">
              <TrendingUp size={18} className="reports-panel__icon" />
              <h3>Ανάλυση αξίας</h3>
            </div>
            <div className="reports-table-wrap">
              <table className="reports-table">
                <thead>
                  <tr>
                    <th>Μετρική</th>
                    <th>Αυτός ο μήνας</th>
                    <th>Προηγ. μήνας</th>
                    <th>Μεταβολή</th>
                    <th>Σημείωση</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td>Θέσεις από λίστα αναμονής</td>
                    <td><strong>{d.waitlist_fills?.value ?? '—'}</strong></td>
                    <td className="text-muted">{d.waitlist_fills?.prev ?? '—'}</td>
                    <td><Delta value={d.waitlist_fills?.value} prev={d.waitlist_fills?.prev} /></td>
                    <td className="text-muted" style={{ fontSize: '0.78rem' }}>
                      {d.avg_session_eur_estimate ? `~€${d.avg_session_eur_estimate}/συνεδρία → €${d.waitlist_value_eur_estimate} εκτ.` : ''}
                    </td>
                  </tr>
                  <tr>
                    <td>Εκτιμώμενος χρόνος reception</td>
                    <td><strong>{d.reception_saved_minutes ?? '—'} λεπτά</strong></td>
                    <td className="text-muted">—</td>
                    <td>—</td>
                    <td className="text-muted" style={{ fontSize: '0.78rem' }}>
                      {d.minutes_per_booking ?? 5} λεπτά × {d.app_bookings?.value} κρατήσεις → €{d.reception_saved_eur_estimate} εκτ.
                    </td>
                  </tr>
                  <tr>
                    <td>Υπενθυμίσεις πληρωμής/λήξης</td>
                    <td><strong>{d.payment_reminders_sent ?? '—'}</strong></td>
                    <td className="text-muted">—</td>
                    <td>—</td>
                    <td className="text-muted" style={{ fontSize: '0.78rem' }}>{d.payment_reminder_renewals ?? 0} ανανεώσεις που ακολούθησαν</td>
                  </tr>
                  <tr>
                    <td>Μέλη σε κίνδυνο που επέστρεψαν</td>
                    <td><strong>{d.at_risk_returned?.value ?? '—'}</strong></td>
                    <td className="text-muted">{d.at_risk_returned?.prev ?? '—'}</td>
                    <td><Delta value={d.at_risk_returned?.value} prev={d.at_risk_returned?.prev} /></td>
                    <td>—</td>
                  </tr>
                </tbody>
              </table>
            </div>
            <p className="text-muted" style={{ marginTop: 12, fontSize: '0.75rem' }}>
              * Οι εκτιμήσεις σε € είναι ενδεικτικές βάσει μέσης τιμής συνεδρίας και κόστους reception €12/ώρα.
            </p>
          </div>
        </>
      )}
    </Layout>
  );
}
