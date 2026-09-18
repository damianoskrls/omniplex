import { useEffect, useState, useRef } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import {
  Target, UserCheck, Check, TrendingUp, Pencil, Trash2, RefreshCw,
  ChevronDown, X, Save, Plus, ChevronLeft, ChevronRight, BarChart2,
  Calendar, Clock, Users, Award,
} from 'lucide-react';
import TimeInput from '../components/ui/TimeInput';

// ── Helpers ─────────────────────────────────────────────────────────────────
function toDateKey(d) { return d.toISOString().slice(0, 10); }
function fmtDay(d) {
  return d.toLocaleDateString('el-GR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
}
function fmtShortDay(d) {
  return d.toLocaleDateString('el-GR', { weekday: 'short', day: 'numeric', month: 'short' });
}
function fmtTime(iso) {
  if (!iso) return '';
  return new Date(iso).toLocaleTimeString('el-GR', { hour: '2-digit', minute: '2-digit' });
}
function fmtDateInput(iso) { return iso ? new Date(iso).toISOString().slice(0, 10) : ''; }
function fmtTimeInput(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  return `${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`;
}
function isToday(d) { return toDateKey(d) === toDateKey(new Date()); }
function isTomorrow(d) { const t = new Date(); t.setDate(t.getDate()+1); return toDateKey(d) === toDateKey(t); }
function isYesterday(d) { const t = new Date(); t.setDate(t.getDate()-1); return toDateKey(d) === toDateKey(t); }
function dayLabel(d) {
  if (isToday(d)) return 'Σήμερα';
  if (isTomorrow(d)) return 'Αύριο';
  if (isYesterday(d)) return 'Χθες';
  return fmtShortDay(d);
}

function Avatar({ name, avatar, color, size = 30 }) {
  const bg = color || '#7C3AED';
  const initials = (name || '?').split(' ').map(w => w[0]).slice(0, 2).join('').toUpperCase();
  if (avatar) return <img src={avatar} alt={name} style={{ width: size, height: size, borderRadius: '50%', objectFit: 'cover', flexShrink: 0 }} />;
  return (
    <div style={{ width: size, height: size, borderRadius: '50%', background: bg, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontSize: size * 0.36, fontWeight: 700, flexShrink: 0 }}>
      {initials}
    </div>
  );
}

function Toggle({ checked, onChange, activeColor = '#10B981', activeLabel, inactiveLabel, activeIcon }) {
  return (
    <button onClick={() => onChange(!checked)} style={{
      display: 'inline-flex', alignItems: 'center', gap: 7,
      padding: '4px 10px 4px 5px', borderRadius: 99, border: 'none', cursor: 'pointer',
      fontSize: 11.5, fontWeight: 700, transition: 'all 0.18s', whiteSpace: 'nowrap',
      background: checked ? activeColor + '22' : 'var(--surface-2)',
      color: checked ? activeColor : 'var(--text-3)',
    }}>
      <div style={{ width: 28, height: 16, borderRadius: 99, position: 'relative', flexShrink: 0, background: checked ? activeColor : '#D1D5DB', transition: 'background 0.18s' }}>
        <div style={{ position: 'absolute', top: 2, left: checked ? 14 : 2, width: 12, height: 12, borderRadius: '50%', background: '#fff', boxShadow: '0 1px 3px rgba(0,0,0,0.2)', transition: 'left 0.18s' }} />
      </div>
      {checked ? activeLabel : inactiveLabel}
    </button>
  );
}

// ── Client Search inside modal ───────────────────────────────────────────────
function ClientPicker({ value, valueName, valuePhone, onChange, clients }) {
  const [query, setQuery] = useState('');
  const [showList, setShowList] = useState(false);
  const [newMode, setNewMode] = useState(false);
  const [newClient, setNewClient] = useState({ full_name: '', phone: '' });

  function normalize(s) { return String(s||'').toLowerCase().normalize('NFD').replace(/\p{M}/gu,''); }
  const filtered = clients.filter(c =>
    normalize(c.full_name).includes(normalize(query)) || (c.phone||'').includes(query)
  ).slice(0,20);

  const inp = { width: '100%', padding: '8px 11px', borderRadius: 9, border: '1.5px solid var(--border)', background: 'var(--surface-2)', color: 'var(--text)', fontSize: 13, outline: 'none', boxSizing: 'border-box' };
  const lbl = { fontSize: 11, fontWeight: 600, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '0.4px', marginBottom: 4, display: 'block' };

  if (value && !newMode) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 12px', background: 'var(--surface-2)', borderRadius: 10, border: '1.5px solid var(--border)' }}>
        <Avatar name={valueName} size={30} />
        <div style={{ flex: 1 }}>
          <div style={{ fontWeight: 700, fontSize: 13, color: 'var(--text)' }}>{valueName}</div>
          {valuePhone && <div style={{ fontSize: 11.5, color: 'var(--text-3)' }}>{valuePhone}</div>}
        </div>
        <button type="button" onClick={() => onChange(null,null,null)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-3)', fontSize: 12 }}>Αλλαγή</button>
      </div>
    );
  }

  if (newMode) {
    return (
      <div style={{ background: 'var(--surface-2)', borderRadius: 10, padding: 12, border: '1.5px solid var(--border)' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 8 }}>
          <div><label style={lbl}>Ονοματεπώνυμο *</label>
            <input style={inp} placeholder="Γιώργης Παπάς" value={newClient.full_name} onChange={e => setNewClient(n=>({...n,full_name:e.target.value}))} autoFocus />
          </div>
          <div><label style={lbl}>Κινητό *</label>
            <input style={inp} placeholder="69XXXXXXXX" value={newClient.phone} onChange={e => setNewClient(n=>({...n,phone:e.target.value}))} />
          </div>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button type="button" onClick={() => {
            if (!newClient.full_name.trim()) return;
            onChange('__new__', newClient.full_name.trim(), newClient.phone.trim(), newClient);
            setNewMode(false);
          }} style={{ padding: '5px 12px', borderRadius: 8, border: 'none', background: '#76C043', color: '#fff', fontWeight: 600, fontSize: 12, cursor: 'pointer' }}>
            Επιβεβαίωση
          </button>
          <button type="button" onClick={() => setNewMode(false)} style={{ padding: '5px 12px', borderRadius: 8, border: '1.5px solid var(--border)', background: 'transparent', color: 'var(--text-3)', fontWeight: 600, fontSize: 12, cursor: 'pointer' }}>
            Πίσω
          </button>
        </div>
      </div>
    );
  }

  return (
    <div>
      <div style={{ position: 'relative' }}>
        <input style={inp} placeholder="Αναζήτηση ονόματος ή κινητού..."
          value={query} onChange={e=>{setQuery(e.target.value);setShowList(true);}}
          onFocus={()=>setShowList(true)} onBlur={()=>setTimeout(()=>setShowList(false),180)}
          autoComplete="off" />
      </div>
      {showList && (
        <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 10, boxShadow: '0 4px 16px rgba(0,0,0,.1)', maxHeight: 180, overflowY: 'auto', marginTop: 4 }}>
          {filtered.map(c => (
            <button key={c.id} type="button" onMouseDown={() => { onChange(c.id, c.full_name, c.phone||''); setQuery(''); setShowList(false); }}
              style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 10, padding: '8px 12px', background: 'none', border: 'none', cursor: 'pointer', textAlign: 'left' }}>
              <Avatar name={c.full_name} size={28} />
              <div>
                <div style={{ fontWeight: 600, fontSize: 13, color: 'var(--text)' }}>{c.full_name}</div>
                {c.phone && <div style={{ fontSize: 11.5, color: 'var(--text-3)' }}>{c.phone}</div>}
              </div>
            </button>
          ))}
          {filtered.length === 0 && <div style={{ padding: '10px 14px', color: 'var(--text-3)', fontSize: 12.5 }}>Δεν βρέθηκαν</div>}
        </div>
      )}
      <button type="button" onClick={() => setNewMode(true)} style={{ marginTop: 6, background: 'none', border: 'none', color: '#76C043', fontWeight: 600, fontSize: 12.5, cursor: 'pointer', padding: 0, display: 'flex', alignItems: 'center', gap: 4 }}>
        + Νέος πελάτης
      </button>
    </div>
  );
}

