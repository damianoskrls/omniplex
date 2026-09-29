import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { mediaUrl } from '../utils/media';

const STEPS = [
  { id: 'details', title: 'Στοιχεία', required: true, hint: 'Όνομα, τηλέφωνο, υπεύθυνος' },
  { id: 'logo', title: 'Λογότυπο', required: false, hint: 'Το σήμα στην εφαρμογή' },
  { id: 'photos', title: 'Εικόνες', required: false, hint: 'Φωτογραφίες χώρου' },
  { id: 'description', title: 'Περιγραφή', required: false, hint: 'Κείμενο για το προφίλ' },
  { id: 'locations', title: 'Καταστήματα', required: true, hint: 'Τουλάχιστον ένα' },
  { id: 'services', title: 'Υπηρεσίες', required: true, hint: 'Τι κλείνει ο πελάτης' },
  { id: 'plans', title: 'Πακέτα', required: false, hint: 'Συνεδρίες και τιμή' },
  { id: 'rooms', title: 'Αίθουσες', required: false, hint: 'Χώροι ανά κατάστημα' },
  { id: 'dropin', title: 'Drop-in', required: false, hint: 'Σε ποιο κατάστημα και ποια υπηρεσία' },
  { id: 'nutrition', title: 'Διατροφολόγος', required: false, hint: 'Αν υπάρχει, και σε ποιο κατάστημα' },
  { id: 'staff', title: 'Προσωπικό', required: false, hint: 'Ποιοι δουλεύουν' },
  { id: 'hours', title: 'Ώρες και ρόλοι', required: false, hint: 'Τι κάνει ο καθένας και πότε' },
  { id: 'leave', title: 'Άδειες', required: false, hint: 'Ημέρες άδειας' },
  { id: 'payroll', title: 'Αμοιβές', required: false, hint: 'Μισθοδοσία συνεργατών' },
  { id: 'programs', title: 'Προγράμματα', required: false, hint: 'Προγράμματα άσκησης' },
];

function defaultHours() {
  return Object.fromEntries([0, 1, 2, 3, 4, 5, 6].map((d) => [d, { open: '09:00', close: '21:00', closed: d === 6 }]));
}

function stepState(step, checks, progress) {
  if (progress?.skipped?.includes(step.id)) return 'skipped';
  const done = {
    details: checks?.has_name,
    logo: checks?.has_logo,
    photos: checks?.photos > 0,
    description: checks?.has_description,
    locations: checks?.locations > 0,
    services: checks?.services > 0,
    plans: checks?.plans > 0,
    rooms: checks?.rooms > 0,
    dropin: checks?.drop_in_locations > 0,
    nutrition: checks?.nutritionists > 0,
    staff: checks?.staff > 0,
    hours: checks?.staff_with_hours > 0,
    leave: checks?.leaves > 0,
    payroll: false,
    programs: checks?.programs > 0,
  }[step.id];
  return done ? 'done' : '';
}

function blockedReason(step, checks) {
  if (!step.required || !checks) return '';
  if (step.id === 'details' && !checks.has_name) return 'Αποθήκευσε πρώτα το όνομα του γυμναστηρίου.';
  if (step.id === 'locations' && !checks.locations) return 'Χρειάζεται τουλάχιστον ένα κατάστημα για να ξέρει ο πελάτης πού κλείνει.';
  if (step.id === 'services' && !checks.services) return 'Χρειάζεται τουλάχιστον μία υπηρεσία, αλλιώς δεν υπάρχει κάτι για κράτηση.';
  return '';
}

function StepNote({ children }) {
  return <p className="text-muted" style={{ fontSize: '0.88rem', lineHeight: 1.55, marginBottom: 14 }}>{children}</p>;
}

