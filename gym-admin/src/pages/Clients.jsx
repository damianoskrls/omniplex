import { useEffect, useState, useRef } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Plus, Eye, Check, Ban, RotateCcw, Trash2, Search, UserCheck, AlertTriangle } from 'lucide-react';

const FITNESS_GOALS = [
  { id: '', label: '— Δεν έχει οριστεί —' },
  { id: 'weight_loss', label: 'Απώλεια βάρους' },
  { id: 'strength', label: 'Ενδυνάμωση' },
  { id: 'endurance', label: 'Αντοχή' },
  { id: 'flexibility', label: 'Ευλυγισία' },
  { id: 'rehabilitation', label: 'Αποκατάσταση' },
  { id: 'general', label: 'Γενική φυσική κατάσταση' },
];

const STATUS_FILTERS = [
  { id: '', label: 'Όλοι' },
  { id: 'pending', label: 'Εκκρεμείς' },
  { id: 'active', label: 'Ενεργοί' },
  { id: 'suspended', label: 'Απενεργοποιημένοι' },
  { id: 'trash', label: 'Κάδος' },
];

const STATUS_BADGE = {
  pending: 'badge-yellow',
  active: 'badge-green',
  suspended: 'badge-red',
  deleted: 'badge-gray',
};

const EMPTY = {
  full_name: '',
  phone: '',
  pin: '',
  email: '',
  date_of_birth: '',
  weight_kg: '',
  fitness_goal: '',
  trainer_notes: '',
};

