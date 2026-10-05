import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import TimeInput from '../components/ui/TimeInput';
import LocationTeam from '../components/LocationTeam';
import { MapPin, Plus, Trash2 } from 'lucide-react';

const DAYS = ['Δευ', 'Τρί', 'Τετ', 'Πέμ', 'Παρ', 'Σαβ', 'Κυρ'];

function defaultHours() {
  return Object.fromEntries(
    [0, 1, 2, 3, 4, 5, 6].map((d) => [d, { open: '09:00', close: '21:00', closed: d === 6 }]),
  );
}

function parseHours(raw) {
  const base = defaultHours();
  if (!raw) return base;
  try {
    const oh = typeof raw === 'string' ? JSON.parse(raw) : raw;
    return { ...base, ...oh };
  } catch {
    return base;
  }
}

const EMPTY = { name: '', city: '', address: '', phone: '', email: '' };

function LocationCard({ loc, onPatch, onRemove }) {
  const [name, setName] = useState(loc.name || '');
  const [address, setAddress] = useState(loc.address || '');
  const [hours, setHours] = useState(() => parseHours(loc.opening_hours));
  const [savingHours, setSavingHours] = useState(false);

  useEffect(() => {
    setHours(parseHours(loc.opening_hours));
  }, [loc.id, loc.opening_hours]);

  const updateHours = (day, key, val) => {
    setHours((prev) => ({ ...prev, [day]: { ...prev[day], [key]: val } }));
  };

  const applyAllDays = (day) => {
    const src = hours[day];
    setHours((prev) => {
      const next = { ...prev };
      for (let d = 0; d <= 6; d++) next[d] = { ...src };
      return next;
    });
  };

  const saveHours = async () => {
    setSavingHours(true);
    try {
      await onPatch(loc.id, { opening_hours: hours });
      toast.success(`Αποθηκεύτηκε το ωράριο για ${name || loc.name}`);
    } catch {
      /* το onPatch έδειξε ήδη το σφάλμα */
    } finally {
      setSavingHours(false);
    }
  };

  return (
    <div className="card" style={{ padding: 18 }}>
      <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
        <div style={{ width: 44, height: 44, borderRadius: 12, background: 'linear-gradient(135deg, #76C043, #4A8D2C)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
          <MapPin size={20} />
        </div>
        <div style={{ flex: 1 }}>
          <input
            className="form-input"
            value={name}
            onChange={(e) => setName(e.target.value)}
            onBlur={() => { if (name.trim() && name.trim() !== loc.name) onPatch(loc.id, { name: name.trim() }); }}
            style={{ fontWeight: 700, marginBottom: 8 }}
          />
          <input
            className="form-input"
            placeholder="Διεύθυνση"
            value={address}
            onChange={(e) => setAddress(e.target.value)}
            onBlur={() => { if (address !== (loc.address || '')) onPatch(loc.id, { address }); }}
            style={{ marginBottom: 6, fontSize: '0.85rem' }}
          />
          <div className="text-muted" style={{ fontSize: '0.78rem', marginBottom: 8 }}>{loc.city || '—'} · slug: {loc.slug}</div>
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: '0.85rem', cursor: 'pointer' }}>
            <input
              type="checkbox"
              checked={!!loc.accepts_drop_in}
              onChange={(e) => onPatch(loc.id, { accepts_drop_in: e.target.checked ? 1 : 0 })}
            />
            Δέχεται drop-in
          </label>
        </div>
        <button type="button" className="btn btn-danger btn-sm" onClick={() => onRemove(loc)}>
          <Trash2 size={14} />
        </button>
      </div>

      <div style={{ marginTop: 16, paddingTop: 14, borderTop: '1px solid #e2e8f0' }}>
        <div style={{ fontWeight: 700, marginBottom: 4 }}>Ωράριο αυτού του καταστήματος</div>
        <div className="text-muted" style={{ fontSize: '0.78rem', marginBottom: 12 }}>
          {loc.opening_hours
            ? 'Ισχύει μόνο εδώ. Οι κρατήσεις ακολουθούν αυτές τις ώρες.'
            : 'Δεν έχει αποθηκευτεί ακόμα ξεχωριστό ωράριο. Πάτα αποθήκευση για να ισχύει μόνο σε αυτό το κατάστημα.'}
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {[0, 1, 2, 3, 4, 5, 6].map((day) => {
            const h = hours[day] || { open: '09:00', close: '21:00', closed: false };
            return (
              <div key={day} style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap', padding: '8px 10px', borderRadius: 8, background: h.closed ? '#fef2f2' : '#f8fafc', border: '1px solid #e2e8f0' }}>
                <div style={{ width: 36, fontWeight: 600, fontSize: '0.85rem' }}>{DAYS[day]}</div>
                <label style={{ display: 'flex', alignItems: 'center', gap: 4, cursor: 'pointer' }}>
                  <input type="checkbox" checked={!h.closed} onChange={(e) => updateHours(day, 'closed', !e.target.checked)} />
                  <span style={{ fontSize: '0.78rem', color: '#64748b' }}>Ανοιχτά</span>
                </label>
                {!h.closed && (
                  <>
                    <TimeInput value={h.open} onChange={(val) => updateHours(day, 'open', val)} />
                    <span style={{ color: '#94a3b8' }}>—</span>
                    <TimeInput value={h.close} onChange={(val) => updateHours(day, 'close', val)} />
                    <button type="button" onClick={() => applyAllDays(day)} style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#76C043', fontSize: '0.75rem' }}>
                      Σε όλες →
                    </button>
                  </>
                )}
                {h.closed && <span style={{ fontSize: '0.8rem', color: '#94a3b8' }}>Κλειστά</span>}
              </div>
            );
          })}
        </div>
        <button type="button" className="btn btn-primary" style={{ marginTop: 12 }} onClick={saveHours} disabled={savingHours}>
          {savingHours ? 'Αποθήκευση...' : 'Αποθήκευση ωραρίου καταστήματος'}
        </button>
      </div>

      <LocationTeam locationId={loc.id} gymHours={hours} />
      <StoreAdmins locationId={loc.id} />
    </div>
  );
}

