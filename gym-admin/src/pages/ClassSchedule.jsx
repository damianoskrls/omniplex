import { useEffect, useState } from 'react';
import { Calendar, Plus, Pencil, Trash2, X, Check } from 'lucide-react';
import Layout from '../components/Layout';
import api from '../api/client';

const DAYS = ['', 'Δευτέρα', 'Τρίτη', 'Τετάρτη', 'Πέμπτη', 'Παρασκευή', 'Σάββατο', 'Κυριακή'];

const SERVICE_COLORS = [
  '#C6FF3D', '#3EE6FF', '#B48CFF', '#FF6FD8', '#FFB23E',
  '#FF5252', '#69FF47', '#40C4FF', '#FF6E40', '#EEFF41',
];

function colorForService(serviceId) {
  if (!serviceId) return SERVICE_COLORS[0];
  let hash = 0;
  for (let i = 0; i < serviceId.length; i++) hash = serviceId.charCodeAt(i) + ((hash << 5) - hash);
  return SERVICE_COLORS[Math.abs(hash) % SERVICE_COLORS.length];
}

const EMPTY_FORM = {
  day_of_week: 1, start_time: '09:00', service_id: '', staff_id: '', max_capacity: '', room_id: '',
};

function calcEndTime(startTime, durationMins) {
  if (!startTime || !durationMins) return null;
  const [h, m] = startTime.split(':').map(Number);
  const total = h * 60 + m + Number(durationMins);
  const eh = Math.floor(total / 60) % 24;
  const em = total % 60;
  return `${String(eh).padStart(2, '0')}:${String(em).padStart(2, '0')}`;
}

