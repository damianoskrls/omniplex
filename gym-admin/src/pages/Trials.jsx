import { useEffect, useState, useRef } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import { Target, UserCheck, Check, TrendingUp, Pencil, Trash2, RefreshCw, ChevronDown, X, Save, Plus, Clock } from 'lucide-react';

function fmtDate(iso) {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString('el-GR', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
}

function fmtDateInput(iso) {
  if (!iso) return '';
  return new Date(iso).toISOString().slice(0, 10);
}

function fmtTimeInput(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  return `${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`;
}

function isUpcoming(iso) {
  if (!iso) return false;
  return new Date(iso) > new Date();
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

function Toggle({ checked, onChange, activeColor = '#10B981', activeLabel, inactiveLabel, activeIcon }) {
  return (
    <button
      onClick={() => onChange(!checked)}
      style={{
        display: 'inline-flex', alignItems: 'center', gap: 7,
        padding: '5px 10px 5px 6px', borderRadius: 99, border: 'none', cursor: 'pointer',
        fontSize: 12, fontWeight: 700, transition: 'all 0.18s', whiteSpace: 'nowrap',
        background: checked ? activeColor + '22' : 'var(--surface-2)',
        color: checked ? activeColor : 'var(--text-3)',
      }}
    >
      {/* Track */}
      <div style={{
        width: 32, height: 18, borderRadius: 99, position: 'relative', flexShrink: 0,
        background: checked ? activeColor : '#D1D5DB',
        transition: 'background 0.18s',
      }}>
        <div style={{
          position: 'absolute', top: 2, left: checked ? 16 : 2,
          width: 14, height: 14, borderRadius: '50%', background: '#fff',
          boxShadow: '0 1px 3px rgba(0,0,0,0.2)', transition: 'left 0.18s',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          {checked && activeIcon && <span style={{ color: activeColor, lineHeight: 1 }}>{activeIcon}</span>}
        </div>
      </div>
      {checked ? activeLabel : inactiveLabel}
    </button>
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

const PERIODS = [
  { label: 'Αυτόν τον μήνα', value: 'this_month' },
  { label: 'Προηγ. μήνας', value: 'last_month' },
  { label: 'Τελευταίοι 3 μήνες', value: '3months' },
  { label: 'Φέτος', value: 'this_year' },
  { label: 'Όλα', value: 'all' },
];

function periodDates(period) {
  const now = new Date();
  const y = now.getFullYear(), m = now.getMonth();
  if (period === 'this_month') return { from: new Date(y, m, 1), to: new Date(y, m + 1, 0) };
  if (period === 'last_month') return { from: new Date(y, m - 1, 1), to: new Date(y, m, 0) };
  if (period === '3months') return { from: new Date(y, m - 2, 1), to: new Date(y, m + 1, 0) };
  if (period === 'this_year') return { from: new Date(y, 0, 1), to: new Date(y, 11, 31) };
  return null;
}

// ── Edit / Create Modal ─────────────────────────────────────────────────────
function TrialModal({ trial, staffList, services, onClose, onSave, onRepeat }) {
  const isNew = !trial?.id;
  const [form, setForm] = useState({
    trial_date: trial ? fmtDateInput(trial.starts_at) : new Date().toISOString().slice(0, 10),
    trial_time: trial ? fmtTimeInput(trial.starts_at) : '10:00',
    service_id: trial?.service_id || (services[0]?.id ?? ''),
    staff_id: trial?.staff_id || '',
    notes: trial?.notes || '',
    user_id: trial?.user_id || '',
    user_name: trial?.user_name || '',
    user_phone: trial?.user_phone || '',
  });
  const [saving, setSaving] = useState(false);

  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));

  const handleSave = async () => {
    setSaving(true);
    try { await onSave(form); onClose(); }
    catch (e) { alert('Σφάλμα: ' + (e?.response?.data?.error || e.message)); }
    finally { setSaving(false); }
  };

  const inputStyle = {
    width: '100%', padding: '9px 12px', borderRadius: 10,
    border: '1.5px solid var(--border)', background: 'var(--surface-2)',
    color: 'var(--text)', fontSize: 13, outline: 'none', boxSizing: 'border-box',
  };

  const labelStyle = { fontSize: 11.5, fontWeight: 600, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '0.4px', marginBottom: 5, display: 'block' };

  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16 }}
      onClick={e => { if (e.target === e.currentTarget) onClose(); }}>
      <div style={{ background: 'var(--surface)', borderRadius: 20, padding: 28, width: '100%', maxWidth: 460, boxShadow: '0 20px 60px rgba(0,0,0,0.25)', maxHeight: '90vh', overflowY: 'auto' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
          <h3 style={{ fontSize: 16, fontWeight: 700, color: 'var(--text)' }}>
            {isNew ? 'Νέο Δοκιμαστικό' : (onRepeat ? 'Επανάληψη Δοκιμαστικού' : 'Επεξεργασία Δοκιμαστικού')}
          </h3>
          <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-3)', padding: 4 }}><X size={18} /></button>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
          <div>
            <label style={labelStyle}>Ημερομηνία</label>
            <input type="date" value={form.trial_date} onChange={e => set('trial_date', e.target.value)} style={inputStyle} />
          </div>
          <div>
            <label style={labelStyle}>Ώρα</label>
            <input type="time" value={form.trial_time} onChange={e => set('trial_time', e.target.value)} style={inputStyle} />
          </div>
        </div>

        {isNew && (
          <div style={{ marginTop: 14 }}>
            <label style={labelStyle}>Πελάτης (ID)</label>
            <input type="text" value={form.user_id} onChange={e => set('user_id', e.target.value)} placeholder="user_id ή αφήστε κενό" style={inputStyle} />
          </div>
        )}

        <div style={{ marginTop: 14 }}>
          <label style={labelStyle}>Υπηρεσία</label>
          <select value={form.service_id} onChange={e => set('service_id', e.target.value)} style={inputStyle}>
            <option value="">— Χωρίς υπηρεσία —</option>
            {services.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select>
        </div>

        <div style={{ marginTop: 14 }}>
          <label style={labelStyle}>Εκπαιδευτής</label>
          <select value={form.staff_id} onChange={e => set('staff_id', e.target.value)} style={inputStyle}>
            <option value="">— Χωρίς εκπαιδευτή —</option>
            {staffList.map(s => <option key={s.id} value={s.id}>{s.full_name}</option>)}
          </select>
        </div>

        <div style={{ marginTop: 14 }}>
          <label style={labelStyle}>Σχόλια / Σημειώσεις</label>
          <textarea value={form.notes} onChange={e => set('notes', e.target.value)} rows={3}
            placeholder="Προσθήκη σχολίων..."
            style={{ ...inputStyle, resize: 'vertical', fontFamily: 'inherit' }} />
        </div>

        <div style={{ display: 'flex', gap: 10, marginTop: 22 }}>
          <button onClick={onClose} style={{ flex: 1, padding: '10px 0', borderRadius: 12, border: '1.5px solid var(--border)', background: 'var(--surface-2)', color: 'var(--text-2)', fontWeight: 600, cursor: 'pointer', fontSize: 13 }}>Ακύρωση</button>
          <button onClick={handleSave} disabled={saving} style={{ flex: 1, padding: '10px 0', borderRadius: 12, border: 'none', background: 'linear-gradient(135deg,#FCD34D,#F59E0B)', color: '#78350F', fontWeight: 700, cursor: saving ? 'not-allowed' : 'pointer', fontSize: 13, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, opacity: saving ? 0.7 : 1 }}>
            <Save size={14} />{saving ? 'Αποθήκευση...' : 'Αποθήκευση'}
          </button>
        </div>
      </div>
    </div>
  );
}

// ── Delete Confirm ──────────────────────────────────────────────────────────
function DeleteConfirm({ trial, onClose, onConfirm }) {
  const [deleting, setDeleting] = useState(false);
  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16 }}
      onClick={e => { if (e.target === e.currentTarget) onClose(); }}>
      <div style={{ background: 'var(--surface)', borderRadius: 20, padding: 28, width: '100%', maxWidth: 380, boxShadow: '0 20px 60px rgba(0,0,0,0.25)' }}>
        <h3 style={{ fontSize: 16, fontWeight: 700, color: 'var(--text)', marginBottom: 8 }}>Διαγραφή δοκιμαστικού</h3>
        <p style={{ fontSize: 13, color: 'var(--text-2)', marginBottom: 22 }}>
          Θέλεις σίγουρα να διαγράψεις το δοκιμαστικό του <strong>{trial.user_name || 'Άγνωστος'}</strong> στις {fmtDate(trial.starts_at)};
        </p>
        <div style={{ display: 'flex', gap: 10 }}>
          <button onClick={onClose} style={{ flex: 1, padding: '10px 0', borderRadius: 12, border: '1.5px solid var(--border)', background: 'var(--surface-2)', color: 'var(--text-2)', fontWeight: 600, cursor: 'pointer', fontSize: 13 }}>Ακύρωση</button>
          <button onClick={async () => { setDeleting(true); await onConfirm(); onClose(); }} disabled={deleting} style={{ flex: 1, padding: '10px 0', borderRadius: 12, border: 'none', background: '#EF4444', color: '#fff', fontWeight: 700, cursor: deleting ? 'not-allowed' : 'pointer', fontSize: 13, opacity: deleting ? 0.7 : 1 }}>
            {deleting ? 'Διαγραφή...' : 'Διαγραφή'}
          </button>
        </div>
      </div>
    </div>
  );
}

