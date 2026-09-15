import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import StaffDeleteModal from '../components/StaffDeleteModal';
import { Plus, Settings, Trash2 } from 'lucide-react';

const EMPTY = { full_name: '', role: 'Trainer', bio: '', color_hex: '#607D8B' };

export default function Staff() {
  const [staff, setStaff] = useState([]);
  const [modal, setModal] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState(null);
  const [form, setForm] = useState(EMPTY);
  const navigate = useNavigate();

  const load = () => api.get('/client-admin/staff').then(r => setStaff(r.data)).catch(() => {});
  useEffect(() => { load(); }, []);

  const handleCreate = async (e) => {
    e.preventDefault();
    try {
      const res = await api.post('/client-admin/staff', form);
      toast.success('Προστέθηκε προσωπικό');
      setModal(false);
      setForm(EMPTY);
      navigate(`/staff/${res.data.id}`);
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  return (
    <Layout title="Προσωπικό">
      <div className="page-header">
        <h1 className="page-title">Προσωπικό ({staff.length})</h1>
        <button className="btn btn-primary" onClick={() => setModal(true)}><Plus size={16} /> Νέο μέλος</button>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: 16 }}>
        {staff.map(s => (
          <div className="card" key={s.id}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{ width: 40, height: 40, borderRadius: '50%', background: s.color_hex, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700 }}>
                {s.full_name[0]}
              </div>
              <div>
                <div style={{ fontWeight: 600 }}>{s.full_name}</div>
                <div className="text-muted">{s.role}</div>
              </div>
            </div>
            {s.bio && <p className="text-muted" style={{ marginTop: 8, fontSize: '0.8rem', lineHeight: 1.4 }}>{s.bio}</p>}
            <div className="text-muted" style={{ marginTop: 6, fontSize: '0.8rem' }}>
              Υπηρεσίες: {s.services?.map(x => x.service_name).join(', ') || '—'}
            </div>
            <div style={{ marginTop: 8 }}>
              {s.portal_enabled ? (
                <span className="badge badge-green" style={{ fontSize: '0.75rem' }}>
                  Portal: {s.portal_email}
                </span>
              ) : s.portal_email ? (
                <span className="badge badge-yellow" style={{ fontSize: '0.75rem' }}>
                  Portal χωρίς κωδικό
                </span>
              ) : (
                <span className="text-muted" style={{ fontSize: '0.75rem' }}>Χωρίς portal</span>
              )}
              {Number(s.pending_availability_requests) > 0 && (
                <span className="badge badge-yellow" style={{ fontSize: '0.75rem', marginLeft: 6 }}>
                  {s.pending_availability_requests} αίτηση διαθεσιμότητας
                </span>
              )}
            </div>
            <div style={{ display: 'flex', gap: 8, marginTop: 12, flexWrap: 'wrap' }}>
              <button className="btn btn-secondary btn-sm" onClick={() => navigate(`/staff/${s.id}`)}>
                <Settings size={14} /> Ρυθμίσεις & Διαθεσιμότητα
              </button>
              <button className="btn btn-danger btn-sm" onClick={() => setDeleteTarget(s)}>
                <Trash2 size={14} /> Διαγραφή
              </button>
            </div>
          </div>
        ))}
      </div>

      {modal && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setModal(false)}>
          <div className="modal">
            <div className="modal-title">Νέο μέλος προσωπικού</div>
            <form onSubmit={handleCreate}>
              <div className="form-group">
                <label className="form-label">Ονοματεπώνυμο *</label>
                <input className="form-input" value={form.full_name} onChange={e => setForm({ ...form, full_name: e.target.value })} required />
              </div>
              <div className="form-group">
                <label className="form-label">Ρόλος *</label>
                <input className="form-input" value={form.role} onChange={e => setForm({ ...form, role: e.target.value })} required />
              </div>
              <div className="form-group">
                <label className="form-label">Χρώμα</label>
                <input className="form-input" type="color" value={form.color_hex} onChange={e => setForm({ ...form, color_hex: e.target.value })} />
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setModal(false)}>Ακύρωση</button>
                <button type="submit" className="btn btn-primary">Δημιουργία</button>
              </div>
            </form>
          </div>
        </div>
      )}

      <StaffDeleteModal
        open={!!deleteTarget}
        staffId={deleteTarget?.id}
        staffName={deleteTarget?.full_name}
        onClose={() => setDeleteTarget(null)}
        onDeleted={load}
      />
    </Layout>
  );
}