// ── Modals ───────────────────────────────────────────────────────────────────
function TrialModal({ trial, staffList, services, clients, onClose, onSave, isRepeat }) {
  const isNew = !trial?.id || isRepeat;
  const [form, setForm] = useState({
    trial_date: trial ? fmtDateInput(trial.starts_at) : new Date().toISOString().slice(0, 10),
    trial_time: trial ? fmtTimeInput(trial.starts_at) : '10:00',
    service_id: trial?.service_id || '',
    staff_id: trial?.staff_id || '',
    notes: isRepeat ? '' : (trial?.notes || ''),
    user_id: isRepeat ? (trial?.user_id || '') : (trial?.user_id || ''),
    user_name: isRepeat ? (trial?.user_name || '') : (trial?.user_name || ''),
    user_phone: trial?.user_phone || '',
    new_client: null,
  });
  const [saving, setSaving] = useState(false);
  const [takenServiceIds, setTakenServiceIds] = useState([]);

  useEffect(() => {
    const uid = form.user_id;
    if (uid && uid !== '__new__') {
      api.get(`/client-admin/clients/${uid}/active-service-ids`).then(r => setTakenServiceIds(r.data || [])).catch(() => {});
    } else {
      setTakenServiceIds([]);
    }
  }, [form.user_id]);
  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));

  const handleClientChange = (id, name, phone, newClientData) => {
    if (id === '__new__') {
      setForm(f => ({ ...f, user_id: '', user_name: name, user_phone: phone, new_client: newClientData }));
    } else if (id === null) {
      setForm(f => ({ ...f, user_id: '', user_name: '', user_phone: '', new_client: null }));
    } else {
      setForm(f => ({ ...f, user_id: id, user_name: name, user_phone: phone, new_client: null }));
    }
  };

  const handleSave = async () => {
    setSaving(true);
    try { await onSave(form); onClose(); }
    catch (e) { alert('Σφάλμα: ' + (e?.response?.data?.error || e.message)); }
    finally { setSaving(false); }
  };

  const inp = { width: '100%', padding: '9px 12px', borderRadius: 10, border: '1.5px solid var(--border)', background: 'var(--surface-2)', color: 'var(--text)', fontSize: 13, outline: 'none', boxSizing: 'border-box' };
  const lbl = { fontSize: 11.5, fontWeight: 600, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '0.4px', marginBottom: 5, display: 'block' };

  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16 }}
      onClick={e => { if (e.target === e.currentTarget) onClose(); }}>
      <div style={{ background: 'var(--surface)', borderRadius: 20, padding: 28, width: '100%', maxWidth: 460, boxShadow: '0 24px 64px rgba(0,0,0,0.2)', maxHeight: '90vh', overflowY: 'auto' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 22 }}>
          <h3 style={{ fontSize: 16, fontWeight: 700, color: 'var(--text)', margin: 0 }}>
            {isRepeat ? 'Επανάληψη Δοκιμαστικού' : (trial?.id ? 'Επεξεργασία' : 'Νέο Δοκιμαστικό')}
          </h3>
          <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-3)', padding: 6, borderRadius: '50%', display: 'flex' }}>
            <X size={18} />
          </button>
        </div>

        {isRepeat && trial?.user_name && (
          <div style={{ background: 'var(--surface-2)', borderRadius: 12, padding: '10px 14px', marginBottom: 16, fontSize: 13, color: 'var(--text-2)' }}>
            Επανάληψη για: <strong>{trial.user_name}</strong>
          </div>
        )}

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
          <div><label style={lbl}>Ημερομηνία</label><input type="date" value={form.trial_date} onChange={e => set('trial_date', e.target.value)} style={inp} /></div>
          <div><label style={lbl}>Ώρα</label><TimeInput value={form.trial_time} onChange={val => set('trial_time', val)} /></div>
        </div>

        {!isRepeat && (
          <div style={{ marginTop: 14 }}>
            <label style={lbl}>Πελάτης <span style={{ fontWeight: 400, textTransform: 'none', letterSpacing: 0 }}>(προαιρετικό)</span></label>
            <ClientPicker
              value={form.user_id || form.new_client ? (form.user_id || '__new__') : ''}
              valueName={form.user_name}
              valuePhone={form.user_phone}
              onChange={handleClientChange}
              clients={clients}
            />
          </div>
        )}

        <div style={{ marginTop: 14 }}><label style={lbl}>Υπηρεσία</label>
          <select value={form.service_id} onChange={e => set('service_id', e.target.value)} style={inp}>
            <option value="">— Χωρίς υπηρεσία —</option>
            {services
              .filter(s => s.category !== 'nutrition_consultation')
              .map(s => (
                <option key={s.id} value={s.id} disabled={takenServiceIds.includes(s.id)}>
                  {s.name}{takenServiceIds.includes(s.id) ? ' (ήδη μέλος)' : ''}
                </option>
              ))}
          </select>
        </div>
        <div style={{ marginTop: 14 }}><label style={lbl}>Εκπαιδευτής</label>
          <select value={form.staff_id} onChange={e => set('staff_id', e.target.value)} style={inp}>
            <option value="">— Χωρίς εκπαιδευτή —</option>
            {staffList.map(s => <option key={s.id} value={s.id}>{s.full_name}</option>)}
          </select>
        </div>
        <div style={{ marginTop: 14 }}><label style={lbl}>Σχόλια</label>
          <textarea value={form.notes} onChange={e => set('notes', e.target.value)} rows={3} placeholder="Σημειώσεις..." style={{ ...inp, resize: 'vertical', fontFamily: 'inherit' }} />
        </div>
        <div style={{ display: 'flex', gap: 10, marginTop: 22 }}>
          <button onClick={onClose} style={{ flex: 1, padding: '10px 0', borderRadius: 12, border: '1.5px solid var(--border)', background: 'var(--surface-2)', color: 'var(--text-2)', fontWeight: 600, cursor: 'pointer', fontSize: 13 }}>Ακύρωση</button>
          <button onClick={handleSave} disabled={saving} style={{ flex: 2, padding: '10px 0', borderRadius: 12, border: 'none', background: 'linear-gradient(135deg,#FCD34D,#F59E0B)', color: '#78350F', fontWeight: 700, cursor: saving ? 'not-allowed' : 'pointer', fontSize: 13, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, opacity: saving ? 0.7 : 1 }}>
            <Save size={14} />{saving ? 'Αποθήκευση...' : 'Αποθήκευση'}
          </button>
        </div>
      </div>
    </div>
  );
}

