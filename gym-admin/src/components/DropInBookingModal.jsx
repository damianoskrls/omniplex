import { useEffect, useState } from 'react';
import { X, Zap } from 'lucide-react';
import api from '../api/client';
import toast from 'react-hot-toast';

function normalize(str) {
  return String(str || '').toLowerCase().normalize('NFD').replace(/\p{M}/gu, '');
}

export default function DropInBookingModal({ open, onClose, onSuccess, initialDate }) {
  const [clients, setClients] = useState([]);
  const [services, setServices] = useState([]);
  const [slots, setSlots] = useState([]);
  const [staff, setStaff] = useState([]);
  const [locations, setLocations] = useState([]);
  const [slotsLoading, setSlotsLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [clientQuery, setClientQuery] = useState('');

  const [form, setForm] = useState({
    user_id: '', service_id: '', date: initialDate || '', time: '',
    staff_id: '', location_id: '', price: '', payment_method: 'cash',
  });

  useEffect(() => {
    if (!open) return;
    setForm(f => ({ ...f, date: initialDate || f.date }));
    api.get('/client-admin/clients').then(r => setClients(r.data)).catch(() => {});
    api.get('/client-admin/services').then(r => {
      setServices(r.data.filter(s => s.drop_in_price_cents != null && s.is_active !== 0));
    }).catch(() => {});
  }, [open, initialDate]);

  const selectedService = services.find(s => s.id === form.service_id);

  useEffect(() => {
    if (!form.service_id) { setSlots([]); setStaff([]); setLocations([]); return; }
    // auto-fill price from service
    if (selectedService?.drop_in_price_cents != null) {
      setForm(f => ({ ...f, price: String(selectedService.drop_in_price_cents / 100) }));
    }
    api.get(`/client-admin/services/${form.service_id}/locations`).then(r => {
      setLocations(r.data || []);
      if (r.data?.length === 1) setForm(f => ({ ...f, location_id: r.data[0].id }));
    }).catch(() => {});
  }, [form.service_id]);

  useEffect(() => {
    if (!form.service_id || !form.date) { setSlots([]); return; }
    setSlotsLoading(true);
    const params = new URLSearchParams({ service_id: form.service_id, date: form.date });
    if (form.location_id) params.set('location_id', form.location_id);
    api.get(`/client-admin/slots?${params}`)
      .then(r => {
        setSlots(r.data || []);
        const allStaff = [];
        const seen = new Set();
        (r.data || []).forEach(slot => (slot.available_staff || []).forEach(s => {
          if (!seen.has(s.id)) { seen.add(s.id); allStaff.push(s); }
        }));
        setStaff(allStaff);
      })
      .catch(() => setSlots([]))
      .finally(() => setSlotsLoading(false));
  }, [form.service_id, form.date, form.location_id]);

  const filteredClients = clients.filter(c =>
    normalize(c.full_name).includes(normalize(clientQuery)) ||
    normalize(c.email).includes(normalize(clientQuery)) ||
    String(c.phone || '').includes(clientQuery)
  );

  const selectedClient = clients.find(c => c.id === form.user_id);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!form.user_id || !form.service_id || !form.date || !form.time) {
      toast.error('Συμπλήρωσε όλα τα υποχρεωτικά πεδία');
      return;
    }
    setSubmitting(true);
    try {
      await api.post('/client-admin/bookings/drop-in', {
        user_id: form.user_id,
        service_id: form.service_id,
        date: form.date,
        time: form.time,
        staff_id: form.staff_id || undefined,
        location_id: form.location_id || undefined,
        price_cents: Math.round(parseFloat(form.price || '0') * 100),
        payment_method: form.payment_method,
      });
      toast.success('Κράτηση drop-in δημιουργήθηκε');
      onSuccess?.();
      onClose();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSubmitting(false);
    }
  };

  if (!open) return null;

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" style={{ maxWidth: 520 }} onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h2 style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <Zap size={18} /> Μεμονωμένη συνεδρία (Drop-in)
          </h2>
          <button type="button" className="modal-close" onClick={onClose}><X size={20} /></button>
        </div>
        <form onSubmit={handleSubmit} className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>

          {/* Client */}
          <div className="form-group" style={{ marginBottom: 0 }}>
            <label className="form-label">Πελάτης *</label>
            <input
              className="form-input"
              placeholder="Αναζήτηση ονόματος, email, τηλεφώνου..."
              value={selectedClient ? selectedClient.full_name : clientQuery}
              onChange={e => { setClientQuery(e.target.value); setForm(f => ({ ...f, user_id: '' })); }}
              onFocus={() => { if (selectedClient) setClientQuery(''); setForm(f => ({ ...f, user_id: '' })); }}
            />
            {!form.user_id && clientQuery && (
              <div style={{ border: '1px solid #e2e8f0', borderRadius: 8, marginTop: 4, maxHeight: 180, overflowY: 'auto', background: '#fff', zIndex: 10, position: 'relative' }}>
                {filteredClients.slice(0, 8).map(c => (
                  <div key={c.id}
                    style={{ padding: '8px 12px', cursor: 'pointer', fontSize: '0.88rem' }}
                    onMouseDown={() => { setForm(f => ({ ...f, user_id: c.id })); setClientQuery(''); }}
                    onMouseOver={e => e.currentTarget.style.background = '#f1f5f9'}
                    onMouseOut={e => e.currentTarget.style.background = ''}
                  >
                    <strong>{c.full_name}</strong>
                    {c.email && <span style={{ color: '#64748b', marginLeft: 8 }}>{c.email}</span>}
                  </div>
                ))}
                {filteredClients.length === 0 && <div style={{ padding: 12, color: '#94a3b8', fontSize: '0.85rem' }}>Δεν βρέθηκε πελάτης</div>}
              </div>
            )}
          </div>

          {/* Service */}
          <div className="form-group" style={{ marginBottom: 0 }}>
            <label className="form-label">Υπηρεσία * <span style={{ fontWeight: 400, color: '#94a3b8', fontSize: '0.8rem' }}>(μόνο υπηρεσίες με τιμή drop-in)</span></label>
            <select className="form-input" value={form.service_id} onChange={e => setForm(f => ({ ...f, service_id: e.target.value, time: '', staff_id: '' }))} required>
              <option value="">— Επίλεξε υπηρεσία —</option>
              {services.map(s => (
                <option key={s.id} value={s.id}>{s.name} — €{(s.drop_in_price_cents / 100).toFixed(2)}</option>
              ))}
            </select>
            {services.length === 0 && (
              <div style={{ marginTop: 6, fontSize: '0.82rem', color: '#f59e0b' }}>
                Δεν έχεις ορίσει τιμή drop-in σε καμία υπηρεσία. Πήγαινε στις Υπηρεσίες και συμπλήρωσε την τιμή drop-in.
              </div>
            )}
          </div>

          {/* Date + Location */}
          <div style={{ display: 'grid', gridTemplateColumns: locations.length > 1 ? '1fr 1fr' : '1fr', gap: 12 }}>
            <div className="form-group" style={{ marginBottom: 0 }}>
              <label className="form-label">Ημερομηνία *</label>
              <input className="form-input" type="date" value={form.date} onChange={e => setForm(f => ({ ...f, date: e.target.value, time: '' }))} required />
            </div>
            {locations.length > 1 && (
              <div className="form-group" style={{ marginBottom: 0 }}>
                <label className="form-label">Γυμναστήριο</label>
                <select className="form-input" value={form.location_id} onChange={e => setForm(f => ({ ...f, location_id: e.target.value, time: '' }))}>
                  <option value="">— Επίλεξε —</option>
                  {locations.map(l => <option key={l.id} value={l.id}>{l.name}</option>)}
                </select>
              </div>
            )}
          </div>

          {/* Time slots */}
          {form.service_id && form.date && (
            <div className="form-group" style={{ marginBottom: 0 }}>
              <label className="form-label">Ώρα *</label>
              {slotsLoading ? <div style={{ color: '#94a3b8', fontSize: '0.85rem' }}>Φόρτωση...</div> : (
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                  {slots.filter(s => !s.is_full).map(s => (
                    <button
                      key={s.time} type="button"
                      onClick={() => setForm(f => ({ ...f, time: s.time, staff_id: '' }))}
                      style={{
                        padding: '6px 14px', borderRadius: 8, border: `1.5px solid ${form.time === s.time ? '#4ade80' : '#e2e8f0'}`,
                        background: form.time === s.time ? '#f0fdf4' : '#fff',
                        fontWeight: form.time === s.time ? 700 : 400, fontSize: '0.88rem', cursor: 'pointer',
                      }}
                    >{s.time}</button>
                  ))}
                  {slots.filter(s => !s.is_full).length === 0 && <span style={{ color: '#94a3b8', fontSize: '0.85rem' }}>Δεν υπάρχουν διαθέσιμες ώρες</span>}
                </div>
              )}
            </div>
          )}

          {/* Staff */}
          {form.time && staff.length > 0 && (
            <div className="form-group" style={{ marginBottom: 0 }}>
              <label className="form-label">Γυμναστής</label>
              <select className="form-input" value={form.staff_id} onChange={e => setForm(f => ({ ...f, staff_id: e.target.value }))}>
                <option value="">— Αυτόματη ανάθεση —</option>
                {(slots.find(s => s.time === form.time)?.available_staff || []).map(s => (
                  <option key={s.id} value={s.id}>{s.full_name}</option>
                ))}
              </select>
            </div>
          )}

          {/* Price + Payment method */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <div className="form-group" style={{ marginBottom: 0 }}>
              <label className="form-label">Τιμή (€) *</label>
              <input
                className="form-input" type="number" min={0} step={0.5}
                value={form.price}
                onChange={e => setForm(f => ({ ...f, price: e.target.value }))}
                required
              />
            </div>
            <div className="form-group" style={{ marginBottom: 0 }}>
              <label className="form-label">Τρόπος πληρωμής</label>
              <select className="form-input" value={form.payment_method} onChange={e => setForm(f => ({ ...f, payment_method: e.target.value }))}>
                <option value="cash">Μετρητά</option>
                <option value="card">Κάρτα</option>
                <option value="bank_transfer">Τραπεζική μεταφορά</option>
              </select>
            </div>
          </div>

          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, paddingTop: 8, borderTop: '1px solid #f1f5f9' }}>
            <button type="button" className="btn btn-secondary" onClick={onClose}>Άκυρο</button>
            <button type="submit" className="btn btn-primary" disabled={submitting}>
              {submitting ? 'Αποθήκευση...' : 'Κράτηση & Πληρωμή'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
