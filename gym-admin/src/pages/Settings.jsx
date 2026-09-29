import { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Save, Upload, Download } from 'lucide-react';
import { mediaUrl } from '../utils/media';

function GymCapacitySection() {
  const [capacity, setCapacity] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    api.get('/client-admin/gym-capacity').then(r => {
      setCapacity(r.data.gym_capacity != null ? String(r.data.gym_capacity) : '');
    }).catch(() => {});
  }, []);

  const save = async () => {
    setSaving(true);
    try {
      await api.patch('/client-admin/gym-capacity', {
        gym_capacity: capacity === '' ? null : parseInt(capacity, 10),
      });
      toast.success('Χωρητικότητα αποθηκεύτηκε');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div style={{ borderTop: '1px solid #e2e8f0', paddingTop: 16, marginTop: 4 }}>
      <div style={{ fontSize: '0.85rem', fontWeight: 600, marginBottom: 6 }}>Χωρητικότητα χώρου</div>
      <p className="text-muted" style={{ fontSize: '0.78rem', marginBottom: 10 }}>
        Ο μέγιστος αριθμός ατόμων που μπορούν να χρησιμοποιούν τον χώρο ταυτόχρονα.
        Χρησιμοποιείται για να δείχνει στους πελάτες αν ο χώρος είναι ελεύθερος ή γεμάτος.
      </p>
      <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
        <input
          className="form-input"
          type="number"
          min="1"
          placeholder="π.χ. 50"
          value={capacity}
          onChange={e => setCapacity(e.target.value)}
          style={{ maxWidth: 120 }}
        />
        <span className="text-muted" style={{ fontSize: '0.82rem' }}>άτομα</span>
        <button className="btn btn-primary" onClick={save} disabled={saving} style={{ marginLeft: 8 }}>
          {saving ? 'Αποθήκευση...' : 'Αποθήκευση'}
        </button>
      </div>
    </div>
  );
}