function DetailsStep({ onSaved }) {
  const [form, setForm] = useState(null);
  const [saving, setSaving] = useState(false);
  useEffect(() => {
    api.get('/client-admin/settings').then((r) => {
      const d = r.data;
      setForm({
        app_name: d.app_name || d.business_name || '',
        gym_phone: d.gym_phone || '',
        gym_email: d.gym_email || '',
        gym_address: d.gym_address || '',
        owner_name: d.owner_name || '',
        owner_phone: d.owner_phone || '',
      });
    }).catch(() => toast.error('Δεν φορτώθηκαν τα στοιχεία'));
  }, []);
  if (!form) return null;
  const save = async (e) => {
    e.preventDefault();
    if (!form.app_name.trim()) return toast.error('Το όνομα είναι απαραίτητο');
    setSaving(true);
    try {
      await api.patch('/client-admin/settings', form);
      toast.success('Αποθηκεύτηκαν τα στοιχεία');
      onSaved();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };
  const set = (key) => (e) => setForm({ ...form, [key]: e.target.value });
  return (
    <form onSubmit={save}>
      <StepNote>Αυτά βλέπει ο πελάτης στην εφαρμογή. Το όνομα δεν παραλείπεται.</StepNote>
      <div className="form-group"><label className="form-label">Όνομα στην εφαρμογή *</label><input className="form-input" value={form.app_name} onChange={set('app_name')} required /></div>
      <div className="form-grid-2">
        <div className="form-group"><label className="form-label">Τηλέφωνο</label><input className="form-input" value={form.gym_phone} onChange={set('gym_phone')} /></div>
        <div className="form-group"><label className="form-label">Email</label><input className="form-input" value={form.gym_email} onChange={set('gym_email')} /></div>
      </div>
      <div className="form-group"><label className="form-label">Διεύθυνση έδρας</label><input className="form-input" value={form.gym_address} onChange={set('gym_address')} /></div>
      <div className="form-grid-2">
        <div className="form-group"><label className="form-label">Υπεύθυνος</label><input className="form-input" value={form.owner_name} onChange={set('owner_name')} /></div>
        <div className="form-group"><label className="form-label">Τηλέφωνο υπευθύνου</label><input className="form-input" value={form.owner_phone} onChange={set('owner_phone')} /></div>
      </div>
      <button className="btn btn-primary" disabled={saving}>{saving ? 'Αποθήκευση...' : 'Αποθήκευση στοιχείων'}</button>
    </form>
  );
}

function LogoStep({ onSaved }) {
  const [logo, setLogo] = useState(null);
  const [uploading, setUploading] = useState(false);
  useEffect(() => {
    api.get('/client-admin/settings').then((r) => setLogo(r.data.logo_url || null)).catch(() => {});
  }, []);
  const upload = async (file) => {
    if (!file) return;
    setUploading(true);
    const fd = new FormData();
    fd.append('logo', file);
    try {
      const r = await api.post('/client-admin/settings/logo', fd, { headers: { 'Content-Type': 'multipart/form-data' } });
      setLogo(r.data.logo_url);
      toast.success('Ανέβηκε το λογότυπο');
      onSaved();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setUploading(false);
    }
  };
  return (
    <div>
      <StepNote>Το λογότυπο φαίνεται στην εφαρμογή των πελατών. Μπορείς να το προσθέσεις και αργότερα.</StepNote>
      {logo && <img src={mediaUrl(logo)} alt="" style={{ height: 64, marginBottom: 12, objectFit: 'contain' }} />}
      <label className="btn btn-secondary" style={{ cursor: 'pointer' }}>
        {uploading ? 'Μεταφόρτωση...' : 'Ανέβασε λογότυπο'}
        <input type="file" accept="image/*" hidden onChange={(e) => upload(e.target.files?.[0])} />
      </label>
    </div>
  );
}

function PhotosStep({ onSaved }) {
  const [photos, setPhotos] = useState([]);
  const [uploading, setUploading] = useState(false);
  const load = () => api.get('/client-admin/gym-photos').then((r) => setPhotos(r.data || [])).catch(() => {});
  useEffect(() => { load(); }, []);
  const upload = async (files) => {
    if (!files?.length) return;
    setUploading(true);
    try {
      for (const file of files) {
        const fd = new FormData();
        fd.append('photo', file);
        await api.post('/client-admin/gym-photos/upload', fd, { headers: { 'Content-Type': 'multipart/form-data' } });
      }
      await load();
      onSaved();
      toast.success('Ανέβηκαν οι εικόνες');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setUploading(false);
    }
  };
  return (
    <div>
      <StepNote>Εικόνες του χώρου στο προφίλ του γυμναστηρίου. Δεν μπλοκάρουν τις κρατήσεις.</StepNote>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 12 }}>
        {photos.map((p) => <img key={p.id} src={mediaUrl(p.url)} alt="" style={{ width: 96, height: 72, objectFit: 'cover', borderRadius: 8 }} />)}
      </div>
      <label className="btn btn-secondary" style={{ cursor: 'pointer' }}>
        {uploading ? 'Μεταφόρτωση...' : 'Προσθήκη εικόνων'}
        <input type="file" accept="image/*" multiple hidden onChange={(e) => upload(e.target.files)} />
      </label>
    </div>
  );
}

