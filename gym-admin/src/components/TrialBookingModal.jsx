import { useEffect, useState } from 'react';
import { FlaskConical, UserPlus, X, Check, Calendar } from 'lucide-react';
import api from '../api/client';
import toast from 'react-hot-toast';
import { mediaUrl, hashColor, initials } from '../utils/media';

function normalize(str) {
  return String(str || '').toLowerCase().normalize('NFD').replace(/\p{M}/gu, '');
}

function Avatar({ name, image, size = 36, color }) {
  const bg = color || hashColor(name || '?');
  return image
    ? <img src={mediaUrl(image)} alt={name} style={{ width: size, height: size, borderRadius: '50%', objectFit: 'cover', flexShrink: 0 }} />
    : <div style={{ width: size, height: size, borderRadius: '50%', background: bg, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontWeight: 700, fontSize: Math.round(size * 0.36), flexShrink: 0 }}>
        {initials(name)}
      </div>;
}

export default function TrialBookingModal({ open, editTrial, presetClient, initialDate, onClose, onSuccess }) {
  const isEdit = !!editTrial;
  const [clients, setClients] = useState([]);
  const [services, setServices] = useState([]);
  const [staff, setStaff] = useState([]);
  const [query, setQuery] = useState('');
  const [showList, setShowList] = useState(false);
  const [newClientMode, setNewClientMode] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [form, setForm] = useState({
    user_id: '', user_name: '', user_phone: '',
    trial_date: new Date().toISOString().slice(0, 10),
    trial_time: '10:00',
    service_id: '',
    staff_id: '',
    notes: '',
  });
  const [newClient, setNewClient] = useState({ full_name: '', phone: '' });

  useEffect(() => {
    if (!open) return;
    if (isEdit) {
      const d = new Date(editTrial.starts_at);
      const pad = n => String(n).padStart(2, '0');
      setForm({
        user_id: editTrial.user_id || '',
        user_name: editTrial.user_name || '',
        user_phone: editTrial.user_phone || '',
        trial_date: `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`,
        trial_time: `${pad(d.getHours())}:${pad(d.getMinutes())}`,
        service_id: editTrial.service_id || '',
        staff_id: editTrial.staff_id || '',
        notes: editTrial.notes || '',
      });
    } else {
      setForm({
        user_id: presetClient?.id || '',
        user_name: presetClient?.full_name || '',
        user_phone: presetClient?.phone || '',
        trial_date: initialDate || new Date().toISOString().slice(0, 10),
        trial_time: '10:00',
        service_id: '',
        staff_id: '',
        notes: '',
      });
    }
    setQuery(''); setNewClientMode(false); setNewClient({ full_name: '', phone: '' }); setShowList(false);
    api.get('/client-admin/clients').then(r => setClients(r.data || [])).catch(() => {});
    api.get('/client-admin/services').then(r => setServices(r.data || [])).catch(() => {});
    api.get('/client-admin/staff').then(r => setStaff(r.data || [])).catch(() => {});
  }, [open, editTrial]);

  if (!open) return null;

  const filtered = clients.filter(c =>
    normalize(c.full_name).includes(normalize(query)) || (c.phone || '').includes(query)
  ).slice(0, 20);

  function set(k, v) { setForm(f => ({ ...f, [k]: v })); }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!form.trial_date || !form.trial_time) { toast.error('Συμπλήρωσε ημερομηνία και ώρα'); return; }
    setSubmitting(true);
    try {
      if (isEdit) {
        await api.patch(`/client-admin/trials/${editTrial.id}`, {
          trial_date: form.trial_date,
          trial_time: form.trial_time,
          service_id: form.service_id || null,
          staff_id: form.staff_id || null,
          notes: form.notes || null,
        });
        toast.success('Το δοκιμαστικό ενημερώθηκε');
      } else {
        let userId = form.user_id || null;
        if (newClientMode) {
          if (!newClient.full_name.trim() || !newClient.phone.trim()) {
            toast.error('Συμπλήρωσε όνομα και κινητό'); setSubmitting(false); return;
          }
          const res = await api.post('/client-admin/clients', {
            full_name: newClient.full_name.trim(),
            phone: newClient.phone.trim(),
          });
          userId = res.data?.id;
          if (!userId) throw new Error('Δεν δημιουργήθηκε ο πελάτης');
        }
        await api.post('/client-admin/trials', {
          trial_date: form.trial_date,
          trial_time: form.trial_time,
          service_id: form.service_id || undefined,
          staff_id: form.staff_id || undefined,
          user_id: userId || undefined,
          notes: form.notes || undefined,
        });
        toast.success('Το δοκιμαστικό καταχωρήθηκε');
      }
      onSuccess?.();
      onClose();
    } catch (err) {
      toast.error(err.response?.data?.error || err.message || 'Σφάλμα');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal cb-modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 520 }}>

        {/* Header */}
        <div className="cb-modal-header" style={{ padding: '20px 32px' }}>
          <div>
            <div className="cb-modal-title">
              <FlaskConical size={16} style={{ color: '#76C043' }} /> {isEdit ? 'Επεξεργασία Δοκιμαστικού' : 'Νέο Δοκιμαστικό'}
            </div>
          </div>
          <button type="button" className="cb-modal-close" onClick={onClose}><X size={20} /></button>
        </div>

        <form onSubmit={handleSubmit}>
          <div style={{ padding: '24px 32px', display: 'flex', flexDirection: 'column', gap: 24 }}>

            {/* Date + Time */}
            <div>
              <div className="cb-section-label"><Calendar size={14} /> Πότε;</div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginTop: 10 }}>
                <div className="form-group" style={{ marginBottom: 0 }}>
                  <label className="form-label">Ημερομηνία *</label>
                  <input type="date" className="form-input" value={form.trial_date}
                    onChange={e => set('trial_date', e.target.value)} required />
                </div>
                <div className="form-group" style={{ marginBottom: 0 }}>
                  <label className="form-label">Ώρα *</label>
                  <input type="time" className="form-input" value={form.trial_time}
                    onChange={e => set('trial_time', e.target.value)} required />
                </div>
              </div>
            </div>

            {/* Client (only for new trials) */}
            {!isEdit && (
              <div>
                <div className="cb-section-label" style={{ marginBottom: 10 }}>
                  Πελάτης <span style={{ fontWeight: 400, fontSize: '0.8rem', color: '#94a3b8' }}>(προαιρετικό)</span>
                </div>

                {!newClientMode ? (
                  <>
                    {form.user_id ? (
                      <div className="cb-selected-client" style={{ marginTop: 0 }}>
                        <Avatar name={form.user_name} size={40} />
                        <div className="cb-selected-info">
                          <div className="cb-selected-name">{form.user_name}</div>
                          {form.user_phone && <div className="cb-selected-meta">{form.user_phone}</div>}
                        </div>
                        <button type="button" className="cb-text-btn"
                          onClick={() => { set('user_id', ''); set('user_name', ''); set('user_phone', ''); }}>
                          Αλλαγή
                        </button>
                      </div>
                    ) : (
                      <>
                        <div className="cb-search" style={{ marginBottom: 0 }}>
                          <input className="cb-search-input" placeholder="Αναζήτηση ονόματος ή κινητού..."
                            value={query} onChange={e => { setQuery(e.target.value); setShowList(true); }}
                            onFocus={() => setShowList(true)} onBlur={() => setTimeout(() => setShowList(false), 180)}
                            autoComplete="off" />
                        </div>
                        {showList && (
                          <div className="cb-client-list" style={{ maxHeight: 200, marginTop: 4, borderRadius: 10, border: '1px solid #e2e8f0', boxShadow: '0 4px 16px rgba(0,0,0,.08)' }}>
                            {filtered.map(c => (
                              <button key={c.id} type="button" className="cb-client-item"
                                onMouseDown={() => { set('user_id', c.id); set('user_name', c.full_name); set('user_phone', c.phone || ''); setQuery(''); setShowList(false); }}>
                                <Avatar name={c.full_name} size={36} />
                                <div className="cb-client-item-text">
                                  <div className="cb-client-item-name">{c.full_name}</div>
                                  {c.phone && <div className="cb-client-item-meta">{c.phone}</div>}
                                </div>
                              </button>
                            ))}
                            {filtered.length === 0 && <div style={{ padding: '12px 16px', color: '#94a3b8', fontSize: '0.875rem' }}>Δεν βρέθηκαν αποτελέσματα</div>}
                          </div>
                        )}
                        <button type="button" className="cb-text-btn" style={{ marginTop: 8, display: 'flex', alignItems: 'center', gap: 4 }}
                          onClick={() => { setNewClientMode(true); }}>
                          <UserPlus size={14} /> Νέος πελάτης
                        </button>
                      </>
                    )}
                  </>
                ) : (
                  <div style={{ background: '#f8fafc', border: '1px solid #e2e8f0', borderRadius: 10, padding: 14 }}>
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 10 }}>
                      <div className="form-group" style={{ marginBottom: 0 }}>
                        <label className="form-label">Ονοματεπώνυμο *</label>
                        <input className="form-input" placeholder="π.χ. Γιώργης Παπάς"
                          value={newClient.full_name} onChange={e => setNewClient(n => ({ ...n, full_name: e.target.value }))} autoFocus />
                      </div>
                      <div className="form-group" style={{ marginBottom: 0 }}>
                        <label className="form-label">Κινητό *</label>
                        <input className="form-input" placeholder="69XXXXXXXX" type="tel"
                          value={newClient.phone} onChange={e => setNewClient(n => ({ ...n, phone: e.target.value }))} />
                      </div>
                    </div>
                    <button type="button" className="cb-text-btn" onClick={() => setNewClientMode(false)}>
                      ← Επιλογή υπάρχοντος
                    </button>
                  </div>
                )}
              </div>
            )}

            {/* Service */}
            <div>
              <div className="cb-section-label" style={{ marginBottom: 10 }}>
                Υπηρεσία <span style={{ fontWeight: 400, fontSize: '0.8rem', color: '#94a3b8' }}>(προαιρετικό)</span>
              </div>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                {[{ id: '', name: 'Χωρίς' }, ...services].map(s => (
                  <button key={s.id} type="button"
                    onClick={() => set('service_id', s.id)}
                    className={form.service_id === s.id ? 'badge badge-green' : 'badge badge-gray'}
                    style={{ cursor: 'pointer', fontSize: '0.8rem', padding: '5px 12px', border: 'none', display: 'flex', alignItems: 'center', gap: 4 }}>
                    {form.service_id === s.id && <Check size={11} />}
                    {s.name}
                  </button>
                ))}
              </div>
            </div>

            {/* Staff */}
            <div>
              <div className="cb-section-label" style={{ marginBottom: 10 }}>
                Γυμναστής <span style={{ fontWeight: 400, fontSize: '0.8rem', color: '#94a3b8' }}>(προαιρετικό)</span>
              </div>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                <button type="button"
                  onClick={() => set('staff_id', '')}
                  className={!form.staff_id ? 'badge badge-green' : 'badge badge-gray'}
                  style={{ cursor: 'pointer', fontSize: '0.8rem', padding: '5px 12px', border: 'none', display: 'flex', alignItems: 'center', gap: 4 }}>
                  {!form.staff_id && <Check size={11} />} Χωρίς
                </button>
                {staff.map(s => (
                  <button key={s.id} type="button"
                    onClick={() => set('staff_id', s.id)}
                    style={{
                      display: 'flex', alignItems: 'center', gap: 8,
                      padding: '5px 12px 5px 6px', borderRadius: 20,
                      border: `2px solid ${form.staff_id === s.id ? (s.color_hex || 'var(--hs-primary)') : '#e2e8f0'}`,
                      background: form.staff_id === s.id ? '#f0fdf4' : '#fff',
                      cursor: 'pointer', transition: 'all .15s',
                    }}>
                    <Avatar name={s.full_name} image={s.avatar_url} size={26} color={s.color_hex} />
                    <span style={{ fontWeight: 600, fontSize: '0.8rem', color: form.staff_id === s.id ? '#15803d' : '#374151' }}>
                      {s.full_name}
                    </span>
                    {form.staff_id === s.id && <Check size={11} color="#15803d" />}
                  </button>
                ))}
              </div>
            </div>

            {/* Notes */}
            <div>
              <div className="cb-section-label" style={{ marginBottom: 10 }}>
                Σχόλιο <span style={{ fontWeight: 400, fontSize: '0.8rem', color: '#94a3b8' }}>(προαιρετικό)</span>
              </div>
              <input
                className="form-input"
                placeholder="π.χ. Ήρθε, συζητήσαμε τιμές..."
                value={form.notes}
                onChange={e => set('notes', e.target.value)}
              />
            </div>

          </div>

          {/* Footer */}
          <div className="cb-modal-footer" style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, padding: '16px 32px' }}>
            <button type="button" className="btn btn-secondary" onClick={onClose}>Άκυρο</button>
            <button type="submit" className="btn btn-primary" disabled={submitting}>
              {submitting ? 'Αποθήκευση...' : isEdit ? 'Ενημέρωση' : 'Καταχώρηση'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