// ── Mini popup: create client when becoming member ───────────────────────────
function MemberClientModal({ onClose, onConfirm }) {
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [saving, setSaving] = useState(false);
  const inp = { width: '100%', padding: '9px 12px', borderRadius: 10, border: '1.5px solid var(--border)', background: 'var(--surface-2)', color: 'var(--text)', fontSize: 13, outline: 'none', boxSizing: 'border-box' };
  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', zIndex: 1100, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16 }}
      onClick={e => { if (e.target === e.currentTarget) onClose(); }}>
      <div style={{ background: 'var(--surface)', borderRadius: 18, padding: 24, width: '100%', maxWidth: 360, boxShadow: '0 24px 64px rgba(0,0,0,0.2)' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
          <h3 style={{ fontSize: 15, fontWeight: 700, color: 'var(--text)', margin: 0 }}>Δημιουργία πελάτη</h3>
          <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-3)', borderRadius: '50%', padding: 4, display: 'flex' }}><X size={17}/></button>
        </div>
        <p style={{ fontSize: 13, color: 'var(--text-3)', marginBottom: 16, marginTop: 0 }}>
          Το δοκιμαστικό δεν έχει συνδεδεμένο πελάτη. Συμπλήρωσε τα στοιχεία για να δημιουργήσεις τον πελάτη.
        </p>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 18 }}>
          <div>
            <label style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '0.4px', marginBottom: 4, display: 'block' }}>Ονοματεπώνυμο *</label>
            <input style={inp} placeholder="Γιώργης Παπάς" value={name} onChange={e=>setName(e.target.value)} autoFocus />
          </div>
          <div>
            <label style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '0.4px', marginBottom: 4, display: 'block' }}>Κινητό</label>
            <input style={inp} placeholder="69XXXXXXXX" value={phone} onChange={e=>setPhone(e.target.value)} />
          </div>
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <button onClick={onClose} style={{ flex: 1, padding: '10px 0', borderRadius: 10, border: '1.5px solid var(--border)', background: 'var(--surface-2)', color: 'var(--text-2)', fontWeight: 600, fontSize: 13, cursor: 'pointer' }}>Άκυρο</button>
          <button disabled={!name.trim() || saving} onClick={async () => {
            setSaving(true);
            await onConfirm({ full_name: name.trim(), phone: phone.trim() });
            setSaving(false); onClose();
          }} style={{ flex: 2, padding: '10px 0', borderRadius: 10, border: 'none', background: name.trim() ? '#10B981' : '#D1D5DB', color: '#fff', fontWeight: 700, fontSize: 13, cursor: name.trim() ? 'pointer' : 'not-allowed' }}>
            {saving ? 'Αποθήκευση...' : 'Αποθήκευση & επιβεβαίωση'}
          </button>
        </div>
      </div>
    </div>
  );
}

function DeleteConfirm({ trial, onClose, onConfirm }) {
  const [deleting, setDeleting] = useState(false);
  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16 }}
      onClick={e => { if (e.target === e.currentTarget) onClose(); }}>
      <div style={{ background: 'var(--surface)', borderRadius: 20, padding: 28, width: '100%', maxWidth: 380, boxShadow: '0 24px 64px rgba(0,0,0,0.2)' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
          <h3 style={{ fontSize: 16, fontWeight: 700, color: 'var(--text)', margin: 0 }}>Διαγραφή δοκιμαστικού</h3>
          <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-3)', padding: 6, borderRadius: '50%', display: 'flex' }}><X size={18} /></button>
        </div>
        <p style={{ fontSize: 13, color: 'var(--text-2)', marginBottom: 22 }}>
          Διαγραφή δοκιμαστικού <strong>{trial.user_name || 'Άγνωστος'}</strong> στις {fmtTime(trial.starts_at)};
        </p>
        <div style={{ display: 'flex', gap: 10 }}>
          <button onClick={onClose} style={{ flex: 1, padding: '10px 0', borderRadius: 12, border: '1.5px solid var(--border)', background: 'var(--surface-2)', color: 'var(--text-2)', fontWeight: 600, cursor: 'pointer', fontSize: 13 }}>Ακύρωση</button>
          <button onClick={async () => { setDeleting(true); await onConfirm(); onClose(); }} disabled={deleting} style={{ flex: 1, padding: '10px 0', borderRadius: 12, border: 'none', background: '#EF4444', color: '#fff', fontWeight: 700, cursor: 'pointer', fontSize: 13, opacity: deleting ? 0.7 : 1 }}>
            {deleting ? 'Διαγραφή...' : 'Διαγραφή'}
          </button>
        </div>
      </div>
    </div>
  );
}

