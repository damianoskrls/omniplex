import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import { Target, UserCheck, Check, ChevronDown, TrendingUp, Users, Percent } from 'lucide-react';

function fmtDate(iso) {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString('el-GR', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
}

function Avatar({ name, avatar, color, size = 30 }) {
  const bg = color || '#7C3AED';
  const initials = (name || '?').split(' ').map(w => w[0]).slice(0, 2).join('').toUpperCase();
  if (avatar) return <img src={avatar} alt={name} style={{ width: size, height: size, borderRadius: '50%', objectFit: 'cover', flexShrink: 0 }} />;
  return (
    <div style={{ width: size, height: size, borderRadius: '50%', background: bg, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontSize: size * 0.35, fontWeight: 700, flexShrink: 0 }}>
      {initials}
    </div>
  );
}

function StatCard({ label, value, sub, icon: Icon, gradient }) {
  return (
    <div style={{
      flex: '1 1 0', minWidth: 130, background: 'var(--surface)',
      borderRadius: 16, padding: '18px 18px 14px',
      border: '1px solid var(--border)', position: 'relative', overflow: 'hidden',
    }}>
      <div style={{ position: 'absolute', top: 0, right: 0, width: 70, height: 70, background: gradient, borderRadius: '0 16px 0 100%', opacity: 0.13 }} />
      <div style={{ width: 36, height: 36, borderRadius: 11, background: gradient, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 12 }}>
        <Icon size={17} color="#fff" strokeWidth={2.5} />
      </div>
      <div style={{ fontSize: 26, fontWeight: 800, color: 'var(--text)', letterSpacing: '-0.5px', lineHeight: 1 }}>{value}</div>
      <div style={{ fontSize: 12, color: 'var(--text-3)', marginTop: 4, fontWeight: 500 }}>{label}</div>
      {sub && <div style={{ fontSize: 11, color: 'var(--text-3)', marginTop: 6 }}>{sub}</div>}
    </div>
  );
}

function StaffDropdown({ value, options, onChange }) {
  return (
    <div style={{ position: 'relative', display: 'inline-flex', alignItems: 'center' }}>
      <select
        value={value || ''}
        onChange={e => onChange(e.target.value)}
        style={{
          appearance: 'none', background: value ? 'rgba(124,58,237,0.06)' : 'var(--surface-2)',
          border: `1.5px solid ${value ? '#7C3AED' : 'var(--border)'}`,
          borderRadius: 9, padding: '6px 28px 6px 10px',
          fontSize: 12.5, fontWeight: 500, color: value ? '#7C3AED' : 'var(--text-3)',
          cursor: 'pointer', outline: 'none', minWidth: 130,
        }}
      >
        <option value="">— Κανείς —</option>
        {options.map(s => <option key={s.id} value={s.id}>{s.full_name}</option>)}
      </select>
      <ChevronDown size={12} style={{ position: 'absolute', right: 8, pointerEvents: 'none', color: value ? '#7C3AED' : 'var(--text-3)' }} />
    </div>
  );
}

export default function Trials() {
  const [rows, setRows] = useState([]);
  const [staffList, setStaffList] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showPast, setShowPast] = useState(true);

  const reload = () => {
    setLoading(true);
    api.get('/client-admin/trials', { params: { past: showPast ? '1' : '0' } })
      .then(r => setRows(r.data || []))
      .catch(e => console.error(e))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    api.get('/client-admin/staff').then(r => setStaffList(r.data || [])).catch(() => {});
  }, []);

  useEffect(() => { reload(); }, [showPast]);

  const setRefer = async (id, staffId) => {
    await api.patch(`/client-admin/trials/${id}/refer`, { referred_by_staff_id: staffId || null });
    reload();
  };

  const toggleMember = async (id, became) => {
    await api.patch(`/client-admin/trials/${id}/refer`, { trial_became_member: became ? 1 : 0 });
    reload();
  };

  const totals = rows.reduce((a, r) => {
    a.total++;
    if (r.trial_became_member) a.converted++;
    if (r.referred_by_staff_id) a.referred++;
    return a;
  }, { total: 0, converted: 0, referred: 0 });

  const convRate = totals.total > 0 ? Math.round((totals.converted / totals.total) * 100) : 0;

  return (
    <Layout>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 28 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <div style={{
            width: 48, height: 48, borderRadius: 16,
            background: 'linear-gradient(135deg,#FCD34D,#F59E0B)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 8px 20px rgba(245,158,11,0.3)',
          }}>
            <Target size={22} color="#fff" strokeWidth={2.5} />
          </div>
          <div>
            <h1 style={{ fontSize: 22, fontWeight: 800, color: 'var(--text)', letterSpacing: '-0.3px' }}>Δοκιμαστικά</h1>
            <p style={{ fontSize: 13, color: 'var(--text-3)', marginTop: 2 }}>Διαχείριση & παρακολούθηση μετατροπών</p>
          </div>
        </div>
        <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', fontSize: 13, fontWeight: 500, color: 'var(--text-2)', background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 10, padding: '8px 14px' }}>
          <input type="checkbox" checked={showPast} onChange={e => setShowPast(e.target.checked)} style={{ accentColor: 'var(--accent)', width: 14, height: 14 }} />
          Εμφάνιση παλαιών
        </label>
      </div>

      {/* Stats */}
      <div style={{ display: 'flex', gap: 14, marginBottom: 24, flexWrap: 'wrap' }}>
        <StatCard label="Σύνολο δοκιμαστικών" value={totals.total} icon={Target} gradient="linear-gradient(135deg,#FCD34D,#F59E0B)" />
        <StatCard label="Έγιναν μέλη" value={totals.converted} icon={UserCheck} gradient="linear-gradient(135deg,#34D399,#10B981)" />
        <StatCard label="Ποσοστό μετατροπής" value={`${convRate}%`} icon={TrendingUp} gradient="linear-gradient(135deg,#60A5FA,#2563EB)" sub={`${totals.converted} από ${totals.total}`} />
        <StatCard label="Μέσω γυμναστή" value={totals.referred} icon={Users} gradient="linear-gradient(135deg,#A78BFA,#7C3AED)" />
      </div>

      {/* Table */}
      {loading ? (
        <div style={{ display: 'flex', justifyContent: 'center', padding: 60 }}>
          <div style={{ width: 36, height: 36, borderRadius: '50%', border: '3px solid var(--border)', borderTopColor: '#F59E0B', animation: 'spin 0.8s linear infinite' }} />
        </div>
      ) : rows.length === 0 ? (
        <div style={{ background: 'var(--surface)', borderRadius: 18, border: '1.5px dashed var(--border)', padding: '60px 20px', textAlign: 'center' }}>
          <div style={{ width: 56, height: 56, borderRadius: '50%', background: 'var(--surface-2)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 14px' }}>
            <Target size={24} color="var(--text-3)" />
          </div>
          <p style={{ fontWeight: 600, fontSize: 15, color: 'var(--text-2)', marginBottom: 4 }}>Δεν υπάρχουν δοκιμαστικά</p>
          <p style={{ fontSize: 13, color: 'var(--text-3)' }}>Τσέκαρε "Εμφάνιση παλαιών" για ιστορικά δεδομένα</p>
        </div>
      ) : (
        <div style={{ background: 'var(--surface)', borderRadius: 18, border: '1px solid var(--border)', overflow: 'hidden' }}>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
              <thead>
                <tr style={{ background: 'var(--surface-2)', borderBottom: '1px solid var(--border)' }}>
                  {['Ημερομηνία', 'Άτομο', 'Υπηρεσία', 'Γυμναστής', 'Από γυμναστή', 'Έγινε μέλος'].map(h => (
                    <th key={h} style={{ padding: '12px 16px', textAlign: 'left', fontWeight: 600, color: 'var(--text-3)', fontSize: 11.5, textTransform: 'uppercase', letterSpacing: '0.4px', whiteSpace: 'nowrap' }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {rows.map((r, i) => (
                  <tr key={r.id} style={{ borderBottom: i < rows.length - 1 ? '1px solid var(--border)' : 'none', transition: 'background 0.12s' }}
                    onMouseEnter={e => e.currentTarget.style.background = 'var(--surface-2)'}
                    onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
                  >
                    <td style={{ padding: '14px 16px', whiteSpace: 'nowrap', color: 'var(--text-3)', fontSize: 12.5 }}>{fmtDate(r.starts_at)}</td>
                    <td style={{ padding: '14px 16px' }}>
                      {r.user_name ? (
                        <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
                          <Avatar name={r.user_name} size={32} color="#7C3AED" />
                          <div>
                            <div style={{ fontWeight: 600, color: 'var(--text)', fontSize: 13 }}>{r.user_name}</div>
                            {r.user_phone && <div style={{ fontSize: 11.5, color: 'var(--text-3)' }}>{r.user_phone}</div>}
                          </div>
                        </div>
                      ) : <span style={{ color: 'var(--border-2)', fontSize: 18 }}>—</span>}
                    </td>
                    <td style={{ padding: '14px 16px' }}>
                      {r.service_name ? (
                        <span style={{ fontSize: 12.5, fontWeight: 500, color: 'var(--text-2)', background: 'var(--surface-2)', padding: '4px 10px', borderRadius: 99 }}>{r.service_name}</span>
                      ) : <span style={{ color: 'var(--border-2)', fontSize: 18 }}>—</span>}
                    </td>
                    <td style={{ padding: '14px 16px' }}>
                      {r.staff_name ? (
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                          <Avatar name={r.staff_name} avatar={r.staff_avatar} color={r.staff_color} size={28} />
                          <span style={{ fontSize: 13, fontWeight: 500, color: 'var(--text-2)' }}>{r.staff_name}</span>
                        </div>
                      ) : <span style={{ color: 'var(--border-2)', fontSize: 18 }}>—</span>}
                    </td>
                    <td style={{ padding: '14px 16px' }}>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                        <StaffDropdown value={r.referred_by_staff_id} options={staffList} onChange={staffId => setRefer(r.id, staffId)} />
                        {r.referred_by_staff_name && (
                          <div style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: 11, color: '#7C3AED', fontWeight: 500 }}>
                            <Avatar name={r.referred_by_staff_name} avatar={r.referred_by_staff_avatar} size={16} color="#7C3AED" />
                            {r.referred_by_staff_name}
                          </div>
                        )}
                      </div>
                    </td>
                    <td style={{ padding: '14px 16px' }}>
                      <button
                        onClick={() => toggleMember(r.id, !r.trial_became_member)}
                        style={{
                          display: 'inline-flex', alignItems: 'center', gap: 6,
                          padding: '6px 14px', borderRadius: 99, border: 'none', cursor: 'pointer',
                          fontSize: 12.5, fontWeight: 700, transition: 'all 0.15s',
                          background: r.trial_became_member ? 'linear-gradient(135deg,#D1FAE5,#A7F3D0)' : 'var(--surface-2)',
                          color: r.trial_became_member ? '#065F46' : 'var(--text-3)',
                          boxShadow: r.trial_became_member ? '0 2px 8px rgba(16,185,129,0.2)' : 'none',
                        }}
                      >
                        {r.trial_became_member ? <UserCheck size={13} /> : <Check size={13} />}
                        {r.trial_became_member ? 'Μέλος' : 'Όχι'}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </Layout>
  );
}