export default function Settings() {
  const logoRef = useRef();
  const [form, setForm] = useState({
    app_name: '',
    gym_address: '',
    gym_phone: '',
    gym_email: '',
    owner_name: '',
    owner_phone: '',
    logo_url: null,
    feature_online_booking: 1,
    feature_loyalty_points: 0,
    feature_memberships: 1,
    feature_waitlist: 0,
    feature_nutrition: 0,
  });
  const [saving, setSaving] = useState(false);
  const [uploadingLogo, setUploadingLogo] = useState(false);
  const [backing, setBacking] = useState(false);

  useEffect(() => {
    api.get('/client-admin/settings').then(r => {
      const d = r.data;
      setForm({
        app_name: d.app_name || '',
        gym_address: d.gym_address || '',
        gym_phone: d.gym_phone || '',
        gym_email: d.gym_email || '',
        owner_name: d.owner_name || '',
        owner_phone: d.owner_phone || '',
        logo_url: d.logo_url || null,
        feature_online_booking: d.feature_online_booking ?? 1,
        feature_loyalty_points: d.feature_loyalty_points ?? 0,
        feature_memberships: d.feature_memberships ?? 1,
        feature_waitlist: d.feature_waitlist ?? 0,
        feature_nutrition: d.feature_nutrition ?? 0,
      });
    }).catch(() => toast.error('Σφάλμα φόρτωσης ρυθμίσεων'));
  }, []);

  const save = async () => {
    setSaving(true);
    try {
      await api.patch('/client-admin/settings', form);
      toast.success('Ρυθμίσεις αποθηκεύτηκαν');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };

  const uploadLogo = async (file) => {
    if (!file) return;
    setUploadingLogo(true);
    const fd = new FormData();
    fd.append('logo', file);
    try {
      const r = await api.post('/client-admin/settings/logo', fd, { headers: { 'Content-Type': 'multipart/form-data' } });
      setForm(prev => ({ ...prev, logo_url: r.data.logo_url }));
      toast.success('Logo ανέβηκε');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setUploadingLogo(false);
    }
  };

  const backup = async () => {
    setBacking(true);
    try {
      const res = await api.get('/client-admin/backup', { responseType: 'blob' });
      const url = URL.createObjectURL(res.data);
      const a = document.createElement('a');
      a.href = url;
      a.download = `handstand-backup-${new Date().toISOString().slice(0,10)}.json`;
      a.click();
      URL.revokeObjectURL(url);
      toast.success('Backup κατεβάστηκε');
    } catch { toast.error('Σφάλμα backup'); }
    finally { setBacking(false); }
  };

  const toggle = (key) => setForm(prev => ({ ...prev, [key]: prev[key] ? 0 : 1 }));

  return (
    <Layout title="Ρυθμίσεις">
      <div className="page-header">
        <h1 className="page-title">Ρυθμίσεις</h1>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <Link to="/setup" className="btn btn-secondary">Οδηγός έναρξης</Link>
          <button className="btn btn-secondary" onClick={backup} disabled={backing}>
            <Download size={15} /> {backing ? 'Εξαγωγή...' : 'Backup δεδομένων'}
          </button>
          <button className="btn btn-primary" onClick={save} disabled={saving}>
            <Save size={15} /> {saving ? 'Αποθήκευση...' : 'Αποθήκευση'}
          </button>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20 }}>
        {/* Basic info */}
        <div className="card">
          <div className="modal-title" style={{ marginBottom: 16 }}>Στοιχεία επιχείρησης</div>

          {/* Logo */}
          <div className="form-group">
            <label className="form-label">Logo</label>
            <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
              {form.logo_url ? (
                <img src={mediaUrl(form.logo_url)} alt="logo" style={{ height: 60, maxWidth: 160, objectFit: 'contain', borderRadius: 8, border: '1px solid #e2e8f0' }} />
              ) : (
                <div style={{ width: 80, height: 60, borderRadius: 8, background: '#f1f5f9', border: '1px dashed #cbd5e1', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#94a3b8', fontSize: '0.75rem' }}>Χωρίς logo</div>
              )}
              <label className="btn btn-secondary btn-sm" style={{ cursor: 'pointer' }}>
                <Upload size={14} /> {uploadingLogo ? 'Ανέβασμα...' : 'Αλλαγή logo'}
                <input ref={logoRef} type="file" accept="image/*,.svg" style={{ display: 'none' }} onChange={e => uploadLogo(e.target.files[0])} />
              </label>
            </div>
          </div>

          <div className="form-group">
            <label className="form-label">Όνομα στην εφαρμογή</label>
            <input className="form-input" value={form.app_name} onChange={e => setForm({ ...form, app_name: e.target.value })} placeholder="π.χ. Handstand" />
            <p className="text-muted" style={{ marginTop: 6, fontSize: '0.78rem' }}>
              Το όνομα που βλέπουν οι πελάτες στην εφαρμογή κινητού (κάτω από το icon). Αλλαγές εφαρμόζονται μετά από νέο build της εφαρμογής.
            </p>
          </div>
          <div className="form-group">
            <label className="form-label">Διεύθυνση</label>
            <input className="form-input" value={form.gym_address} onChange={e => setForm({ ...form, gym_address: e.target.value })} placeholder="Οδός, Αριθμός, Πόλη" />
          </div>
          <div className="form-grid-2">
            <div className="form-group">
              <label className="form-label">Τηλέφωνο</label>
              <input className="form-input" value={form.gym_phone} onChange={e => setForm({ ...form, gym_phone: e.target.value })} placeholder="+30 210..." />
            </div>
            <div className="form-group">
              <label className="form-label">Email</label>
              <input className="form-input" type="email" value={form.gym_email} onChange={e => setForm({ ...form, gym_email: e.target.value })} />
            </div>
          </div>

          <div style={{ borderTop: '1px solid #e2e8f0', paddingTop: 16, marginTop: 4 }}>
            <div style={{ fontSize: '0.85rem', fontWeight: 600, marginBottom: 10 }}>Ιδιοκτήτης</div>
            <div className="form-grid-2">
              <div className="form-group">
                <label className="form-label">Ονοματεπώνυμο</label>
                <input className="form-input" value={form.owner_name} onChange={e => setForm({ ...form, owner_name: e.target.value })} />
              </div>
              <div className="form-group">
                <label className="form-label">Τηλέφωνο</label>
                <input className="form-input" value={form.owner_phone} onChange={e => setForm({ ...form, owner_phone: e.target.value })} />
              </div>
            </div>
          </div>

          {/* Gym capacity */}
          <GymCapacitySection />

          {/* Features */}
          <div style={{ borderTop: '1px solid #e2e8f0', paddingTop: 16, marginTop: 4 }}>
            <div style={{ fontSize: '0.85rem', fontWeight: 600, marginBottom: 10 }}>Λειτουργίες εφαρμογής</div>
            {[
              { key: 'feature_online_booking', label: 'Online κρατήσεις' },
              { key: 'feature_loyalty_points', label: 'Πόντοι επιβράβευσης' },
              { key: 'feature_memberships', label: 'Συνδρομές / Πακέτα' },
              { key: 'feature_waitlist', label: 'Λίστα αναμονής' },
              { key: 'feature_nutrition', label: 'Διατροφή (module)' },
            ].map(f => (
              <label key={f.key} style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8, cursor: 'pointer' }}>
                <div
                  onClick={() => toggle(f.key)}
                  style={{
                    width: 44, height: 24, borderRadius: 12,
                    background: form[f.key] ? '#76C043' : '#e2e8f0',
                    position: 'relative', transition: 'background 0.2s', cursor: 'pointer',
                  }}
                >
                  <div style={{
                    position: 'absolute', top: 2, left: form[f.key] ? 22 : 2,
                    width: 20, height: 20, borderRadius: '50%', background: '#fff',
                    transition: 'left 0.2s', boxShadow: '0 1px 3px rgba(0,0,0,0.2)',
                  }} />
                </div>
                <span style={{ fontSize: '0.9rem' }}>{f.label}</span>
              </label>
            ))}
          </div>
        </div>

        <div className="card">
          <div className="modal-title" style={{ marginBottom: 4 }}>Ωράριο καταστημάτων</div>
          <div className="text-muted" style={{ fontSize: '0.85rem', lineHeight: 1.55, marginBottom: 14 }}>
            Κάθε κατάστημα έχει το δικό του ωράριο. Δημιούργησε Κηφισιά, Νέα Ιωνία και τα υπόλοιπα, και όρισε πότε είναι ανοιχτό το καθένα.
          </div>
          <Link to="/locations" className="btn btn-primary">Διαχείριση καταστημάτων</Link>

          {/* Mobile app branding */}
          <div style={{ marginTop: 24, padding: 16, background: '#f0fdf4', borderRadius: 12, border: '1px solid #c7d2fe' }}>
            <div style={{ fontWeight: 600, marginBottom: 6 }}>Εφαρμογή πελατών (white-label)</div>
            <div className="text-muted" style={{ fontSize: '0.8rem', lineHeight: 1.55, marginBottom: 10 }}>
              Η εφαρμογή κινητού των πελατών σου εμφανίζει το <strong>όνομα</strong> και το <strong>logo</strong> που ορίζεις εδώ.
              Για QR check-in άνοιξε από το μενού <strong>QR Check-in</strong> σε tablet στην είσοδο.
            </div>
            <div className="text-muted" style={{ fontSize: '0.78rem' }}>
              Αν αλλάξεις logo ή όνομα, ενημέρωσε τον διαχειριστή OmniPlex για ενημέρωση της εφαρμογής στο App Store / Play Store.
            </div>
          </div>

          {/* Backup card — intentional last item */}
          {/* Backup card */}
          <div style={{ marginTop: 24, padding: 16, background: '#f8fafc', borderRadius: 12, border: '1px solid #e2e8f0' }}>
            <div style={{ fontWeight: 600, marginBottom: 6 }}>Backup συστήματος</div>
            <div className="text-muted" style={{ fontSize: '0.8rem', marginBottom: 12 }}>
              Εξαγωγή όλων των δεδομένων (πελάτες, κρατήσεις, συνδρομές, ωράρια) σε JSON αρχείο.
            </div>
            <button className="btn btn-secondary" onClick={backup} disabled={backing}>
              <Download size={14} /> {backing ? 'Εξαγωγή...' : 'Κατέβασε backup'}
            </button>
          </div>
        </div>
      </div>
    </Layout>
  );
}
