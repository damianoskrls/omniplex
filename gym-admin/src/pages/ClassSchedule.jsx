import { useEffect, useState } from 'react';
import { Calendar, Plus, Pencil, Trash2, X, Check } from 'lucide-react';
import api from '../api/client';

const DAYS = ['', 'Δευτέρα', 'Τρίτη', 'Τετάρτη', 'Πέμπτη', 'Παρασκευή', 'Σάββατο', 'Κυριακή'];

const CLASS_COLORS = [
  '#C6FF3D', '#3EE6FF', '#B48CFF', '#FF6FD8', '#FFB23E',
  '#FF5252', '#69FF47', '#40C4FF', '#FF6E40', '#EEFF41',
];

const EMPTY_FORM = {
  day_of_week: 1, start_time: '09:00', class_name: '',
  trainer_name: '', color: '#C6FF3D', equipment: '', max_capacity: '',
};

export default function ClassSchedule() {
  const [entries, setEntries]   = useState([]);
  const [loading, setLoading]   = useState(true);
  const [modal, setModal]       = useState(null); // null | 'add' | entry obj
  const [form, setForm]         = useState(EMPTY_FORM);
  const [saving, setSaving]     = useState(false);
  const [error, setError]       = useState(null);
  const [activeDay, setActiveDay] = useState(1);

  async function load() {
    setLoading(true);
    try {
      const r = await api.get('/client-admin/class-schedules');
      setEntries(r.data);
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

  function openEdit(entry) {
    setForm({
      day_of_week:  entry.day_of_week,
      start_time:   entry.start_time,
      class_name:   entry.class_name,
      trainer_name: entry.trainer_name || '',
      color:        entry.color || '#C6FF3D',
      equipment:    entry.equipment || '',
      max_capacity: entry.max_capacity != null ? String(entry.max_capacity) : '',
    });
    setModal(entry);
    setError(null);
  }

  async function handleSave() {
    if (!form.class_name.trim()) { setError('Συμπλήρωσε το όνομα'); return; }
    setSaving(true); setError(null);
    try {
      const payload = {
        ...form,
        max_capacity: form.max_capacity ? parseInt(form.max_capacity) : null,
        trainer_name: form.trainer_name || null,
        equipment:    form.equipment || null,
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
    <div className="max-w-4xl mx-auto p-6 space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Calendar className="text-indigo-500" size={24} />
          <div>
            <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Εβδομαδιαίο Πρόγραμμα</h1>
            <p className="text-sm text-gray-500">Διαχείριση ωρών και μαθημάτων γυμναστηρίου</p>
          </div>
        </div>
        <button onClick={openAdd} className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold rounded-xl transition-colors">
          <Plus size={16} /> Νέο Μάθημα
        </button>
      </div>

      {/* Day tabs */}
      <div className="flex gap-1 bg-gray-100 dark:bg-gray-800 rounded-xl p-1">
        {DAYS.slice(1).map((d, i) => {
          const day = i + 1;
          const count = entries.filter(e => e.day_of_week === day).length;
          return (
            <button
              key={day}
              onClick={() => setActiveDay(day)}
              className={`flex-1 py-2 px-1 rounded-lg text-sm font-medium transition-colors relative ${
                activeDay === day
                  ? 'bg-white dark:bg-gray-700 text-indigo-600 dark:text-indigo-400 shadow'
                  : 'text-gray-500 hover:text-gray-700 dark:hover:text-gray-300'
              }`}
            >
              {d.slice(0, 3)}
              {count > 0 && (
                <span className="ml-1 text-xs bg-indigo-100 dark:bg-indigo-900 text-indigo-600 dark:text-indigo-400 rounded-full px-1.5">
                  {count}
                </span>
              )}
            </button>
          );
        })}
      </div>

      {/* Entries for selected day */}
      {loading ? (
        <div className="text-center text-gray-400 py-12">Φόρτωση…</div>
      ) : dayEntries.length === 0 ? (
        <div className="text-center py-12 border-2 border-dashed border-gray-200 dark:border-gray-700 rounded-2xl">
          <p className="text-gray-400 mb-3">Δεν υπάρχουν μαθήματα για {DAYS[activeDay]}</p>
          <button onClick={openAdd} className="text-indigo-600 font-semibold text-sm hover:underline">+ Προσθήκη μαθήματος</button>
        </div>
      ) : (
        <div className="space-y-2">
          {dayEntries.map(e => (
            <div key={e.id} className="flex items-center gap-4 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl px-5 py-4">
              <div className="w-1 self-stretch rounded-full" style={{ backgroundColor: e.color || '#C6FF3D' }} />
              <div className="w-16 text-center">
                <span className="text-lg font-bold text-gray-900 dark:text-white">{e.start_time}</span>
              </div>
              <div className="flex-1">
                <p className="font-semibold text-gray-900 dark:text-white">{e.class_name}</p>
                <p className="text-sm text-gray-500">
                  {[e.trainer_name, e.equipment, e.max_capacity ? `${e.max_capacity} άτομα` : null].filter(Boolean).join(' · ')}
                </p>
              </div>
              <button onClick={() => openEdit(e)} className="p-2 text-gray-400 hover:text-indigo-600 rounded-lg hover:bg-indigo-50 dark:hover:bg-indigo-900/20 transition-colors">
                <Pencil size={16} />
              </button>
              <button onClick={() => handleDelete(e.id)} className="p-2 text-gray-400 hover:text-red-500 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors">
                <Trash2 size={16} />
              </button>
            </div>
          ))}
        </div>
      )}

      {/* Modal */}
      {modal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50">
          <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-2xl w-full max-w-md p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-bold text-gray-900 dark:text-white">
                {modal === 'add' ? 'Νέο Μάθημα' : 'Επεξεργασία Μαθήματος'}
              </h2>
              <button onClick={() => setModal(null)} className="text-gray-400 hover:text-gray-600"><X size={20} /></button>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-medium text-gray-500 mb-1">Ημέρα</label>
                <select
                  value={form.day_of_week}
                  onChange={e => setForm(f => ({ ...f, day_of_week: Number(e.target.value) }))}
                  className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                >
                  {DAYS.slice(1).map((d, i) => <option key={i+1} value={i+1}>{d}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-xs font-medium text-gray-500 mb-1">Ώρα</label>
                <input
                  type="time"
                  value={form.start_time}
                  onChange={e => setForm(f => ({ ...f, start_time: e.target.value }))}
                  className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">Όνομα Μαθήματος *</label>
              <input
                value={form.class_name}
                onChange={e => setForm(f => ({ ...f, class_name: e.target.value }))}
                placeholder="π.χ. Circuit Workout, Pilates, TRX…"
                className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
              />
            </div>

            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">Εκπαιδευτής</label>
              <input
                value={form.trainer_name}
                onChange={e => setForm(f => ({ ...f, trainer_name: e.target.value }))}
                placeholder="π.χ. Νίκος Παπαδόπουλος"
                className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-medium text-gray-500 mb-1">Εξοπλισμός</label>
                <input
                  value={form.equipment}
                  onChange={e => setForm(f => ({ ...f, equipment: e.target.value }))}
                  placeholder="π.χ. TRX, FitBall"
                  className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                />
              </div>
              <div>
                <label className="block text-xs font-medium text-gray-500 mb-1">Μέγ. Χωρητικότητα</label>
                <input
                  type="number"
                  value={form.max_capacity}
                  onChange={e => setForm(f => ({ ...f, max_capacity: e.target.value }))}
                  placeholder="π.χ. 20"
                  className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-medium text-gray-500 mb-2">Χρώμα</label>
              <div className="flex gap-2 flex-wrap">
                {CLASS_COLORS.map(c => (
                  <button
                    key={c}
                    type="button"
                    onClick={() => setForm(f => ({ ...f, color: c }))}
                    className="w-7 h-7 rounded-full border-2 transition-transform hover:scale-110"
                    style={{
                      backgroundColor: c,
                      borderColor: form.color === c ? '#6366f1' : 'transparent',
                      transform: form.color === c ? 'scale(1.2)' : undefined,
                    }}
                  />
                ))}
              </div>
            </div>

            {error && <p className="text-sm text-red-500">{error}</p>}

            <div className="flex gap-3 pt-2">
              <button onClick={() => setModal(null)} className="flex-1 py-2.5 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 rounded-xl font-medium text-sm hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                Άκυρο
              </button>
              <button onClick={handleSave} disabled={saving} className="flex-1 flex items-center justify-center gap-2 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl font-semibold text-sm transition-colors disabled:opacity-50">
                <Check size={15} />
                {saving ? 'Αποθήκευση…' : 'Αποθήκευση'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
