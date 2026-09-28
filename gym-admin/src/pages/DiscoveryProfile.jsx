import { useEffect, useRef, useState } from 'react';
import {
  Globe, MapPin, Eye, EyeOff, Save, Zap, Image, UserCircle,
  CalendarDays, Package, Upload, Trash2, Star, Plus, Pencil, X, Check,
} from 'lucide-react';
import api from '../api/client';

// ── helpers ──────────────────────────────────────────────────────────────────

const TABS = [
  { id: 'info',     label: 'Πληροφορίες', icon: Globe },
  { id: 'photos',   label: 'Φωτογραφίες', icon: Image },
  { id: 'trainers', label: 'Trainers',     icon: UserCircle },
  { id: 'schedule', label: 'Πρόγραμμα',   icon: CalendarDays },
  { id: 'packages', label: 'Πακέτα',      icon: Package },
];

const DAYS = ['', 'Δευτέρα', 'Τρίτη', 'Τετάρτη', 'Πέμπτη', 'Παρασκευή', 'Σάββατο', 'Κυριακή'];

const CLASS_COLORS = [
  '#C52473', '#B48CFF', '#3EE6FF', '#FF6FD8', '#FFB23E',
  '#FF5252', '#69FF47', '#40C4FF', '#FF6E40', '#EEFF41',
];

// ── Info Tab ─────────────────────────────────────────────────────────────────