// ── Inline Notes ────────────────────────────────────────────────────────────
function NotesCell({ trial, onSave }) {
  const [editing, setEditing] = useState(false);
  const [val, setVal] = useState(trial.notes || '');
  const [saving, setSaving] = useState(false);
  const ref = useRef();

  useEffect(() => { if (editing && ref.current) ref.current.focus(); }, [editing]);

  const save = async () => {
    if (val === (trial.notes || '')) { setEditing(false); return; }
    setSaving(true);
    await onSave(val);
    setSaving(false);
    setEditing(false);
  };

  if (editing) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <input ref={ref} value={val} onChange={e => setVal(e.target.value)}
          onKeyDown={e => { if (e.key === 'Enter') save(); if (e.key === 'Escape') { setVal(trial.notes || ''); setEditing(false); } }}
          style={{ padding: '5px 9px', borderRadius: 8, border: '1.5px solid #F59E0B', background: 'var(--surface)', color: 'var(--text)', fontSize: 12.5, outline: 'none', width: 160 }}
        />
        <button onClick={save} disabled={saving} style={{ background: '#F59E0B', border: 'none', borderRadius: 6, padding: '4px 8px', cursor: 'pointer', color: '#fff' }}>
          <Check size={12} />
        </button>
        <button onClick={() => { setVal(trial.notes || ''); setEditing(false); }} style={{ background: 'var(--surface-2)', border: 'none', borderRadius: 6, padding: '4px 8px', cursor: 'pointer', color: 'var(--text-3)' }}>
          <X size={12} />
        </button>
      </div>
    );
  }

  return (
    <div onClick={() => setEditing(true)} style={{ cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 6, maxWidth: 180 }}>
      {val ? (
        <span style={{ fontSize: 12, color: 'var(--text-2)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', maxWidth: 150 }}>{val}</span>
      ) : (
        <span style={{ fontSize: 12, color: 'var(--text-3)', fontStyle: 'italic' }}>Προσθήκη σχολίου...</span>
      )}
      <Pencil size={11} color="var(--text-3)" style={{ flexShrink: 0 }} />
    </div>
  );
}

