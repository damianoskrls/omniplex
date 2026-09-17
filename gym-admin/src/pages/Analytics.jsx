import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import { TrendingUp, TrendingDown, DollarSign, Users, Target, Activity, ChevronDown } from 'lucide-react';

const biz = () => JSON.parse(localStorage.getItem('gym_admin_business') || '{}');

const MONTHS = ['Ιανουάριος','Φεβρουάριος','Μάρτιος','Απρίλιος','Μάιος','Ιούνιος',
                'Ιούλιος','Αύγουστος','Σεπτέμβριος','Οκτώβριος','Νοέμβριος','Δεκέμβριος'];
const MONTHS_SHORT = ['Ιαν','Φεβ','Μαρ','Απρ','Μαΐ','Ιουν','Ιουλ','Αυγ','Σεπ','Οκτ','Νοε','Δεκ'];

function fmt(n) { return '€' + Number(n || 0).toLocaleString('el-GR', { maximumFractionDigits: 0 }); }
function pct(n) { return Number(n || 0).toFixed(1) + '%'; }
function trend(curr, prev) {
  if (!prev || prev === 0) return null;
  return Math.round(((curr - prev) / prev) * 100);
}

function KpiCard({ label, value, prev, prevLabel, icon: Icon, gradient, trendVal }) {
  const up = trendVal > 0;
  const hasTraend = trendVal !== null && trendVal !== undefined;
  return (
    <div style={{
      flex: '1 1 0', minWidth: 160,
      background: 'var(--surface)',
      borderRadius: 18,
      padding: '22px 22px 18px',
      border: '1px solid var(--border)',
      position: 'relative',
      overflow: 'hidden',
    }}>
      <div style={{
        position: 'absolute', top: 0, right: 0, width: 90, height: 90,
        background: gradient, borderRadius: '0 18px 0 100%', opacity: 0.12,
      }} />
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 14 }}>
        <div style={{
          width: 40, height: 40, borderRadius: 12,
          background: gradient, display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <Icon size={18} color="#fff" strokeWidth={2.5} />
        </div>
        {hasTraend && (
          <span style={{
            display: 'inline-flex', alignItems: 'center', gap: 3, fontSize: 11.5, fontWeight: 700,
            color: up ? 'var(--success)' : 'var(--danger)',
            background: up ? 'var(--success-dim)' : 'var(--danger-dim)',
            padding: '3px 9px', borderRadius: 99,
          }}>
            {up ? <TrendingUp size={11} /> : <TrendingDown size={11} />}
            {Math.abs(trendVal)}%
          </span>
        )}
      </div>
      <div style={{ fontSize: 28, fontWeight: 800, color: 'var(--text)', letterSpacing: '-0.5px', lineHeight: 1 }}>{value}</div>
      <div style={{ fontSize: 12.5, color: 'var(--text-3)', marginTop: 5, fontWeight: 500 }}>{label}</div>
      {prev !== undefined && (
        <div style={{ fontSize: 11, color: 'var(--text-3)', marginTop: 8, paddingTop: 8, borderTop: '1px solid var(--border)' }}>
          {prevLabel || 'Προηγ.'} <span style={{ color: 'var(--text-2)', fontWeight: 600 }}>{prev}</span>
        </div>
      )}
    </div>
  );
}

function BarList({ items, valueKey, labelKey, color }) {
  if (!items?.length) return <div style={{ color: 'var(--text-3)', fontSize: 13, padding: '8px 0' }}>Δεν υπάρχουν δεδομένα</div>;
  const max = Math.max(...items.map(i => i[valueKey] || 0), 1);
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
      {items.map((item, i) => {
        const pct = ((item[valueKey] || 0) / max) * 100;
        return (
          <div key={i}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
              <span style={{ fontSize: 13, fontWeight: 500, color: 'var(--text-2)' }}>{item[labelKey] || 'Άλλο'}</span>
              <span style={{ fontSize: 13, fontWeight: 700, color: 'var(--text)' }}>{fmt(item[valueKey])}</span>
            </div>
            <div style={{ height: 6, background: 'var(--surface-2)', borderRadius: 99, overflow: 'hidden' }}>
              <div style={{
                height: '100%', width: `${pct}%`,
                background: color, borderRadius: 99,
                transition: 'width 0.6s cubic-bezier(.4,0,.2,1)',
              }} />
            </div>
          </div>
        );
      })}
    </div>
  );
}

