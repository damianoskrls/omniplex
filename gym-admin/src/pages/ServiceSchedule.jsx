import { useEffect, useState, useMemo } from 'react';
import { Link, useParams } from 'react-router-dom';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { ArrowLeft, Plus, Trash2, X, Edit2, Check, ChevronDown, ChevronUp, Save } from 'lucide-react';
import LocationCheckboxes from '../components/LocationCheckboxes';

const WEEKDAYS = [
  { v: 0, label: 'Δευ' }, { v: 1, label: 'Τρί' }, { v: 2, label: 'Τετ' },
  { v: 3, label: 'Πέμ' }, { v: 4, label: 'Παρ' }, { v: 5, label: 'Σαβ' }, { v: 6, label: 'Κυρ' },
];
const WEEKDAYS_FULL = ['Δευτέρα', 'Τρίτη', 'Τετάρτη', 'Πέμπτη', 'Παρασκευή', 'Σάββατο', 'Κυριακή'];
const ICON_KEYS = [
  { v: '', label: '— Χωρίς icon —' },
  { v: 'cross_training', label: 'Cross Training' }, { v: 'strength', label: 'Strength' },
  { v: 'trx', label: 'TRX' }, { v: 'pilates', label: 'Pilates' }, { v: 'yoga', label: 'Yoga' },
  { v: 'cycling', label: 'Cycling / RPM' }, { v: 'hiit', label: 'HIIT' },
  { v: 'stretching', label: 'Stretching' },
];

const EMPTY_FORM = {
  label: '', subtitle: '', icon_key: '',
  weekdays: [], times: [], singleTime: '',
  rangeFrom: '09:00', rangeTo: '18:00', interval: 60,
  selectedRoomIds: [], selectedStaffIds: [],
  max_capacity: '',
};

function Chip({ label, checked, onClick, color = '#76C043' }) {
  return (
    <button type="button" onClick={onClick} style={{
      padding: '5px 13px', borderRadius: 20,
      border: `1.5px solid ${checked ? color : '#e2e8f0'}`,
      background: checked ? (color === '#64748b' ? '#f1f5f9' : '#f0fdf4') : '#fff',
      color: checked ? (color === '#64748b' ? '#475569' : color) : '#64748b',
      fontWeight: checked ? 600 : 400, fontSize: '0.85rem', cursor: 'pointer',
      display: 'flex', alignItems: 'center', gap: 4, transition: 'all 0.12s',
    }}>
      {checked && <Check size={12} />}{label}
    </button>
  );
}