// ── Inline notes ────────────────────────────────────────────────────────────
function NotesCell({ trial, onSave }) {
  const [editing, setEditing] = useState(false);
  const [val, setVal] = useState(trial.notes || '');
  const [saving, setSaving] = useState(false);
  const ref = useRef();
  useEffect(() => { if (editing && ref.current) ref.current.focus(); }, [editing]);
  const save = async () => {
    if (val === (trial.notes || '')) { setEditing(false); return; }
    setSaving(true); await onSave(val); setSaving(false); setEditing(false);
  };
  if (editing) return (
    <div style={{ display: 'flex', gap: 5, marginTop: 6 }}>
      <input ref={ref} value={val} onChange={e => setVal(e.target.value)}
        onKeyDown={e => { if (e.key === 'Enter') save(); if (e.key === 'Escape') { setVal(trial.notes||''); setEditing(false); } }}
        style={{ flex: 1, padding: '5px 9px', borderRadius: 8, border: '1.5px solid #F59E0B', background: 'var(--surface)', color: 'var(--text)', fontSize: 12.5, outline: 'none' }} />
      <button onClick={save} disabled={saving} style={{ background: '#F59E0B', border: 'none', borderRadius: 6, padding: '5px 8px', cursor: 'pointer', color: '#fff' }}><Check size={11} /></button>
      <button onClick={() => { setVal(trial.notes||''); setEditing(false); }} style={{ background: 'var(--surface-2)', border: 'none', borderRadius: 6, padding: '5px 8px', cursor: 'pointer', color: 'var(--text-3)' }}><X size={11} /></button>
    </div>
  );
  return (
    <div onClick={() => setEditing(true)} style={{ cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 5, marginTop: 4 }}>
      {val
        ? <span style={{ fontSize: 12, color: 'var(--text-3)', fontStyle: 'italic' }}>💬 {val}</span>
        : <span style={{ fontSize: 12, color: 'var(--text-3)', opacity: 0.6 }}>+ Σχόλιο</span>}
    </div>
  );
}

