import { useEffect, useState } from 'react';
import { Globe, MapPin, Eye, EyeOff, Save } from 'lucide-react';
import api from '../api/client';

export default function DiscoveryProfile() {
  const [form, setForm] = useState({
    city: '', country: 'GR', latitude: '', longitude: '',
    description: '', is_discoverable: false,
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving]   = useState(false);
  const [saved, setSaved]     = useState(false);
  const [error, setError]     = useState(null);

  useEffect(() => {
    api.get('/client-admin/discovery-profile')
      .then(r => {
        const d = r.data;
        setForm({
          city:            d.city || '',
          country:         d.country || 'GR',
          latitude:        d.latitude != null ? String(d.latitude) : '',
          longitude:       d.longitude != null ? String(d.longitude) : '',
          description:     d.description || '',
          is_discoverable: !!d.is_discoverable,
        });
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, []);

  async function handleSave(e) {
    e.preventDefault();
    setSaving(true); setError(null); setSaved(false);
    try {
      await api.patch('/client-admin/discovery-profile', {
        city:            form.city || null,
        country:         form.country || null,
        latitude:        form.latitude ? parseFloat(form.latitude) : null,
        longitude:       form.longitude ? parseFloat(form.longitude) : null,
        description:     form.description || null,
        is_discoverable: form.is_discoverable ? 1 : 0,
      });
      setSaved(true);
      setTimeout(() => setSaved(false), 2500);
    } catch (err) {
      setError(err.response?.data?.error || err.message);
    } finally {
      setSaving(false);
    }
  }

  if (loading) return <div className="p-8 text-center text-gray-400">Φόρτωση…</div>;

  return (
    <div className="max-w-2xl mx-auto p-6 space-y-6">
      <div className="flex items-center gap-3">
        <Globe className="text-indigo-500" size={24} />
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Προβολή στην Αγορά</h1>
          <p className="text-sm text-gray-500">Εμφάνιση του γυμναστηρίου σας στην αναζήτηση της εφαρμογής</p>
        </div>
      </div>

      {/* Visibility toggle card */}
      <div className={`rounded-2xl border-2 p-5 flex items-center justify-between transition-colors ${
        form.is_discoverable
          ? 'border-indigo-400 bg-indigo-50 dark:bg-indigo-900/20'
          : 'border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800'
      }`}>
        <div className="flex items-center gap-3">
          {form.is_discoverable
            ? <Eye className="text-indigo-600" size={22} />
            : <EyeOff className="text-gray-400" size={22} />}
          <div>
            <p className="font-semibold text-gray-900 dark:text-white">
              {form.is_discoverable ? 'Εμφανίζεστε στην αναζήτηση' : 'Δεν εμφανίζεστε στην αναζήτηση'}
            </p>
            <p className="text-sm text-gray-500">
              {form.is_discoverable
                ? 'Οι χρήστες μπορούν να βρουν το γυμναστήριό σας'
                : 'Ενεργοποιήστε για να εμφανίζεστε στα αποτελέσματα αναζήτησης'}
            </p>
          </div>
        </div>
        <button
          type="button"
          onClick={() => setForm(f => ({ ...f, is_discoverable: !f.is_discoverable }))}
          className={`relative inline-flex h-7 w-12 items-center rounded-full transition-colors ${
            form.is_discoverable ? 'bg-indigo-600' : 'bg-gray-300 dark:bg-gray-600'
          }`}
        >
          <span className={`inline-block h-5 w-5 transform rounded-full bg-white shadow transition-transform ${
            form.is_discoverable ? 'translate-x-6' : 'translate-x-1'
          }`} />
        </button>
      </div>

      <form onSubmit={handleSave} className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-200 dark:border-gray-700 p-6 space-y-5">
        <h2 className="font-semibold text-gray-900 dark:text-white flex items-center gap-2">
          <MapPin size={18} className="text-indigo-500" />
          Πληροφορίες Τοποθεσίας
        </h2>

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Πόλη</label>
            <input
              value={form.city}
              onChange={e => setForm(f => ({ ...f, city: e.target.value }))}
              placeholder="π.χ. Αθήνα"
              className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Χώρα</label>
            <input
              value={form.country}
              onChange={e => setForm(f => ({ ...f, country: e.target.value }))}
              placeholder="GR"
              className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Γεωγρ. Πλάτος</label>
            <input
              type="number"
              step="any"
              value={form.latitude}
              onChange={e => setForm(f => ({ ...f, latitude: e.target.value }))}
              placeholder="π.χ. 37.9838"
              className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Γεωγρ. Μήκος</label>
            <input
              type="number"
              step="any"
              value={form.longitude}
              onChange={e => setForm(f => ({ ...f, longitude: e.target.value }))}
              placeholder="π.χ. 23.7275"
              className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Περιγραφή</label>
          <textarea
            rows={3}
            value={form.description}
            onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
            placeholder="Σύντομη περιγραφή του γυμναστηρίου σας που θα βλέπουν οι χρήστες στην αναζήτηση…"
            className="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-500 resize-none"
          />
        </div>

        {error && <p className="text-sm text-red-500">{error}</p>}

        <button
          type="submit"
          disabled={saving}
          className="flex items-center gap-2 px-5 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold rounded-xl transition-colors disabled:opacity-50"
        >
          <Save size={16} />
          {saving ? 'Αποθήκευση…' : saved ? '✓ Αποθηκεύτηκε' : 'Αποθήκευση'}
        </button>
      </form>
    </div>
  );
}