function DescriptionStep({ onSaved }) {
  const [text, setText] = useState('');
  const [saving, setSaving] = useState(false);
  useEffect(() => {
    api.get('/client-admin/discovery-profile').then((r) => setText(r.data.description || '')).catch(() => {});
  }, []);
  const save = async () => {
    setSaving(true);
    try {
      await api.patch('/client-admin/discovery-profile', { description: text });
      toast.success('Αποθηκεύτηκε η περιγραφή');
      onSaved();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };
  return (
    <div>
      <StepNote>Σύντομη περιγραφή για όποιον βρίσκει το γυμναστήριο. Η πλήρης προβολή είναι στην Αγορά.</StepNote>
      <textarea className="form-input" rows={5} value={text} onChange={(e) => setText(e.target.value)} placeholder="Τι προσφέρει το γυμναστήριο" />
      <button type="button" className="btn btn-primary" style={{ marginTop: 10 }} onClick={save} disabled={saving}>{saving ? '...' : 'Αποθήκευση περιγραφής'}</button>
      <div style={{ marginTop: 10 }}><Link to="/discovery-profile">Άνοιξε την πλήρη προβολή στην αγορά</Link></div>
    </div>
  );
}

function LocationsStep({ checks, onSaved }) {
  const [form, setForm] = useState({ name: '', city: '', address: '', accepts_drop_in: false });
  const [saving, setSaving] = useState(false);
  const save = async (e) => {
    e.preventDefault();
    if (!form.name.trim()) return toast.error('Βάλε όνομα καταστήματος');
    setSaving(true);
    try {
      await api.post('/client-admin/locations', {
        ...form,
        accepts_drop_in: form.accepts_drop_in ? 1 : 0,
        opening_hours: defaultHours(),
      });
      toast.success('Προστέθηκε κατάστημα με ωράριο Δευ–Σαβ 09:00–21:00');
      setForm({ name: '', city: '', address: '', accepts_drop_in: false });
      onSaved();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };
  return (
    <form onSubmit={save}>
      <StepNote>
        Χρειάζεται τουλάχιστον ένα κατάστημα. Ήδη έχεις {checks?.locations || 0}, με δικό τους ωράριο {checks?.locations_with_hours || 0}.
        Μετά την προσθήκη, στην σελίδα Καταστήματα ορίζεις ποιοι δουλεύουν εκεί και τις ώρες τους.
      </StepNote>
      <div className="form-group"><label className="form-label">Όνομα *</label><input className="form-input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="π.χ. Κηφισιά" /></div>
      <div className="form-grid-2">
        <div className="form-group"><label className="form-label">Περιοχή</label><input className="form-input" value={form.city} onChange={(e) => setForm({ ...form, city: e.target.value })} /></div>
        <div className="form-group"><label className="form-label">Διεύθυνση</label><input className="form-input" value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} /></div>
      </div>
      <label style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 12 }}>
        <input type="checkbox" checked={form.accepts_drop_in} onChange={(e) => setForm({ ...form, accepts_drop_in: e.target.checked })} />
        Δέχεται drop-in
      </label>
      <button className="btn btn-primary" disabled={saving}>{saving ? '...' : 'Προσθήκη καταστήματος'}</button>
      <div style={{ marginTop: 10 }}><Link to="/locations">Ωράριο, ομάδα και drop-in ανά κατάστημα</Link></div>
    </form>
  );
}

