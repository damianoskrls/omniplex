import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import Layout from '../components/Layout';
import api from '../api/client';

const API_BASE = import.meta.env.VITE_API_URL ?? '${API_BASE}';
import {
  Building2, TrendingUp, AlertCircle, Euro, Users, Clock,
  CalendarClock, AlertTriangle, CheckCircle, ChevronRight, BarChart3,
} from 'lucide-react';

const fmt    = (n) => new Intl.NumberFormat('el-GR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(n || 0);
const fmtDate = (d) => d ? new Date(d).toLocaleDateString('el-GR') : '—';
const MONTH_NAMES = ['Ιαν','Φεβ','Μαρ','Απρ','Μαϊ','Ιουν','Ιουλ','Αυγ','Σεπ','Οκτ','Νοε','Δεκ'];

const STATUS_COLOR = { trial:'badge-yellow', active:'badge-green', suspended:'badge-red', cancelled:'badge-gray' };
const STATUS_LABEL = { trial:'Trial', active:'Ενεργό', suspended:'Ανασταλμένο', cancelled:'Ακυρωμένο' };

const BILLING_LABEL = {
  monthly_fee: 'Μηνιαία Χρέωση', annual_fee: 'Ετήσια Χρέωση',
  per_booking: 'Ανά Κράτηση', revenue_share: 'Revenue Share', custom: 'Custom',
};

// ── Revenue bar chart ──────────────────────────────────────────
function RevenueChart({ monthly }) {
  if (!monthly?.length) return (
    <div style={{ textAlign:'center', padding:'32px 0', color:'#94a3b8', fontSize:'0.85rem' }}>
      Δεν υπάρχουν δεδομένα εισπράξεων ακόμα
    </div>
  );

  const max = Math.max(...monthly.map(m => Number(m.collected)), 1);

  return (
    <div style={{ display:'flex', alignItems:'flex-end', gap:10, height:120, padding:'8px 0' }}>
      {monthly.map(m => {
        const [y, mo] = m.month.split('-');
        const label   = `${MONTH_NAMES[Number(mo) - 1]} '${y.slice(2)}`;
        const pct     = (Number(m.collected) / max) * 100;
        return (
          <div key={m.month} style={{ flex:1, display:'flex', flexDirection:'column', alignItems:'center', gap:4 }}>
            <div style={{ fontSize:'0.7rem', fontWeight:600, color:'#475569' }}>€{Math.round(Number(m.collected))}</div>
            <div style={{ width:'100%', display:'flex', alignItems:'flex-end', height:72 }}>
              <div style={{
                width:'100%', height:`${Math.max(pct, 4)}%`,
                background: 'linear-gradient(180deg, #6366f1, #818cf8)',
                borderRadius:'6px 6px 0 0', transition:'height 0.3s ease',
              }}/>
            </div>
            <div style={{ fontSize:'0.7rem', color:'#94a3b8', whiteSpace:'nowrap' }}>{label}</div>
          </div>
        );
      })}
    </div>
  );
}

export default function Dashboard() {
  const [data, setData]       = useState(null);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    api.get('/tenants/dashboard/overview')
      .then(r => setData(r.data))
      .catch(() => api.get('/tenants').then(r => setData({ tenants: r.data, totals: {}, monthly_revenue: [] })))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <Layout title="Dashboard"><div className="loading">Φόρτωση…</div></Layout>;

  const { totals = {}, tenants = [], monthly_revenue = [] } = data || {};

  const KPI = ({ icon: Icon, label, value, color, sub }) => (
    <div className="stat-card" style={{ display:'flex', alignItems:'center', gap:14 }}>
      <div style={{ width:44, height:44, borderRadius:12, background:`${color}18`, display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0 }}>
        <Icon size={20} style={{ color }}/>
      </div>
      <div>
        <div className="stat-label">{label}</div>
        <div className="stat-value" style={{ color }}>{value}</div>
        {sub && <div className="text-muted" style={{ fontSize:'0.75rem', marginTop:2 }}>{sub}</div>}
      </div>
    </div>
  );

  // Derived lists
  const overdueTenants = tenants
    .filter(t => Number(t.outstanding) > 0)
    .sort((a, b) => Number(b.outstanding) - Number(a.outstanding));

  const trialTenants = tenants.filter(t => !t.sub_status || t.sub_status === 'trial');

  const renewalSoon = tenants
    .filter(t => {
      if (!t.next_renewal_at) return false;
      const days = (new Date(t.next_renewal_at) - new Date()) / 86400000;
      return days >= 0 && days <= 30;
    })
    .sort((a, b) => new Date(a.next_renewal_at) - new Date(b.next_renewal_at));

  const suspendedTenants = tenants.filter(t => t.sub_status === 'suspended');

  const daysUntil = (d) => {
    if (!d) return null;
    return Math.ceil((new Date(d) - new Date()) / 86400000);
  };

  const urgencyColor = (days) => {
    if (days <= 7)  return '#dc2626';
    if (days <= 14) return '#d97706';
    return '#16a34a';
  };

  return (
    <Layout title="Dashboard">

      {/* ── KPI Row ── */}
      <div className="stats-grid">
        <KPI icon={Building2}    label="Σύνολο Clients"      value={totals.tenants || tenants.length}           color="#6366f1" sub={`${totals.active || 0} ενεργοί`}/>
        <KPI icon={TrendingUp}   label="MRR (εκτιμ.)"        value={`€${fmt(totals.mrr)}`}                      color="#16a34a" sub="Monthly Recurring Revenue"/>
        <KPI icon={Euro}         label="Εισπράξεις μήνα"     value={`€${fmt(totals.collected_this_month)}`}     color="#0284c7" sub="Πληρωμένα τιμολόγια"/>
        <KPI icon={AlertCircle}  label="Ανεξόφλητα"          value={`€${fmt(totals.pending_amount)}`}           color={totals.overdue_invoices > 0 ? '#dc2626' : '#64748b'} sub={`${totals.overdue_invoices || 0} ληξιπρόθεσμα`}/>
        <KPI icon={Clock}        label="Σε Trial / Χωρίς"    value={trialTenants.length}                        color="#d97706" sub="Χωρίς ενεργή συνδρομή"/>
        <KPI icon={CalendarClock} label="Ανανεώσεις 30 μέρες" value={renewalSoon.length}                       color="#7c3aed" sub="Επερχόμενες ανανεώσεις"/>
      </div>

      {/* ── Alert Banners ── */}
      {(overdueTenants.length > 0 || trialTenants.length > 0 || suspendedTenants.length > 0) && (
        <div style={{ display:'flex', flexDirection:'column', gap:8, marginBottom:16 }}>
          {overdueTenants.length > 0 && (
            <div style={{ padding:'11px 16px', background:'#fef2f2', border:'1px solid #fecaca', borderRadius:10, display:'flex', alignItems:'center', gap:10 }}>
              <AlertCircle size={16} style={{ color:'#dc2626', flexShrink:0 }}/>
              <span style={{ fontSize:'0.85rem', color:'#991b1b', fontWeight:500 }}>
                {overdueTenants.length} client(s) με ανεξόφλητα ποσά —&nbsp;
                {overdueTenants.map(t => `${t.name} (€${fmt(t.outstanding)})`).join(', ')}
              </span>
            </div>
          )}
          {trialTenants.length > 0 && (
            <div style={{ padding:'11px 16px', background:'#fffbeb', border:'1px solid #fde68a', borderRadius:10, display:'flex', alignItems:'center', gap:10 }}>
              <Clock size={16} style={{ color:'#d97706', flexShrink:0 }}/>
              <span style={{ fontSize:'0.85rem', color:'#92400e', fontWeight:500 }}>
                {trialTenants.length} client(s) χωρίς ενεργό συνδρομή: {trialTenants.map(t => t.name).join(', ')}
              </span>
            </div>
          )}
          {suspendedTenants.length > 0 && (
            <div style={{ padding:'11px 16px', background:'#fef2f2', border:'1px solid #fecaca', borderRadius:10, display:'flex', alignItems:'center', gap:10 }}>
              <AlertTriangle size={16} style={{ color:'#dc2626', flexShrink:0 }}/>
              <span style={{ fontSize:'0.85rem', color:'#991b1b', fontWeight:500 }}>
                {suspendedTenants.length} client(s) σε αναστολή: {suspendedTenants.map(t => t.name).join(', ')}
              </span>
            </div>
          )}
        </div>
      )}

      {/* ── Reports Row: Debtors + Renewals ── */}
      <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:16, marginBottom:16 }}>

        {/* Χρεώστες */}
        <div className="card">
          <div className="card-header">
            <span className="card-title" style={{ display:'flex', alignItems:'center', gap:7 }}>
              <AlertCircle size={15} style={{ color:'#dc2626' }}/> Ανεξόφλητα Υπόλοιπα
            </span>
            <span className="text-muted" style={{ fontSize:'0.78rem' }}>
              Σύνολο: €{fmt(totals.pending_amount)}
            </span>
          </div>
          {overdueTenants.length === 0 ? (
            <div style={{ display:'flex', alignItems:'center', gap:8, padding:'12px 0', color:'#16a34a' }}>
              <CheckCircle size={16}/> <span style={{ fontSize:'0.85rem' }}>Όλοι οι clients είναι εντάξει!</span>
            </div>
          ) : (
            <div style={{ display:'flex', flexDirection:'column', gap:0 }}>
              {overdueTenants.map(t => (
                <div key={t.id}
                  onClick={() => navigate(`/tenants/${t.id}/billing`)}
                  style={{ display:'flex', alignItems:'center', gap:10, padding:'10px 0',
                    borderBottom:'1px solid #f1f5f9', cursor:'pointer' }}
                  className="hover-row">
                  {t.logo_url
                    ? <img src={`${API_BASE}${t.logo_url}`} alt="" style={{ width:30, height:30, borderRadius:6, objectFit:'contain', background:'#f8fafc', flexShrink:0 }}/>
                    : <div style={{ width:30, height:30, borderRadius:6, background: t.primary_color || '#e2e8f0', flexShrink:0, display:'flex', alignItems:'center', justifyContent:'center' }}>
                        <Building2 size={14} style={{ color:'#fff' }}/>
                      </div>}
                  <div style={{ flex:1, minWidth:0 }}>
                    <div style={{ fontWeight:600, fontSize:'0.85rem' }}>{t.name}</div>
                    <div style={{ fontSize:'0.75rem', color:'#94a3b8' }}>
                      {t.overdue_count > 0
                        ? <span style={{ color:'#dc2626' }}>{t.overdue_count} ληξιπρόθεσμα</span>
                        : 'Εκκρεμεί'}
                      {t.oldest_due_date && ` · από ${fmtDate(t.oldest_due_date)}`}
                    </div>
                  </div>
                  <div style={{ fontWeight:700, fontSize:'0.95rem', color:'#dc2626', flexShrink:0 }}>
                    €{fmt(t.outstanding)}
                  </div>
                  <ChevronRight size={14} style={{ color:'#cbd5e1', flexShrink:0 }}/>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Επερχόμενες Ανανεώσεις */}
        <div className="card">
          <div className="card-header">
            <span className="card-title" style={{ display:'flex', alignItems:'center', gap:7 }}>
              <CalendarClock size={15} style={{ color:'#7c3aed' }}/> Επερχόμενες Ανανεώσεις
            </span>
            <span className="text-muted" style={{ fontSize:'0.78rem' }}>Επόμενες 30 μέρες</span>
          </div>
          {renewalSoon.length === 0 ? (
            <div style={{ padding:'12px 0', color:'#94a3b8', fontSize:'0.85rem' }}>
              Καμία ανανέωση τις επόμενες 30 μέρες
            </div>
          ) : (
            <div style={{ display:'flex', flexDirection:'column', gap:0 }}>
              {renewalSoon.map(t => {
                const days = daysUntil(t.next_renewal_at);
                const color = urgencyColor(days);
                const fee = t.billing_cycle === 'annual'
                  ? `€${fmt(t.annual_fee)}/έτος`
                  : `€${fmt(t.monthly_fee)}/μήνα`;
                return (
                  <div key={t.id}
                    onClick={() => navigate(`/tenants/${t.id}/billing`)}
                    style={{ display:'flex', alignItems:'center', gap:10, padding:'10px 0',
                      borderBottom:'1px solid #f1f5f9', cursor:'pointer' }}
                    className="hover-row">
                    {t.logo_url
                      ? <img src={`${API_BASE}${t.logo_url}`} alt="" style={{ width:30, height:30, borderRadius:6, objectFit:'contain', background:'#f8fafc', flexShrink:0 }}/>
                      : <div style={{ width:30, height:30, borderRadius:6, background: t.primary_color || '#e2e8f0', flexShrink:0, display:'flex', alignItems:'center', justifyContent:'center' }}>
                          <Building2 size={14} style={{ color:'#fff' }}/>
                        </div>}
                    <div style={{ flex:1, minWidth:0 }}>
                      <div style={{ fontWeight:600, fontSize:'0.85rem' }}>{t.name}</div>
                      <div style={{ fontSize:'0.75rem', color:'#94a3b8' }}>{fee} · {BILLING_LABEL[t.billing_model] || t.billing_model}</div>
                    </div>
                    <div style={{ textAlign:'right', flexShrink:0 }}>
                      <div style={{ fontWeight:700, fontSize:'0.85rem', color }}>{fmtDate(t.next_renewal_at)}</div>
                      <div style={{ fontSize:'0.72rem', color, fontWeight:600 }}>
                        {days === 0 ? 'Σήμερα!' : `σε ${days} μέρ.`}
                      </div>
                    </div>
                    <ChevronRight size={14} style={{ color:'#cbd5e1', flexShrink:0 }}/>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      {/* ── Revenue Chart ── */}
      <div className="card" style={{ marginBottom:16 }}>
        <div className="card-header">
          <span className="card-title" style={{ display:'flex', alignItems:'center', gap:7 }}>
            <BarChart3 size={15} style={{ color:'#6366f1' }}/> Εισπράξεις — Τελευταίοι 6 μήνες
          </span>
          <span className="text-muted" style={{ fontSize:'0.78rem' }}>
            Σύνολο: €{fmt(monthly_revenue.reduce((s, m) => s + Number(m.collected), 0))}
          </span>
        </div>
        <RevenueChart monthly={monthly_revenue}/>
      </div>

      {/* ── Full Clients Table ── */}
      <div className="card">
        <div className="card-header">
          <span className="card-title">Όλοι οι Clients</span>
          <span className="text-muted" style={{ fontSize:'0.8rem' }}>Κάνε κλικ για λεπτομέρειες</span>
        </div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Client</th>
                <th>Τύπος / Plan</th>
                <th>Συνδρομή</th>
                <th>Αμοιβή</th>
                <th>Ανανέωση</th>
                <th>Χρήστες</th>
                <th>Κρατήσεις 30d</th>
                <th>Ανεξόφλητα</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {tenants.map(t => {
                const fee = t.billing_cycle === 'annual'
                  ? `€${fmt(t.annual_fee)}/έτος`
                  : t.monthly_fee > 0 ? `€${fmt(t.monthly_fee)}/μήνα` : '—';
                const outstanding = Number(t.outstanding || 0);
                const days = daysUntil(t.next_renewal_at);
                const renewalUrgent = days !== null && days <= 7;
                return (
                  <tr key={t.id} style={{ cursor:'pointer' }}
                    onClick={() => navigate(`/tenants/${t.id}`)}>
                    <td>
                      <div style={{ display:'flex', alignItems:'center', gap:8 }}>
                        {t.logo_url
                          ? <img src={`${API_BASE}${t.logo_url}`} alt="" style={{ width:28, height:28, borderRadius:6, objectFit:'contain', background:'#f1f5f9' }}/>
                          : <div style={{ width:28, height:28, borderRadius:6, background: t.primary_color || '#e2e8f0', display:'flex', alignItems:'center', justifyContent:'center' }}>
                              <Building2 size={14} style={{ color:'#fff' }}/>
                            </div>}
                        <div>
                          <div style={{ fontWeight:600, fontSize:'0.875rem' }}>{t.name}</div>
                          <div className="text-muted" style={{ fontSize:'0.75rem' }}>{t.slug}</div>
                        </div>
                      </div>
                    </td>
                    <td>
                      <span className="badge badge-blue" style={{ marginRight:4 }}>{t.business_type}</span>
                      <span className="badge badge-gray">{t.plan}</span>
                    </td>
                    <td>
                      <span className={`badge ${STATUS_COLOR[t.sub_status] || 'badge-gray'}`}>
                        {STATUS_LABEL[t.sub_status] || 'Χωρίς'}
                      </span>
                    </td>
                    <td style={{ fontWeight:600, fontSize:'0.85rem' }}>{fee}</td>
                    <td style={{ fontSize:'0.82rem', color: renewalUrgent ? '#dc2626' : days !== null && days <= 30 ? '#d97706' : undefined }}>
                      <div>{fmtDate(t.next_renewal_at)}</div>
                      {days !== null && days <= 30 && (
                        <div style={{ fontSize:'0.72rem', fontWeight:600 }}>
                          {days === 0 ? 'Σήμερα!' : `σε ${days}μ`}
                        </div>
                      )}
                    </td>
                    <td style={{ fontWeight:600 }}>{t.user_count || 0}</td>
                    <td>{t.bookings_30d || 0}</td>
                    <td style={{ fontWeight:600, color: outstanding > 0 ? '#dc2626' : '#16a34a' }}>
                      {outstanding > 0 ? `€${fmt(outstanding)}` : <CheckCircle size={14}/>}
                    </td>
                    <td>
                      {t.is_active
                        ? <span className="badge badge-green">Ενεργό</span>
                        : <span className="badge badge-red">Ανενεργό</span>}
                    </td>
                  </tr>
                );
              })}
              {!tenants.length && <tr><td colSpan={9} className="loading">Δεν υπάρχουν clients</td></tr>}
            </tbody>
          </table>
        </div>
      </div>
    </Layout>
  );
}
