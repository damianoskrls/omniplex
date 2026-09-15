import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Plus, Save, X } from 'lucide-react';

const EMPTY = {
  full_name: '',
  email: '',
  password: '',
  phone: '',
  bio: '',
  is_active: true,
  location_id: '',
};

export default function Nutritionists() {
  const [rows, setRows] = useState([]);
  const [locations, setLocations] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [editing, setEditing] = useState(null);
  const [form, setForm] = useState(EMPTY);

  const load = async () => {
    const [listRes, locRes] = await Promise.all([
      api.get('/client-admin/nutritionists'),
      api.get('/client-admin/locations').catch(() => ({ data: [] })),
    ]);
    setRows(listRes.data || []);
    setLocations(locRes.data || []);
  };

  useEffect(() => {
    setLoading(true);
    load().catch(() => toast.error('Σφάλμα')).finally(() => setLoading(false));
  }, []);

  const openNew = () => {
    setEditing('new');
    setForm(EMPTY);
  };

  const openEdit = (row) => {
    setEditing(row.id);
    setForm({
      full_name: row.full_name || '',
      email: row.email || '',
      password: '',
      phone: row.phone || '',
      bio: row.bio || '',
      is_active: !!row.is_active,
      location_id: row.location_id || '',
    });
  };

  const closeForm = () => {
    setEditing(null);
    setForm(EMPTY);
  };

  const save = async () => {
    if (!form.full_name || !form.email) {
      toast.error('Συμπλήρωσε όνομα και email');
      return;
    }
    setSaving(true);
    try {
      const payload = {
        ...form,
        location_id: form.location_id || null,
        password: form.password || undefined,
      };
      if (editing === 'new') {
        await api.post('/client-admin/nutritionists', payload);
        toast.success('Προστέθηκε διατροφολόγος');
      } else {
        await api.put(`/client-admin/nutritionists/${editing}`, payload);
        toast.success('Αποθηκεύτηκε');
      }
      closeForm();
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return <Layout title="Διατροφολόγοι" variant="nutrition"><div className="loading">Φόρτωση...</div></Layout>;
  }

  return (
    <Layout title="Διατροφολόγοι" variant="nutrition">
      <div className="page-header">
        <div>
          <h1 className="page-title">Διατροφολόγοι</h1>
          <p className="text-muted" style={{ margin: '6px 0 0' }}>
            Ανεξάρτητη υπηρεσία — η τοποθεσία δείχνει σε ποιο κατάστημα εργάζεται ο κάθε διατροφολόγος.
          </p>
        </div>
        <button type="button" className="btn btn-primary" onClick={openNew}>
          <Plus size={16} /> Νέος διατροφολόγος
        </button>
      </div>

      <div className="card" style={{ marginBottom: 16 }}>
        <table>
          <thead>
            <tr>
              <th>Όνομα</th>
              <th>Email</th>
              <th>Τοποθεσία</th>
              <th>Κατάσταση</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 && (
              <tr><td colSpan={5} className="text-muted">Δεν υπάρχουν διατροφολόγοι</td></tr>
            )}
            {rows.map(row => (
              <tr key={row.id}>
                <td style={{ fontWeight: 600 }}>{row.full_name}</td>
                <td>{row.email}</td>
                <td>{row.location_name || '—'}</td>
                <td>
                  <span className={`badge ${row.is_active ? 'badge-green' : 'badge-gray'}`}>
                    {row.is_active ? 'Ενεργός' : 'Ανενεργός'}
                  </span>
                </td>
                <td>
                  <button type="button" className="btn btn-sm btn-secondary" onClick={() => openEdit(row)}>
                    Επεξεργασία
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {editing && (
        <div className="card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
            <h2 style={{ margin: 0, fontSize: '1.1rem' }}>
              {editing === 'new' ? 'Νέος διατροφολόγος' : 'Επεξεργασία διατροφολόγου'}
            </h2>
            <button type="button" className="btn btn-sm btn-secondary" onClick={closeForm}><X size={14} /></button>
          </div>
          <div className="form-grid-2">
            <div className="form-group">
              <label className="form-label">Ονοματεπώνυμο</label>
              <input className="form-input" value={form.full_name} onChange={e => setForm({ ...form, full_name: e.target.value })} />
            </div>
            <div className="form-group">
              <label className="form-label">Email (σύνδεση)</label>
              <input className="form-input" type="email" value={form.email} onChange={e => setForm({ ...form, email: e.target.value })} />
            </div>
            <div className="form-group">
              <label className="form-label">Τοποθεσία καταστήματος</label>
              <select className="form-input" value={form.location_id} onChange={e => setForm({ ...form, location_id: e.target.value })}>
                <option value="">— Χωρίς συγκεκριμένη —</option>
                {locations.map(loc => (
                  <option key={loc.id} value={loc.id}>{loc.name}</option>
                ))}
              </select>
            </div>
            <div className="form-group">
              <label className="form-label">Τηλέφωνο</label>
              <input className="form-input" value={form.phone} onChange={e => setForm({ ...form, phone: e.target.value })} />
            </div>
            <div className="form-group">
              <label className="form-label">Κωδικός {editing !== 'new' ? '(άδειο = χωρίς αλλαγή)' : ''}</label>
              <input className="form-input" type="password" value={form.password} onChange={e => setForm({ ...form, password: e.target.value })} />
            </div>
            <div className="form-group" style={{ display: 'flex', alignItems: 'center', gap: 8, paddingTop: 28 }}>
              <input type="checkbox" id="nut-active" checked={form.is_active} onChange={e => setForm({ ...form, is_active: e.target.checked })} />
              <label htmlFor="nut-active">Ενεργός</label>
            </div>
            <div className="form-group" style={{ gridColumn: '1 / -1' }}>
              <label className="form-label">Bio</label>
              <textarea className="form-input" rows={3} value={form.bio} onChange={e => setForm({ ...form, bio: e.target.value })} />
            </div>
          </div>
          <button type="button" className="btn btn-primary" onClick={save} disabled={saving}>
            <Save size={16} /> {saving ? 'Αποθήκευση...' : 'Αποθήκευση'}
          </button>
        </div>
      )}
    </Layout>
  );
}