function ServicesStep({ onSaved }) {
  const [locations, setLocations] = useState([]);
  const [form, setForm] = useState({ name: '', duration_mins: 60, location_ids: [], drop_in: '' });
  const [saving, setSaving] = useState(false);
  useEffect(() => {
    api.get('/client-admin/locations').then((r) => setLocations((r.data || []).filter((l) => l.is_active))).catch(() => {});
  }, []);
  const toggleLoc = (id) => {
    setForm((f) => ({
      ...f,
      location_ids: f.location_ids.includes(id) ? f.location_ids.filter((x) => x !== id) : [...f.location_ids, id],
    }));
  };
  const save = async (e) => {
    e.preventDefault();
    if (!form.name.trim()) return toast.error('Βάλε όνομα υπηρεσίας');
    setSaving(true);
    try {
      const created = await api.post('/client-admin/services', {
        name: form.name.trim(),
        duration_mins: Number(form.duration_mins) || 60,
        location_ids: form.location_ids,
      });
      if (form.drop_in !== '') {
        await api.patch(`/client-admin/services/${created.data.id}`, {
          drop_in_price_cents: Math.round(Number(form.drop_in) * 100),
        });
      }
      toast.success('Προστέθηκε υπηρεσία');
      setForm({ name: '', duration_mins: 60, location_ids: [], drop_in: '' });
      onSaved();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };
  return (
    <form onSubmit={save}>
      <StepNote>Χωρίς υπηρεσία ο πελάτης δεν έχει τι να κλείσει. Αν δεν διαλέξεις κατάστημα, ισχύει σε όλα.</StepNote>
      <div className="form-grid-2">
        <div className="form-group"><label className="form-label">Όνομα *</label><input className="form-input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="π.χ. Personal training" /></div>
        <div className="form-group"><label className="form-label">Διάρκεια (λεπτά)</label><input className="form-input" type="number" min="15" value={form.duration_mins} onChange={(e) => setForm({ ...form, duration_mins: e.target.value })} /></div>
      </div>
      <div className="form-group">
        <label className="form-label">Σε ποια καταστήματα</label>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {locations.map((loc) => (
            <label key={loc.id} style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
              <input type="checkbox" checked={form.location_ids.includes(loc.id)} onChange={() => toggleLoc(loc.id)} />
              {loc.name}
            </label>
          ))}
        </div>
      </div>
      <div className="form-group"><label className="form-label">Τιμή drop-in (€, προαιρετικά)</label><input className="form-input" value={form.drop_in} onChange={(e) => setForm({ ...form, drop_in: e.target.value })} placeholder="π.χ. 20" /></div>
      <button className="btn btn-primary" disabled={saving}>{saving ? '...' : 'Προσθήκη υπηρεσίας'}</button>
      <div style={{ marginTop: 10 }}><Link to="/services">Πλήρης λίστα υπηρεσιών και πρόγραμμα τάξεων</Link></div>
    </form>
  );
}

function PlansStep({ onSaved }) {
  const [services, setServices] = useState([]);
  const [form, setForm] = useState({ service_id: '', sessions: 8, price: '' });
  const [saving, setSaving] = useState(false);
  useEffect(() => {
    api.get('/client-admin/services').then((r) => setServices((r.data || []).filter((s) => s.is_active !== 0))).catch(() => {});
  }, []);
  const save = async (e) => {
    e.preventDefault();
    if (!form.service_id || form.price === '') return toast.error('Διάλεξε υπηρεσία και τιμή');
    setSaving(true);
    try {
      await api.post('/client-admin/plans', {
        service_id: form.service_id,
        sessions: Number(form.sessions),
        duration_mins: 60,
        price_cents: Math.round(Number(form.price) * 100),
        billing_period: 'monthly',
      });
      toast.success('Προστέθηκε πακέτο');
      setForm({ service_id: '', sessions: 8, price: '' });
      onSaved();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };
  return (
    <form onSubmit={save}>
      <StepNote>Τα πακέτα είναι οι συνδρομές που αγοράζει ο πελάτης. Μπορούν να μπουν και μετά τις πρώτες κρατήσεις.</StepNote>
      <div className="form-group">
        <label className="form-label">Υπηρεσία</label>
        <select className="form-input" value={form.service_id} onChange={(e) => setForm({ ...form, service_id: e.target.value })}>
          <option value="">Επίλεξε</option>
          {services.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
        </select>
      </div>
      <div className="form-grid-2">
        <div className="form-group"><label className="form-label">Συνεδρίες</label><input className="form-input" type="number" min="1" value={form.sessions} onChange={(e) => setForm({ ...form, sessions: e.target.value })} /></div>
        <div className="form-group"><label className="form-label">Τιμή (€)</label><input className="form-input" value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} /></div>
      </div>
      <button className="btn btn-primary" disabled={saving}>{saving ? '...' : 'Προσθήκη πακέτου'}</button>
      <div style={{ marginTop: 10 }}><Link to="/plans">Όλα τα πακέτα</Link></div>
    </form>
  );
}

function RoomsStep({ onSaved }) {
  const [locations, setLocations] = useState([]);
  const [form, setForm] = useState({ name: '', location_id: '', short_info: '' });
  const [saving, setSaving] = useState(false);
  useEffect(() => {
    api.get('/client-admin/locations').then((r) => {
      const locs = (r.data || []).filter((l) => l.is_active);
      setLocations(locs);
      if (locs[0]) setForm((f) => ({ ...f, location_id: f.location_id || locs[0].id }));
    }).catch(() => {});
  }, []);
  const save = async (e) => {
    e.preventDefault();
    if (!form.name.trim()) return toast.error('Βάλε όνομα αίθουσας');
    setSaving(true);
    try {
      await api.post('/client-admin/rooms', form);
      toast.success('Προστέθηκε αίθουσα');
      setForm({ ...form, name: '', short_info: '' });
      onSaved();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };
  return (
    <form onSubmit={save}>
      <StepNote>Οι αίθουσες χρησιμοποιούνται στο πρόγραμμα των τάξεων. Αν δεν έχεις ξεχωριστούς χώρους, παράλειψέ το.</StepNote>
      <div className="form-group"><label className="form-label">Όνομα</label><input className="form-input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="π.χ. Studio 1" /></div>
      <div className="form-group">
        <label className="form-label">Κατάστημα</label>
        <select className="form-input" value={form.location_id} onChange={(e) => setForm({ ...form, location_id: e.target.value })}>
          {locations.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}
        </select>
      </div>
      <div className="form-group"><label className="form-label">Σύντομη περιγραφή</label><input className="form-input" value={form.short_info} onChange={(e) => setForm({ ...form, short_info: e.target.value })} /></div>
      <button className="btn btn-primary" disabled={saving}>{saving ? '...' : 'Προσθήκη αίθουσας'}</button>
      <div style={{ marginTop: 10 }}><Link to="/rooms">Όλες οι αίθουσες</Link></div>
    </form>
  );
}

function DropInStep({ onSaved }) {
  const [locations, setLocations] = useState([]);
  const [services, setServices] = useState([]);
  useEffect(() => {
    Promise.all([
      api.get('/client-admin/locations'),
      api.get('/client-admin/services'),
    ]).then(([locs, svcs]) => {
      setLocations((locs.data || []).filter((l) => l.is_active));
      setServices((svcs.data || []).filter((s) => s.is_active !== 0));
    }).catch(() => {});
  }, []);
  const toggleLoc = async (loc) => {
    try {
      await api.patch(`/client-admin/locations/${loc.id}`, { accepts_drop_in: loc.accepts_drop_in ? 0 : 1 });
      setLocations((prev) => prev.map((l) => l.id === loc.id ? { ...l, accepts_drop_in: loc.accepts_drop_in ? 0 : 1 } : l));
      onSaved();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };
  const savePrice = async (svc, euros) => {
    try {
      await api.patch(`/client-admin/services/${svc.id}`, {
        drop_in_price_cents: euros === '' ? null : Math.round(Number(euros) * 100),
      });
      toast.success(`Drop-in για ${svc.name}`);
      onSaved();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };
  return (
    <div>
      <StepNote>Το drop-in ανοίγει μόνο στα καταστήματα που το δέχονται, και μόνο στις υπηρεσίες που έχουν τιμή.</StepNote>
      <div style={{ fontWeight: 700, marginBottom: 8 }}>Καταστήματα</div>
      {locations.map((loc) => (
        <label key={loc.id} style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 8 }}>
          <input type="checkbox" checked={!!loc.accepts_drop_in} onChange={() => toggleLoc(loc)} />
          {loc.name}
        </label>
      ))}
      <div style={{ fontWeight: 700, margin: '14px 0 8px' }}>Υπηρεσίες με τιμή drop-in</div>
      {services.map((svc) => (
        <DropInPrice key={svc.id} svc={svc} onSave={savePrice} />
      ))}
    </div>
  );
}

function DropInPrice({ svc, onSave }) {
  const [value, setValue] = useState(svc.drop_in_price_cents ? String(svc.drop_in_price_cents / 100) : '');
  return (
    <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 8 }}>
      <div style={{ flex: 1 }}>{svc.name}</div>
      <input className="form-input" style={{ maxWidth: 120 }} value={value} onChange={(e) => setValue(e.target.value)} placeholder="€" />
      <button type="button" className="btn btn-secondary btn-sm" onClick={() => onSave(svc, value)}>ΟΚ</button>
    </div>
  );
}

function NutritionStep({ checks, onSaved }) {
  const [locations, setLocations] = useState([]);
  const [enabled, setEnabled] = useState(!!checks?.nutrition_enabled);
  const [form, setForm] = useState({ full_name: '', email: '', location_id: '' });
  const [saving, setSaving] = useState(false);
  useEffect(() => {
    api.get('/client-admin/locations').then((r) => setLocations((r.data || []).filter((l) => l.is_active))).catch(() => {});
  }, []);
  const toggle = async (next) => {
    try {
      await api.patch('/client-admin/settings', { feature_nutrition: next ? 1 : 0 });
      setEnabled(next);
      onSaved();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };
  const save = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      await api.post('/client-admin/nutritionists', { ...form, location_id: form.location_id || null });
      toast.success('Προστέθηκε διατροφολόγος');
      setForm({ full_name: '', email: '', location_id: '' });
      onSaved();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };
  return (
    <div>
      <StepNote>Αν δεν έχεις διατροφολόγο, παράλειψέ το. Αν έχεις, διάλεξε και το κατάστημα όπου δέχεται.</StepNote>
      <label style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 14 }}>
        <input type="checkbox" checked={enabled} onChange={(e) => toggle(e.target.checked)} />
        Ενεργό τμήμα διατροφής ({checks?.nutritionists || 0} διατροφολόγοι)
      </label>
      {enabled && (
        <form onSubmit={save}>
          <div className="form-grid-2">
            <div className="form-group"><label className="form-label">Όνομα</label><input className="form-input" value={form.full_name} onChange={(e) => setForm({ ...form, full_name: e.target.value })} required /></div>
            <div className="form-group"><label className="form-label">Email</label><input className="form-input" type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} required /></div>
          </div>
          <div className="form-group">
            <label className="form-label">Κατάστημα</label>
            <select className="form-input" value={form.location_id} onChange={(e) => setForm({ ...form, location_id: e.target.value })}>
              <option value="">Όλα / δεν έχει οριστεί</option>
              {locations.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}
            </select>
          </div>
          <button className="btn btn-primary" disabled={saving}>{saving ? '...' : 'Προσθήκη διατροφολόγου'}</button>
          <div style={{ marginTop: 10 }}><Link to="/nutrition/nutritionists">Διατροφολόγοι</Link></div>
        </form>
      )}
    </div>
  );
}