export default function ClassSchedule() {
  const [entries, setEntries]     = useState([]);
  const [services, setServices]   = useState([]);
  const [staff, setStaff]         = useState([]);
  const [rooms, setRooms]         = useState([]);
  const [loading, setLoading]     = useState(true);
  const [modal, setModal]         = useState(null);
  const [form, setForm]           = useState(EMPTY_FORM);
  const [saving, setSaving]       = useState(false);
  const [error, setError]         = useState(null);
  const [activeDay, setActiveDay] = useState(1);

  async function load() {
    setLoading(true);
    try {
      const [schedRes, svcRes, staffRes, roomsRes] = await Promise.all([
        api.get('/client-admin/class-schedules'),
        api.get('/client-admin/services'),
        api.get('/client-admin/staff'),
        api.get('/client-admin/rooms'),
      ]);
      setEntries(schedRes.data);
      setServices(svcRes.data.filter(s => s.is_active !== 0));
      setStaff(staffRes.data.filter(s => s.is_active !== 0));
      setRooms(roomsRes.data);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { load(); }, []);

  function openAdd() {
    setForm({ ...EMPTY_FORM, day_of_week: activeDay });
    setModal('add');
    setError(null);
  }

  function onServiceChange(serviceId) {
    const svc = services.find(s => s.id === serviceId);
    setForm(f => ({
      ...f,
      service_id: serviceId,
      max_capacity: f.max_capacity || (svc?.default_capacity != null ? String(svc.default_capacity) : ''),
    }));
  }

  function openEdit(entry) {
    setForm({
      day_of_week:  entry.day_of_week,
      start_time:   entry.start_time?.slice(0, 5) || entry.start_time,
      service_id:   entry.service_id || '',
      staff_id:     entry.staff_id || '',
      max_capacity: entry.max_capacity != null ? String(entry.max_capacity) : '',
      room_id:      entry.room_id || '',
    });
    setModal(entry);
    setError(null);
  }

  async function handleSave() {
    if (!form.service_id) { setError('Επίλεξε υπηρεσία'); return; }
    setSaving(true); setError(null);
    try {
      const payload = {
        day_of_week:  form.day_of_week,
        start_time:   form.start_time,
        service_id:   form.service_id,
        staff_id:     form.staff_id || null,
        max_capacity: form.max_capacity ? parseInt(form.max_capacity) : null,
        room_id:      form.room_id || null,
      };
      if (modal === 'add') {
        await api.post('/client-admin/class-schedules', payload);
      } else {
        await api.put(`/client-admin/class-schedules/${modal.id}`, payload);
      }
      await load();
      setModal(null);
    } catch (e) {
      setError(e.response?.data?.error || e.message);
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(id) {
    if (!confirm('Διαγραφή μαθήματος;')) return;
    await api.delete(`/client-admin/class-schedules/${id}`);
    await load();
  }

  const dayEntries = entries.filter(e => e.day_of_week === activeDay);

  return (
    <Layout title="Εβδομαδιαίο Πρόγραμμα">
      <div className="page-header">
        <h1 className="page-title">
          <Calendar size={20} style={{ marginRight: 8, verticalAlign: 'middle' }} />
          Εβδομαδιαίο Πρόγραμμα
        </h1>
        <button className="btn btn-primary" onClick={openAdd}>
          <Plus size={16} /> Νέο Μάθημα
        </button>
      </div>

      {/* Day tabs */}
      <div className="card" style={{ padding: '4px', display: 'flex', gap: 2, flexWrap: 'wrap', marginBottom: 20 }}>
        {DAYS.slice(1).map((d, i) => {
          const day = i + 1;
          const count = entries.filter(e => e.day_of_week === day).length;
          return (
            <button
              key={day}
              onClick={() => setActiveDay(day)}
              style={{
                flex: '1 1 auto',
                padding: '8px 4px',
                borderRadius: 8,
                border: 'none',
                cursor: 'pointer',
                fontWeight: 600,
                fontSize: '0.8rem',
                background: activeDay === day ? 'var(--tenant-primary, #16a34a)' : 'transparent',
                color: activeDay === day ? '#fff' : 'var(--text-secondary, #888)',
                transition: 'background 0.15s',
              }}
            >
              {d.slice(0, 3)}
              {count > 0 && (
                <span style={{
                  marginLeft: 4,
                  fontSize: '0.7rem',
                  background: activeDay === day ? 'rgba(255,255,255,0.25)' : 'rgba(22,163,74,0.12)',
                  color: activeDay === day ? '#fff' : 'var(--tenant-primary, #16a34a)',
                  borderRadius: 99,
                  padding: '1px 6px',
                }}>
                  {count}
                </span>
              )}
            </button>
          );
        })}
      </div>

      {/* Entries for selected day */}
      {loading ? (
        <div className="text-muted" style={{ textAlign: 'center', padding: '40px 0' }}>Φόρτωση…</div>
      ) : dayEntries.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '40px 0', border: '2px dashed var(--border, #e5e7eb)', borderRadius: 12 }}>
          <p className="text-muted" style={{ marginBottom: 12 }}>Δεν υπάρχουν μαθήματα για {DAYS[activeDay]}</p>
          <button className="btn btn-secondary btn-sm" onClick={openAdd}>+ Προσθήκη μαθήματος</button>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {dayEntries.map(e => (
            <div key={e.id} className="card" style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 16px' }}>
              <div style={{ width: 4, alignSelf: 'stretch', borderRadius: 4, background: colorForService(e.service_id), flexShrink: 0 }} />
              <div style={{ minWidth: 80, textAlign: 'center' }}>
                <span style={{ fontSize: '1rem', fontWeight: 700 }}>{e.start_time?.slice(0, 5)}</span>
                {e.duration_mins && (
                  <div style={{ fontSize: '0.72rem', color: 'var(--text-secondary, #888)' }}>
                    {calcEndTime(e.start_time?.slice(0, 5), e.duration_mins)}
                  </div>
                )}
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 600, marginBottom: 2 }}>{e.class_name}</div>
                <div className="text-muted" style={{ fontSize: '0.8rem' }}>
                  {[e.trainer_name, e.room_display_name || e.room_name, e.max_capacity ? `${e.max_capacity} άτομα` : null].filter(Boolean).join(' · ')}
                </div>
              </div>
              <button className="btn btn-secondary btn-sm" onClick={() => openEdit(e)} title="Επεξεργασία">
                <Pencil size={14} />
              </button>
              <button className="btn btn-danger btn-sm" onClick={() => handleDelete(e.id)} title="Διαγραφή">
                <Trash2 size={14} />
              </button>
            </div>
          ))}
        </div>
      )}

      {/* Modal */}
      {modal && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setModal(null)}>
          <div className="modal" style={{ maxWidth: 440 }}>
            <div className="modal-title" style={{ display: 'flex', alignItems: 'center' }}>
              {modal === 'add' ? 'Νέο Μάθημα' : 'Επεξεργασία Μαθήματος'}
              <button style={{ marginLeft: 'auto', background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-secondary, #888)' }} onClick={() => setModal(null)}>
                <X size={18} />
              </button>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div className="form-group">
                <label className="form-label">Ημέρα</label>
                <select
                  className="form-input"
                  value={form.day_of_week}
                  onChange={e => setForm(f => ({ ...f, day_of_week: Number(e.target.value) }))}
                >
                  {DAYS.slice(1).map((d, i) => <option key={i+1} value={i+1}>{d}</option>)}
                </select>
              </div>
              <div className="form-group">
                <label className="form-label">Ώρα</label>
                <input
                  type="time"
                  className="form-input"
                  value={form.start_time}
                  onChange={e => setForm(f => ({ ...f, start_time: e.target.value }))}
                />
              </div>
            </div>

            <div className="form-group">
              <label className="form-label">Υπηρεσία *</label>
              <select
                className="form-input"
                value={form.service_id}
                onChange={e => onServiceChange(e.target.value)}
              >
                <option value="">— Επίλεξε υπηρεσία —</option>
                {services.map(s => (
                  <option key={s.id} value={s.id}>
                    {s.name}{s.duration_mins ? ` (${s.duration_mins} λεπτά)` : ''}
                  </option>
                ))}
              </select>
              {form.service_id && (() => {
                const svc = services.find(s => s.id === form.service_id);
                const end = svc?.duration_mins ? calcEndTime(form.start_time, svc.duration_mins) : null;
                return end ? (
                  <div style={{ fontSize: '0.78rem', color: 'var(--text-secondary, #888)', marginTop: 4 }}>
                    Διάρκεια: {svc.duration_mins} λεπτά → λήξη στις {end}
                  </div>
                ) : null;
              })()}
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div className="form-group">
                <label className="form-label">Εκπαιδευτής</label>
                <select
                  className="form-input"
                  value={form.staff_id}
                  onChange={e => setForm(f => ({ ...f, staff_id: e.target.value }))}
                >
                  <option value="">— Χωρίς εκπαιδευτή —</option>
                  {staff.map(s => (
                    <option key={s.id} value={s.id}>{s.full_name}</option>
                  ))}
                </select>
              </div>
              <div className="form-group">
                <label className="form-label">Αίθουσα</label>
                <select
                  className="form-input"
                  value={form.room_id}
                  onChange={e => setForm(f => ({ ...f, room_id: e.target.value }))}
                >
                  <option value="">— Χωρίς αίθουσα —</option>
                  {rooms.map(r => (
                    <option key={r.id} value={r.id}>{r.name}</option>
                  ))}
                </select>
              </div>
            </div>

            <div className="form-group">
              <label className="form-label">Μέγ. Χωρητικότητα</label>
              <input
                type="number"
                className="form-input"
                value={form.max_capacity}
                onChange={e => setForm(f => ({ ...f, max_capacity: e.target.value }))}
                placeholder="π.χ. 20"
              />
            </div>

            {error && <p style={{ color: 'var(--danger, #ef4444)', fontSize: '0.85rem', margin: '4px 0' }}>{error}</p>}

            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setModal(null)}>Άκυρο</button>
              <button className="btn btn-primary" onClick={handleSave} disabled={saving}>
                <Check size={15} />
                {saving ? 'Αποθήκευση…' : 'Αποθήκευση'}
              </button>
            </div>
          </div>
        </div>
      )}
    </Layout>
  );
}