function StoreAdmins({ locationId }) {
  const [admins, setAdmins] = useState([]);
  const [form, setForm] = useState({ full_name: '', email: '', password: '' });
  const [saving, setSaving] = useState(false);

  const load = () => api.get('/client-admin/location-admins', { params: { location_id: locationId } })
    .then((r) => setAdmins(r.data || []))
    .catch(() => {});

  useEffect(() => { load(); }, [locationId]);

  const addAdmin = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      await api.post('/client-admin/location-admins', { ...form, location_id: locationId });
      toast.success('Ο διαχειριστής δημιουργήθηκε');
      setForm({ full_name: '', email: '', password: '' });
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };

  const removeAdmin = async (admin) => {
    if (!window.confirm(`Να αφαιρεθεί ο ${admin.full_name};`)) return;
    try {
      await api.delete(`/client-admin/location-admins/${admin.id}`);
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  return (
    <div style={{ marginTop: 16, paddingTop: 14, borderTop: '1px solid #e2e8f0' }}>
      <div style={{ fontWeight: 700, marginBottom: 4 }}>Διαχειριστές καταστήματος</div>
      <div className="text-muted" style={{ fontSize: '0.78rem', marginBottom: 12 }}>
        Μπαίνουν με το δικό τους email και κωδικό και βλέπουν μόνο αυτό το κατάστημα.
      </div>
      {admins.map((admin) => (
        <div key={admin.id} style={{ display: 'flex', justifyContent: 'space-between', gap: 8, alignItems: 'center', padding: '8px 0', borderBottom: '1px solid #f1f5f9' }}>
          <div>
            <div style={{ fontWeight: 600 }}>{admin.full_name}</div>
            <div className="text-muted" style={{ fontSize: '0.78rem' }}>{admin.email}</div>
          </div>
          <button type="button" className="btn btn-danger btn-sm" onClick={() => removeAdmin(admin)}>
            <Trash2 size={14} />
          </button>
        </div>
      ))}
      <form onSubmit={addAdmin} style={{ display: 'grid', gap: 8, marginTop: 12, gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))' }}>
        <input className="form-input" placeholder="Ονοματεπώνυμο" value={form.full_name} required
          onChange={(e) => setForm({ ...form, full_name: e.target.value })} />
        <input className="form-input" type="email" placeholder="Email" value={form.email} required
          onChange={(e) => setForm({ ...form, email: e.target.value })} />
        <input className="form-input" type="password" placeholder="Κωδικός" value={form.password} required minLength={6}
          onChange={(e) => setForm({ ...form, password: e.target.value })} />
        <button type="submit" className="btn btn-primary" disabled={saving}>{saving ? '...' : 'Προσθήκη'}</button>
      </form>
    </div>
  );
}

export default function Locations() {
  const [locations, setLocations] = useState([]);
  const [form, setForm] = useState(EMPTY);
  const [saving, setSaving] = useState(false);

  const load = () => api.get('/client-admin/locations').then((r) => setLocations(r.data)).catch(() => {});

  useEffect(() => { load(); }, []);

  const addLocation = async (e) => {
    e.preventDefault();
    if (!form.name.trim()) return toast.error('Βάλε όνομα καταστήματος');
    setSaving(true);
    try {
      await api.post('/client-admin/locations', {
        ...form,
        opening_hours: defaultHours(),
        sort_order: locations.length,
      });
      toast.success('Προστέθηκε κατάστημα');
      setForm(EMPTY);
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };

  const onPatch = async (id, patch) => {
    try {
      await api.patch(`/client-admin/locations/${id}`, patch);
      setLocations((prev) => prev.map((x) => x.id === id ? { ...x, ...patch } : x));
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
      throw err;
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

  const active = locations.filter((l) => l.is_active);

  return (
    <Layout title="Καταστήματα">
      <div className="page-header">
        <h1 className="page-title">Καταστήματα</h1>
        <p className="text-muted">
          Σε κάθε κατάστημα ορίζεις πότε είναι ανοιχτό, ποιοι γυμναστές δουλεύουν εκεί, τι κάνει ο καθένας και τις ώρες διαθεσιμότητάς του.
        </p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'minmax(280px, 360px) 1fr', gap: 20, alignItems: 'start' }}>
        <div className="card">
          <div className="modal-title" style={{ marginBottom: 14 }}><Plus size={16} /> Νέο κατάστημα</div>
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
          {active.map((loc) => (
            <LocationCard key={loc.id} loc={loc} onPatch={onPatch} onRemove={remove} />
          ))}
          {!active.length && (
            <div className="card" style={{ padding: 24, textAlign: 'center', color: '#94a3b8' }}>
              Δεν υπάρχουν καταστήματα ακόμα. Πρόσθεσε το πρώτο αριστερά.
            </div>
          )}
        </div>
      </div>
    </Layout>
  );
}
