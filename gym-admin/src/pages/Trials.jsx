import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import { Target, Check, UserCheck, ChevronDown } from 'lucide-react';

function fmtDate(iso) {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString('el-GR', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
}

function Avatar({ name, avatar, color, size = 28 }) {
  if (avatar) return <img src={avatar} alt={name} style={{ width: size, height: size, borderRadius: '50%', objectFit: 'cover' }} />;
  const initials = (name || '?').split(' ').map(w => w[0]).slice(0, 2).join('');
  return (
    <div style={{ width: size, height: size, borderRadius: '50%', background: color || '#94A3B8', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontSize: size * 0.36, fontWeight: 700 }}>
      {initials}
    </div>
  );
}

export default function Trials() {
  const [rows, setRows] = useState([]);
  const [staffList, setStaffList] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showPast, setShowPast] = useState(false);
  const [editId, setEditId] = useState(null);

  const reload = () => {
    setLoading(true);
    api.get('/trials', { params: { past: showPast ? '1' : '0' } })
      .then(r => setRows(r.data))
      .catch(e => console.error(e))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    api.get('/staff').then(r => setStaffList(r.data)).catch(() => {});
  }, []);

  useEffect(() => { reload(); }, [showPast]);

  const setRefer = async (id, staffId) => {
    await api.patch(`/trials/${id}/refer`, { referred_by_staff_id: staffId || null });
    reload();
  };

  const toggleMember = async (id, became) => {
    await api.patch(`/trials/${id}/refer`, { trial_became_member: became ? 1 : 0 });
    reload();
  };

  const totals = rows.reduce((acc, r) => {
    acc.total++;
    if (r.trial_became_member) acc.converted++;
    if (r.referred_by_staff_id) acc.referred++;
    return acc;
  }, { total: 0, converted: 0, referred: 0 });

  return (
    <Layout>
      <div className="page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 44, height: 44, borderRadius: 14, background: 'linear-gradient(135deg,#fef3c7,#fde68a)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#D97706' }}>
            <Target size={22} />
          </div>
          <div>
            <h1 className="page-title">Δοκιμαστικά</h1>
            <div className="text-muted" style={{ marginTop: 2 }}>Διαχείριση & παρακολούθηση μετατροπών</div>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, cursor: 'pointer', color: 'var(--color-text-muted)' }}>
            <input type="checkbox" checked={showPast} onChange={e => setShowPast(e.target.checked)} />
            Εμφάνιση παλαιών
          </label>
        </div>
      </div>

      {/* KPI row */}
      <div style={{ display: 'flex', gap: 14, flexWrap: 'wrap', marginBottom: 24 }}>
        {[
          { label: 'Σύνολο', value: totals.total, color: '#D97706', bg: '#fef3c7' },
          { label: 'Έγιναν μέλη', value: totals.converted, color: '#16A34A', bg: '#dcfce7' },
          { label: 'Μετατροπή', value: totals.total ? `${Math.round((totals.converted / totals.total) * 100)}%` : '—', color: '#2563EB', bg: '#dbeafe' },
          { label: 'Με γυμναστή', value: totals.referred, color: '#7C3AED', bg: '#ede9fe' },
        ].map((k, i) => (
          <div key={i} className="bk-card" style={{ flex: '1 1 140px', minWidth: 120 }}>
            <div style={{ width: 32, height: 32, borderRadius: 9, background: k.bg, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 8 }}>
              <Target size={15} color={k.color} />
            </div>
            <div style={{ fontSize: 26, fontWeight: 800, color: 'var(--color-text)', lineHeight: 1 }}>{k.value}</div>
            <div style={{ fontSize: 12, color: '#64748B', marginTop: 4 }}>{k.label}</div>
          </div>
        ))}
      </div>

      {loading ? <div className="loading">Φόρτωση…</div> : rows.length === 0 ? (
        <div className="bk-empty">Δεν υπάρχουν δοκιμαστικά</div>
      ) : (
        <div className="bk-card" style={{ padding: 0, overflow: 'hidden' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
            <thead>
              <tr style={{ borderBottom: '1px solid var(--color-border)', background: 'var(--color-surface-alt, #F8FAFC)' }}>
                {['Ημ/νία', 'Άτομο', 'Υπηρεσία', 'Γυμναστής', 'Από γυμναστή', 'Μέλος;'].map(h => (
                  <th key={h} style={{ padding: '10px 14px', textAlign: 'left', fontWeight: 600, color: '#64748B', fontSize: 12 }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map(r => (
                <tr key={r.id} style={{ borderBottom: '1px solid var(--color-border)' }}>
                  <td style={{ padding: '10px 14px', whiteSpace: 'nowrap', color: '#64748B' }}>{fmtDate(r.starts_at)}</td>
                  <td style={{ padding: '10px 14px' }}>
                    <div style={{ fontWeight: 600 }}>{r.user_name || '—'}</div>
                    {r.user_phone && <div style={{ fontSize: 11, color: '#94A3B8' }}>{r.user_phone}</div>}
                  </td>
                  <td style={{ padding: '10px 14px', color: '#475569' }}>{r.service_name || '—'}</td>
                  <td style={{ padding: '10px 14px' }}>
                    {r.staff_name ? (
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                        <Avatar name={r.staff_name} avatar={r.staff_avatar} color={r.staff_color} />
                        <span style={{ fontSize: 12 }}>{r.staff_name}</span>
                      </div>
                    ) : <span style={{ color: '#CBD5E1' }}>—</span>}
                  </td>
                  <td style={{ padding: '10px 14px' }}>
                    <div style={{ position: 'relative', display: 'inline-block' }}>
                      <select
                        value={r.referred_by_staff_id || ''}
                        onChange={e => setRefer(r.id, e.target.value)}
                        style={{ fontSize: 12, padding: '4px 24px 4px 8px', borderRadius: 7, border: '1px solid var(--color-border)', background: 'var(--color-surface)', color: 'var(--color-text)', appearance: 'none', cursor: 'pointer', minWidth: 120 }}
                      >
                        <option value="">— Κανείς —</option>
                        {staffList.map(s => (
                          <option key={s.id} value={s.id}>{s.full_name}</option>
                        ))}
                      </select>
                      <ChevronDown size={12} style={{ position: 'absolute', right: 7, top: '50%', transform: 'translateY(-50%)', pointerEvents: 'none', color: '#94A3B8' }} />
                    </div>
                    {r.referred_by_staff_name && (
                      <div style={{ fontSize: 11, color: '#7C3AED', marginTop: 3, display: 'flex', alignItems: 'center', gap: 4 }}>
                        <Avatar name={r.referred_by_staff_name} avatar={r.referred_by_staff_avatar} size={16} />
                        {r.referred_by_staff_name}
                      </div>
                    )}
                  </td>
                  <td style={{ padding: '10px 14px' }}>
                    <button
                      onClick={() => toggleMember(r.id, !r.trial_became_member)}
                      style={{ display: 'inline-flex', alignItems: 'center', gap: 5, padding: '5px 12px', borderRadius: 8, border: 'none', cursor: 'pointer', fontSize: 12, fontWeight: 600, background: r.trial_became_member ? '#dcfce7' : '#F1F5F9', color: r.trial_became_member ? '#16A34A' : '#94A3B8' }}
                    >
                      {r.trial_became_member ? <><UserCheck size={13} /> Μέλος</> : <><Check size={13} /> Όχι</>}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Layout>
  );
}
