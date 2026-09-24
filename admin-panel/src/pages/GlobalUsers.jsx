import { useEffect, useState, useCallback } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Search, Trash2, Edit2, X, ChevronLeft, ChevronRight, Smartphone, Eye, EyeOff } from 'lucide-react';

const EMPTY_EDIT = { email: '', full_name: '', phone: '', password: '' };

export default function GlobalUsers() {
  const [rows, setRows]         = useState([]);
  const [total, setTotal]       = useState(0);
  const [page, setPage]         = useState(1);
  const [q, setQ]               = useState('');
  const [loading, setLoading]   = useState(false);
  const [editUser, setEditUser] = useState(null);
  const [detailUser, setDetail] = useState(null);
  const [editForm, setEditForm] = useState(EMPTY_EDIT);
  const [saving, setSaving]     = useState(false);
  const [showPwd, setShowPwd]   = useState(false);
  const limit = 50;

  const load = useCallback(async (pg, search) => {
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
  }, []);

  useEffect(() => { load(page, q); }, [page]); // eslint-disable-line

  // debounce search
  useEffect(() => {
    const t = setTimeout(() => { setPage(1); load(1, q); }, 400);
    return () => clearTimeout(t);
  }, [q]); // eslint-disable-line

  const openEdit = (user) => {
    setEditUser(user);
    setEditForm({ email: user.email || '', full_name: user.full_name || '', phone: user.phone || '', password: '' });
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
    if (!window.confirm(`Διαγραφή χρήστη "${user.full_name}" (${user.email || user.phone}); Αυτό δεν αναιρείται.`)) return;
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
      {/* Toolbar */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20 }}>
        <div style={{ position: 'relative', flex: 1, maxWidth: 400 }}>
          <Search size={15} style={{ position: 'absolute', left: 10, top: '50%', transform: 'translateY(-50%)', color: 'var(--text-3)', pointerEvents: 'none' }} />
          <input
            className="form-input"
            placeholder="Αναζήτηση με email, όνομα ή τηλέφωνο..."
            value={q}
            onChange={e => setQ(e.target.value)}
            style={{ paddingLeft: 34 }}
          />
        </div>
        <span style={{ fontSize: 13, color: 'var(--text-2)', whiteSpace: 'nowrap' }}>
          {total} χρήστες
        </span>
      </div>

      {/* Table */}
      {loading ? (
        <div style={{ padding: 40, textAlign: 'center', color: 'var(--text-3)' }}>Φόρτωση...</div>
      ) : rows.length === 0 ? (
        <div style={{ padding: 40, textAlign: 'center', color: 'var(--text-3)' }}>Δεν βρέθηκαν χρήστες</div>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Όνομα</th>
                <th>Email</th>
                <th>Τηλέφωνο</th>
                <th>Γυμναστήρια</th>
                <th>Εγγραφή</th>
                <th style={{ width: 110 }}></th>
              </tr>
            </thead>
            <tbody>
              {rows.map(u => (
                <tr key={u.id}>
                  <td>
                    <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                      <Smartphone size={13} style={{ color: 'var(--accent)', flexShrink: 0 }} />
                      <strong>{u.full_name}</strong>
                    </span>
                  </td>
                  <td style={{ color: 'var(--text-2)' }}>{u.email || <span style={{ color: 'var(--text-3)' }}>—</span>}</td>
                  <td style={{ color: 'var(--text-2)' }}>{u.phone || <span style={{ color: 'var(--text-3)' }}>—</span>}</td>
                  <td>
                    <span className={`badge ${u.linked_gyms_count > 0 ? 'badge-green' : 'badge-gray'}`}>
                      {u.linked_gyms_count} γυμν.
                    </span>
                  </td>
                  <td style={{ color: 'var(--text-3)', fontSize: 12 }}>
                    {new Date(u.created_at).toLocaleDateString('el-GR')}
                  </td>
                  <td>
                    <div style={{ display: 'flex', gap: 4 }}>
                      <button className="btn btn-secondary btn-sm" title="Λεπτομέρειες" onClick={() => openDetail(u)}>
                        <Eye size={13} />
                      </button>
                      <button className="btn btn-secondary btn-sm" title="Επεξεργασία" onClick={() => openEdit(u)}>
                        <Edit2 size={13} />
                      </button>
                      <button className="btn btn-danger btn-sm" title="Διαγραφή" onClick={() => handleDelete(u)}>
                        <Trash2 size={13} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Pagination */}
      {pages > 1 && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 16, justifyContent: 'center' }}>
          <button className="btn btn-secondary btn-sm" disabled={page <= 1} onClick={() => setPage(p => p - 1)}>
            <ChevronLeft size={15} />
          </button>
          <span style={{ fontSize: 13, color: 'var(--text-2)' }}>Σελίδα {page} / {pages}</span>
          <button className="btn btn-secondary btn-sm" disabled={page >= pages} onClick={() => setPage(p => p + 1)}>
            <ChevronRight size={15} />
          </button>
        </div>
      )}

      {/* Edit Modal */}
      {editUser && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setEditUser(null)}>
          <div className="modal" style={{ maxWidth: 480 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
              <div className="modal-title" style={{ margin: 0 }}>Επεξεργασία Χρήστη</div>
              <button className="btn btn-secondary btn-sm" onClick={() => setEditUser(null)} style={{ padding: '4px 8px' }}>
                <X size={16} />
              </button>
            </div>
            <form onSubmit={handleSave}>
              <div className="form-group">
                <label className="form-label">Ονοματεπώνυμο</label>
                <input className="form-input" value={editForm.full_name}
                  onChange={e => setEditForm(f => ({ ...f, full_name: e.target.value }))} />
              </div>
              <div className="form-group">
                <label className="form-label">Email</label>
                <input className="form-input" type="email" value={editForm.email}
                  onChange={e => setEditForm(f => ({ ...f, email: e.target.value }))} />
              </div>
              <div className="form-group">
                <label className="form-label">Τηλέφωνο</label>
                <input className="form-input" value={editForm.phone}
                  onChange={e => setEditForm(f => ({ ...f, phone: e.target.value }))} />
              </div>
              <div className="form-group">
                <label className="form-label">
                  Νέος Κωδικός{' '}
                  <span style={{ fontWeight: 400, color: 'var(--text-3)' }}>(αφήστε κενό αν δεν αλλάζει)</span>
                </label>
                <div style={{ position: 'relative' }}>
                  <input
                    className="form-input"
                    type={showPwd ? 'text' : 'password'}
                    placeholder="Νέος κωδικός..."
                    value={editForm.password}
                    onChange={e => setEditForm(f => ({ ...f, password: e.target.value }))}
                    style={{ paddingRight: 36 }}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPwd(v => !v)}
                    style={{ position: 'absolute', right: 10, top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-3)', padding: 0 }}
                  >
                    {showPwd ? <EyeOff size={15} /> : <Eye size={15} />}
                  </button>
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

      {/* Detail Modal */}
      {detailUser && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setDetail(null)}>
          <div className="modal" style={{ maxWidth: 560 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
              <div className="modal-title" style={{ margin: 0 }}>
                <Smartphone size={16} style={{ color: 'var(--accent)', marginRight: 8, verticalAlign: 'middle' }} />
                {detailUser.user.full_name}
              </div>
              <button className="btn btn-secondary btn-sm" onClick={() => setDetail(null)} style={{ padding: '4px 8px' }}>
                <X size={16} />
              </button>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px 20px', marginBottom: 24, background: 'var(--surface-2)', borderRadius: 10, padding: 16 }}>
              <div>
                <div style={{ fontSize: 11, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600 }}>Email</div>
                <div style={{ marginTop: 3 }}>{detailUser.user.email || <span style={{ color: 'var(--text-3)' }}>—</span>}</div>
              </div>
              <div>
                <div style={{ fontSize: 11, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600 }}>Τηλέφωνο</div>
                <div style={{ marginTop: 3 }}>{detailUser.user.phone || <span style={{ color: 'var(--text-3)' }}>—</span>}</div>
              </div>
              <div style={{ gridColumn: '1 / -1' }}>
                <div style={{ fontSize: 11, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600 }}>ID</div>
                <div style={{ marginTop: 3, fontSize: 11, fontFamily: 'monospace', color: 'var(--text-2)' }}>{detailUser.user.id}</div>
              </div>
              <div>
                <div style={{ fontSize: 11, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600 }}>Εγγραφή</div>
                <div style={{ marginTop: 3, fontSize: 13 }}>{new Date(detailUser.user.created_at).toLocaleString('el-GR')}</div>
              </div>
            </div>

            <div style={{ fontWeight: 700, marginBottom: 10 }}>
              Συνδεδεμένα Γυμναστήρια ({(detailUser.linkedGyms || []).length})
            </div>
            {(detailUser.linkedGyms || []).length === 0 ? (
              <p style={{ color: 'var(--text-3)', fontSize: 13, marginBottom: 16 }}>Δεν έχει συνδεθεί με κάποιο γυμναστήριο.</p>
            ) : (
              <div className="table-wrap" style={{ marginBottom: 16 }}>
                <table style={{ fontSize: 13 }}>
                  <thead>
                    <tr><th>Γυμναστήριο</th><th>Status</th><th>Σύνδεση</th></tr>
                  </thead>
                  <tbody>
                    {(detailUser.linkedGyms || []).map(g => (
                      <tr key={g.user_id}>
                        <td>{g.business_name}</td>
                        <td><span className="badge badge-green">Συνδεδεμένο</span></td>
                        <td style={{ color: 'var(--text-3)' }}>{new Date(g.linked_at).toLocaleDateString('el-GR')}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            {(detailUser.joinRequests || []).length > 0 && (
              <>
                <div style={{ fontWeight: 700, marginBottom: 10 }}>Εκκρεμή αιτήματα ({detailUser.joinRequests.length})</div>
                <div className="table-wrap">
                  <table style={{ fontSize: 13 }}>
                    <thead>
                      <tr><th>Γυμναστήριο</th><th>Status</th><th>Ημ/νία</th></tr>
                    </thead>
                    <tbody>
                      {detailUser.joinRequests.map(g => (
                        <tr key={g.id}>
                          <td>{g.business_name}</td>
                          <td>
                            <span className={`badge ${g.status === 'pending' ? 'badge-yellow' : 'badge-gray'}`}>
                              {g.status === 'pending' ? 'Εκκρεμεί' : 'Απορρίφθηκε'}
                            </span>
                          </td>
                          <td style={{ color: 'var(--text-3)' }}>{new Date(g.requested_at).toLocaleDateString('el-GR')}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </>
            )}

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
