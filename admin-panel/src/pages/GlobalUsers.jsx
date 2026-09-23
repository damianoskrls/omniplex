import { useEffect, useState, useCallback } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Search, Trash2, Edit2, X, ChevronLeft, ChevronRight, Smartphone, Eye, EyeOff } from 'lucide-react';

const EMPTY_EDIT = { email: '', full_name: '', phone: '', password: '' };

export default function GlobalUsers() {
  const [rows, setRows]           = useState([]);
  const [total, setTotal]         = useState(0);
  const [page, setPage]           = useState(1);
  const [q, setQ]                 = useState('');
  const [loading, setLoading]     = useState(false);
  const [editUser, setEditUser]   = useState(null); // { id, ...fields }
  const [detailUser, setDetail]   = useState(null); // full detail modal
  const [editForm, setEditForm]   = useState(EMPTY_EDIT);
  const [saving, setSaving]       = useState(false);
  const [showPwd, setShowPwd]     = useState(false);
  const limit = 50;

  const load = useCallback(async (pg = page, search = q) => {
    setLoading(true);
    try {
      const r = await api.get('/tenants/global-users', { params: { page: pg, limit, q: search } });
      setRows(r.data.rows);
      setTotal(r.data.total);
    } catch {
      toast.error('Σφάλμα φόρτωσης χρηστών');
    } finally {
      setLoading(false);
    }
  }, [page, q]);

  useEffect(() => { load(page, q); }, [page]); // eslint-disable-line

  // debounce search
  useEffect(() => {
    const t = setTimeout(() => { setPage(1); load(1, q); }, 400);
    return () => clearTimeout(t);
  }, [q]); // eslint-disable-line

  const openEdit = (user) => {
    setEditUser(user);
    setEditForm({ email: user.email, full_name: user.full_name, phone: user.phone || '', password: '' });
    setShowPwd(false);
  };

  const openDetail = async (user) => {
    try {
      const r = await api.get(`/tenants/global-users/${user.id}`);
      setDetail(r.data);
    } catch { toast.error('Σφάλμα'); }
  };

  const handleSave = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      const body = { ...editForm };
      if (!body.password) delete body.password;
      await api.put(`/tenants/global-users/${editUser.id}`, body);
      toast.success('Ο χρήστης ενημερώθηκε');
      setEditUser(null);
      load(page, q);
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally { setSaving(false); }
  };

  const handleDelete = async (user) => {
    if (!window.confirm(`Διαγραφή χρήστη "${user.full_name}" (${user.email}); Αυτό δεν αναιρείται.`)) return;
    try {
      await api.delete(`/tenants/global-users/${user.id}`);
      toast.success('Χρήστης διαγράφηκε');
      load(page, q);
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const pages = Math.ceil(total / limit);

  return (
    <Layout title="OmniPlex Χρήστες">
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20 }}>
        <div style={{ position: 'relative', flex: 1, maxWidth: 400 }}>
          <Search size={16} style={{ position: 'absolute', left: 10, top: '50%', transform: 'translateY(-50%)', color: '#9ca3af', pointerEvents: 'none' }} />
          <input
            className="form-control"
            placeholder="Αναζήτηση με email, όνομα ή τηλέφωνο..."
            value={q}
            onChange={e => setQ(e.target.value)}
            style={{ paddingLeft: 34 }}
          />
        </div>
        <span className="text-muted" style={{ fontSize: 13, whiteSpace: 'nowrap' }}>
          {total} χρήστες
        </span>
      </div>

      {loading ? (
        <div className="text-muted" style={{ padding: 32, textAlign: 'center' }}>Φόρτωση...</div>
      ) : rows.length === 0 ? (
        <div className="text-muted" style={{ padding: 32, textAlign: 'center' }}>Δεν βρέθηκαν χρήστες</div>
      ) : (
        <div className="table-responsive">
          <table className="table">
            <thead>
              <tr>
                <th>Όνομα</th>
                <th>Email</th>
                <th>Τηλέφωνο</th>
                <th>Γυμναστήρια</th>
                <th>Εγγραφή</th>
                <th style={{ width: 100 }}></th>
              </tr>
            </thead>
            <tbody>
              {rows.map(u => (
                <tr key={u.id}>
                  <td>
                    <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                      <Smartphone size={14} style={{ color: '#6366f1', flexShrink: 0 }} />
                      <strong>{u.full_name}</strong>
                    </span>
                  </td>
                  <td>{u.email}</td>
                  <td>{u.phone || <span className="text-muted">—</span>}</td>
                  <td>
                    <span className={`badge ${u.linked_gyms_count > 0 ? 'badge-success' : 'badge-secondary'}`}>
                      {u.linked_gyms_count} γυμν.
                    </span>
                  </td>
                  <td className="text-muted" style={{ fontSize: 12 }}>
                    {new Date(u.created_at).toLocaleDateString('el-GR')}
                  </td>
                  <td>
                    <div style={{ display: 'flex', gap: 4 }}>
                      <button className="btn btn-secondary btn-sm" title="Λεπτομέρειες" onClick={() => openDetail(u)}>
                        <Eye size={14} />
                      </button>
                      <button className="btn btn-secondary btn-sm" title="Επεξεργασία" onClick={() => openEdit(u)}>
                        <Edit2 size={14} />
                      </button>
                      <button className="btn btn-danger btn-sm" title="Διαγραφή" onClick={() => handleDelete(u)}>
                        <Trash2 size={14} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {pages > 1 && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 16, justifyContent: 'center' }}>
          <button className="btn btn-secondary btn-sm" disabled={page <= 1} onClick={() => setPage(p => p - 1)}>
            <ChevronLeft size={16} />
          </button>
          <span className="text-muted" style={{ fontSize: 13 }}>Σελίδα {page} / {pages}</span>
          <button className="btn btn-secondary btn-sm" disabled={page >= pages} onClick={() => setPage(p => p + 1)}>
            <ChevronRight size={16} />
          </button>
        </div>
      )}

      {/* Edit modal */}
      {editUser && (
        <div className="modal-overlay" onClick={() => setEditUser(null)}>
          <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 480 }}>
            <div className="modal-header">
              <h3>Επεξεργασία Χρήστη</h3>
              <button className="modal-close" onClick={() => setEditUser(null)}><X size={20} /></button>
            </div>
            <form onSubmit={handleSave}>
              <div className="modal-body">
                <div className="form-group">
                  <label>Ονοματεπώνυμο</label>
                  <input className="form-control" value={editForm.full_name}
                    onChange={e => setEditForm(f => ({ ...f, full_name: e.target.value }))} />
                </div>
                <div className="form-group">
                  <label>Email</label>
                  <input className="form-control" type="email" value={editForm.email}
                    onChange={e => setEditForm(f => ({ ...f, email: e.target.value }))} />
                </div>
                <div className="form-group">
                  <label>Τηλέφωνο</label>
                  <input className="form-control" value={editForm.phone}
                    onChange={e => setEditForm(f => ({ ...f, phone: e.target.value }))} />
                </div>
                <div className="form-group">
                  <label>Νέος Κωδικός <span className="text-muted" style={{ fontWeight: 400 }}>(αφήστε κενό αν δεν αλλάζει)</span></label>
                  <div style={{ position: 'relative' }}>
                    <input
                      className="form-control"
                      type={showPwd ? 'text' : 'password'}
                      placeholder="Νέος κωδικός..."
                      value={editForm.password}
                      onChange={e => setEditForm(f => ({ ...f, password: e.target.value }))}
                      style={{ paddingRight: 36 }}
                    />
                    <button type="button" style={{ position: 'absolute', right: 8, top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', cursor: 'pointer', color: '#9ca3af' }}
                      onClick={() => setShowPwd(v => !v)}>
                      {showPwd ? <EyeOff size={16} /> : <Eye size={16} />}
                    </button>
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setEditUser(null)}>Ακύρωση</button>
                <button type="submit" className="btn btn-primary" disabled={saving}>
                  {saving ? 'Αποθήκευση...' : 'Αποθήκευση'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Detail modal */}
      {detailUser && (
        <div className="modal-overlay" onClick={() => setDetail(null)}>
          <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 560 }}>
            <div className="modal-header">
              <h3>Χρήστης: {detailUser.user.full_name}</h3>
              <button className="modal-close" onClick={() => setDetail(null)}><X size={20} /></button>
            </div>
            <div className="modal-body">
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px 16px', marginBottom: 20 }}>
                <div><span className="text-muted" style={{ fontSize: 12 }}>Email</span><div>{detailUser.user.email}</div></div>
                <div><span className="text-muted" style={{ fontSize: 12 }}>Τηλέφωνο</span><div>{detailUser.user.phone || '—'}</div></div>
                <div><span className="text-muted" style={{ fontSize: 12 }}>ID</span><div style={{ fontSize: 11, fontFamily: 'monospace' }}>{detailUser.user.id}</div></div>
                <div><span className="text-muted" style={{ fontSize: 12 }}>Εγγραφή</span><div>{new Date(detailUser.user.created_at).toLocaleString('el-GR')}</div></div>
              </div>

              <h4 style={{ marginBottom: 8 }}>Γυμναστήρια ({detailUser.gyms.length})</h4>
              {detailUser.gyms.length === 0 ? (
                <p className="text-muted">Δεν έχει συνδεθεί με κάποιο γυμναστήριο.</p>
              ) : (
                <table className="table" style={{ fontSize: 13 }}>
                  <thead>
                    <tr><th>Γυμναστήριο</th><th>Status</th><th>Ημ/νία</th></tr>
                  </thead>
                  <tbody>
                    {detailUser.gyms.map(g => (
                      <tr key={g.id}>
                        <td>{g.business_name}</td>
                        <td>
                          <span className={`badge ${g.status === 'approved' ? 'badge-success' : g.status === 'pending' ? 'badge-warning' : 'badge-secondary'}`}>
                            {g.status === 'approved' ? 'Εγκεκριμένο' : g.status === 'pending' ? 'Εκκρεμεί' : 'Απορρίφθηκε'}
                          </span>
                        </td>
                        <td className="text-muted">{new Date(g.requested_at).toLocaleDateString('el-GR')}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setDetail(null)}>Κλείσιμο</button>
              <button className="btn btn-primary" onClick={() => { setDetail(null); openEdit(detailUser.user); }}>
                <Edit2 size={14} /> Επεξεργασία
              </button>
            </div>
          </div>
        </div>
      )}
    </Layout>
  );
}