export default function ServiceSchedule() {
  const { id } = useParams();
  const [service, setService] = useState(null);
  const [schedules, setSchedules] = useState([]);
  const [staffList, setStaffList] = useState([]);
  const [roomsList, setRoomsList] = useState([]);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState(EMPTY_FORM);
  const [saving, setSaving] = useState(false);
  const [selectedSlotIds, setSelectedSlotIds] = useState([]);
  const [editingSlot, setEditingSlot] = useState(null); // {id, field, value}
  const [editingLabel, setEditingLabel] = useState(null); // {oldLabel, newLabel, icon_key, subtitle}
  const [filterLabel, setFilterLabel] = useState(null);
  const [bulkCapacity, setBulkCapacity] = useState('');
  const [bulkSaving, setBulkSaving] = useState(false);
  const [locations, setLocations] = useState([]);
  const [activeLocationId, setActiveLocationId] = useState('');
  const [serviceLocationIds, setServiceLocationIds] = useState([]);

  const load = async (locId = activeLocationId) => {
    const locRes = await api.get('/client-admin/locations');
    const locs = (locRes.data || []).filter((l) => l.is_active);
    setLocations(locs);
    const chosen = locId || locs[0]?.id || '';
    if (chosen !== activeLocationId) setActiveLocationId(chosen);

    const schParams = chosen ? { location_id: chosen } : {};
    const roomParams = chosen ? { location_id: chosen } : {};
    const [svcRes, schRes, staffRes, roomsRes, svcLocRes] = await Promise.all([
      api.get('/client-admin/services'),
      api.get(`/client-admin/services/${id}/slot-schedules`, { params: schParams }),
      api.get('/client-admin/staff'),
      api.get('/client-admin/rooms', { params: roomParams }),
      api.get(`/client-admin/services/${id}/locations`).catch(() => ({ data: [] })),
    ]);
    setService(svcRes.data.find(s => s.id === id) || null);
    setSchedules(schRes.data);
    setStaffList(staffRes.data.filter(s => s.is_active));
    setRoomsList(roomsRes.data);
    setServiceLocationIds(svcLocRes.data || []);
  };

  useEffect(() => { load().catch(() => {}); }, [id]);

  useEffect(() => {
    if (activeLocationId) load(activeLocationId).catch(() => {});
  }, [activeLocationId]);

  // Unique labels in schedules
  const labels = useMemo(() => {
    const seen = new Set();
    return schedules
      .filter(s => s.label)
      .map(s => s.label)
      .filter(l => { if (seen.has(l)) return false; seen.add(l); return true; });
  }, [schedules]);

  const hasLabels = labels.length > 0;

  // Filtered + sorted slots
  const displayedSlots = useMemo(() => {
    let list = filterLabel === null ? schedules : schedules.filter(s => (s.label || '') === filterLabel);
    return [...list].sort((a, b) => a.weekday - b.weekday || a.start_time.localeCompare(b.start_time));
  }, [schedules, filterLabel]);

  // ── Form helpers ──────────────────────────────────────────────
  const generateRangeTimes = () => {
    const parse = t => { const [h, m] = t.split(':').map(Number); return h * 60 + (m || 0); };
    const fmt = m => `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
    const times = [];
    for (let m = parse(form.rangeFrom); m <= parse(form.rangeTo); m += Number(form.interval)) times.push(fmt(m));
    const next = [...new Set([...form.times, ...times])].sort();
    setForm(p => ({ ...p, times: next }));
    toast.success(`${times.length} ώρες προστέθηκαν`);
  };

  const addSingleTime = () => {
    if (!form.singleTime) return;
    setForm(p => ({ ...p, times: [...new Set([...p.times, p.singleTime])].sort(), singleTime: '' }));
  };

  const removeTime = i => setForm(p => ({ ...p, times: p.times.filter((_, idx) => idx !== i) }));

  const toggleDay = d => setForm(p => {
    const has = p.weekdays.includes(d);
    return { ...p, weekdays: has ? p.weekdays.filter(x => x !== d) : [...p.weekdays, d].sort((a, b) => a - b) };
  });

  // ── Save slots ───────────────────────────────────────────────
  const saveSlots = async (e) => {
    e.preventDefault();
    const times = form.times.filter(t => t.trim());
    if (!form.weekdays.length) return toast.error('Επίλεξε τουλάχιστον μία ημέρα');
    if (!times.length) return toast.error('Πρόσθεσε τουλάχιστον μία ώρα');

    const roomOptions = form.selectedRoomIds.length
      ? form.selectedRoomIds
      : [null];
    const staffOptions = form.selectedStaffIds.length ? form.selectedStaffIds : [null];
    const pairs = roomOptions.flatMap(room_id => staffOptions.map(staff_id => ({ room_id, staff_id })));
    const cap = form.max_capacity !== '' ? Number(form.max_capacity) : null;

    setSaving(true);
    try {
      await Promise.all(pairs.map(pair =>
        api.post(`/client-admin/services/${id}/slot-schedules`, {
          weekdays: form.weekdays, start_times: times,
          label: form.label || null, subtitle: form.subtitle || null,
          icon_key: form.icon_key || null,
          room_id: pair.room_id, staff_id: pair.staff_id, max_capacity: cap,
          location_id: activeLocationId || null,
        })
      ));
      const total = form.weekdays.length * times.length * pairs.length;
      toast.success(`Προστέθηκαν ${total} slots`);
      setShowForm(false);
      setForm(EMPTY_FORM);
      load();
    } catch (err) { toast.error(err.response?.data?.error || 'Σφάλμα'); }
    finally { setSaving(false); }
  };

  // ── Bulk delete ───────────────────────────────────────────────
  const deleteSelected = async () => {
    if (!window.confirm(`Διαγραφή ${selectedSlotIds.length} slots;`)) return;
    await Promise.all(selectedSlotIds.map(sid => api.delete(`/client-admin/services/${id}/slot-schedules/${sid}`)));
    toast.success(`Διαγράφηκαν ${selectedSlotIds.length} slots`);
    setSelectedSlotIds([]);
    load();
  };

  const deleteSlot = async sid => {
    if (!window.confirm('Διαγραφή slot;')) return;
    await api.delete(`/client-admin/services/${id}/slot-schedules/${sid}`);
    setSelectedSlotIds(p => p.filter(x => x !== sid));
    load();
  };

  // ── Inline field edit ─────────────────────────────────────────
  const saveSlotField = async (slotId, field, value) => {
    await api.patch(`/client-admin/services/${id}/slot-schedules/${slotId}`, { [field]: value || null });
    setEditingSlot(null);
    load();
  };

  // ── Rename label group ────────────────────────────────────────
  const saveLabelEdit = async () => {
    if (!editingLabel) return;
    const slots = schedules.filter(s => (s.label || '') === editingLabel.oldLabel);
    await Promise.all(slots.map(s =>
      api.patch(`/client-admin/services/${id}/slot-schedules/${s.id}`, {
        label: editingLabel.newLabel || null,
        subtitle: editingLabel.subtitle || null,
        icon_key: editingLabel.icon_key || null,
      })
    ));
    toast.success('Ενημερώθηκε');
    if (filterLabel === editingLabel.oldLabel) setFilterLabel(editingLabel.newLabel || null);
    setEditingLabel(null);
    load();
  };

  // ── Delete entire label group ─────────────────────────────────
  const deleteLabelGroup = async label => {
    const slots = schedules.filter(s => (s.label || '') === label);
    if (!window.confirm(`Διαγραφή όλων των slots "${label || '(χωρίς τίτλο)'}"; (${slots.length} slots)`)) return;
    await Promise.all(slots.map(s => api.delete(`/client-admin/services/${id}/slot-schedules/${s.id}`)));
    toast.success('Διαγράφηκαν');
    if (filterLabel === label) setFilterLabel(null);
    load();
  };

  const applyBulkCapacity = async () => {
    const cap = bulkCapacity === '' ? null : Number(bulkCapacity);
    if (cap !== null && (!Number.isFinite(cap) || cap < 1)) {
      toast.error('Βάλε έγκυρο αριθμό χωρητικότητας');
      return;
    }
    const slots = filterLabel != null
      ? schedules.filter((s) => (s.label || '') === filterLabel)
      : selectedSlotIds.length
        ? schedules.filter((s) => selectedSlotIds.includes(s.id))
        : [];
    if (!slots.length) {
      toast.error('Δεν υπάρχουν slots για ενημέρωση');
      return;
    }
    if (!window.confirm(`Αλλαγή χωρητικότητας σε ${cap ?? 'απεριόριστη'} για ${slots.length} slots;`)) return;
    setBulkSaving(true);
    try {
      await Promise.all(slots.map((s) => api.patch(`/client-admin/services/${id}/slot-schedules/${s.id}`, { max_capacity: cap })));
      toast.success(`Ενημερώθηκαν ${slots.length} slots`);
      setBulkCapacity('');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setBulkSaving(false);
    }
  };

  const toggleSelect = slotId => setSelectedSlotIds(p => p.includes(slotId) ? p.filter(x => x !== slotId) : [...p, slotId]);
  const toggleSelectAll = () => setSelectedSlotIds(p => p.length === displayedSlots.length ? [] : displayedSlots.map(s => s.id));

  return (
    <Layout title={`${service?.name || 'Υπηρεσία'} — Πρόγραμμα`}>
      {/* Header */}
      <div className="page-header">
        <div>
          <Link to="/services" className="btn btn-secondary btn-sm" style={{ marginBottom: 8 }}>
            <ArrowLeft size={14} /> Υπηρεσίες
          </Link>
          <h1 className="page-title">{service?.name} — Πρόγραμμα & χωρητικότητα</h1>
          <p className="text-muted" style={{ marginTop: 4, fontSize: '0.88rem' }}>
            Εδώ ορίζεις ώρες, αίθουσες, γυμναστές και <strong>πόσα άτομα χωράει κάθε slot</strong> (π.χ. Cross Training max 15).
          </p>
          {locations.length > 1 && (
            <div style={{ marginTop: 10, display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
              <span className="text-muted" style={{ fontSize: '0.85rem' }}>Τοποθεσία:</span>
              <select className="form-select" style={{ width: 220 }} value={activeLocationId} onChange={(e) => setActiveLocationId(e.target.value)}>
                {locations.map((loc) => <option key={loc.id} value={loc.id}>{loc.name}</option>)}
              </select>
            </div>
          )}
        </div>
        <button className="btn btn-primary" onClick={() => { setShowForm(v => !v); setForm(EMPTY_FORM); }}>
          <Plus size={15} /> Προσθήκη slots
          {showForm ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
        </button>
      </div>

      {locations.length > 1 && (
        <div className="card" style={{ marginBottom: 16, padding: 16 }}>
          <LocationCheckboxes
            value={serviceLocationIds}
            onChange={async (ids) => {
              setServiceLocationIds(ids);
              try {
                await api.put(`/client-admin/services/${id}/locations`, { location_ids: ids });
                toast.success('Τοποθεσίες υπηρεσίας αποθηκεύτηκαν');
              } catch {
                toast.error('Σφάλμα');
              }
            }}
            label="Διαθέσιμη σε γυμναστήρια"
          />
        </div>
      )}

      {/* ── Add slots form ── */}
      {showForm && (
        <div className="card" style={{ marginBottom: 16 }}>
          <form onSubmit={saveSlots}>
            {/* Label (optional) */}
            <div className="form-grid-2" style={{ marginBottom: 12 }}>
              <div className="form-group" style={{ marginBottom: 0 }}>
                <label className="form-label">
                  Τίτλος μαθήματος
                  <span style={{ fontWeight: 400, color: '#94a3b8', marginLeft: 6, fontSize: '0.78rem' }}>(προαιρετικό)</span>
                </label>
                {labels.length > 0 ? (
                  <div style={{ display: 'flex', gap: 8 }}>
                    <input
                      className="form-input"
                      placeholder="π.χ. Cross Training ή κενό"
                      value={form.label}
                      onChange={e => setForm(p => ({ ...p, label: e.target.value }))}
                      list="existing-labels"
                    />
                    <datalist id="existing-labels">
                      {labels.map(l => <option key={l} value={l} />)}
                    </datalist>
                  </div>
                ) : (
                  <input className="form-input" placeholder="π.χ. Cross Training (αφήστε κενό αν δεν χρειάζεται)" value={form.label} onChange={e => setForm(p => ({ ...p, label: e.target.value }))} />
                )}
              </div>
              <div className="form-group" style={{ marginBottom: 0 }}>
                <label className="form-label">Υπότιτλος</label>
                <input className="form-input" placeholder="π.χ. HIIT + functional" value={form.subtitle} onChange={e => setForm(p => ({ ...p, subtitle: e.target.value }))} />
              </div>
            </div>

            {form.label && (
              <div className="form-group">
                <label className="form-label">Icon στο app</label>
                <select className="form-input" style={{ maxWidth: 200 }} value={form.icon_key} onChange={e => setForm(p => ({ ...p, icon_key: e.target.value }))}>
                  {ICON_KEYS.map(i => <option key={i.v} value={i.v}>{i.label}</option>)}
                </select>
              </div>
            )}

            {/* Days */}
            <div className="form-group">
              <label className="form-label">Ημέρες *</label>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                {WEEKDAYS.map(w => (
                  <Chip key={w.v} label={w.label} checked={form.weekdays.includes(w.v)} onClick={() => toggleDay(w.v)} />
                ))}
                <Chip label="Δευ–Παρ" checked={false} onClick={() => setForm(p => ({ ...p, weekdays: [0,1,2,3,4] }))} color="#64748b" />
                <Chip label="Όλη εβδ." checked={false} onClick={() => setForm(p => ({ ...p, weekdays: [0,1,2,3,4,5,6] }))} color="#64748b" />
              </div>
            </div>

            {/* Times */}
            <div className="form-group">
              <label className="form-label">Ώρες *</label>
              <div style={{ background: '#f8fafc', border: '1px solid #e2e8f0', borderRadius: 8, padding: 12, marginBottom: 10 }}>
                <div style={{ fontSize: '0.8rem', color: '#64748b', marginBottom: 8 }}>Μαζική προσθήκη από εύρος</div>
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'flex-end' }}>
                  <div>
                    <div style={{ fontSize: '0.75rem', color: '#94a3b8', marginBottom: 2 }}>Από</div>
                    <input type="time" className="form-input" style={{ maxWidth: 110 }} value={form.rangeFrom} onChange={e => setForm(p => ({ ...p, rangeFrom: e.target.value }))} />
                  </div>
                  <div>
                    <div style={{ fontSize: '0.75rem', color: '#94a3b8', marginBottom: 2 }}>Έως</div>
                    <input type="time" className="form-input" style={{ maxWidth: 110 }} value={form.rangeTo} onChange={e => setForm(p => ({ ...p, rangeTo: e.target.value }))} />
                  </div>
                  <div>
                    <div style={{ fontSize: '0.75rem', color: '#94a3b8', marginBottom: 2 }}>Κάθε</div>
                    <select className="form-input" style={{ maxWidth: 120 }} value={form.interval} onChange={e => setForm(p => ({ ...p, interval: Number(e.target.value) }))}>
                      <option value={30}>30 λεπτά</option>
                      <option value={45}>45 λεπτά</option>
                      <option value={60}>1 ώρα</option>
                      <option value={90}>1.5 ώρα</option>
                      <option value={120}>2 ώρες</option>
                    </select>
                  </div>
                  <button type="button" className="btn btn-primary btn-sm" onClick={generateRangeTimes}>Προσθήκη ωρών</button>
                </div>
              </div>
              {form.times.length > 0 && (
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 8 }}>
                  {form.times.map((t, i) => (
                    <span key={i} style={{ display: 'inline-flex', alignItems: 'center', gap: 4, padding: '3px 10px', borderRadius: 20, background: '#f0fdf4', border: '1px solid #c7d2fe', fontSize: '0.85rem' }}>
                      {t}
                      <button type="button" onClick={() => removeTime(i)} style={{ border: 'none', background: 'none', cursor: 'pointer', padding: 0, color: '#64748b', display: 'flex' }}><X size={12} /></button>
                    </span>
                  ))}
                  <button type="button" className="btn btn-secondary btn-sm" onClick={() => setForm(p => ({ ...p, times: [] }))}>Καθαρισμός</button>
                </div>
              )}
              <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                <input type="time" className="form-input" style={{ maxWidth: 120 }} value={form.singleTime} onChange={e => setForm(p => ({ ...p, singleTime: e.target.value }))} />
                <button type="button" className="btn btn-secondary btn-sm" onClick={addSingleTime}><Plus size={13} /> Μία ώρα</button>
              </div>
            </div>

            {/* Rooms */}
            {roomsList.length > 0 && (
              <div className="form-group">
                <label className="form-label">
                  Αίθουσες
                  <span style={{ fontWeight: 400, color: '#94a3b8', marginLeft: 6, fontSize: '0.78rem' }}>
                    {form.selectedRoomIds.length === 0 ? '(οποιαδήποτε)' : `${form.selectedRoomIds.length} επιλεγμένες`}
                  </span>
                </label>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                  {roomsList.length > 1 && (
                    <Chip label="Οποιαδήποτε" checked={form.selectedRoomIds.length === 0} onClick={() => setForm(p => ({ ...p, selectedRoomIds: [] }))} color="#64748b" />
                  )}
                  {roomsList.map(r => {
                    const checked = form.selectedRoomIds.includes(r.id);
                    return (
                      <Chip key={r.id} label={r.name} checked={checked} onClick={() => {
                        if (roomsList.length === 1) return;
                        setForm(p => ({ ...p, selectedRoomIds: checked ? p.selectedRoomIds.filter(x => x !== r.id) : [...p.selectedRoomIds, r.id] }));
                      }} />
                    );
                  })}
                </div>
              </div>
            )}

            {/* Staff */}
            <div className="form-group">
              <label className="form-label">
                Γυμναστές
                <span style={{ fontWeight: 400, color: '#94a3b8', marginLeft: 6, fontSize: '0.78rem' }}>
                  {form.selectedStaffIds.length === 0 ? '(οποιοσδήποτε)' : `${form.selectedStaffIds.length} επιλεγμένοι`}
                </span>
              </label>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                <Chip label="Οποιοσδήποτε" checked={form.selectedStaffIds.length === 0} onClick={() => setForm(p => ({ ...p, selectedStaffIds: [] }))} color="#64748b" />
                {staffList.map(s => {
                  const checked = form.selectedStaffIds.includes(s.id);
                  return (
                    <Chip key={s.id} label={s.full_name} checked={checked} onClick={() => setForm(p => ({
                      ...p, selectedStaffIds: checked ? p.selectedStaffIds.filter(x => x !== s.id) : [...p.selectedStaffIds, s.id]
                    }))} />
                  );
                })}
              </div>
            </div>

            {/* Capacity */}
            <div className="form-group">
              <label className="form-label">Χωρητικότητα ανά αίθουσα</label>
              <input type="number" min="1" className="form-input" style={{ maxWidth: 160 }} placeholder="π.χ. 10" value={form.max_capacity} onChange={e => setForm(p => ({ ...p, max_capacity: e.target.value }))} />
            </div>

            {/* Summary */}
            {form.weekdays.length > 0 && form.times.length > 0 && (() => {
              const rooms = Math.max(form.selectedRoomIds.length, 1);
              const staff = Math.max(form.selectedStaffIds.length, 1);
              const total = form.weekdays.length * form.times.length * rooms * staff;
              return total > 1 ? (
                <div style={{ fontSize: '0.8rem', color: '#166534', marginBottom: 12, padding: '6px 12px', background: '#f0fdf4', borderRadius: 8, border: '1px solid #bbf7d0' }}>
                  {form.weekdays.length} ημ. × {form.times.length} ώρ. × {rooms} αίθ. × {staff} γυμν. = <strong>{total} slots</strong>
                </div>
              ) : null;
            })()}

            <div style={{ display: 'flex', gap: 8 }}>
              <button type="submit" className="btn btn-primary" disabled={saving}><Save size={14} /> Αποθήκευση</button>
              <button type="button" className="btn btn-secondary" onClick={() => setShowForm(false)}>Άκυρο</button>
            </div>
          </form>
        </div>
      )}

      {/* ── Slots table ── */}
      <div className="card">
        {/* Label filter tabs (only when multiple labels) */}
        {hasLabels && (
          <div style={{ display: 'flex', gap: 0, borderBottom: '1px solid #e2e8f0', marginBottom: 16, flexWrap: 'wrap' }}>
            <button type="button" onClick={() => setFilterLabel(null)} style={{ padding: '7px 16px', border: 'none', borderBottom: `2px solid ${filterLabel === null ? '#76C043' : 'transparent'}`, background: 'none', cursor: 'pointer', fontWeight: filterLabel === null ? 600 : 400, color: filterLabel === null ? '#76C043' : '#64748b', fontSize: '0.88rem' }}>
              Όλα ({schedules.length})
            </button>
            {labels.map(label => {
              const count = schedules.filter(s => (s.label || '') === label).length;
              const isActive = filterLabel === label;
              return (
                <div key={label} style={{ display: 'flex', alignItems: 'center' }}>
                  <button type="button" onClick={() => setFilterLabel(isActive ? null : label)} style={{ padding: '7px 14px', border: 'none', borderBottom: `2px solid ${isActive ? '#76C043' : 'transparent'}`, background: 'none', cursor: 'pointer', fontWeight: isActive ? 600 : 400, color: isActive ? '#76C043' : '#64748b', fontSize: '0.88rem' }}>
                    {label} ({count})
                  </button>
                  {isActive && (
                    <>
                      <button type="button" title="Μετονομασία / επεξεργασία" onClick={() => {
                        const sample = schedules.find(s => s.label === label);
                        setEditingLabel({ oldLabel: label, newLabel: label, subtitle: sample?.subtitle || '', icon_key: sample?.icon_key || '' });
                      }} style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#76C043', padding: '0 4px' }}>
                        <Edit2 size={13} />
                      </button>
                      <button type="button" title="Διαγραφή ομάδας" onClick={() => deleteLabelGroup(label)} style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#ef4444', padding: '0 4px' }}>
                        <Trash2 size={13} />
                      </button>
                    </>
                  )}
                </div>
              );
            })}
            {schedules.filter(s => !s.label).length > 0 && (
              <button type="button" onClick={() => setFilterLabel('')} style={{ padding: '7px 14px', border: 'none', borderBottom: `2px solid ${filterLabel === '' ? '#76C043' : 'transparent'}`, background: 'none', cursor: 'pointer', fontWeight: filterLabel === '' ? 600 : 400, color: filterLabel === '' ? '#76C043' : '#94a3b8', fontSize: '0.88rem' }}>
                Χωρίς τίτλο ({schedules.filter(s => !s.label).length})
              </button>
            )}
          </div>
        )}

        {/* Edit label modal */}
        {editingLabel && (
          <div style={{ background: '#f0fdf4', borderRadius: 10, padding: 14, marginBottom: 14, border: '1px solid #c7d2fe' }}>
            <div style={{ fontWeight: 600, marginBottom: 10 }}>Επεξεργασία τίτλου «{editingLabel.oldLabel}»</div>
            <div className="form-grid-2" style={{ marginBottom: 10 }}>
              <div className="form-group" style={{ marginBottom: 0 }}>
                <label className="form-label">Τίτλος</label>
                <input className="form-input" value={editingLabel.newLabel} onChange={e => setEditingLabel(p => ({ ...p, newLabel: e.target.value }))} />
              </div>
              <div className="form-group" style={{ marginBottom: 0 }}>
                <label className="form-label">Υπότιτλος</label>
                <input className="form-input" value={editingLabel.subtitle} onChange={e => setEditingLabel(p => ({ ...p, subtitle: e.target.value }))} />
              </div>
              <div className="form-group" style={{ marginBottom: 0 }}>
                <label className="form-label">Icon</label>
                <select className="form-input" value={editingLabel.icon_key} onChange={e => setEditingLabel(p => ({ ...p, icon_key: e.target.value }))}>
                  {ICON_KEYS.map(i => <option key={i.v} value={i.v}>{i.label}</option>)}
                </select>
              </div>
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <button className="btn btn-primary btn-sm" onClick={saveLabelEdit}><Save size={13} /> Αποθήκευση</button>
              <button className="btn btn-secondary btn-sm" onClick={() => setEditingLabel(null)}>Άκυρο</button>
            </div>
          </div>
        )}

        {hasLabels && filterLabel != null && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14, padding: '10px 12px', background: '#f0fdf4', borderRadius: 10, border: '1px solid #bbf7d0', flexWrap: 'wrap' }}>
            <span style={{ fontSize: '0.85rem', fontWeight: 600, color: '#166534' }}>
              Μαζική χωρητικότητα για «{filterLabel}»:
            </span>
            <input
              type="number"
              min="1"
              className="form-input"
              style={{ width: 90, padding: '6px 10px' }}
              placeholder="π.χ. 20"
              value={bulkCapacity}
              onChange={(e) => setBulkCapacity(e.target.value)}
            />
            <button type="button" className="btn btn-primary btn-sm" disabled={bulkSaving} onClick={applyBulkCapacity}>
              Εφαρμογή σε όλα
            </button>
          </div>
        )}
        {displayedSlots.length > 0 && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 10, padding: '7px 10px', background: selectedSlotIds.length ? '#fef2f2' : '#f8fafc', borderRadius: 8, border: `1px solid ${selectedSlotIds.length ? '#fecaca' : '#e2e8f0'}` }}>
            <input type="checkbox" checked={selectedSlotIds.length === displayedSlots.length && displayedSlots.length > 0} onChange={toggleSelectAll} style={{ width: 15, height: 15, cursor: 'pointer' }} />
            <span style={{ fontSize: '0.82rem', color: '#64748b' }}>
              {selectedSlotIds.length > 0 ? `${selectedSlotIds.length} επιλεγμένα` : 'Επιλογή όλων'}
            </span>
            {selectedSlotIds.length > 0 && (
              <button className="btn btn-danger btn-sm" onClick={deleteSelected}>
                <Trash2 size={13} /> Διαγραφή {selectedSlotIds.length}
              </button>
            )}
          </div>
        )}

        <table>
          <thead>
            <tr>
              <th style={{ width: 32 }}></th>
              <th>Ημέρα</th>
              <th>Ώρα</th>
              {hasLabels && <th>Τίτλος</th>}
              <th>Γυμναστής</th>
              <th>Αίθουσα</th>
              <th>Χωρητικότητα</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {displayedSlots.map(s => (
              <tr key={s.id} style={{ background: selectedSlotIds.includes(s.id) ? '#fef2f2' : undefined }}>
                <td>
                  <input type="checkbox" checked={selectedSlotIds.includes(s.id)} onChange={() => toggleSelect(s.id)} style={{ width: 14, height: 14, cursor: 'pointer' }} />
                </td>
                <td>{WEEKDAYS_FULL[s.weekday]}</td>
                <td style={{ fontWeight: 600 }}>{String(s.start_time).slice(0, 5)}</td>
                {hasLabels && <td style={{ color: '#64748b', fontSize: '0.85rem' }}>{s.label || '—'}</td>}

                {/* Staff inline edit */}
                <td>{editingSlot?.id === s.id && editingSlot.field === 'staff_id' ? (
                  <div style={{ display: 'flex', gap: 4 }}>
                    <select className="form-input" style={{ padding: '2px 6px', fontSize: '0.82rem' }} value={editingSlot.value} onChange={e => setEditingSlot({ ...editingSlot, value: e.target.value })}>
                      <option value="">— Οποιοσδήποτε —</option>
                      {staffList.map(st => <option key={st.id} value={st.id}>{st.full_name}</option>)}
                    </select>
                    <button onClick={() => saveSlotField(s.id, 'staff_id', editingSlot.value)} style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#22c55e' }}><Check size={13} /></button>
                    <button onClick={() => setEditingSlot(null)} style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#94a3b8' }}><X size={13} /></button>
                  </div>
                ) : (
                  <span onClick={() => setEditingSlot({ id: s.id, field: 'staff_id', value: s.staff_id || '' })} style={{ cursor: 'pointer', borderBottom: '1px dashed #cbd5e1' }}>
                    {s.staff_name || <span style={{ color: '#94a3b8' }}>—</span>}
                    <Edit2 size={10} style={{ marginLeft: 3, color: '#94a3b8' }} />
                  </span>
                )}</td>

                {/* Room inline edit */}
                <td>{editingSlot?.id === s.id && editingSlot.field === 'room_id' ? (
                  <div style={{ display: 'flex', gap: 4 }}>
                    <select className="form-input" style={{ padding: '2px 6px', fontSize: '0.82rem' }} value={editingSlot.value} onChange={e => setEditingSlot({ ...editingSlot, value: e.target.value })}>
                      <option value="">— Χωρίς —</option>
                      {roomsList.map(r => <option key={r.id} value={r.id}>{r.name}</option>)}
                    </select>
                    <button onClick={() => saveSlotField(s.id, 'room_id', editingSlot.value || null)} style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#22c55e' }}><Check size={13} /></button>
                    <button onClick={() => setEditingSlot(null)} style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#94a3b8' }}><X size={13} /></button>
                  </div>
                ) : (
                  <span onClick={() => setEditingSlot({ id: s.id, field: 'room_id', value: s.room_id || '' })} style={{ cursor: 'pointer', borderBottom: '1px dashed #cbd5e1' }}>
                    {s.room_display_name || s.room_name || <span style={{ color: '#94a3b8' }}>—</span>}
                    <Edit2 size={10} style={{ marginLeft: 3, color: '#94a3b8' }} />
                  </span>
                )}</td>

                {/* Capacity inline edit */}
                <td>{editingSlot?.id === s.id && editingSlot.field === 'max_capacity' ? (
                  <div style={{ display: 'flex', gap: 4 }}>
                    <input type="number" className="form-input" style={{ width: 70, padding: '2px 6px', fontSize: '0.82rem' }} value={editingSlot.value} onChange={e => setEditingSlot({ ...editingSlot, value: e.target.value })} />
                    <button onClick={() => saveSlotField(s.id, 'max_capacity', editingSlot.value ? Number(editingSlot.value) : null)} style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#22c55e' }}><Check size={13} /></button>
                    <button onClick={() => setEditingSlot(null)} style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#94a3b8' }}><X size={13} /></button>
                  </div>
                ) : (
                  <span onClick={() => setEditingSlot({ id: s.id, field: 'max_capacity', value: s.max_capacity ?? '' })} style={{ cursor: 'pointer', borderBottom: '1px dashed #cbd5e1' }}>
                    {s.max_capacity ?? <span style={{ color: '#94a3b8' }}>—</span>}
                    <Edit2 size={10} style={{ marginLeft: 3, color: '#94a3b8' }} />
                  </span>
                )}</td>

                <td>
                  <button className="btn btn-danger btn-sm" onClick={() => deleteSlot(s.id)}><Trash2 size={13} /></button>
                </td>
              </tr>
            ))}
            {!displayedSlots.length && (
              <tr><td colSpan={8} className="text-muted" style={{ textAlign: 'center', padding: 32 }}>
                Δεν υπάρχουν slots. Πάτα «Προσθήκη slots» για να ξεκινήσεις.
              </td></tr>
            )}
          </tbody>
        </table>
      </div>
    </Layout>
  );
}