function InfoSection() {
  const [form, setForm] = useState({
    city: '', country: 'GR', latitude: '', longitude: '',
    description: '', is_discoverable: false, accepts_drop_in: false,
    drop_in_price_cents: '',
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving]   = useState(false);
  const [saved, setSaved]     = useState(false);
  const [error, setError]     = useState(null);

  useEffect(() => {
    api.get('/client-admin/discovery-profile').then(r => {
      const d = r.data;
      setForm({
        city:                d.city || '',
        country:             d.country || 'GR',
        latitude:            d.latitude != null ? String(d.latitude) : '',
        longitude:           d.longitude != null ? String(d.longitude) : '',
        description:         d.description || '',
        is_discoverable:     !!d.is_discoverable,
        accepts_drop_in:     !!d.accepts_drop_in,
        drop_in_price_cents: d.drop_in_price_cents ? String(d.drop_in_price_cents / 100) : '',
      });
      setLoading(false);
    }).catch(() => setLoading(false));
  }, []);

  async function handleSave(e) {
    e.preventDefault();
    setSaving(true); setError(null); setSaved(false);
    try {
      await api.patch('/client-admin/discovery-profile', {
        city:                form.city || null,
        country:             form.country || null,
        latitude:            form.latitude ? parseFloat(form.latitude) : null,
        longitude:           form.longitude ? parseFloat(form.longitude) : null,
        description:         form.description || null,
        is_discoverable:     form.is_discoverable ? 1 : 0,
        accepts_drop_in:     form.accepts_drop_in ? 1 : 0,
        drop_in_price_cents: form.drop_in_price_cents ? Math.round(parseFloat(form.drop_in_price_cents) * 100) : 0,
      });
      setSaved(true);
      setTimeout(() => setSaved(false), 2500);
    } catch (err) {
      setError(err.response?.data?.error || err.message);
    } finally {
      setSaving(false);
    }
  }

  if (loading) return <div className="text-center py-16 text-gray-400">Φόρτωση…</div>;

  const Toggle = ({ label, desc, value, onChange, icon: Icon, activeColor = 'indigo' }) => (
    <div
      className={`rounded-2xl border-2 p-5 flex items-center justify-between cursor-pointer transition-colors ${
        value ? `border-${activeColor}-400 bg-${activeColor}-50 dark:bg-${activeColor}-900/20`
              : 'border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800'
      }`}
      onClick={() => onChange(!value)}
    >
      <div className="flex items-center gap-3">
        <Icon className={value ? `text-${activeColor}-600` : 'text-gray-400'} size={22} />
        <div>
          <p className="font-semibold text-gray-900 dark:text-white">{label}</p>
          <p className="text-sm text-gray-500">{desc}</p>
        </div>
      </div>
      <button
        type="button"
        className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${value ? `bg-${activeColor}-500` : 'bg-gray-300 dark:bg-gray-600'}`}
        onClick={e => { e.stopPropagation(); onChange(!value); }}
      >
        <span className={`inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform ${value ? 'translate-x-6' : 'translate-x-1'}`} />
      </button>
    </div>
  );

  return (
    <form onSubmit={handleSave} className="space-y-5 max-w-2xl">
      <Toggle
        label={form.is_discoverable ? 'Εμφανίζεστε στην αναζήτηση' : 'Δεν εμφανίζεστε στην αναζήτηση'}
        desc="Ενεργοποιήστε για να εμφανίζεστε στα αποτελέσματα"
        value={form.is_discoverable}
        onChange={v => setForm(f => ({ ...f, is_discoverable: v }))}
        icon={form.is_discoverable ? Eye : EyeOff}
      />

      <div className={`rounded-2xl border-2 p-5 space-y-3 transition-colors ${
        form.accepts_drop_in ? 'border-green-400 bg-green-50 dark:bg-green-900/20' : 'border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800'
      }`}>
        <div className="flex items-center justify-between cursor-pointer" onClick={() => setForm(f => ({ ...f, accepts_drop_in: !f.accepts_drop_in }))}>
          <div className="flex items-center gap-3">
            <Zap className={form.accepts_drop_in ? 'text-green-600' : 'text-gray-400'} size={22} />
            <div>
              <p className="font-semibold text-gray-900 dark:text-white">Drop-in Είσοδος</p>
              <p className="text-sm text-gray-500">Αποδοχή μεμονωμένων επισκέψεων</p>
            </div>
          </div>
          <button
            type="button"
            className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${form.accepts_drop_in ? 'bg-green-500' : 'bg-gray-300 dark:bg-gray-600'}`}
            onClick={e => { e.stopPropagation(); setForm(f => ({ ...f, accepts_drop_in: !f.accepts_drop_in })); }}
          >
            <span className={`inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform ${form.accepts_drop_in ? 'translate-x-6' : 'translate-x-1'}`} />
          </button>
        </div>
        {form.accepts_drop_in && (
          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">Τιμή Drop-in (€)</label>
            <input
              type="number"
              step="0.01"
              min="0"
              value={form.drop_in_price_cents}
              onChange={e => setForm(f => ({ ...f, drop_in_price_cents: e.target.value }))}
              placeholder="π.χ. 10.00"
              className="w-40 px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-green-400"
            />
          </div>
        )}
      </div>

      <div className="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-2xl p-5 space-y-4">
        <div className="flex items-center gap-2 mb-1">
          <MapPin size={16} className="text-gray-400" />
          <span className="font-semibold text-gray-900 dark:text-white text-sm">Τοποθεσία</span>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">Πόλη</label>
            <input value={form.city} onChange={e => setForm(f => ({ ...f, city: e.target.value }))} placeholder="π.χ. Αθήνα"
              className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-sm text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-400" />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">Χώρα</label>
            <input value={form.country} onChange={e => setForm(f => ({ ...f, country: e.target.value }))} placeholder="GR"
              className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-sm text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-400" />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">Γεωγρ. Πλάτος</label>
            <input value={form.latitude} onChange={e => setForm(f => ({ ...f, latitude: e.target.value }))} placeholder="π.χ. 37.9838"
              className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-sm text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-400" />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">Γεωγρ. Μήκος</label>
            <input value={form.longitude} onChange={e => setForm(f => ({ ...f, longitude: e.target.value }))} placeholder="π.χ. 23.7275"
              className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-sm text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-400" />
          </div>
        </div>
        <div>
          <label className="block text-xs font-medium text-gray-500 mb-1">Περιγραφή</label>
          <textarea value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
            rows={3} placeholder="Σύντομη περιγραφή του γυμναστηρίου σας που θα βλέπουν οι χρήστες"
            className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-sm text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-400 resize-none" />
        </div>
      </div>

      {error && <p className="text-sm text-red-500">{error}</p>}

      <button type="submit" disabled={saving}
        className="flex items-center gap-2 px-6 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold rounded-xl transition-colors disabled:opacity-50">
        {saved ? <Check size={16} /> : <Save size={16} />}
        {saving ? 'Αποθήκευση…' : saved ? 'Αποθηκεύτηκε!' : 'Αποθήκευση'}
      </button>
    </form>
  );
}