function StaffStep({ checks, onSaved }) {
  const [form, setForm] = useState({ full_name: '', role: 'Trainer' });
  const [saving, setSaving] = useState(false);
  const save = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      await api.post('/client-admin/staff', form);
      toast.success('Προστέθηκε. Τις ώρες και τις υπηρεσίες του τις ορίζεις στο επόμενο βήμα ή στην καρτέλα του.');
      setForm({ full_name: '', role: 'Trainer' });
      onSaved();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };
  return (
    <form onSubmit={save}>
      <StepNote>
        Προσωπικό τώρα: {checks?.staff || 0}. Χωρίς γυμναστή, οι προσωπικές υπηρεσίες δεν δείχνουν ώρες.
        Τάξεις με πρόγραμμα μπορούν να μείνουν χωρίς συγκεκριμένο άτομο.
      </StepNote>
      <div className="form-grid-2">
        <div className="form-group"><label className="form-label">Ονοματεπώνυμο</label><input className="form-input" value={form.full_name} onChange={(e) => setForm({ ...form, full_name: e.target.value })} required /></div>
        <div className="form-group"><label className="form-label">Ρόλος</label><input className="form-input" value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value })} required /></div>
      </div>
      <button className="btn btn-primary" disabled={saving}>{saving ? '...' : 'Προσθήκη'}</button>
      <div style={{ marginTop: 10 }}><Link to="/staff">Λίστα προσωπικού</Link></div>
    </form>
  );
}

