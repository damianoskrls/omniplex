import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { MapPin, Plus, Trash2, Save } from 'lucide-react';

const EMPTY = { name: '', city: '', address: '', phone: '', email: '' };

export default function Locations() {
  const [locations, setLocations] = useState([]);
  const [form, setForm] = useState(EMPTY);
  const [saving, setSaving] = useState(false);

  const load = () => api.get('/client-admin/locations').then((r) => setLocations(r.data)).catch(() => {});

  useEffect(() => { load(); }, []);

  const addLocation = async (e) => {
    e.preventDefault();
    if (!form.name.trim()) return toast.error('Βάλε όνομα τοποθεσίας');
    setSaving(true);
    try {
      await api.post('/client-admin/locations', {
        ...form,
        sort_order: locations.length,
      });
      toast.success('Προστέθηκε γυμναστήριο');
      setForm(EMPTY);
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };

  const updateField = async (id, patch) => {
    try {
      await api.patch(`/client-admin/locations/${id}`, patch);
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const remove = async (loc) => {
    if (!window.confirm(`Απενεργοποίηση «${loc.name}»;`)) return;
    try {
      await api.delete(`/client-admin/locations/${loc.id}`);
      toast.success('Απενεργοποιήθηκε');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  return (
    <Layout title="Τοποθεσίες">
      <div className="page-header">
        <h1 className="page-title">Γυμναστήρια / Τοποθεσίες</h1>
        <p className="text-muted">
          Διαχειρίσου πολλαπλά καταστήματα (π.χ. Κηφισιά, Αχαρνές). Πρόγραμμα, αίθουσες και γυμναστές αντιστοιχούν σε κάθε τοποθεσία.
        </p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 20, alignItems: 'start' }}>
        <div className="card">
          <div className="modal-title" style={{ marginBottom: 14 }}><Plus size={16} /> Νέα τοποθεσία</div>
          <form onSubmit={addLocation}>
            <div className="form-group">
              <label className="form-label">Όνομα *</label>
              <input className="form-input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="π.χ. Κηφισιά" required />
            </div>
            <div className="form-group">
              <label className="form-label">Περιοχή / Πόλη</label>
              <input className="form-input" value={form.city} onChange={(e) => setForm({ ...form, city: e.target.value })} placeholder="π.χ. Κηφισιά" />
            </div>
            <div className="form-group">
              <label className="form-label">Διεύθυνση</label>
              <input className="form-input" value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} />
            </div>
            <div className="form-grid-2">
              <div className="form-group">
                <label className="form-label">Τηλέφωνο</label>
                <input className="form-input" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
              </div>
              <div className="form-group">
                <label className="form-label">Email</label>
                <input className="form-input" type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
              </div>
            </div>
            <button type="submit" className="btn btn-primary" disabled={saving}>
              <Plus size={14} /> {saving ? '...' : 'Προσθήκη'}
            </button>
          </form>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {locations.filter((l) => l.is_active).map((loc) => (
            <div key={loc.id} className="card" style={{ padding: 18 }}>
              <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
                <div style={{ width: 44, height: 44, borderRadius: 12, background: 'linear-gradient(135deg, #76C043, #4A8D2C)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <MapPin size={20} />
                </div>
                <div style={{ flex: 1 }}>
                  <input
                    className="form-input"
                    value={loc.name}
                    onChange={(e) => setLocations((prev) => prev.map((x) => x.id === loc.id ? { ...x, name: e.target.value } : x))}
                    onBlur={() => updateField(loc.id, { name: loc.name })}
                    style={{ fontWeight: 700, marginBottom: 8 }}
                  />
                  <input
                    className="form-input"
                    placeholder="Διεύθυνση"
                    value={loc.address || ''}
                    onChange={(e) => setLocations((prev) => prev.map((x) => x.id === loc.id ? { ...x, address: e.target.value } : x))}
                    onBlur={() => updateField(loc.id, { address: loc.address })}
                    style={{ marginBottom: 6, fontSize: '0.85rem' }}
                  />
                  <div className="text-muted" style={{ fontSize: '0.78rem' }}>{loc.city || '—'} · slug: {loc.slug}</div>
                </div>
                <button type="button" className="btn btn-danger btn-sm" onClick={() => remove(loc)}>
                  <Trash2 size={14} />
                </button>
              </div>
            </div>
          ))}
          {!locations.filter((l) => l.is_active).length && (
            <div className="card" style={{ padding: 24, textAlign: 'center', color: '#94a3b8' }}>
              Δεν υπάρχουν τοποθεσίες ακόμα
            </div>
          )}
        </div>
      </div>
    </Layout>
  );
}