// ── Photos Tab ────────────────────────────────────────────────────────────────

function PhotosSection() {
  const [photos, setPhotos]     = useState([]);
  const [loading, setLoading]   = useState(true);
  const [uploading, setUploading] = useState(false);
  const [error, setError]       = useState(null);
  const inputRef = useRef();

  async function load() {
    setLoading(true);
    try { const r = await api.get('/client-admin/gym-photos'); setPhotos(r.data); }
    finally { setLoading(false); }
  }
  useEffect(() => { load(); }, []);

  async function handleUpload(e) {
    const files = Array.from(e.target.files || []);
    if (!files.length) return;
    setUploading(true); setError(null);
    try {
      for (const file of files) {
        const fd = new FormData(); fd.append('photo', file);
        await api.post('/client-admin/gym-photos/upload', fd, { headers: { 'Content-Type': 'multipart/form-data' } });
      }
      await load();
    } catch (err) { setError(err.response?.data?.error || err.message); }
    finally { setUploading(false); if (inputRef.current) inputRef.current.value = ''; }
  }

  async function setCover(id) {
    await api.patch(`/client-admin/gym-photos/${id}/set-cover`);
    setPhotos(ps => ps.map(p => ({ ...p, is_cover: p.id === id ? 1 : 0 })));
  }

  async function handleDelete(id) {
    if (!confirm('Διαγραφή φωτογραφίας;')) return;
    await api.delete(`/client-admin/gym-photos/${id}`);
    setPhotos(ps => ps.filter(p => p.id !== id));
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <p className="text-sm text-gray-500">Κλικ στο ⭐ για να ορίσετε την κεντρική φωτογραφία του προφίλ</p>
        <button onClick={() => inputRef.current?.click()} disabled={uploading}
          className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold rounded-xl text-sm transition-colors disabled:opacity-50">
          <Upload size={15} /> {uploading ? 'Μεταφόρτωση…' : 'Προσθήκη'}
        </button>
        <input ref={inputRef} type="file" accept="image/*" multiple className="hidden" onChange={handleUpload} />
      </div>

      {error && <p className="text-sm text-red-500">{error}</p>}

      {loading ? (
        <div className="text-center py-12 text-gray-400">Φόρτωση…</div>
      ) : photos.length === 0 ? (
        <div onClick={() => inputRef.current?.click()}
          className="border-2 border-dashed border-gray-300 dark:border-gray-700 rounded-2xl p-16 flex flex-col items-center gap-3 cursor-pointer hover:border-indigo-400 transition-colors">
          <Image size={40} className="text-gray-300 dark:text-gray-600" />
          <p className="text-gray-500 font-medium">Δεν υπάρχουν φωτογραφίες</p>
          <p className="text-sm text-gray-400">Κλικ για μεταφόρτωση (JPG, PNG, WebP)</p>
        </div>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
          {photos.map(p => (
            <div key={p.id} className={`relative group rounded-xl overflow-hidden aspect-video bg-gray-100 dark:bg-gray-800 ${p.is_cover ? 'ring-2 ring-yellow-400' : ''}`}>
              <img src={p.url} alt="" className="w-full h-full object-cover" />
              {p.is_cover && (
                <div className="absolute top-2 left-2 bg-yellow-400 text-yellow-900 text-xs font-bold px-2 py-0.5 rounded-full">
                  Κεντρική
                </div>
              )}
              <div className="absolute top-2 right-2 flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                <button onClick={() => setCover(p.id)} title="Ορισμός ως κεντρική"
                  className={`p-1.5 rounded-lg ${p.is_cover ? 'bg-yellow-400 text-yellow-900' : 'bg-white/90 text-gray-600 hover:bg-yellow-400 hover:text-yellow-900'} transition-colors`}>
                  <Star size={13} />
                </button>
                <button onClick={() => handleDelete(p.id)}
                  className="p-1.5 bg-red-500 hover:bg-red-600 text-white rounded-lg transition-colors">
                  <Trash2 size={13} />
                </button>
              </div>
            </div>
          ))}
          <div onClick={() => inputRef.current?.click()}
            className="aspect-video border-2 border-dashed border-gray-300 dark:border-gray-700 rounded-xl flex flex-col items-center justify-center gap-2 cursor-pointer hover:border-indigo-400 transition-colors">
            <Upload size={20} className="text-gray-400" />
            <span className="text-xs text-gray-400">Προσθήκη</span>
          </div>
        </div>
      )}
    </div>
  );
}