function HoursStep({ checks }) {
  return (
    <div>
      <StepNote>
        {checks?.staff_with_hours || 0} από {checks?.staff || 0} έχουν ώρες διαθεσιμότητας.
        Σε κάθε κατάστημα ορίζεις ποιος δουλεύει, ποιες υπηρεσίες κάνει εκεί, και αν το ωράριο ισχύει για έναν ή για όλους.
      </StepNote>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        <Link to="/locations" className="btn btn-primary">Καταστήματα και ώρες ομάδας</Link>
        <Link to="/staff" className="btn btn-secondary">Καρτέλες γυμναστών</Link>
        <Link to="/services" className="btn btn-secondary">Πρόγραμμα τάξεων</Link>
      </div>
    </div>
  );
}

function LeaveStep({ checks, onSaved }) {
  const [days, setDays] = useState(checks?.annual_leave_days ?? 20);
  const [saving, setSaving] = useState(false);
  const save = async () => {
    setSaving(true);
    try {
      await api.patch('/client-admin/settings/annual-leave-days', { annual_leave_days: Number(days) });
      toast.success('Αποθηκεύτηκαν οι ημέρες άδειας');
      onSaved();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };
  return (
    <div>
      <StepNote>Καταχωρημένες άδειες: {checks?.leaves || 0}. Οι συγκεκριμένες ημερομηνίες μπαίνουν από την σελίδα αδειών.</StepNote>
      <div className="form-group" style={{ maxWidth: 220 }}>
        <label className="form-label">Ημέρες ετήσιας άδειας</label>
        <input className="form-input" type="number" min="1" value={days} onChange={(e) => setDays(e.target.value)} />
      </div>
      <button type="button" className="btn btn-primary" onClick={save} disabled={saving}>{saving ? '...' : 'Αποθήκευση'}</button>
      <div style={{ marginTop: 10 }}><Link to="/staff-leaves">Άδειες προσωπικού</Link></div>
    </div>
  );
}

function PayrollStep() {
  return (
    <div>
      <StepNote>Οι αμοιβές συνεργατών και τα έξοδα δεν χρειάζονται για να ανοίξουν οι κρατήσεις.</StepNote>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        <Link to="/trainer-fees" className="btn btn-primary">Αμοιβές συνεργατών</Link>
        <Link to="/expenses" className="btn btn-secondary">Γενικά έξοδα</Link>
      </div>
    </div>
  );
}

function ProgramsStep({ checks }) {
  return (
    <div>
      <StepNote>Προγράμματα άσκησης: {checks?.programs || 0}. Τα φτιάχνεις ανά πελάτη όταν ξεκινήσει η προπόνηση.</StepNote>
      <Link to="/programs" className="btn btn-primary">Προγράμματα άσκησης</Link>
    </div>
  );
}

export default function SetupWizard() {
  const navigate = useNavigate();
  const [status, setStatus] = useState(null);
  const [stepId, setStepId] = useState('details');

  const refresh = async () => {
    const r = await api.get('/client-admin/setup-wizard');
    setStatus(r.data);
    return r.data;
  };

  useEffect(() => {
    refresh().then((data) => {
      if (data?.progress?.last_step && STEPS.some((s) => s.id === data.progress.last_step)) {
        setStepId(data.progress.last_step);
      }
    }).catch(() => toast.error('Δεν φορτώθηκε ο οδηγός'));
  }, []);

  const index = Math.max(0, STEPS.findIndex((s) => s.id === stepId));
  const step = STEPS[index];
  const checks = status?.checks;
  const progress = status?.progress || { skipped: [] };

  const persist = async (patch) => {
    const r = await api.patch('/client-admin/setup-wizard', patch);
    setStatus((prev) => prev && ({ ...prev, progress: r.data.progress }));
  };

  const goTo = async (id) => {
    setStepId(id);
    persist({ last_step: id }).catch(() => {});
  };

  const move = async (dir, { skip } = {}) => {
    if (dir > 0 && !skip) {
      const reason = blockedReason(step, checks);
      if (reason) return toast.error(reason);
    }
    const skipped = new Set(progress.skipped || []);
    if (skip) skipped.add(step.id);
    else skipped.delete(step.id);
    const next = STEPS[index + dir];
    if (!next && dir > 0) {
      const missing = STEPS.filter((s) => blockedReason(s, checks));
      if (missing.length) {
        toast.error('Μένουν υποχρεωτικά βήματα');
        goTo(missing[0].id);
        return;
      }
      await persist({ skipped: [...skipped], finished: true, dismissed: true, last_step: step.id });
      toast.success('Η αρχική ρύθμιση ολοκληρώθηκε');
      navigate('/');
      return;
    }
    if (!next) return;
    await persist({ skipped: [...skipped], last_step: next.id });
    setStepId(next.id);
  };

  const body = {
    details: <DetailsStep onSaved={refresh} />,
    logo: <LogoStep onSaved={refresh} />,
    photos: <PhotosStep onSaved={refresh} />,
    description: <DescriptionStep onSaved={refresh} />,
    locations: <LocationsStep checks={checks} onSaved={refresh} />,
    services: <ServicesStep onSaved={refresh} />,
    plans: <PlansStep onSaved={refresh} />,
    rooms: <RoomsStep onSaved={refresh} />,
    dropin: <DropInStep onSaved={refresh} />,
    nutrition: <NutritionStep checks={checks} onSaved={refresh} />,
    staff: <StaffStep checks={checks} onSaved={refresh} />,
    hours: <HoursStep checks={checks} />,
    leave: <LeaveStep checks={checks} onSaved={refresh} />,
    payroll: <PayrollStep />,
    programs: <ProgramsStep checks={checks} />,
  }[step.id];

  return (
    <Layout title="Οδηγός έναρξης">
      <div className="page-header">
        <div>
          <h1 className="page-title">Οδηγός έναρξης</h1>
          <p className="text-muted">Βήμα {index + 1} από {STEPS.length}. Τα υποχρεωτικά είναι το όνομα, ένα κατάστημα και μία υπηρεσία.</p>
        </div>
        <button type="button" className="btn btn-secondary" onClick={() => { persist({ dismissed: true }).then(() => navigate('/')); }}>
          Έξοδος
        </button>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '260px 1fr', gap: 20, alignItems: 'start' }}>
        <div className="card" style={{ padding: 10 }}>
          {STEPS.map((item, i) => {
            const state = stepState(item, checks, progress);
            const active = item.id === step.id;
            return (
              <button
                key={item.id}
                type="button"
                onClick={() => goTo(item.id)}
                style={{
                  width: '100%', textAlign: 'left', border: 'none', background: active ? '#f0fdf4' : 'transparent',
                  borderRadius: 8, padding: '8px 10px', cursor: 'pointer', marginBottom: 2,
                }}
              >
                <div style={{ fontWeight: active ? 700 : 500, fontSize: '0.88rem' }}>
                  {i + 1}. {item.title}
                  {item.required ? ' *' : ''}
                </div>
                <div className="text-muted" style={{ fontSize: '0.72rem' }}>
                  {state === 'done' ? 'Συμπληρωμένο' : state === 'skipped' ? 'Παραλείφθηκε' : item.hint}
                </div>
              </button>
            );
          })}
        </div>
        <div className="card">
          <div className="modal-title" style={{ marginBottom: 8 }}>
            {step.title} {step.required ? <span style={{ color: '#b45309', fontSize: '0.8rem' }}>απαραίτητο</span> : <span className="text-muted" style={{ fontSize: '0.8rem' }}>προαιρετικό</span>}
          </div>
          {body}
          <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, marginTop: 22 }}>
            <button type="button" className="btn btn-secondary" disabled={index === 0} onClick={() => move(-1)}>Πίσω</button>
            <div style={{ display: 'flex', gap: 8 }}>
              {!step.required && <button type="button" className="btn btn-secondary" onClick={() => move(1, { skip: true })}>Παράλειψη</button>}
              <button type="button" className="btn btn-primary" onClick={() => move(1)}>
                {index === STEPS.length - 1 ? 'Ολοκλήρωση' : 'Συνέχεια'}
              </button>
            </div>
          </div>
        </div>
      </div>
    </Layout>
  );
}