export default function Clients() {
  const [clients, setClients] = useState([]);
  const [pendingTotal, setPendingTotal] = useState(0);
  const [statusFilter, setStatusFilter] = useState('');
  const [modal, setModal] = useState(false);
  const [form, setForm] = useState(EMPTY);
  const [saving, setSaving] = useState(false);
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();

  // Phone lookup state
  const [lookupPhone, setLookupPhone] = useState('');
  const [lookupResult, setLookupResult] = useState(null); // null | { status, ... }
  const [lookupLoading, setLookupLoading] = useState(false);
  const [claimedName, setClaimedName] = useState('');
  const [nameVerified, setNameVerified] = useState(false);
  const [nameChecking, setNameChecking] = useState(false);
  const lookupTimer = useRef(null);
  const nameTimer = useRef(null);

  const inTrash = statusFilter === 'trash';

  const load = async () => {
    const params = inTrash ? { view: 'trash' } : (statusFilter ? { status: statusFilter } : {});
    try {
      const [clientsRes, dashRes] = await Promise.all([
        api.get('/client-admin/clients', { params }),
        inTrash ? Promise.resolve({ data: {} }) : api.get('/client-admin/dashboard'),
      ]);
      setClients(clientsRes.data);
      if (!inTrash) setPendingTotal(dashRes.data.pending_clients || 0);
    } catch {
      /* ignore */
    }
  };

  useEffect(() => { load(); }, [statusFilter]);

  useEffect(() => {
    const f = searchParams.get('status');
    if (f && STATUS_FILTERS.some(s => s.id === f)) setStatusFilter(f);
  }, []);

  const setFilter = (id) => {
    setStatusFilter(id);
    if (id) setSearchParams({ status: id });
    else setSearchParams({});
  };

  const moveToTrash = async (userId, name) => {
    if (!window.confirm(`Μεταφορά του ${name} στον κάδο;\n\nΟ πελάτης δεν θα εμφανίζεται στη λίστα και δεν θα μπορεί να συνδεθεί. Τα ιστορικά (κρατήσεις, πακέτα) διατηρούνται.`)) return;
    try {
      await api.delete(`/client-admin/clients/${userId}`);
      toast.success('Ο πελάτης μεταφέρθηκε στον κάδο');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const restoreClient = async (userId, name) => {
    try {
      await api.post(`/client-admin/clients/${userId}/restore`);
      toast.success(`Ο πελάτης ${name} επανήλθε`);
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const permanentDelete = async (userId, name) => {
    if (!window.confirm(`ΟΡΙΣΤΙΚΗ διαγραφή του ${name};\n\nΘα διαγραφούν όλα τα δεδομένα (κρατήσεις, πακέτα, πληρωμές). Δεν αναιρείται.`)) return;
    try {
      await api.delete(`/client-admin/clients/${userId}/permanent`);
      toast.success('Ο πελάτης διαγράφηκε οριστικά');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const updateStatus = async (userId, status) => {
    const labels = { active: 'εγκρίθηκε', suspended: 'απενεργοποιήθηκε', pending: 'επανήλθε σε αναμονή' };
    try {
      await api.patch(`/client-admin/clients/${userId}/status`, { status });
      toast.success(`Ο πελάτης ${labels[status]}`);
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const approveClient = async (userId, name) => {
    try {
      await api.post(`/client-admin/clients/${userId}/approve`);
      toast.success(`✓ Ο ${name} εγκρίθηκε — στάλθηκε SMS`);
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const rejectClient = async (userId, name) => {
    if (!window.confirm(`Απόρριψη αίτησης του ${name};\nΟ χρήστης θα ενημερωθεί με SMS.`)) return;
    try {
      await api.post(`/client-admin/clients/${userId}/reject`);
      toast.success(`Η αίτηση του ${name} απορρίφθηκε`);
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const openModal = () => {
    setModal(true);
    setLookupPhone('');
    setLookupResult(null);
    setClaimedName('');
    setNameVerified(false);
    setNameChecking(false);
    setForm(EMPTY);
  };

  const handleLookupPhone = (value) => {
    setLookupPhone(value);
    setLookupResult(null);
    clearTimeout(lookupTimer.current);
    const digits = value.replace(/\D/g, '');
    if (digits.length < 7) return;
    lookupTimer.current = setTimeout(async () => {
      setLookupLoading(true);
      try {
        const res = await api.get('/client-admin/clients/lookup', { params: { phone: value } });
        setLookupResult(res.data);
        if (res.data.status === 'has_request') {
          const gu = res.data.global_user;
          if (gu) setForm(f => ({ ...f, full_name: gu.full_name || '', email: gu.email || '', phone: gu.phone || value }));
        } else if (res.data.status === 'not_found') {
          setForm(f => ({ ...f, phone: f.phone || value }));
        }
      } catch (e) {
        const msg = e.response?.data?.error || e.message || 'Σφάλμα αναζήτησης';
        setLookupResult({ status: 'error', message: msg });
      }
      setLookupLoading(false);
    }, 600);
  };

  const handleClaimedNameChange = (value) => {
    setClaimedName(value);
    setNameVerified(false);
    clearTimeout(nameTimer.current);
    const guId = lookupResult?.global_user?.id;
    if (!value.trim() || !guId) return;
    nameTimer.current = setTimeout(async () => {
      setNameChecking(true);
      try {
        const res = await api.get('/client-admin/clients/verify-name', {
          params: { global_user_id: guId, claimed_name: value.trim() },
        });
        setNameVerified(!!res.data.match);
      } catch { setNameVerified(false); }
      setNameChecking(false);
    }, 400);
  };

  const handleAddGlobal = async (guId, name, skipNameCheck = false) => {
    const id = guId || lookupResult?.global_user?.id;
    const nm = name || claimedName;
    if (!id) return;
    setSaving(true);
    try {
      const payload = skipNameCheck
        ? { global_user_id: id, skip_name_check: true }
        : { global_user_id: id, claimed_name: nm };
      await api.post('/client-admin/clients/add-global', payload);
      toast.success('Ο πελάτης προστέθηκε ενεργός');
      setModal(false);
      load();
    } catch (err) {
      toast.error(err.response?.data?.message || err.response?.data?.error || 'Σφάλμα');
    } finally { setSaving(false); }
  };

  const handleInviteGlobal = async () => {
    const guId = lookupResult?.global_user?.id;
    if (!guId) return;
    setSaving(true);
    try {
      await api.post('/client-admin/clients/invite', { global_user_id: guId, claimed_name: claimedName });
      toast.success('Η πρόσκληση στάλθηκε στο OmniPlex app του πελάτη');
      setModal(false);
      load();
    } catch (err) {
      toast.error(err.response?.data?.message || err.response?.data?.error || 'Σφάλμα');
    } finally { setSaving(false); }
  };

  const handleCancelInvite = async () => {
    const guId = lookupResult?.global_user?.id;
    if (!guId) return;
    setSaving(true);
    try {
      await api.delete('/client-admin/clients/cancel-invite', { data: { global_user_id: guId } });
      toast.success('Το αίτημα ακυρώθηκε');
      setLookupResult(null);
      setLookupPhone('');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally { setSaving(false); }
  };

  const handleCreate = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      await api.post('/client-admin/clients', {
        full_name: form.full_name,
        phone: form.phone,
        pin: form.pin || undefined,
        email: form.email || undefined,
        date_of_birth: form.date_of_birth || undefined,
        weight_kg: form.weight_kg !== '' ? Number(form.weight_kg) : undefined,
        fitness_goal: form.fitness_goal || undefined,
        trainer_notes: form.trainer_notes || undefined,
      });
      toast.success('Ο πελάτης δημιουργήθηκε (ενεργός αμέσως)');
      setModal(false);
      setForm(EMPTY);
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Layout title="Πελάτες">
      <div className="page-header">
        <h1 className="page-title">Πελάτες ({clients.length})</h1>
        <button className="btn btn-primary" onClick={openModal}>
          <Plus size={16} /> Νέος πελάτης
        </button>
      </div>

      <div className="bk-group-tabs" style={{ marginBottom: 16 }}>
        {STATUS_FILTERS.map(f => (
          <button
            key={f.id || 'all'}
            type="button"
            className={`bk-group-tab ${statusFilter === f.id ? 'active' : ''}`}
            onClick={() => setFilter(f.id)}
          >
            {f.label}
            {f.id === 'pending' && pendingTotal > 0 && statusFilter !== 'pending' && (
              <span className="badge badge-yellow" style={{ marginLeft: 4 }}>{pendingTotal}</span>
            )}
          </button>
        ))}
      </div>

      {inTrash && (
        <div className="card" style={{ marginBottom: 16 }}>
          <strong>Κάδος πελατών</strong>
          <div className="text-muted" style={{ marginTop: 4 }}>
            Οι πελάτες εδώ δεν εμφανίζονται στη λίστα και δεν μπορούν να συνδεθούν. Μπορείς να τους επαναφέρεις ή να τους διαγράψεις οριστικά.
          </div>
        </div>
      )}

      {statusFilter === 'pending' && clients.length > 0 && (
        <div className="card" style={{ marginBottom: 16, background: 'var(--warning-dim)', borderColor: 'rgba(255,178,36,0.25)' }}>
          <strong>Εκκρεμείς εγγραφές από την εφαρμογή</strong>
          <div className="text-muted" style={{ marginTop: 4 }}>
            Οι πελάτες δεν μπορούν να συνδεθούν μέχρι να πατήσεις «Έγκριση».
          </div>
        </div>
      )}

      <div className="card">
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Όνομα</th>
                <th>Email</th>
                <th>Τηλέφωνο</th>
                <th>Κατάσταση</th>
                {!inTrash && <th>Στόχος</th>}
                {inTrash && <th>Διαγράφηκε</th>}
                <th>Κρατήσεις</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {clients.map(c => {
                const st = c.account_status || 'active';
                const deletedAt = c.deleted_at
                  ? new Date(c.deleted_at).toLocaleString('el-GR', {
                    day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit',
                  })
                  : '—';
                return (
                  <tr key={c.id}>
                    <td>
                      <div style={{ fontWeight: 600 }}>{c.full_name}</div>
                      {!inTrash && c.birthday_today && (
                        <span style={{ fontSize: '0.75rem', color: '#16a34a' }}>Γενέθλια σήμερα</span>
                      )}
                    </td>
                    <td>{c.email}</td>
                    <td>{c.phone || '—'}</td>
                    <td>
                      <span className={`badge ${STATUS_BADGE[st] || 'badge-gray'}`}>
                        {c.account_status_label || st}
                      </span>
                    </td>
                    {!inTrash && <td>{c.fitness_goal_label || '—'}</td>}
                    {inTrash && <td className="text-muted" style={{ fontSize: '0.85rem' }}>{deletedAt}</td>}
                    <td>{c.total_bookings}</td>
                    <td>
                      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                        {inTrash ? (
                          <>
                            <button
                              className="btn btn-primary btn-sm"
                              title="Επαναφορά"
                              onClick={() => restoreClient(c.id, c.full_name)}
                            >
                              <RotateCcw size={14} />
                            </button>
                            <button
                              className="btn btn-danger btn-sm"
                              title="Οριστική διαγραφή"
                              onClick={() => permanentDelete(c.id, c.full_name)}
                            >
                              <Trash2 size={14} />
                            </button>
                            <button className="btn btn-secondary btn-sm" onClick={() => navigate(`/clients/${c.id}`)}>
                              <Eye size={14} />
                            </button>
                          </>
                        ) : (
                          <>
                        {st === 'pending' && (
                          <>
                            <button
                              className="btn btn-primary btn-sm"
                              title="Έγκριση + SMS"
                              onClick={() => approveClient(c.id, c.full_name)}
                            >
                              <Check size={14} /> Έγκριση
                            </button>
                            <button
                              className="btn btn-danger btn-sm"
                              title="Απόρριψη + SMS"
                              onClick={() => rejectClient(c.id, c.full_name)}
                            >
                              <Ban size={14} /> Απόρριψη
                            </button>
                          </>
                        )}
                        {st === 'active' && (
                          <button
                            className="btn btn-danger btn-sm"
                            title="Απενεργοποίηση"
                            onClick={() => {
                              if (window.confirm(`Απενεργοποίηση του ${c.full_name};`)) {
                                updateStatus(c.id, 'suspended');
                              }
                            }}
                          >
                            <Ban size={14} />
                          </button>
                        )}
                        {st === 'suspended' && (
                          <button
                            className="btn btn-secondary btn-sm"
                            title="Επανενεργοποίηση"
                            onClick={() => updateStatus(c.id, 'active')}
                          >
                            <RotateCcw size={14} />
                          </button>
                        )}
                        <button className="btn btn-secondary btn-sm" onClick={() => navigate(`/clients/${c.id}`)}>
                          <Eye size={14} />
                        </button>
                        <button
                          className="btn btn-danger btn-sm"
                          title="Μεταφορά στον κάδο"
                          onClick={() => moveToTrash(c.id, c.full_name)}
                        >
                          <Trash2 size={14} />
                        </button>
                          </>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
              {!clients.length && <tr><td colSpan={inTrash ? 7 : 7} className="loading">{inTrash ? 'Ο κάδος είναι άδειος' : 'Δεν υπάρχουν πελάτες'}</td></tr>}
            </tbody>
          </table>
        </div>
      </div>

      {modal && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setModal(false)}>
          <div className="modal" style={{ maxWidth: 520 }}>
            <div className="modal-title">Νέος πελάτης</div>

            {/* ── Step 1: Phone lookup ── */}
            <div className="form-group" style={{ marginBottom: 8 }}>
              <label className="form-label">Αναζήτηση με κινητό</label>
              <div style={{ position: 'relative' }}>
                <Search size={15} style={{ position: 'absolute', left: 10, top: '50%', transform: 'translateY(-50%)', color: '#94a3b8', pointerEvents: 'none' }} />
                <input
                  className="form-input"
                  type="tel"
                  placeholder="Πληκτρολόγησε κινητό για αναζήτηση..."
                  value={lookupPhone}
                  onChange={e => handleLookupPhone(e.target.value)}
                  autoFocus
                  style={{ paddingLeft: 34, paddingRight: 36 }}
                />
                {lookupLoading && (
                  <span style={{ position: 'absolute', right: 10, top: '50%', transform: 'translateY(-50%)', color: '#94a3b8', fontSize: '0.75rem' }}>…</span>
                )}
              </div>
            </div>

            {/* ── Lookup result banners ── */}
            {lookupResult?.status === 'error' && (
              <div style={{ background: 'var(--danger-dim, #fef2f2)', border: '1px solid rgba(239,68,68,0.3)', borderRadius: 10, padding: '12px 14px', marginBottom: 16 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontWeight: 600, color: '#dc2626' }}>
                  <AlertTriangle size={15} /> Σφάλμα αναζήτησης
                </div>
                <div className="text-muted" style={{ marginTop: 4, fontSize: '0.85rem' }}>{lookupResult.message}</div>
              </div>
            )}
            {lookupResult?.status === 'in_this_gym' && (
              <div style={{ background: 'var(--warning-dim, #fef9ec)', border: '1px solid rgba(255,178,36,0.3)', borderRadius: 10, padding: '12px 14px', marginBottom: 16 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontWeight: 600, color: '#b45309' }}>
                  <AlertTriangle size={15} /> Ο πελάτης είναι ήδη εγγεγραμμένος στο γυμναστήριό σου
                </div>
                <div className="text-muted" style={{ marginTop: 4, fontSize: '0.85rem' }}>
                  {lookupResult.user?.full_name} — {lookupResult.user?.phone}
                </div>
                <button
                  type="button"
                  className="btn btn-secondary"
                  style={{ marginTop: 8, fontSize: '0.85rem' }}
                  onClick={() => { setModal(false); navigate(`/clients/${lookupResult.user.id}`); }}
                >
                  Άνοιγμα προφίλ
                </button>
              </div>
            )}

            {lookupResult?.status === 'has_request' && (
              <div style={{ background: '#f0fdf4', border: '1px solid rgba(34,197,94,0.3)', borderRadius: 10, padding: '14px 16px', marginBottom: 16 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontWeight: 600, color: '#16a34a', marginBottom: 6 }}>
                  <UserCheck size={15} /> Υπάρχει εκκρεμές αίτημα εγγραφής για το γυμναστήριό σου
                </div>
                <div className="text-muted" style={{ marginBottom: 12, fontSize: '0.85rem' }}>
                  Ο πελάτης <strong>{lookupResult.global_user?.full_name || lookupResult.global_user?.masked_name}</strong> έχει στείλει αίτημα.
                  Μπορείς να τον προσθέσεις άμεσα ή να ακυρώσεις το αίτημα.
                </div>
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                  <button
                    type="button"
                    className="btn btn-primary"
                    style={{ fontSize: '0.85rem' }}
                    disabled={saving}
                    onClick={() => handleAddGlobal(lookupResult.global_user?.id, null, true)}
                  >
                    Προσθήκη ως πελάτης
                  </button>
                  <button
                    type="button"
                    className="btn btn-secondary"
                    style={{ fontSize: '0.85rem', color: '#dc2626', borderColor: '#dc2626' }}
                    disabled={saving}
                    onClick={handleCancelInvite}
                  >
                    Ακύρωση αιτήματος
                  </button>
                </div>
              </div>
            )}

            {lookupResult?.status === 'global_user_elsewhere' && (
              <div style={{ background: '#eff6ff', border: '1px solid rgba(59,130,246,0.3)', borderRadius: 10, padding: '14px 16px', marginBottom: 16 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontWeight: 600, color: '#1d4ed8', marginBottom: 6 }}>
                  <AlertTriangle size={15} /> Υπάρχει ήδη λογαριασμός με αυτό το κινητό στο OmniPlex
                </div>
                <div style={{ fontSize: '0.875rem', color: '#374151', marginBottom: 12 }}>
                  Ανήκει σε{' '}
                  <strong style={{ fontFamily: 'monospace', letterSpacing: 1 }}>
                    {lookupResult.global_user?.masked_name}
                  </strong>.
                  <div style={{ marginTop: 6, color: '#6b7280', fontSize: '0.8rem' }}>
                    Για λόγους GDPR εμφανίζεται μόνο η αρχή κάθε ονόματος. Πληκτρολόγησε το πλήρες ονοματεπώνυμο για ταυτοποίηση.
                  </div>
                </div>
                <div className="form-group" style={{ marginBottom: 12 }}>
                  <label className="form-label">Πλήρες ονοματεπώνυμο πελάτη</label>
                  <div style={{ position: 'relative' }}>
                    <input
                      className="form-input"
                      placeholder="π.χ. Δημήτρης Βακέρλης"
                      value={claimedName}
                      onChange={e => handleClaimedNameChange(e.target.value)}
                      style={{ paddingRight: 36, borderColor: nameVerified ? '#16a34a' : claimedName && !nameChecking ? '#dc2626' : undefined }}
                      autoFocus
                    />
                    <span style={{ position: 'absolute', right: 10, top: '50%', transform: 'translateY(-50%)', fontSize: '1rem', lineHeight: 1 }}>
                      {nameChecking ? <span style={{ color: '#94a3b8', fontSize: '0.75rem' }}>…</span>
                        : nameVerified ? '✓'
                        : claimedName ? <span style={{ color: '#dc2626' }}>✗</span>
                        : null}
                    </span>
                  </div>
                  {nameVerified && (
                    <div style={{ marginTop: 5, color: '#16a34a', fontSize: '0.82rem', fontWeight: 600 }}>
                      ✓ Ταυτοποιήθηκε — επίλεξε πώς να τον προσθέσεις
                    </div>
                  )}
                  {claimedName && !nameChecking && !nameVerified && (
                    <div style={{ marginTop: 5, color: '#dc2626', fontSize: '0.82rem' }}>
                      Το όνομα δεν ταυτοποιείται
                    </div>
                  )}
                </div>
                {nameVerified && (
                  <div style={{ display: 'flex', gap: 8, flexDirection: 'column' }}>
                    <button
                      type="button"
                      className="btn btn-primary"
                      style={{ fontSize: '0.9rem', width: '100%' }}
                      disabled={saving}
                      onClick={() => handleAddGlobal()}
                    >
                      {saving ? '...' : '✓ Προσθήκη ως πελάτης (άμεσα)'}
                    </button>
                    <button
                      type="button"
                      className="btn btn-secondary"
                      style={{ fontSize: '0.85rem', width: '100%' }}
                      disabled={saving}
                      onClick={handleInviteGlobal}
                    >
                      📱 Πρόσκληση μέσω OmniPlex App
                    </button>
                    <small className="text-muted" style={{ textAlign: 'center' }}>
                      Η πρόσκληση θα εμφανιστεί στο app του χρήστη — θα μπει ενεργός μόλις την αποδεχτεί.
                    </small>
                  </div>
                )}
              </div>
            )}

            {/* ── Divider before manual form ── */}
            {(lookupResult?.status === 'not_found' || !lookupResult) && (
              <p className="text-muted" style={{ marginBottom: 16, fontSize: '0.85rem' }}>
                {lookupResult?.status === 'not_found'
                  ? 'Δεν βρέθηκε στο OmniPlex — συμπλήρωσε τα στοιχεία για νέο πελάτη.'
                  : 'Ή συμπλήρωσε τα στοιχεία απευθείας για νέο πελάτη.'}
              </p>
            )}

            {/* ── New client form — hidden when phone found elsewhere ── */}
            {lookupResult?.status !== 'global_user_elsewhere' && lookupResult?.status !== 'in_this_gym' && (
              <form onSubmit={handleCreate}>
                <div className="form-group">
                  <label className="form-label">Ονοματεπώνυμο *</label>
                  <input className="form-input" value={form.full_name} onChange={e => setForm({ ...form, full_name: e.target.value })} required />
                </div>
                <div className="form-grid-2">
                  <div className="form-group">
                    <label className="form-label">Κινητό *</label>
                    <input
                      className="form-input"
                      type="tel"
                      value={form.phone !== '' ? form.phone : lookupPhone}
                      onChange={e => setForm({ ...form, phone: e.target.value })}
                      required
                      placeholder="6901234567"
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">PIN (4 ψηφία)</label>
                    <input
                      className="form-input"
                      type="text"
                      inputMode="numeric"
                      maxLength={4}
                      placeholder={form.phone ? form.phone.replace(/\D/g,'').slice(-4) || '—' : 'αυτόματο'}
                      value={form.pin || ''}
                      onChange={e => setForm({ ...form, pin: e.target.value.replace(/\D/g,'').slice(0,4) })}
                    />
                    <small className="text-muted">Κενό = τελευταία 4 ψηφία κινητού</small>
                  </div>
                </div>
                <div className="form-group">
                  <label className="form-label">Email</label>
                  <input className="form-input" type="email" value={form.email} onChange={e => setForm({ ...form, email: e.target.value })} />
                </div>
                <div className="form-grid-2">
                  <div className="form-group">
                    <label className="form-label">Ημερομηνία γέννησης</label>
                    <input className="form-input" type="date" value={form.date_of_birth} onChange={e => setForm({ ...form, date_of_birth: e.target.value })} />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Βάρος (kg)</label>
                    <input className="form-input" type="number" step="0.1" min="0" placeholder="Προαιρετικό" value={form.weight_kg} onChange={e => setForm({ ...form, weight_kg: e.target.value })} />
                  </div>
                </div>
                <div className="form-group">
                  <label className="form-label">Στόχος</label>
                  <select className="form-select" value={form.fitness_goal} onChange={e => setForm({ ...form, fitness_goal: e.target.value })}>
                    {FITNESS_GOALS.map(g => (
                      <option key={g.id || 'none'} value={g.id}>{g.label}</option>
                    ))}
                  </select>
                </div>
                <div className="form-group">
                  <label className="form-label">Σημειώσεις για γυμναστή</label>
                  <textarea
                    className="form-input"
                    rows={2}
                    placeholder="π.χ. χειρουργείο, τραυματισμός..."
                    value={form.trainer_notes}
                    onChange={e => setForm({ ...form, trainer_notes: e.target.value })}
                  />
                </div>
                <div className="modal-footer">
                  <button type="button" className="btn btn-secondary" onClick={() => setModal(false)}>Ακύρωση</button>
                  <button type="submit" className="btn btn-primary" disabled={saving}>{saving ? '...' : 'Δημιουργία'}</button>
                </div>
              </form>
            )}

            {/* Footer for blocked states */}
            {(lookupResult?.status === 'in_this_gym' || lookupResult?.status === 'global_user_elsewhere' || lookupResult?.status === 'has_request') && (
              <div className="modal-footer" style={{ justifyContent: 'flex-end' }}>
                <button type="button" className="btn btn-secondary" onClick={() => setModal(false)}>Κλείσιμο</button>
              </div>
            )}
          </div>
        </div>
      )}
    </Layout>
  );
}