// ── Trainers Tab ──────────────────────────────────────────────────────────────

const EMPTY_TRAINER = { name: '', specialty: '', photo_url: '' };

function TrainersSection() {
  const [trainers, setTrainers] = useState([]);
  const [loading, setLoading]   = useState(true);
  const [modal, setModal]       = useState(null);
  const [form, setForm]         = useState(EMPTY_TRAINER);
  const [saving, setSaving]     = useState(false);
  const [error, setError]       = useState(null);
  const [uploading, setUploading] = useState(false);
  const photoRef = useRef();

  async function load() {
    setLoading(true);
    try { const r = await api.get('/client-admin/gym-trainers'); setTrainers(r.data); }
    finally { setLoading(false); }
  }
  useEffect(() => { load(); }, []);

  function openAdd() { setForm(EMPTY_TRAINER); setModal('add'); setError(null); }
  function openEdit(t) { setForm({ name: t.name, specialty: t.specialty || '', photo_url: t.photo_url || '' }); setModal(t); setError(null); }

  async function handlePhotoUpload(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    try {
      const fd = new FormData(); fd.append('photo', file);
      const r = await api.post('/client-admin/gym-trainers/upload-photo', fd, { headers: { 'Content-Type': 'multipart/form-data' } });
      setForm(f => ({ ...f, photo_url: r.data.url }));
    } catch (err) { setError(err.response?.data?.error || err.message); }
    finally { setUploading(false); if (photoRef.current) photoRef.current.value = ''; }
  }

  async function handleSave() {
    if (!form.name.trim()) { setError('Συμπλήρωσε το όνομα'); return; }
    setSaving(true); setError(null);
    try {
      const payload = { name: form.name.trim(), specialty: form.specialty || null, photo_url: form.photo_url || null };
      if (modal === 'add') await api.post('/client-admin/gym-trainers', payload);
      else await api.put(`/client-admin/gym-trainers/${modal.id}`, payload);
      await load(); setModal(null);
    } catch (e) { setError(e.response?.data?.error || e.message); }
    finally { setSaving(false); }
  }

  async function handleDelete(id) {
    if (!confirm('Διαγραφή trainer;')) return;
    await api.delete(`/client-admin/gym-trainers/${id}`);
    setTrainers(ts => ts.filter(t => t.id !== id));
  }

  return (
    <div className="space-y-4">
      <div className="flex justify-end">
        <button onClick={openAdd}
          className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold rounded-xl text-sm transition-colors">
          <Plus size={15} /> Νέος Trainer
        </button>
      </div>

      {loading ? <div className="text-center py-12 text-gray-400">Φόρτωση…</div>
        : trainers.length === 0 ? (
          <div className="text-center py-12 border-2 border-dashed border-gray-200 dark:border-gray-700 rounded-2xl">
            <UserCircle size={40} className="mx-auto text-gray-300 dark:text-gray-600 mb-3" />
            <p className="text-gray-400 mb-3">Δεν υπάρχουν trainers</p>
            <button onClick={openAdd} className="text-indigo-600 font-semibold text-sm hover:underline">+ Προσθήκη trainer</button>
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
            {trainers.map(t => (
              <div key={t.id} className="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-2xl p-4 flex flex-col items-center gap-3 relative group">
                {t.photo_url ? (
                  <img src={t.photo_url} alt={t.name} className="w-16 h-16 rounded-full object-cover" />
                ) : (
                  <div className="w-16 h-16 rounded-full bg-indigo-100 dark:bg-indigo-900/30 flex items-center justify-center">
                    <UserCircle size={32} className="text-indigo-400" />
                  </div>
                )}
                <div className="text-center">
                  <p className="font-semibold text-gray-900 dark:text-white text-sm">{t.name}</p>
                  {t.specialty && <p className="text-xs text-gray-500 mt-0.5">{t.specialty}</p>}
                </div>
                <div className="absolute top-2 right-2 flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                  <button onClick={() => openEdit(t)} className="p-1.5 text-gray-400 hover:text-indigo-600 bg-white dark:bg-gray-700 rounded-lg shadow">
                    <Pencil size={12} />
                  </button>
                  <button onClick={() => handleDelete(t.id)} className="p-1.5 text-gray-400 hover:text-red-500 bg-white dark:bg-gray-700 rounded-lg shadow">
                    <Trash2 size={12} />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}

      {modal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50">
          <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-2xl w-full max-w-sm p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-bold text-gray-900 dark:text-white">
                {modal === 'add' ? 'Νέος Trainer' : 'Επεξεργασία'}
              </h2>
              <button onClick={() => setModal(null)} className="text-gray-400 hover:text-gray-600"><X size={20} /></button>
            </div>

            <div className="flex flex-col items-center gap-3">
              {form.photo_url ? (
                <img src={form.photo_url} alt="" className="w-20 h-20 rounded-full object-cover" />
              ) : (
                <div className="w-20 h-20 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center">
                  <UserCircle size={36} className="text-gray-400" />
                </div>
              )}
              <button type="button" onClick={() => photoRef.current?.click()}
                className="text-sm text-indigo-600 hover:underline font-medium flex items-center gap-1">
                <Upload size={13} /> {uploading ? 'Μεταφόρτωση…' : 'Ανέβασε φωτογραφία'}
              </button>
              <input ref={photoRef} type="file" accept="image/*" className="hidden" onChange={handlePhotoUpload} />
            </div>

            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">Όνομα *</label>
              <input value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))}
                placeholder="π.χ. Νίκος Παπαδόπουλος"
                className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 text-sm text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-400" />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">Ειδικότητα</label>
              <input value={form.specialty} onChange={e => setForm(f => ({ ...f, specialty: e.target.value }))}
                placeholder="π.χ. CrossFit, Pilates, TRX"
                className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 text-sm text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-400" />
            </div>

            {error && <p className="text-sm text-red-500">{error}</p>}

            <div className="flex gap-3 pt-1">
              <button onClick={() => setModal(null)}
                className="flex-1 py-2.5 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 rounded-xl font-medium text-sm hover:bg-gray-50 dark:hover:bg-gray-800">
                Άκυρο
              </button>
              <button onClick={handleSave} disabled={saving}
                className="flex-1 flex items-center justify-center gap-2 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl font-semibold text-sm disabled:opacity-50">
                <Check size={14} /> {saving ? 'Αποθήκευση…' : 'Αποθήκευση'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// ── Schedule Tab ──────────────────────────────────────────────────────────────

const EMPTY_CLASS = { day_of_week: 1, start_time: '09:00', class_name: '', trainer_name: '', color: '#C52473', equipment: '', max_capacity: '' };

function ScheduleSection() {
  const [entries, setEntries]   = useState([]);
  const [loading, setLoading]   = useState(true);
  const [modal, setModal]       = useState(null);
  const [form, setForm]         = useState(EMPTY_CLASS);
  const [saving, setSaving]     = useState(false);
  const [error, setError]       = useState(null);
  const [activeDay, setActiveDay] = useState(new Date().getDay() || 7);

  async function load() {
    setLoading(true);
    try { const r = await api.get('/client-admin/class-schedules'); setEntries(r.data); }
    finally { setLoading(false); }
  }
  useEffect(() => { load(); }, []);

  function openAdd() { setForm({ ...EMPTY_CLASS, day_of_week: activeDay }); setModal('add'); setError(null); }
  function openEdit(e) {
    setForm({ day_of_week: e.day_of_week, start_time: e.start_time, class_name: e.class_name,
      trainer_name: e.trainer_name || '', color: e.color || '#C52473',
      equipment: e.equipment || '', max_capacity: e.max_capacity != null ? String(e.max_capacity) : '' });
    setModal(e); setError(null);
  }

  async function handleSave() {
    if (!form.class_name.trim()) { setError('Συμπλήρωσε το όνομα'); return; }
    setSaving(true); setError(null);
    try {
      const payload = { ...form, max_capacity: form.max_capacity ? parseInt(form.max_capacity) : null, trainer_name: form.trainer_name || null, equipment: form.equipment || null };
      if (modal === 'add') await api.post('/client-admin/class-schedules', payload);
      else await api.put(`/client-admin/class-schedules/${modal.id}`, payload);
      await load(); setModal(null);
    } catch (e) { setError(e.response?.data?.error || e.message); }
    finally { setSaving(false); }
  }

  async function handleDelete(id) {
    if (!confirm('Διαγραφή μαθήματος;')) return;
    await api.delete(`/client-admin/class-schedules/${id}`);
    setEntries(es => es.filter(e => e.id !== id));
  }

  const dayEntries = entries.filter(e => e.day_of_week === activeDay);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div className="flex gap-1 bg-gray-100 dark:bg-gray-800 rounded-xl p-1 flex-1 mr-4">
          {DAYS.slice(1).map((d, i) => {
            const day = i + 1;
            const count = entries.filter(e => e.day_of_week === day).length;
            return (
              <button key={day} onClick={() => setActiveDay(day)}
                className={`flex-1 py-2 px-1 rounded-lg text-sm font-medium transition-colors relative ${
                  activeDay === day ? 'bg-white dark:bg-gray-700 text-indigo-600 dark:text-indigo-400 shadow' : 'text-gray-500 hover:text-gray-700 dark:hover:text-gray-300'
                }`}>
                {d.slice(0, 3)}
                {count > 0 && <span className="ml-1 text-xs bg-indigo-100 dark:bg-indigo-900 text-indigo-600 dark:text-indigo-400 rounded-full px-1">{count}</span>}
              </button>
            );
          })}
        </div>
        <button onClick={openAdd} className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold rounded-xl text-sm whitespace-nowrap">
          <Plus size={15} /> Νέο Μάθημα
        </button>
      </div>

      {loading ? <div className="text-center py-12 text-gray-400">Φόρτωση…</div>
        : dayEntries.length === 0 ? (
          <div className="text-center py-12 border-2 border-dashed border-gray-200 dark:border-gray-700 rounded-2xl">
            <p className="text-gray-400 mb-3">Δεν υπάρχουν μαθήματα για {DAYS[activeDay]}</p>
            <button onClick={openAdd} className="text-indigo-600 font-semibold text-sm hover:underline">+ Προσθήκη μαθήματος</button>
          </div>
        ) : (
          <div className="space-y-2">
            {dayEntries.map(e => (
              <div key={e.id} className="flex items-center gap-4 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl px-5 py-4">
                <div className="w-1 self-stretch rounded-full" style={{ backgroundColor: e.color || '#C52473' }} />
                <div className="w-14 text-center">
                  <span className="text-base font-bold text-gray-900 dark:text-white">{e.start_time}</span>
                </div>
                <div className="flex-1 min-w-0">
                  <p className="font-semibold text-gray-900 dark:text-white">{e.class_name}</p>
                  <p className="text-sm text-gray-500 truncate">
                    {[e.trainer_name, e.equipment, e.max_capacity ? `${e.max_capacity} άτομα` : null].filter(Boolean).join(' · ')}
                  </p>
                </div>
                <button onClick={() => openEdit(e)} className="p-2 text-gray-400 hover:text-indigo-600 rounded-lg hover:bg-indigo-50 dark:hover:bg-indigo-900/20">
                  <Pencil size={15} />
                </button>
                <button onClick={() => handleDelete(e.id)} className="p-2 text-gray-400 hover:text-red-500 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20">
                  <Trash2 size={15} />
                </button>
              </div>
            ))}
          </div>
        )}

      {modal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50">
          <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-2xl w-full max-w-md p-6 space-y-4 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-bold text-gray-900 dark:text-white">{modal === 'add' ? 'Νέο Μάθημα' : 'Επεξεργασία'}</h2>
              <button onClick={() => setModal(null)} className="text-gray-400 hover:text-gray-600"><X size={20} /></button>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-medium text-gray-500 mb-1">Ημέρα</label>
                <select value={form.day_of_week} onChange={e => setForm(f => ({ ...f, day_of_week: Number(e.target.value) }))}
                  className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 text-sm text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-400">
                  {DAYS.slice(1).map((d, i) => <option key={i+1} value={i+1}>{d}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-xs font-medium text-gray-500 mb-1">Ώρα</label>
                <input type="time" value={form.start_time} onChange={e => setForm(f => ({ ...f, start_time: e.target.value }))}
                  className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 text-sm text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-400" />
              </div>
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">Όνομα Μαθήματος *</label>
              <input value={form.class_name} onChange={e => setForm(f => ({ ...f, class_name: e.target.value }))} placeholder="π.χ. CrossFit, Pilates, TRX…"
                className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 text-sm text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-400" />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">Εκπαιδευτής</label>
              <input value={form.trainer_name} onChange={e => setForm(f => ({ ...f, trainer_name: e.target.value }))} placeholder="π.χ. Νίκος Παπαδόπουλος"
                className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 text-sm text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-400" />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-medium text-gray-500 mb-1">Εξοπλισμός</label>
                <input value={form.equipment} onChange={e => setForm(f => ({ ...f, equipment: e.target.value }))} placeholder="π.χ. TRX"
                  className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 text-sm text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-400" />
              </div>
              <div>
                <label className="block text-xs font-medium text-gray-500 mb-1">Μέγ. Χωρητικότητα</label>
                <input type="number" value={form.max_capacity} onChange={e => setForm(f => ({ ...f, max_capacity: e.target.value }))} placeholder="π.χ. 20"
                  className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 text-sm text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-400" />
              </div>
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-2">Χρώμα</label>
              <div className="flex gap-2 flex-wrap">
                {CLASS_COLORS.map(c => (
                  <button key={c} type="button" onClick={() => setForm(f => ({ ...f, color: c }))}
                    className="w-7 h-7 rounded-full border-2 transition-transform hover:scale-110"
                    style={{ backgroundColor: c, borderColor: form.color === c ? '#6366f1' : 'transparent', transform: form.color === c ? 'scale(1.2)' : undefined }} />
                ))}
              </div>
            </div>
            {error && <p className="text-sm text-red-500">{error}</p>}
            <div className="flex gap-3 pt-1">
              <button onClick={() => setModal(null)} className="flex-1 py-2.5 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 rounded-xl font-medium text-sm">Άκυρο</button>
              <button onClick={handleSave} disabled={saving}
                className="flex-1 flex items-center justify-center gap-2 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl font-semibold text-sm disabled:opacity-50">
                <Check size={14} /> {saving ? 'Αποθήκευση…' : 'Αποθήκευση'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// ── Packages Tab ──────────────────────────────────────────────────────────────

function PackagesSection() {
  const [plans, setPlans] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get('/client-admin/plans').then(r => { setPlans(r.data || []); setLoading(false); }).catch(() => setLoading(false));
  }, []);

  if (loading) return <div className="text-center py-12 text-gray-400">Φόρτωση…</div>;

  return (
    <div className="space-y-4">
      <p className="text-sm text-gray-500">Τα παρακάτω πακέτα εμφανίζονται στους χρήστες. Για να τα επεξεργαστείτε πηγαίνετε στην ενότητα <strong>Πακέτα</strong>.</p>
      {plans.length === 0 ? (
        <div className="text-center py-12 border-2 border-dashed border-gray-200 dark:border-gray-700 rounded-2xl">
          <Package size={40} className="mx-auto text-gray-300 dark:text-gray-600 mb-3" />
          <p className="text-gray-400">Δεν υπάρχουν πακέτα ακόμα</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {plans.map(p => (
            <div key={p.id} className="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-2xl p-4">
              <div className="flex items-start justify-between gap-2">
                <div className="flex-1 min-w-0">
                  <p className="font-semibold text-gray-900 dark:text-white truncate">{p.name}</p>
                  {p.description && <p className="text-xs text-gray-500 mt-0.5 line-clamp-2">{p.description}</p>}
                  <div className="flex flex-wrap gap-2 mt-2">
                    {p.duration_days && <span className="text-xs bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-300 px-2 py-0.5 rounded-full">{p.duration_days} μέρες</span>}
                    {p.sessions && <span className="text-xs bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-300 px-2 py-0.5 rounded-full">{p.sessions} συνεδρίες</span>}
                  </div>
                </div>
                <div className="text-right shrink-0">
                  <span className="text-lg font-bold text-indigo-600 dark:text-indigo-400">{((p.price_cents || 0) / 100).toFixed(0)}€</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ── Main Component ────────────────────────────────────────────────────────────

export default function DiscoveryProfile() {
  const [tab, setTab] = useState('info');

  return (
    <div className="max-w-4xl mx-auto p-6 space-y-6">
      <div className="flex items-center gap-3">
        <Globe className="text-indigo-500" size={24} />
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Προβολή στην Αγορά</h1>
          <p className="text-sm text-gray-500">Διαχείριση όλων των πληροφοριών που βλέπουν οι χρήστες στο app</p>
        </div>
      </div>

      {/* Tab bar */}
      <div className="flex gap-1 bg-gray-100 dark:bg-gray-800 rounded-xl p-1 overflow-x-auto">
        {TABS.map(t => (
          <button key={t.id} onClick={() => setTab(t.id)}
            className={`flex items-center gap-2 px-4 py-2.5 rounded-lg text-sm font-medium whitespace-nowrap transition-colors ${
              tab === t.id ? 'bg-white dark:bg-gray-700 text-indigo-600 dark:text-indigo-400 shadow' : 'text-gray-500 hover:text-gray-700 dark:hover:text-gray-300'
            }`}>
            <t.icon size={15} />
            {t.label}
          </button>
        ))}
      </div>

      {/* Tab content */}
      <div>
        {tab === 'info'     && <InfoSection />}
        {tab === 'photos'   && <PhotosSection />}
        {tab === 'trainers' && <TrainersSection />}
        {tab === 'schedule' && <ScheduleSection />}
        {tab === 'packages' && <PackagesSection />}
      </div>
    </div>
  );
}
