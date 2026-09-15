import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Save } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

const EMPTY = {
  full_name: '',
  email: '',
  password: '',
  phone: '',
  bio: '',
  is_active: true,
};

export default function NutritionProfile() {
  const { isOwner } = useAuth();
  const [form, setForm] = useState(EMPTY);
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get('/client-admin/nutritionist')
      .then(r => {
        if (!r.data) return;
        const d = r.data;
        setForm({
          full_name: d.full_name || '',
          email: d.email || '',
          password: '',
          phone: d.phone || '',
          bio: d.bio || '',
          is_active: !!d.is_active,
        });
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const save = async () => {
    if (!isOwner) return;
    setSaving(true);
    try {
      await api.put('/client-admin/nutritionist', {
        full_name: form.full_name,
        email: form.email,
        password: form.password || undefined,
        phone: form.phone || null,
        bio: form.bio || null,
        is_active: form.is_active,
      });
      toast.success('Το προφίλ διατροφολόγου αποθηκεύτηκε');
      setForm(prev => ({ ...prev, password: '' }));
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return <Layout title="Προφίλ διατροφολόγου" variant="nutrition"><div className="loading">Φόρτωση...</div></Layout>;
  }

  return (
    <Layout title="Προφίλ διατροφολόγου" variant="nutrition">
      <div className="page-header">
        <div>
          <h1 className="page-title">Προφίλ διατροφολόγου</h1>
          <p className="text-muted" style={{ margin: '6px 0 0' }}>
            Στοιχεία συνεργάτη. Τα πακέτα διατροφής ορίζονται ξεχωριστά.
          </p>
        </div>
      </div>

      <div className="card">
        <div className="form-grid-2">
          <div className="form-group">
            <label className="form-label">Ονοματεπώνυμο</label>
            <input className="form-input" value={form.full_name} disabled={!isOwner} onChange={e => setForm({ ...form, full_name: e.target.value })} />
          </div>
          <div className="form-group">
            <label className="form-label">Email σύνδεσης</label>
            <input className="form-input" type="email" value={form.email} disabled={!isOwner} onChange={e => setForm({ ...form, email: e.target.value })} />
          </div>
          <div className="form-group">
            <label className="form-label">Τηλέφωνο</label>
            <input className="form-input" value={form.phone} disabled={!isOwner} onChange={e => setForm({ ...form, phone: e.target.value })} />
          </div>
          {isOwner && (
            <div className="form-group">
              <label className="form-label">Νέος κωδικός (προαιρετικό)</label>
              <input className="form-input" type="password" value={form.password} onChange={e => setForm({ ...form, password: e.target.value })} placeholder="Αφήστε κενό για να μην αλλάξει" />
            </div>
          )}
        </div>
        <div className="form-group">
          <label className="form-label">Βιογραφικό / σημειώσεις</label>
          <textarea className="form-input" rows={3} value={form.bio} disabled={!isOwner} onChange={e => setForm({ ...form, bio: e.target.value })} />
        </div>
        {isOwner && (
          <>
            <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', marginBottom: 16 }}>
              <input type="checkbox" checked={form.is_active} onChange={e => setForm({ ...form, is_active: e.target.checked })} />
              <span>Ενεργός λογαριασμός διατροφολόγου</span>
            </label>
            <button className="btn btn-primary" type="button" onClick={save} disabled={saving}>
              <Save size={14} /> {saving ? 'Αποθήκευση...' : 'Αποθήκευση'}
            </button>
          </>
        )}
      </div>
    </Layout>
  );
}