function Select({ value, onChange, children }) {
  return (
    <div style={{ position: 'relative', display: 'inline-flex', alignItems: 'center' }}>
      <select value={value} onChange={onChange} style={{
        appearance: 'none', background: 'var(--surface)', border: '1px solid var(--border)',
        borderRadius: 10, padding: '8px 32px 8px 13px', fontSize: 13, fontWeight: 600,
        color: 'var(--text)', cursor: 'pointer', outline: 'none',
      }}>
        {children}
      </select>
      <ChevronDown size={14} style={{ position: 'absolute', right: 10, pointerEvents: 'none', color: 'var(--text-3)' }} />
    </div>
  );
}

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
  const revTrend = data ? trend(data.revenue?.current, data.revenue?.previous) : null;
  const profTrend = data ? trend(data.profit?.current, data.profit?.previous) : null;
  const memTrend = data ? trend(data.new_members?.current, data.new_members?.previous) : null;

  return (
    <Layout>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 28 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <div style={{
            width: 48, height: 48, borderRadius: 16,
            background: 'linear-gradient(135deg,#6366F1,#8B5CF6)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 8px 20px rgba(99,102,241,0.3)',
          }}>
            <Activity size={22} color="#fff" strokeWidth={2.5} />
          </div>
          <div>
            <h1 style={{ fontSize: 22, fontWeight: 800, color: 'var(--text)', letterSpacing: '-0.3px' }}>Αναλυτικά Στοιχεία</h1>
            <p style={{ fontSize: 13, color: 'var(--text-3)', marginTop: 2 }}>Έσοδα, έξοδα & μετατροπές</p>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <Select value={month} onChange={e => setMonth(Number(e.target.value))}>
            {MONTHS_SHORT.map((m, i) => <option key={i} value={i + 1}>{m}</option>)}
          </Select>
          <Select value={year} onChange={e => setYear(Number(e.target.value))}>
            {years.map(y => <option key={y} value={y}>{y}</option>)}
          </Select>
        </div>
      </div>

      {loading ? (
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: 300 }}>
          <div style={{ textAlign: 'center' }}>
            <div style={{ width: 40, height: 40, borderRadius: '50%', border: '3px solid var(--border)', borderTopColor: 'var(--accent)', animation: 'spin 0.8s linear infinite', margin: '0 auto 12px' }} />
            <p style={{ color: 'var(--text-3)', fontSize: 13 }}>Φόρτωση δεδομένων…</p>
          </div>
        </div>
      ) : !data ? (
        <div style={{ textAlign: 'center', padding: '80px 20px', color: 'var(--text-3)' }}>
          <Activity size={40} style={{ margin: '0 auto 12px', opacity: 0.3 }} />
          <p style={{ fontSize: 14 }}>Δεν υπάρχουν δεδομένα για αυτή την περίοδο</p>
        </div>
      ) : (
        <>
          {/* KPI grid */}
          <div style={{ display: 'flex', gap: 14, flexWrap: 'wrap', marginBottom: 24 }}>
            <KpiCard label="Έσοδα" value={fmt(data.revenue?.current)} prev={fmt(data.revenue?.previous)} icon={DollarSign} gradient="linear-gradient(135deg,#3B82F6,#2563EB)" trendVal={revTrend} />
            <KpiCard label="Έξοδα" value={fmt(data.expenses?.current)} prev={fmt(data.expenses?.previous)} icon={TrendingDown} gradient="linear-gradient(135deg,#F87171,#EF4444)" trendVal={null} />
            <KpiCard label="Κέρδος" value={fmt(data.profit?.current)} prev={fmt(data.profit?.previous)} icon={TrendingUp} gradient="linear-gradient(135deg,#34D399,#10B981)" trendVal={profTrend} />
            <KpiCard label="Νέα μέλη" value={data.new_members?.current ?? '—'} prev={data.new_members?.previous ?? '—'} icon={Users} gradient="linear-gradient(135deg,#A78BFA,#7C3AED)" trendVal={memTrend} />
            <KpiCard label="Δοκιμαστικά" value={data.trials ?? '—'} icon={Target} gradient="linear-gradient(135deg,#FCD34D,#F59E0B)" trendVal={null} />
            <KpiCard label="Μετατροπές" value={pct(data.conversion_rate)} prevLabel={`${data.conversions ?? 0} από ${data.trials ?? 0}`} prev="" icon={Activity} gradient="linear-gradient(135deg,#67E8F9,#0891B2)" trendVal={null} />
          </div>

          {/* Charts row */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
            <div style={{ background: 'var(--surface)', borderRadius: 18, padding: 24, border: '1px solid var(--border)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 20 }}>
                <div style={{ width: 8, height: 8, borderRadius: '50%', background: '#3B82F6' }} />
                <span style={{ fontWeight: 700, fontSize: 14, color: 'var(--text)' }}>Έσοδα ανά υπηρεσία</span>
              </div>
              <BarList items={data.revenue_by_service} valueKey="revenue" labelKey="service_name" color="linear-gradient(90deg,#60A5FA,#2563EB)" />
            </div>
            <div style={{ background: 'var(--surface)', borderRadius: 18, padding: 24, border: '1px solid var(--border)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 20 }}>
                <div style={{ width: 8, height: 8, borderRadius: '50%', background: '#EF4444' }} />
                <span style={{ fontWeight: 700, fontSize: 14, color: 'var(--text)' }}>Έξοδα ανά κατηγορία</span>
              </div>
              <BarList items={data.expenses_by_category} valueKey="total" labelKey="category" color="linear-gradient(90deg,#FCA5A5,#EF4444)" />
            </div>
          </div>
        </>
      )}
      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </Layout>
  );
}
