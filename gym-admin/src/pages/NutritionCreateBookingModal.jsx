import { useEffect, useMemo, useState } from 'react';
import { Calendar, Search, User, X } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import api from '../api/client';
import toast from 'react-hot-toast';

function normalize(str) {
  return String(str || '').toLowerCase().normalize('NFD').replace(/\p{M}/gu, '');
}

function todayStr() {
  const d = new Date();
  return d.toISOString().slice(0, 10);
}

export default function NutritionCreateBookingModal({ open, onClose, onSuccess }) {
  const { isOwner } = useAuth();
  const [clients, setClients] = useState([]);
  const [slots, setSlots] = useState([]);
  const [slotsLoading, setSlotsLoading] = useState(false);
  const [loading, setLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [clientQuery, setClientQuery] = useState('');
  const [clientOpen, setClientOpen] = useState(false);
  const [nutritionists, setNutritionists] = useState([]);
  const [nutritionistId, setNutritionistId] = useState('');
  const [form, setForm] = useState({
    user_id: '',
    date: todayStr(),
    time: '',
  });

  const needsNutritionistChoice = isOwner && nutritionists.length > 1;
  const nutritionistReady = !needsNutritionistChoice || nutritionistId;

  useEffect(() => {
    if (!open) return;
    setForm({ user_id: '', date: todayStr(), time: '' });
    setClientQuery('');
    setClientOpen(false);
    setSlots([]);
    setNutritionistId('');
    setLoading(true);
    const requests = [
      api.get('/client-admin/nutrition/bookings/bookable-clients'),
    ];
    if (isOwner) {
      requests.push(api.get('/client-admin/nutrition/consultation/setup'));
    }
    Promise.all(requests)
      .then(([clientsRes, setupRes]) => {
        setClients(clientsRes.data || []);
        const nuts = setupRes?.data?.nutritionists || [];
        setNutritionists(nuts);
        if (nuts.length === 1) setNutritionistId(nuts[0].id);
      })
      .catch(() => toast.error('Δεν φορτώθηκαν τα στοιχεία'))
      .finally(() => setLoading(false));
  }, [open, isOwner]);

  const selectedClient = useMemo(
    () => clients.find(c => c.id === form.user_id) || null,
    [clients, form.user_id],
  );

  const filteredClients = useMemo(() => {
    const q = normalize(clientQuery).trim();
    if (!q) return clients.slice(0, 15);
    return clients.filter(c => {
      const hay = normalize(`${c.full_name} ${c.email || ''} ${c.phone || ''}`);
      return hay.includes(q);
    }).slice(0, 20);
  }, [clients, clientQuery]);

  const loadSlots = async (date, nutId) => {
    if (!date || (needsNutritionistChoice && !nutId)) {
      setSlots([]);
      return;
    }
    setSlotsLoading(true);
    try {
      const params = { date };
      if (nutId) params.nutritionist_id = nutId;
      const r = await api.get('/client-admin/nutrition/bookings/slots', { params });
      setSlots((r.data.slots || []).filter(s => !s.is_full && (s.available_staff?.length || 0) > 0));
    } catch {
      setSlots([]);
      toast.error('Δεν φορτώθηκαν οι διαθέσιμες ώρες');
    } finally {
      setSlotsLoading(false);
    }
  };

  useEffect(() => {
    if (!open) return;
    loadSlots(form.date, nutritionistId);
  }, [open, form.date, nutritionistId, needsNutritionistChoice]);

  const pickClient = (client) => {
    if (client.has_pending_booking) {
      toast.error('Ο πελάτης έχει ήδη ενεργό αίτημα κράτησης');
      return;
    }
    setForm(prev => ({ ...prev, user_id: client.id }));
    setClientQuery(client.full_name);
    setClientOpen(false);
  };

  const submit = async (e) => {
    e.preventDefault();
    if (!form.user_id || !form.date || !form.time) return;
    if (!nutritionistReady) {
      toast.error('Επίλεξε διατροφολόγο');
      return;
    }
    setSubmitting(true);
    try {
      await api.post('/client-admin/nutrition/bookings', {
        user_id: form.user_id,
        date: form.date,
        time: form.time,
        nutritionist_id: nutritionistId || undefined,
      });
      toast.success('Η κράτηση καταχωρήθηκε');
      onSuccess?.();
      onClose();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSubmitting(false);
    }
  };

  if (!open) return null;

  const canSubmit = form.user_id && form.date && form.time && nutritionistReady && !submitting;

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal cb-modal" onClick={e => e.stopPropagation()}>
        <div className="cb-modal-header">
          <div>
            <div className="cb-modal-title">Νέα κράτηση διατροφολόγου</div>
            <div className="cb-modal-sub">Για ενεργό πελάτη με διαθέσιμες επισκέψεις</div>
          </div>
          <button type="button" className="cb-icon-btn" onClick={onClose} aria-label="Κλείσιμο">
            <X size={18} />
          </button>
        </div>

        {loading ? (
          <div className="loading">Φόρτωση...</div>
        ) : (
          <form onSubmit={submit} className="cb-form">
            {needsNutritionistChoice && (
              <section className="cb-section">
                <div className="cb-section-label">Διατροφολόγος</div>
                <select
                  className="form-input"
                  value={nutritionistId}
                  onChange={e => {
                    setNutritionistId(e.target.value);
                    setForm(prev => ({ ...prev, time: '' }));
                  }}
                >
                  <option value="">Επίλεξε διατροφολόγο...</option>
                  {nutritionists.map(n => (
                    <option key={n.id} value={n.id}>
                      {n.location_name ? `${n.full_name} — ${n.location_name}` : n.full_name}
                    </option>
                  ))}
                </select>
              </section>
            )}

            <section className="cb-section">
              <div className="cb-section-label"><User size={16} /> Πελάτης</div>
              <div className="cb-search-wrap">
                <Search size={16} className="cb-search-icon" />
                <input
                  className="form-input cb-search-input"
                  placeholder="Αναζήτηση πελάτη..."
                  value={clientQuery}
                  onChange={e => { setClientQuery(e.target.value); setClientOpen(true); }}
                  onFocus={() => setClientOpen(true)}
                />
              </div>
              {clientOpen && filteredClients.length > 0 && (
                <div className="cb-client-dropdown">
                  {filteredClients.map(c => (
                    <button
                      key={c.id}
                      type="button"
                      className="cb-client-option"
                      onClick={() => pickClient(c)}
                    >
                      <span>{c.full_name}</span>
                      <span className="text-muted" style={{ fontSize: '0.8rem' }}>
                        {c.credits_remaining} επισκέψεις
                        {c.has_pending_booking ? ' · αίτημα σε αναμονή' : ''}
                      </span>
                    </button>
                  ))}
                </div>
              )}
              {selectedClient && (
                <div className="cb-selected-client" style={{ marginTop: 10 }}>
                  <div>
                    <div style={{ fontWeight: 600 }}>{selectedClient.full_name}</div>
                    <div className="text-muted" style={{ fontSize: '0.85rem' }}>
                      {selectedClient.credits_remaining} / {selectedClient.credits_total} επισκέψεις διαθέσιμες
                    </div>
                  </div>
                </div>
              )}
              {!clients.length && (
                <p className="text-muted" style={{ marginTop: 8, fontSize: '0.9rem' }}>
                  Δεν βρέθηκαν ενεργοί πελάτες με υπόλοιπο επισκέψεων διατροφολόγου.
                </p>
              )}
            </section>

            <section className="cb-section">
              <div className="cb-section-label"><Calendar size={16} /> Ημερομηνία & ώρα</div>
              <input
                type="date"
                className="form-input"
                value={form.date}
                min={todayStr()}
                onChange={e => setForm(prev => ({ ...prev, date: e.target.value, time: '' }))}
              />
              <div style={{ marginTop: 12 }}>
                {slotsLoading && <div className="text-muted">Φόρτωση ωρών...</div>}
                {!slotsLoading && slots.length === 0 && (
                  <div className="text-muted">Δεν υπάρχουν διαθέσιμες ώρες αυτή την ημέρα</div>
                )}
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 8 }}>
                  {slots.map(slot => (
                    <button
                      key={slot.time}
                      type="button"
                      className={`btn btn-sm ${form.time === slot.time ? 'btn-primary' : 'btn-secondary'}`}
                      onClick={() => setForm(prev => ({ ...prev, time: slot.time }))}
                    >
                      {slot.time}
                    </button>
                  ))}
                </div>
              </div>
            </section>

            <div className="cb-form-actions">
              <button type="button" className="btn btn-secondary" onClick={onClose}>Ακύρωση</button>
              <button type="submit" className="btn btn-primary" disabled={!canSubmit}>
                {submitting ? 'Αποθήκευση...' : 'Καταχώρηση κράτησης'}
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}