// ── Trial Card ───────────────────────────────────────────────────────────────
function TrialCard({ r, slotIndex, slotTotal, staffList, onEdit, onDelete, onRepeat, onToggleMember, onToggleConsidering, onUpdateStaff, onSaveNotes }) {
  const showSlotNum = !r.user_name && slotTotal > 1;
  return (
    <div style={{
      background: 'var(--surface)', borderRadius: 16, border: '1px solid var(--border)',
      padding: '16px 18px', display: 'flex', flexDirection: 'column', gap: 12,
      boxShadow: '0 1px 4px rgba(0,0,0,0.04)',
    }}>
      {/* Top row: time + person + actions */}
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
        {/* Time badge */}
        <div style={{ flexShrink: 0, background: 'linear-gradient(135deg,#FEF3C7,#FDE68A)', borderRadius: 12, padding: '8px 12px', textAlign: 'center', minWidth: 60 }}>
          <div style={{ fontSize: 16, fontWeight: 800, color: '#92400E', lineHeight: 1 }}>{fmtTime(r.starts_at)}</div>
          {showSlotNum && <div style={{ fontSize: 10, fontWeight: 700, color: '#92400E', marginTop: 2 }}>#{slotIndex}</div>}
        </div>

        {/* Person info */}
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
            <Avatar name={r.user_name} size={32} color="#7C3AED" />
            <div>
              <div style={{ fontWeight: 700, fontSize: 14, color: 'var(--text)' }}>{r.user_name || '— Χωρίς πελάτη —'}</div>
              {r.user_phone && <div style={{ fontSize: 12, color: 'var(--text-3)' }}>{r.user_phone}</div>}
            </div>
          </div>
        </div>

        {/* Action buttons */}
        <div style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
          <button onClick={onEdit} title="Επεξεργασία"
            style={{ width: 28, height: 28, borderRadius: 8, border: 'none', background: 'var(--surface-2)', color: 'var(--text-3)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Pencil size={13} />
          </button>
          <button onClick={onRepeat} title="Επανάληψη"
            style={{ width: 28, height: 28, borderRadius: 8, border: 'none', background: '#EFF6FF', color: '#2563EB', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <RefreshCw size={13} />
          </button>
          <button onClick={onDelete} title="Διαγραφή"
            style={{ width: 28, height: 28, borderRadius: 8, border: 'none', background: '#FEF2F2', color: '#EF4444', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Trash2 size={13} />
          </button>
        </div>
      </div>

      {/* Service + Trainer row */}
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
        {r.service_name && (
          <span style={{ fontSize: 12, fontWeight: 500, color: 'var(--text-2)', background: 'var(--surface-2)', padding: '3px 10px', borderRadius: 99 }}>{r.service_name}</span>
        )}

        {/* Inline trainer picker */}
        <div style={{ position: 'relative', display: 'inline-flex', alignItems: 'center', gap: 6 }}>
          {r.staff_name && <Avatar name={r.staff_name} avatar={r.staff_avatar} color={r.staff_color} size={20} />}
          <select value={r.staff_id || ''} onChange={e => onUpdateStaff(e.target.value)}
            style={{ appearance: 'none', WebkitAppearance: 'none', padding: '3px 22px 3px 8px', borderRadius: 99, border: '1.5px solid var(--border)', background: 'var(--surface)', color: r.staff_name ? 'var(--text-2)' : 'var(--text-3)', fontSize: 12, fontWeight: r.staff_name ? 600 : 400, cursor: 'pointer', outline: 'none' }}>
            <option value="">— Εκπαιδευτής —</option>
            {staffList.map(s => <option key={s.id} value={s.id}>{s.full_name}</option>)}
          </select>
          <ChevronDown size={10} style={{ position: 'absolute', right: 7, pointerEvents: 'none', color: 'var(--text-3)' }} />
        </div>
      </div>

      {/* Notes */}
      <NotesCell trial={r} onSave={onSaveNotes} />

      {/* Status toggles */}
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', borderTop: '1px solid var(--border)', paddingTop: 10 }}>
        <Toggle checked={!!r.trial_considering} onChange={onToggleConsidering} activeColor="#F59E0B" activeLabel="Το σκέφτεται" inactiveLabel="Σκέφτεται;" />
        <Toggle checked={!!r.trial_became_member} onChange={onToggleMember} activeColor="#10B981" activeLabel="Έγινε μέλος" inactiveLabel="Έγινε μέλος;" activeIcon={<UserCheck size={10} />} />
      </div>
    </div>
  );
}

// ── Reports Tab ──────────────────────────────────────────────────────────────
const PERIODS = [
  { label: 'Αυτόν τον μήνα', value: 'this_month' },
  { label: 'Προηγ. μήνας', value: 'last_month' },
  { label: '3 μήνες', value: '3months' },
  { label: 'Φέτος', value: 'this_year' },
  { label: 'Όλα', value: 'all' },
];
function periodDates(p) {
  const now = new Date(), y = now.getFullYear(), m = now.getMonth();
  if (p === 'this_month') return { from: new Date(y,m,1), to: new Date(y,m+1,0) };
  if (p === 'last_month') return { from: new Date(y,m-1,1), to: new Date(y,m,0) };
  if (p === '3months')    return { from: new Date(y,m-2,1), to: new Date(y,m+1,0) };
  if (p === 'this_year')  return { from: new Date(y,0,1), to: new Date(y,11,31) };
  return null;
}

function ReportsTab() {
  const [period, setPeriod] = useState('this_month');
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true);
    const params = {};
    const d = periodDates(period);
    if (d) { params.from = d.from.toISOString().slice(0,10); params.to = d.to.toISOString().slice(0,10); }
    api.get('/client-admin/trials', { params })
      .then(r => setRows(r.data || []))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [period]);

  // Compute stats
  const total = rows.length;
  const members = rows.filter(r => r.trial_became_member).length;
  const considering = rows.filter(r => r.trial_considering).length;
  const rate = total > 0 ? Math.round((members / total) * 100) : 0;

  // Per-trainer stats
  const byStaff = {};
  rows.forEach(r => {
    const key = r.staff_id || '__none__';
    const name = r.staff_name || '— Χωρίς εκπαιδευτή —';
    const avatar = r.staff_avatar; const color = r.staff_color;
    if (!byStaff[key]) byStaff[key] = { name, avatar, color, total: 0, members: 0, considering: 0 };
    byStaff[key].total++;
    if (r.trial_became_member) byStaff[key].members++;
    if (r.trial_considering) byStaff[key].considering++;
  });
  const staffRows = Object.values(byStaff).sort((a, b) => b.total - a.total);

  const statBox = (label, value, color, Icon) => (
    <div style={{ flex: '1 1 120px', background: 'var(--surface)', borderRadius: 16, padding: '16px 18px', border: '1px solid var(--border)', position: 'relative', overflow: 'hidden' }}>
      <div style={{ position: 'absolute', top: 0, right: 0, width: 50, height: 50, background: color, opacity: 0.12, borderRadius: '0 16px 0 100%' }} />
      <div style={{ width: 32, height: 32, borderRadius: 10, background: color, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 10 }}>
        <Icon size={15} color="#fff" strokeWidth={2.5} />
      </div>
      <div style={{ fontSize: 24, fontWeight: 800, color: 'var(--text)', lineHeight: 1 }}>{value}</div>
      <div style={{ fontSize: 11.5, color: 'var(--text-3)', marginTop: 4, fontWeight: 500 }}>{label}</div>
    </div>
  );

  return (
    <div>
      {/* Period chips */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 22, flexWrap: 'wrap' }}>
        {PERIODS.map(p => {
          const active = period === p.value;
          return (
            <button key={p.value} onClick={() => setPeriod(p.value)} style={{
              padding: '6px 14px', borderRadius: 99, border: `1.5px solid ${active ? '#F59E0B' : 'var(--border)'}`,
              background: active ? 'linear-gradient(135deg,#FEF3C7,#FDE68A)' : 'var(--surface)',
              color: active ? '#92400E' : 'var(--text-2)', fontWeight: active ? 700 : 500,
              fontSize: 13, cursor: 'pointer', transition: 'all 0.15s',
            }}>{p.label}</button>
          );
        })}
      </div>

      {/* Summary stats */}
      <div style={{ display: 'flex', gap: 12, marginBottom: 24, flexWrap: 'wrap' }}>
        {statBox('Σύνολο δοκιμαστικών', total, 'linear-gradient(135deg,#FCD34D,#F59E0B)', Target)}
        {statBox('Έγιναν μέλη', members, 'linear-gradient(135deg,#34D399,#10B981)', UserCheck)}
        {statBox('Το σκέφτονται', considering, 'linear-gradient(135deg,#FCD34D,#F59E0B)', Clock)}
        {statBox('Ποσοστό μετατροπής', `${rate}%`, 'linear-gradient(135deg,#60A5FA,#2563EB)', TrendingUp)}
      </div>

      {/* Per-trainer breakdown */}
      {loading ? (
        <div style={{ display: 'flex', justifyContent: 'center', padding: 40 }}>
          <div style={{ width: 32, height: 32, borderRadius: '50%', border: '3px solid var(--border)', borderTopColor: '#F59E0B', animation: 'spin 0.8s linear infinite' }} />
        </div>
      ) : staffRows.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '40px 20px', color: 'var(--text-3)', fontSize: 14 }}>Δεν υπάρχουν δοκιμαστικά για αυτή την περίοδο</div>
      ) : (
        <div style={{ background: 'var(--surface)', borderRadius: 18, border: '1px solid var(--border)', overflow: 'hidden' }}>
          <div style={{ padding: '14px 18px', borderBottom: '1px solid var(--border)', display: 'flex', alignItems: 'center', gap: 8 }}>
            <Award size={16} color="#F59E0B" />
            <span style={{ fontWeight: 700, fontSize: 14, color: 'var(--text)' }}>Ανά Εκπαιδευτή</span>
          </div>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
              <thead>
                <tr style={{ background: 'var(--surface-2)', borderBottom: '1px solid var(--border)' }}>
                  {['Εκπαιδευτής', 'Δοκιμαστικά', 'Έγιναν μέλη', 'Το σκέφτονται', 'Ποσοστό'].map(h => (
                    <th key={h} style={{ padding: '10px 16px', textAlign: 'left', fontWeight: 600, color: 'var(--text-3)', fontSize: 11.5, textTransform: 'uppercase', letterSpacing: '0.4px', whiteSpace: 'nowrap' }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {staffRows.map((s, i) => {
                  const r = s.total > 0 ? Math.round((s.members / s.total) * 100) : 0;
                  return (
                    <tr key={i} style={{ borderBottom: i < staffRows.length - 1 ? '1px solid var(--border)' : 'none' }}>
                      <td style={{ padding: '12px 16px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                          <Avatar name={s.name} avatar={s.avatar} color={s.color} size={28} />
                          <span style={{ fontWeight: 600, color: 'var(--text)' }}>{s.name}</span>
                        </div>
                      </td>
                      <td style={{ padding: '12px 16px', fontWeight: 700, color: 'var(--text)' }}>{s.total}</td>
                      <td style={{ padding: '12px 16px' }}>
                        <span style={{ background: '#D1FAE5', color: '#065F46', padding: '3px 10px', borderRadius: 99, fontWeight: 700, fontSize: 12 }}>{s.members}</span>
                      </td>
                      <td style={{ padding: '12px 16px' }}>
                        <span style={{ background: '#FEF3C7', color: '#92400E', padding: '3px 10px', borderRadius: 99, fontWeight: 700, fontSize: 12 }}>{s.considering}</span>
                      </td>
                      <td style={{ padding: '12px 16px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                          <div style={{ flex: 1, height: 6, background: 'var(--surface-2)', borderRadius: 99, maxWidth: 80, overflow: 'hidden' }}>
                            <div style={{ width: `${r}%`, height: '100%', background: 'linear-gradient(90deg,#34D399,#10B981)', borderRadius: 99, transition: 'width 0.5s' }} />
                          </div>
                          <span style={{ fontWeight: 700, color: 'var(--text-2)', fontSize: 12, minWidth: 32 }}>{r}%</span>
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
    </div>
  );
}

// ── Main Page ────────────────────────────────────────────────────────────────
export default function Trials() {
  const [tab, setTab] = useState('calendar'); // 'calendar' | 'reports'
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [staffList, setStaffList] = useState([]);
  const [services, setServices] = useState([]);
  const [clients, setClients] = useState([]);
  const [modal, setModal] = useState(null);
  const [deleteTarget, setDeleteTarget] = useState(null);
  const [memberClientModal, setMemberClientModal] = useState(null); // { trialId }
  const [showAll, setShowAll] = useState(false);
  const [allRows, setAllRows] = useState([]);
  const [allLoading, setAllLoading] = useState(false);

  const dateKey = toDateKey(selectedDate);

  const reload = () => {
    setLoading(true);
    api.get('/client-admin/trials', { params: { from: dateKey, to: dateKey } })
      .then(r => setRows(r.data || []))
      .catch(() => {})
      .finally(() => setLoading(false));
  };

  const loadAll = () => {
    setAllLoading(true);
    api.get('/client-admin/trials')
      .then(r => setAllRows(r.data || []))
      .catch(() => {})
      .finally(() => setAllLoading(false));
  };

  useEffect(() => { reload(); }, [dateKey]);
  useEffect(() => { if (showAll) loadAll(); }, [showAll]);
  useEffect(() => {
    api.get('/client-admin/staff').then(r => setStaffList(r.data || [])).catch(() => {});
    api.get('/client-admin/services').then(r => setServices(r.data || [])).catch(() => {});
    api.get('/client-admin/clients').then(r => setClients(r.data || [])).catch(() => {});
  }, []);

  const goDay = delta => {
    const d = new Date(selectedDate);
    d.setDate(d.getDate() + delta);
    setSelectedDate(d);
  };

  const patchTrialField = async (id, fields) => {
    const row = rows.find(r => r.id === id);
    if (!row) return;
    await api.patch(`/client-admin/trials/${id}`, {
      trial_date: fmtDateInput(row.starts_at),
      trial_time: fmtTimeInput(row.starts_at),
      service_id: row.service_id,
      staff_id: row.staff_id,
      notes: row.notes,
      ...fields,
    });
  };

  const toggleMember = (id, val) => {
    if (val) {
      const row = rows.find(r => r.id === id);
      if (!row?.user_id) {
        setMemberClientModal({ trialId: id });
        return;
      }
    }
    setRows(prev => prev.map(r => r.id === id ? { ...r, trial_became_member: val ? 1 : 0 } : r));
    api.patch(`/client-admin/trials/${id}/refer`, { trial_became_member: val ? 1 : 0 }).catch(() => {});
  };
  const confirmMemberClient = async (trialId, newClientData) => {
    setRows(prev => prev.map(r => r.id === trialId ? { ...r, trial_became_member: 1 } : r));
    await api.patch(`/client-admin/trials/${trialId}/refer`, { trial_became_member: 1, new_client: newClientData });
    reload();
  };
  const toggleConsidering = async (id, val) => {
    setRows(prev => prev.map(r => r.id === id ? { ...r, trial_considering: val ? 1 : 0 } : r));
    await api.patch(`/client-admin/trials/${id}/refer`, { trial_considering: val ? 1 : 0 });
  };
  const updateStaff = async (id, staff_id) => {
    const staff = staffList.find(s => s.id === staff_id);
    setRows(prev => prev.map(r => r.id === id ? { ...r, staff_id: staff_id || null, staff_name: staff?.full_name || null, staff_avatar: staff?.avatar_url || null, staff_color: staff?.color_hex || null } : r));
    await patchTrialField(id, { staff_id: staff_id || null });
  };
  const updateNotes = async (id, notes) => {
    setRows(prev => prev.map(r => r.id === id ? { ...r, notes } : r));
    await patchTrialField(id, { notes });
  };
  const handleDelete = async (id) => {
    await api.delete(`/client-admin/trials/${id}`);
    setRows(prev => prev.filter(r => r.id !== id));
  };
  const handleSaveEdit = async (form) => {
    const payload = { trial_date: form.trial_date, trial_time: form.trial_time, service_id: form.service_id||null, staff_id: form.staff_id||null, notes: form.notes||null };
    if (form.new_client) payload.new_client = form.new_client;
    else payload.user_id = form.user_id || null;
    await api.patch(`/client-admin/trials/${modal.trial.id}`, payload);
    reload();
  };
  const handleSaveNew = async (form) => {
    const payload = { trial_date: form.trial_date, trial_time: form.trial_time, service_id: form.service_id||undefined, staff_id: form.staff_id||undefined, notes: form.notes||undefined };
    if (form.new_client) payload.new_client = form.new_client;
    else if (form.user_id) payload.user_id = form.user_id;
    await api.post('/client-admin/trials', payload);
    reload();
  };
  const handleRepeat = async (form) => { await api.post('/client-admin/trials', { trial_date: form.trial_date, trial_time: form.trial_time, service_id: form.service_id||undefined, staff_id: form.staff_id||undefined, user_id: modal.trial.user_id||undefined }); reload(); };

  // Quick day chips
  const quickDays = [-1, 0, 1, 2, 3].map(delta => {
    const d = new Date(); d.setDate(d.getDate() + delta); return d;
  });

  const tabBtn = (id, label, Icon) => (
    <button onClick={() => setTab(id)} style={{
      display: 'flex', alignItems: 'center', gap: 6, padding: '8px 18px', borderRadius: 10,
      border: 'none', fontWeight: tab === id ? 700 : 500, fontSize: 13, cursor: 'pointer',
      background: tab === id ? 'var(--surface)' : 'transparent',
      color: tab === id ? 'var(--text)' : 'var(--text-3)',
      boxShadow: tab === id ? '0 1px 4px rgba(0,0,0,0.08)' : 'none',
      transition: 'all 0.15s',
    }}>
      <Icon size={15} />{label}
    </button>
  );

  return (
    <Layout>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 22, flexWrap: 'wrap', gap: 12 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <div style={{ width: 48, height: 48, borderRadius: 16, background: 'linear-gradient(135deg,#FCD34D,#F59E0B)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 8px 20px rgba(245,158,11,0.3)' }}>
            <Target size={22} color="#fff" strokeWidth={2.5} />
          </div>
          <div>
            <h1 style={{ fontSize: 22, fontWeight: 800, color: 'var(--text)', letterSpacing: '-0.3px', margin: 0 }}>Δοκιμαστικά</h1>
            <p style={{ fontSize: 13, color: 'var(--text-3)', marginTop: 2, marginBottom: 0 }}>Διαχείριση & παρακολούθηση μετατροπών</p>
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

      {/* Tab bar */}
      <div style={{ display: 'flex', gap: 4, background: 'var(--surface-2)', borderRadius: 12, padding: 4, marginBottom: 24, width: 'fit-content' }}>
        {tabBtn('calendar', 'Ημερολόγιο', Calendar)}
        {tabBtn('reports', 'Αναφορές', BarChart2)}
      </div>

      {tab === 'reports' ? <ReportsTab /> : (
        <>
          {/* Controls row: chips + show-all toggle */}
          <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap', alignItems: 'center', justifyContent: 'space-between' }}>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
              {!showAll && quickDays.map(d => {
                const key = toDateKey(d);
                const active = key === dateKey;
                return (
                  <button key={key} onClick={() => setSelectedDate(new Date(d))} style={{
                    padding: '6px 14px', borderRadius: 99,
                    border: `1.5px solid ${active ? '#F59E0B' : 'var(--border)'}`,
                    background: active ? 'linear-gradient(135deg,#FEF3C7,#FDE68A)' : 'var(--surface)',
                    color: active ? '#92400E' : 'var(--text-2)',
                    fontWeight: active ? 700 : 500, fontSize: 13, cursor: 'pointer', transition: 'all 0.15s',
                  }}>{dayLabel(d)}</button>
                );
              })}
              {showAll && <span style={{ fontSize: 13, color: 'var(--text-3)', fontWeight: 500 }}>Όλα τα δοκιμαστικά</span>}
            </div>
            <button onClick={() => setShowAll(v => !v)} style={{
              padding: '6px 14px', borderRadius: 99, fontSize: 13, fontWeight: 600, cursor: 'pointer',
              border: `1.5px solid ${showAll ? '#F59E0B' : 'var(--border)'}`,
              background: showAll ? 'linear-gradient(135deg,#FEF3C7,#FDE68A)' : 'var(--surface)',
              color: showAll ? '#92400E' : 'var(--text-2)', transition: 'all 0.15s',
            }}>
              {showAll ? '← Ημερολόγιο' : 'Εμφάνιση όλων'}
            </button>
          </div>

          {/* Day navigator — hidden in showAll mode */}
          {!showAll && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20, background: 'var(--surface)', borderRadius: 16, padding: '12px 16px', border: '1px solid var(--border)' }}>
              <button onClick={() => goDay(-1)} style={{ width: 36, height: 36, borderRadius: 10, border: 'none', background: 'var(--surface-2)', color: 'var(--text-2)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <ChevronLeft size={18} />
              </button>
              <div style={{ flex: 1, textAlign: 'center' }}>
                <div style={{ fontWeight: 800, fontSize: 15, color: 'var(--text)', textTransform: 'capitalize' }}>{fmtDay(selectedDate)}</div>
                {isToday(selectedDate) && <div style={{ fontSize: 11, color: '#F59E0B', fontWeight: 700, marginTop: 2 }}>ΣΗΜΕΡΑ</div>}
              </div>
              <button onClick={() => goDay(1)} style={{ width: 36, height: 36, borderRadius: 10, border: 'none', background: 'var(--surface-2)', color: 'var(--text-2)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <ChevronRight size={18} />
              </button>
            </div>
          )}

          {/* ALL view — grouped by period */}
          {showAll ? (() => {
            if (allLoading) return (
              <div style={{ display: 'flex', justifyContent: 'center', padding: 60 }}>
                <div style={{ width: 36, height: 36, borderRadius: '50%', border: '3px solid var(--border)', borderTopColor: '#F59E0B', animation: 'spin 0.8s linear infinite' }} />
              </div>
            );
            const todayKey = toDateKey(new Date());
            const yesterdayKey = toDateKey(new Date(Date.now() - 86400000));
            const weekAgo = toDateKey(new Date(Date.now() - 7 * 86400000));
            const monthAgo = toDateKey(new Date(Date.now() - 30 * 86400000));

            const groups = [
              { label: 'Σήμερα', filter: r => toDateKey(new Date(r.starts_at)) === todayKey },
              { label: 'Χθες', filter: r => toDateKey(new Date(r.starts_at)) === yesterdayKey },
              { label: 'Αυτή η εβδομάδα', filter: r => { const k = toDateKey(new Date(r.starts_at)); return k < todayKey && k > weekAgo; } },
              { label: 'Αυτός ο μήνας', filter: r => { const k = toDateKey(new Date(r.starts_at)); return k <= weekAgo && k > monthAgo; } },
              { label: 'Παλαιότερα', filter: r => toDateKey(new Date(r.starts_at)) <= monthAgo },
            ];
            const sorted = [...allRows].sort((a,b) => new Date(b.starts_at) - new Date(a.starts_at));

            const renderCards = (groupRows) => {
              const slotCounts = {};
              groupRows.forEach(r => { const k = fmtTime(r.starts_at); slotCounts[k] = (slotCounts[k]||0)+1; });
              const slotIdx = {};
              groupRows.forEach(r => { const k = fmtTime(r.starts_at); slotIdx[r.id] = (slotIdx[k]||0)+1; slotIdx[k] = slotIdx[r.id]; });
              return (
                <div style={{ display: 'grid', gap: 12, gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))' }}>
                  {groupRows.map(r => (
                    <TrialCard key={r.id} r={r} staffList={staffList}
                      slotIndex={slotIdx[r.id]} slotTotal={slotCounts[fmtTime(r.starts_at)]}
                      onEdit={() => setModal({ type: 'edit', trial: r })}
                      onDelete={() => setDeleteTarget(r)}
                      onRepeat={() => setModal({ type: 'repeat', trial: r })}
                      onToggleMember={val => toggleMember(r.id, val)}
                      onToggleConsidering={val => toggleConsidering(r.id, val)}
                      onUpdateStaff={staff_id => updateStaff(r.id, staff_id)}
                      onSaveNotes={notes => updateNotes(r.id, notes)}
                    />
                  ))}
                </div>
              );
            };

            const hasAny = groups.some(g => sorted.some(g.filter));
            if (!hasAny) return (
              <div style={{ background: 'var(--surface)', borderRadius: 18, border: '1.5px dashed var(--border)', padding: '60px 20px', textAlign: 'center' }}>
                <Target size={24} color="var(--text-3)" style={{ marginBottom: 10 }} />
                <p style={{ color: 'var(--text-3)', fontSize: 14 }}>Δεν υπάρχουν δοκιμαστικά</p>
              </div>
            );

            return (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 28 }}>
                {groups.map(g => {
                  const gRows = sorted.filter(g.filter);
                  if (!gRows.length) return null;
                  return (
                    <div key={g.label}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
                        <div style={{ fontWeight: 700, fontSize: 14, color: 'var(--text)' }}>{g.label}</div>
                        <span style={{ background: '#F1F5F9', color: '#64748B', fontSize: 11, fontWeight: 700, padding: '2px 8px', borderRadius: 99 }}>{gRows.length}</span>
                        <div style={{ flex: 1, height: 1, background: 'var(--border)' }} />
                      </div>
                      {renderCards(gRows)}
                    </div>
                  );
                })}
              </div>
            );
          })() : null}

          {/* Day view cards */}
          {!showAll && (loading ? (
            <div style={{ display: 'flex', justifyContent: 'center', padding: 60 }}>
              <div style={{ width: 36, height: 36, borderRadius: '50%', border: '3px solid var(--border)', borderTopColor: '#F59E0B', animation: 'spin 0.8s linear infinite' }} />
            </div>
          ) : rows.length === 0 ? (
            <div style={{ background: 'var(--surface)', borderRadius: 18, border: '1.5px dashed var(--border)', padding: '60px 20px', textAlign: 'center' }}>
              <div style={{ width: 56, height: 56, borderRadius: '50%', background: 'var(--surface-2)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 14px' }}>
                <Target size={24} color="var(--text-3)" />
              </div>
              <p style={{ fontWeight: 600, fontSize: 15, color: 'var(--text-2)', marginBottom: 4 }}>Δεν υπάρχουν δοκιμαστικά</p>
              <p style={{ fontSize: 13, color: 'var(--text-3)' }}>Για {isToday(selectedDate) ? 'σήμερα' : fmtShortDay(selectedDate)}</p>
            </div>
          ) : (() => {
            const sorted = [...rows].sort((a,b) => new Date(a.starts_at) - new Date(b.starts_at));
            // Count per time slot for slot numbering
            const slotCounts = {};
            sorted.forEach(r => { const k = fmtTime(r.starts_at); slotCounts[k] = (slotCounts[k]||0)+1; });
            const slotIdx = {};
            sorted.forEach(r => { const k = fmtTime(r.starts_at); slotIdx[r.id] = (slotIdx[k]||0)+1; slotIdx[k] = slotIdx[r.id]; });
            return (
              <div style={{ display: 'grid', gap: 12, gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))' }}>
                {sorted.map(r => (
                  <TrialCard
                    key={r.id} r={r} staffList={staffList}
                    slotIndex={slotIdx[r.id]} slotTotal={slotCounts[fmtTime(r.starts_at)]}
                    onEdit={() => setModal({ type: 'edit', trial: r })}
                    onDelete={() => setDeleteTarget(r)}
                    onRepeat={() => setModal({ type: 'repeat', trial: r })}
                    onToggleMember={val => toggleMember(r.id, val)}
                    onToggleConsidering={val => toggleConsidering(r.id, val)}
                    onUpdateStaff={staff_id => updateStaff(r.id, staff_id)}
                    onSaveNotes={notes => updateNotes(r.id, notes)}
                  />
                ))}
              </div>
            );
          })())}
        </>
      )}

      {/* Modals */}
      {modal?.type === 'edit' && <TrialModal trial={modal.trial} staffList={staffList} services={services} clients={clients} onClose={() => setModal(null)} onSave={handleSaveEdit} />}
      {modal?.type === 'new'  && <TrialModal trial={null} staffList={staffList} services={services} clients={clients} onClose={() => setModal(null)} onSave={handleSaveNew} />}
      {modal?.type === 'repeat' && <TrialModal trial={modal.trial} staffList={staffList} services={services} clients={clients} onClose={() => setModal(null)} onSave={handleRepeat} isRepeat />}
      {deleteTarget && <DeleteConfirm trial={deleteTarget} onClose={() => setDeleteTarget(null)} onConfirm={() => handleDelete(deleteTarget.id)} />}
      {memberClientModal && (
        <MemberClientModal
          onClose={() => setMemberClientModal(null)}
          onConfirm={newClientData => confirmMemberClient(memberClientModal.trialId, newClientData)}
        />
      )}

      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </Layout>
  );
}