// ── Main page ───────────────────────────────────────────────────────────────
export default function Trials() {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [period, setPeriod] = useState('this_month');
  const [staffList, setStaffList] = useState([]);
  const [services, setServices] = useState([]);
  const [modal, setModal] = useState(null); // null | { type:'edit'|'new'|'repeat', trial?:{} }
  const [deleteTarget, setDeleteTarget] = useState(null);

  const reload = () => {
    setLoading(true);
    const params = {};
    const dates = periodDates(period);
    if (dates) {
      params.from = dates.from.toISOString().slice(0, 10);
      params.to = dates.to.toISOString().slice(0, 10);
    }
    api.get('/client-admin/trials', { params })
      .then(r => setRows(r.data || []))
      .catch(e => console.error(e))
      .finally(() => setLoading(false));
  };

  useEffect(() => { reload(); }, [period]);

  useEffect(() => {
    api.get('/client-admin/staff').then(r => setStaffList(r.data || [])).catch(() => {});
    api.get('/client-admin/services').then(r => setServices(r.data || [])).catch(() => {});
  }, []);

  const toggleMember = async (id, became) => {
    setRows(prev => prev.map(r => r.id === id ? { ...r, trial_became_member: became ? 1 : 0 } : r));
    await api.patch(`/client-admin/trials/${id}/refer`, { trial_became_member: became ? 1 : 0 });
  };

  const toggleConsidering = async (id, val) => {
    setRows(prev => prev.map(r => r.id === id ? { ...r, trial_considering: val ? 1 : 0 } : r));
    await api.patch(`/client-admin/trials/${id}/refer`, { trial_considering: val ? 1 : 0 });
  };

  const updateNotes = async (id, notes) => {
    const row = rows.find(r => r.id === id);
    if (!row) return;
    const date = fmtDateInput(row.starts_at);
    const time = fmtTimeInput(row.starts_at);
    await api.patch(`/client-admin/trials/${id}`, { trial_date: date, trial_time: time, service_id: row.service_id, staff_id: row.staff_id, notes });
    setRows(prev => prev.map(r => r.id === id ? { ...r, notes } : r));
  };

  const handleSaveEdit = async (form) => {
    const id = modal.trial.id;
    await api.patch(`/client-admin/trials/${id}`, form);
    reload();
  };

  const handleSaveNew = async (form) => {
    await api.post('/client-admin/trials', form);
    reload();
  };

  const handleRepeat = async (form) => {
    await api.post('/client-admin/trials', { ...form, user_id: modal.trial.user_id });
    reload();
  };

  const handleDelete = async (id) => {
    await api.delete(`/client-admin/trials/${id}`);
    setRows(prev => prev.filter(r => r.id !== id));
  };

  const updateStaff = async (id, staff_id) => {
    const row = rows.find(r => r.id === id);
    if (!row) return;
    await api.patch(`/client-admin/trials/${id}`, {
      trial_date: fmtDateInput(row.starts_at),
      trial_time: fmtTimeInput(row.starts_at),
      service_id: row.service_id,
      staff_id: staff_id || null,
      notes: row.notes,
    });
    const staff = staffList.find(s => s.id === staff_id);
    setRows(prev => prev.map(r => r.id === id ? {
      ...r, staff_id: staff_id || null,
      staff_name: staff?.full_name || null,
      staff_avatar: staff?.avatar_url || null,
      staff_color: staff?.color_hex || null,
    } : r));
  };

  const totals = rows.reduce((a, r) => {
    a.total++;
    if (r.trial_became_member) a.converted++;
    return a;
  }, { total: 0, converted: 0 });
  const convRate = totals.total > 0 ? Math.round((totals.converted / totals.total) * 100) : 0;

  return (
    <Layout>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20, flexWrap: 'wrap', gap: 12 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <div style={{ width: 48, height: 48, borderRadius: 16, background: 'linear-gradient(135deg,#FCD34D,#F59E0B)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 8px 20px rgba(245,158,11,0.3)' }}>
            <Target size={22} color="#fff" strokeWidth={2.5} />
          </div>
          <div>
            <h1 style={{ fontSize: 22, fontWeight: 800, color: 'var(--text)', letterSpacing: '-0.3px' }}>Δοκιμαστικά</h1>
            <p style={{ fontSize: 13, color: 'var(--text-3)', marginTop: 2 }}>Διαχείριση & παρακολούθηση μετατροπών</p>
          </div>
        </div>
        <button onClick={() => setModal({ type: 'new' })} style={{
          display: 'flex', alignItems: 'center', gap: 7, padding: '10px 18px', borderRadius: 12,
          border: 'none', background: 'linear-gradient(135deg,#FCD34D,#F59E0B)', color: '#78350F',
          fontWeight: 700, fontSize: 13, cursor: 'pointer', boxShadow: '0 4px 12px rgba(245,158,11,0.3)',
        }}>
          <Plus size={15} />Νέο Δοκιμαστικό
        </button>
      </div>

      {/* Period filter chips */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 20, flexWrap: 'wrap' }}>
        {PERIODS.map(p => {
          const active = period === p.value;
          return (
            <button key={p.value} onClick={() => setPeriod(p.value)} style={{
              padding: '7px 16px', borderRadius: 99, border: `1.5px solid ${active ? '#F59E0B' : 'var(--border)'}`,
              background: active ? 'linear-gradient(135deg,#FEF3C7,#FDE68A)' : 'var(--surface)',
              color: active ? '#92400E' : 'var(--text-2)',
              fontWeight: active ? 700 : 500, fontSize: 13, cursor: 'pointer',
              boxShadow: active ? '0 2px 8px rgba(245,158,11,0.2)' : 'none',
              transition: 'all 0.15s',
            }}>{p.label}</button>
          );
        })}
      </div>

      {/* Stats */}
      <div style={{ display: 'flex', gap: 14, marginBottom: 24, flexWrap: 'wrap' }}>
        <StatCard label="Σύνολο δοκιμαστικών" value={totals.total} icon={Target} gradient="linear-gradient(135deg,#FCD34D,#F59E0B)" />
        <StatCard label="Έγιναν μέλη" value={totals.converted} icon={UserCheck} gradient="linear-gradient(135deg,#34D399,#10B981)" />
        <StatCard label="Ποσοστό μετατροπής" value={`${convRate}%`} icon={TrendingUp} gradient="linear-gradient(135deg,#60A5FA,#2563EB)" sub={`${totals.converted} από ${totals.total}`} />
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
          <p style={{ fontSize: 13, color: 'var(--text-3)' }}>Επίλεξε άλλη χρονική περίοδο ή πρόσθεσε νέο δοκιμαστικό</p>
        </div>
      ) : (
        <div style={{ background: 'var(--surface)', borderRadius: 18, border: '1px solid var(--border)', overflow: 'hidden' }}>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
              <thead>
                <tr style={{ background: 'var(--surface-2)', borderBottom: '1px solid var(--border)' }}>
                  {['Ημερομηνία', 'Άτομο', 'Υπηρεσία', 'Εκπαιδευτής', 'Σχόλια', 'Σκέφτεται', 'Έγινε μέλος', 'Ενέργειες'].map(h => (
                    <th key={h} style={{ padding: '12px 14px', textAlign: 'left', fontWeight: 600, color: 'var(--text-3)', fontSize: 11.5, textTransform: 'uppercase', letterSpacing: '0.4px', whiteSpace: 'nowrap' }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {rows.map((r, i) => {
                  const upcoming = isUpcoming(r.starts_at);
                  return (
                    <tr key={r.id} style={{ borderBottom: i < rows.length - 1 ? '1px solid var(--border)' : 'none', transition: 'background 0.12s' }}
                      onMouseEnter={e => e.currentTarget.style.background = 'var(--surface-2)'}
                      onMouseLeave={e => e.currentTarget.style.background = 'transparent'}>

                      {/* Date */}
                      <td style={{ padding: '13px 14px', whiteSpace: 'nowrap' }}>
                        <div style={{ fontSize: 12.5, color: 'var(--text-2)', fontWeight: 500 }}>{fmtDate(r.starts_at)}</div>
                        {upcoming && (
                          <span style={{ marginTop: 4, display: 'inline-block', fontSize: 10.5, fontWeight: 700, background: 'linear-gradient(135deg,#DBEAFE,#BFDBFE)', color: '#1D4ED8', borderRadius: 6, padding: '2px 7px' }}>
                            Προγρ/νο
                          </span>
                        )}
                      </td>

                      {/* Person */}
                      <td style={{ padding: '13px 14px' }}>
                        {r.user_name ? (
                          <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
                            <Avatar name={r.user_name} size={32} color="#7C3AED" />
                            <div>
                              <div style={{ fontWeight: 600, color: 'var(--text)', fontSize: 13 }}>{r.user_name}</div>
                              {r.user_phone && <div style={{ fontSize: 11.5, color: 'var(--text-3)' }}>{r.user_phone}</div>}
                            </div>
                          </div>
                        ) : <span style={{ color: 'var(--text-3)' }}>—</span>}
                      </td>

                      {/* Service */}
                      <td style={{ padding: '13px 14px' }}>
                        {r.service_name
                          ? <span style={{ fontSize: 12.5, fontWeight: 500, color: 'var(--text-2)', background: 'var(--surface-2)', padding: '4px 10px', borderRadius: 99, whiteSpace: 'nowrap' }}>{r.service_name}</span>
                          : <span style={{ color: 'var(--text-3)' }}>—</span>}
                      </td>

                      {/* Trainer inline dropdown with avatar */}
                      <td style={{ padding: '13px 14px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                          {r.staff_name && (
                            <Avatar name={r.staff_name} avatar={r.staff_avatar} color={r.staff_color} size={26} />
                          )}
                          <div style={{ position: 'relative' }}>
                            <select
                              value={r.staff_id || ''}
                              onChange={e => updateStaff(r.id, e.target.value)}
                              style={{
                                appearance: 'none', WebkitAppearance: 'none',
                                padding: '5px 26px 5px 9px',
                                borderRadius: 99, border: '1.5px solid var(--border)',
                                background: r.staff_name ? 'var(--surface-2)' : 'var(--surface)',
                                color: r.staff_name ? 'var(--text-2)' : 'var(--text-3)',
                                fontSize: 12.5, fontWeight: r.staff_name ? 600 : 400,
                                cursor: 'pointer', outline: 'none', minWidth: 110,
                              }}
                            >
                              <option value="">— Εκπαιδευτής —</option>
                              {staffList.map(s => <option key={s.id} value={s.id}>{s.full_name}</option>)}
                            </select>
                            <ChevronDown size={11} style={{ position: 'absolute', right: 8, top: '50%', transform: 'translateY(-50%)', pointerEvents: 'none', color: 'var(--text-3)' }} />
                          </div>
                        </div>
                      </td>

                      {/* Notes inline */}
                      <td style={{ padding: '13px 14px' }}>
                        <NotesCell trial={r} onSave={notes => updateNotes(r.id, notes)} />
                      </td>

                      {/* Considering toggle */}
                      <td style={{ padding: '13px 14px' }}>
                        <Toggle
                          checked={!!r.trial_considering}
                          onChange={val => toggleConsidering(r.id, val)}
                          activeColor="#F59E0B"
                          activeLabel="Ναι"
                          inactiveLabel="Όχι"
                        />
                      </td>

                      {/* Became member toggle */}
                      <td style={{ padding: '13px 14px' }}>
                        <Toggle
                          checked={!!r.trial_became_member}
                          onChange={val => toggleMember(r.id, val)}
                          activeColor="#10B981"
                          activeLabel="Μέλος"
                          inactiveLabel="Όχι"
                          activeIcon={<UserCheck size={12} />}
                        />
                      </td>

                      {/* Actions */}
                      <td style={{ padding: '13px 14px' }}>
                        <div style={{ display: 'flex', gap: 6, flexWrap: 'nowrap' }}>
                          <button onClick={() => setModal({ type: 'edit', trial: r })}
                            style={{ height: 30, padding: '0 10px', borderRadius: 8, border: '1px solid var(--border)', background: 'var(--surface-2)', color: 'var(--text-2)', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 5, fontSize: 12, fontWeight: 500, whiteSpace: 'nowrap' }}>
                            <Pencil size={12} />Επεξεργασία
                          </button>
                          <button onClick={() => setModal({ type: 'repeat', trial: r })}
                            style={{ height: 30, padding: '0 10px', borderRadius: 8, border: '1px solid #DBEAFE', background: '#EFF6FF', color: '#2563EB', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 5, fontSize: 12, fontWeight: 600, whiteSpace: 'nowrap' }}>
                            <RefreshCw size={12} />Επανάληψη
                          </button>
                          <button onClick={() => setDeleteTarget(r)}
                            style={{ width: 30, height: 30, borderRadius: 8, border: '1px solid #FEE2E2', background: '#FEF2F2', color: '#EF4444', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                            <Trash2 size={13} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Modals */}
      {modal?.type === 'edit' && (
        <TrialModal
          trial={modal.trial} staffList={staffList} services={services}
          onClose={() => setModal(null)}
          onSave={handleSaveEdit}
        />
      )}
      {modal?.type === 'new' && (
        <TrialModal
          trial={null} staffList={staffList} services={services}
          onClose={() => setModal(null)}
          onSave={handleSaveNew}
        />
      )}
      {modal?.type === 'repeat' && (
        <TrialModal
          trial={modal.trial} staffList={staffList} services={services}
          onClose={() => setModal(null)}
          onSave={handleRepeat}
          onRepeat
        />
      )}
      {deleteTarget && (
        <DeleteConfirm
          trial={deleteTarget}
          onClose={() => setDeleteTarget(null)}
          onConfirm={() => handleDelete(deleteTarget.id)}
        />
      )}

      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </Layout>
  );
}
