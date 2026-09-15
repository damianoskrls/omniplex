import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Plus, Eye, ToggleLeft, ToggleRight, Trash2, EyeOff } from 'lucide-react';

const BUSINESS_TYPES = [
  { value: 'gym',               label: 'Γυμναστήριο' },
  { value: 'aesthetic',         label: 'Κέντρο Αισθητικής' },
  { value: 'salon',             label: 'Κομμωτήριο' },
  { value: 'barbershop',        label: 'Barbershop' },
  { value: 'spa',               label: 'Spa / Wellness' },
  { value: 'pilates',           label: 'Pilates / Yoga' },
  { value: 'physiotherapy',     label: 'Φυσικοθεραπεία' },
  { value: 'personal_training', label: 'Personal Training' },
];

const EMPTY = {
  name: '', slug: '', business_type: 'gym', owner_email: '',
  plan: 'starter', app_name: '', bundle_id: '',
  primary_color: '#6200EE', secondary_color: '#03DAC6',
  admin_password: '',
};

export default function Tenants() {
  const [tenants, setTenants]   = useState([]);
  const [showModal, setModal]   = useState(false);
  const [form, setForm]         = useState(EMPTY);
  const [saving, setSaving]     = useState(false);
  const [showPwd, setShowPwd]   = useState(false);
  const navigate = useNavigate();

  const load = () => api.get('/tenants').then(r => setTenants(r.data)).catch(() => {});
  useEffect(() => { load(); }, []);

  // Auto-fill slug and bundle_id from name
  const handleNameChange = (val) => {
    const slug = val.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '');
    setForm(f => ({
      ...f,
      name:      val,
      slug:      slug,
      bundle_id: `com.bookup.${slug.replace(/-/g, '')}`,
      app_name:  f.app_name || val,
    }));
  };

  const handleCreate = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      await api.post('/tenants', form);
      toast.success(`${form.name} created!`);
      setModal(false);
      setForm(EMPTY);
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Error creating tenant');
    } finally {
      setSaving(false);
    }
  };

  const handleToggle = async (id, name) => {
    try {
      const r = await api.post(`/tenants/${id}/toggle-active`);
      toast.success(`${name} is now ${r.data.is_active ? 'active' : 'inactive'}`);
      load();
    } catch {
      toast.error('Could not toggle status');
    }
  };

  const handleDelete = async (id, name) => {
    if (!window.confirm(`Delete "${name}"? This cannot be undone.`)) return;
    try {
      await api.delete(`/tenants/${id}`);
      toast.success('Tenant deleted');
      load();
    } catch {
      toast.error('Could not delete tenant');
    }
  };

  return (
    <Layout title="Tenants">
      <div className="page-header">
        <h1 className="page-title">Tenants ({tenants.length})</h1>
        <button className="btn btn-primary" onClick={() => setModal(true)}>
          <Plus size={16} /> New Tenant
        </button>
      </div>

      <div className="card">
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Business</th>
                <th>Type</th>
                <th>Plan</th>
                <th>Colors</th>
                <th>Bundle ID</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {tenants.map(t => (
                <tr key={t.id}>
                  <td>
                    <div style={{ fontWeight: 600 }}>{t.name}</div>
                    <div className="text-muted">{t.slug}</div>
                  </td>
                  <td><span className="badge badge-blue">{t.business_type}</span></td>
                  <td>
                    <span className={`badge ${t.plan === 'enterprise' ? 'badge-yellow' : t.plan === 'pro' ? 'badge-blue' : 'badge-gray'}`}>
                      {t.plan}
                    </span>
                  </td>
                  <td>
                    <div className="flex items-center">
                      <span className="swatch" style={{ background: t.primary_color }} title={t.primary_color} />
                      <span className="swatch" style={{ background: t.secondary_color }} title={t.secondary_color} />
                    </div>
                  </td>
                  <td><span className="text-muted">{t.bundle_id}</span></td>
                  <td>
                    {t.is_active
                      ? <span className="badge badge-green">Active</span>
                      : <span className="badge badge-red">Inactive</span>}
                  </td>
                  <td>
                    <div className="flex gap-2">
                      <button className="btn btn-secondary btn-sm" title="View / Edit" onClick={() => navigate(`/tenants/${t.id}`)}>
                        <Eye size={14} />
                      </button>
                      <button className="btn btn-secondary btn-sm" title="Toggle active" onClick={() => handleToggle(t.id, t.name)}>
                        {t.is_active ? <ToggleRight size={14} /> : <ToggleLeft size={14} />}
                      </button>
                      <button className="btn btn-danger btn-sm" title="Delete" onClick={() => handleDelete(t.id, t.name)}>
                        <Trash2 size={14} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {!tenants.length && (
                <tr><td colSpan={7} className="loading">No tenants yet — create one!</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── Create Tenant Modal ── */}
      {showModal && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setModal(false)}>
          <div className="modal">
            <div className="modal-title">New Tenant</div>
            <form onSubmit={handleCreate}>
              <div className="form-grid-2">
                <div className="form-group">
                  <label className="form-label">Business Name *</label>
                  <input className="form-input" value={form.name} onChange={e => handleNameChange(e.target.value)} required />
                </div>
                <div className="form-group">
                  <label className="form-label">Slug *</label>
                  <input className="form-input" value={form.slug} onChange={e => setForm({ ...form, slug: e.target.value })} required />
                </div>
              </div>

              <div className="form-grid-2">
                <div className="form-group">
                  <label className="form-label">Business Type *</label>
                  <select className="form-select" value={form.business_type} onChange={e => setForm({ ...form, business_type: e.target.value })}>
                    {BUSINESS_TYPES.map(t => <option key={t.value} value={t.value}>{t.label}</option>)}
                  </select>
                </div>
                <div className="form-group">
                  <label className="form-label">Plan *</label>
                  <select className="form-select" value={form.plan} onChange={e => setForm({ ...form, plan: e.target.value })}>
                    <option value="starter">Starter</option>
                    <option value="pro">Pro</option>
                    <option value="enterprise">Enterprise</option>
                  </select>
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">Owner Email *</label>
                <input className="form-input" type="email" value={form.owner_email} onChange={e => setForm({ ...form, owner_email: e.target.value })} required />
              </div>

              <div className="form-grid-2">
                <div className="form-group">
                  <label className="form-label">App Name *</label>
                  <input className="form-input" value={form.app_name} onChange={e => setForm({ ...form, app_name: e.target.value })} required />
                </div>
                <div className="form-group">
                  <label className="form-label">Bundle ID *</label>
                  <input className="form-input" value={form.bundle_id} onChange={e => setForm({ ...form, bundle_id: e.target.value })} required />
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">Admin Password</label>
                <div style={{ position:'relative' }}>
                  <input className="form-input" type={showPwd ? 'text' : 'password'} placeholder="Αφήσε κενό για default (admin123)"
                    value={form.admin_password} onChange={e => setForm({ ...form, admin_password: e.target.value })}/>
                  <button type="button" onClick={() => setShowPwd(v => !v)} style={{ position:'absolute', right:10, top:'50%', transform:'translateY(-50%)', border:'none', background:'none', cursor:'pointer', color:'#64748b', display:'flex' }}>
                    {showPwd ? <EyeOff size={15}/> : <Eye size={15}/>}
                  </button>
                </div>
                <div className="text-muted" style={{ fontSize:'0.75rem', marginTop:4 }}>Χρησιμοποιείται για login στο gym-admin panel του πελάτη</div>
              </div>

              <div className="form-grid-2">
                <div className="form-group">
                  <label className="form-label">Primary Color</label>
                  <div className="color-row">
                    <div className="color-preview" style={{ background: form.primary_color }} />
                    <input className="form-input" type="color" value={form.primary_color} onChange={e => setForm({ ...form, primary_color: e.target.value })} style={{ height: 38, padding: 2, cursor: 'pointer' }} />
                  </div>
                </div>
                <div className="form-group">
                  <label className="form-label">Secondary Color</label>
                  <div className="color-row">
                    <div className="color-preview" style={{ background: form.secondary_color }} />
                    <input className="form-input" type="color" value={form.secondary_color} onChange={e => setForm({ ...form, secondary_color: e.target.value })} style={{ height: 38, padding: 2, cursor: 'pointer' }} />
                  </div>
                </div>
              </div>

              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setModal(false)}>Cancel</button>
                <button type="submit" className="btn btn-primary" disabled={saving}>
                  {saving ? 'Creating...' : 'Create Tenant'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </Layout>
  );
}
