import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import { TrendingUp, TrendingDown, DollarSign, Users, Activity, Target } from 'lucide-react';

const biz = () => JSON.parse(localStorage.getItem('gym_admin_business') || '{}');

function KpiCard({ label, value, sub, icon: Icon, color, trend }) {
  const isUp = trend > 0;
  return (
    <div className="bk-card" style={{ flex: '1 1 180px', minWidth: 160 }}>
      <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 8 }}>
        <div style={{ width: 38, height: 38, borderRadius: 10, background: color + '22', display: 'flex', alignItems: 'center', justifyContent: 'center', color }}>
          <Icon size={18} />
        </div>
        {trend !== undefined && (
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3, fontSize: 12, fontWeight: 600, color: isUp ? '#16A34A' : '#DC2626' }}>
            {isUp ? <TrendingUp size={13} /> : <TrendingDown size={13} />}
            {Math.abs(trend)}%
          </span>
        )}
      </div>
      <div style={{ fontSize: 26, fontWeight: 800, color: 'var(--color-text)', lineHeight: 1 }}>{value}</div>
      <div style={{ fontSize: 12, color: '#64748B', marginTop: 4 }}>{label}</div>
      {sub && <div style={{ fontSize: 11, color: '#94A3B8', marginTop: 2 }}>{sub}</div>}
    </div>
  );
}

function fmt(n) {
  if (n == null) return '—';
  return '€' + Number(n).toLocaleString('el-GR', { maximumFractionDigits: 0 });
}

function pct(n) {
  if (n == null) return '—';
  return Number(n).toFixed(1) + '%';
}

function trend(curr, prev) {
  if (!prev || prev === 0) return undefined;
  return Math.round(((curr - prev) / prev) * 100);
}

const MONTHS = ['Ιαν', 'Φεβ', 'Μαρ', 'Απρ', 'Μαΐ', 'Ιουν', 'Ιουλ', 'Αυγ', 'Σεπ', 'Οκτ', 'Νοε', 'Δεκ'];

export default function Analytics() {
  const now = new Date();
  const [year, setYear] = useState(now.getFullYear());
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true);
    const bizId = biz().id;
    if (!bizId) { setLoading(false); return; }
    api.get(`/business/${bizId}/analytics`, { params: { year, month } })
      .then(r => setData(r.data))
      .catch(e => console.error('Analytics error:', e?.response?.data || e.message))
      .finally(() => setLoading(false));
  }, [year, month]);

  const years = [now.getFullYear(), now.getFullYear() - 1, now.getFullYear() - 2];

  return (
    <Layout>
      <div className="page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 44, height: 44, borderRadius: 14, background: 'linear-gradient(135deg,#dbeafe,#bfdbfe)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#2563EB' }}>
            <Activity size={22} />
          </div>
          <div>
            <h1 className="page-title">Αναλυτικά Στοιχεία</h1>
            <div className="text-muted" style={{ marginTop: 2 }}>Έσοδα, έξοδα, μετατροπές</div>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <select className="form-select" style={{ width: 100 }} value={month} onChange={e => setMonth(Number(e.target.value))}>
            {MONTHS.map((m, i) => <option key={i} value={i + 1}>{m}</option>)}
          </select>
          <select className="form-select" style={{ width: 90 }} value={year} onChange={e => setYear(Number(e.target.value))}>
            {years.map(y => <option key={y} value={y}>{y}</option>)}
          </select>
        </div>
      </div>

      {loading ? <div className="loading">Φόρτωση…</div> : !data ? (
        <div className="bk-empty">Δεν υπάρχουν δεδομένα</div>
      ) : (
        <>
          {/* KPI row */}
          <div style={{ display: 'flex', gap: 14, flexWrap: 'wrap', marginBottom: 24 }}>
            <KpiCard label="Έσοδα" value={fmt(data.revenue?.current)} sub={`Προηγ. ${fmt(data.revenue?.previous)}`} icon={DollarSign} color="#2563EB" trend={trend(data.revenue?.current, data.revenue?.previous)} />
            <KpiCard label="Έξοδα" value={fmt(data.expenses?.current)} sub={`Προηγ. ${fmt(data.expenses?.previous)}`} icon={TrendingDown} color="#DC2626" />
            <KpiCard label="Κέρδος" value={fmt(data.profit?.current)} sub={`Προηγ. ${fmt(data.profit?.previous)}`} icon={TrendingUp} color="#16A34A" trend={trend(data.profit?.current, data.profit?.previous)} />
            <KpiCard label="Νέα μέλη" value={data.new_members?.current ?? '—'} sub={`Προηγ. ${data.new_members?.previous ?? '—'}`} icon={Users} color="#7C3AED" trend={trend(data.new_members?.current, data.new_members?.previous)} />
            <KpiCard label="Δοκιμαστικά" value={data.trials ?? '—'} icon={Target} color="#D97706" />
            <KpiCard label="Μετατροπές" value={pct(data.conversion_rate)} sub={`${data.conversions ?? 0} από ${data.trials ?? 0} trials`} icon={Activity} color="#0891B2" />
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
            {/* Revenue by service */}
            {data.revenue_by_service?.length > 0 && (
              <div className="bk-card">
                <div style={{ fontWeight: 700, marginBottom: 14, fontSize: 14 }}>Έσοδα ανά υπηρεσία</div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  {data.revenue_by_service.map((s, i) => {
                    const max = data.revenue_by_service[0].revenue;
                    const pct = max > 0 ? (s.revenue / max) * 100 : 0;
                    return (
                      <div key={i}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13, marginBottom: 4 }}>
                          <span style={{ fontWeight: 500 }}>{s.service_name}</span>
                          <span style={{ color: '#2563EB', fontWeight: 700 }}>{fmt(s.revenue)}</span>
                        </div>
                        <div style={{ height: 6, background: '#F1F5F9', borderRadius: 99, overflow: 'hidden' }}>
                          <div style={{ height: '100%', width: `${pct}%`, background: 'linear-gradient(90deg,#3B82F6,#2563EB)', borderRadius: 99 }} />
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            )}

            {/* Expenses by category */}
            {data.expenses_by_category?.length > 0 && (
              <div className="bk-card">
                <div style={{ fontWeight: 700, marginBottom: 14, fontSize: 14 }}>Έξοδα ανά κατηγορία</div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  {data.expenses_by_category.map((c, i) => {
                    const max = data.expenses_by_category[0].total;
                    const pct = max > 0 ? (c.total / max) * 100 : 0;
                    return (
                      <div key={i}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13, marginBottom: 4 }}>
                          <span style={{ fontWeight: 500 }}>{c.category || 'Άλλο'}</span>
                          <span style={{ color: '#DC2626', fontWeight: 700 }}>{fmt(c.total)}</span>
                        </div>
                        <div style={{ height: 6, background: '#F1F5F9', borderRadius: 99, overflow: 'hidden' }}>
                          <div style={{ height: '100%', width: `${pct}%`, background: 'linear-gradient(90deg,#F87171,#DC2626)', borderRadius: 99 }} />
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            )}
          </div>
        </>
      )}
    </Layout>
  );
}
