import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import Layout from '../components/Layout';
import AvailabilityEditor from '../components/AvailabilityEditor';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Zap } from 'lucide-react';

const DAYS = ['Δευ', 'Τρί', 'Τετ', 'Πέμ', 'Παρ', 'Σαβ', 'Κυρ'];
const EMPTY = { id: null, service_id: '', location_id: '', price: '', staff_ids: [], slots: [] };

function addMinutes(time, mins) {
  const [h, m] = String(time).slice(0, 5).split(':').map(Number);
  const total = (h * 60 + (m || 0) + mins) % (24 * 60);
  return `${String(Math.floor(total / 60)).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`;
}

function slotsFromProgram(schedules, durationMins) {
  const dur = Number(durationMins) > 0 ? Number(durationMins) : 60;
  const seen = new Set();
  return (schedules || []).flatMap((s) => {
    if (s.is_active === 0 || s.is_active === false) return [];
    const start = String(s.start_time || '').slice(0, 5);
    if (!start) return [];
    const key = `${s.weekday}-${start}`;
    if (seen.has(key)) return [];
    seen.add(key);
    return [{ weekday: Number(s.weekday), start_time: start, end_time: addMinutes(start, dur) }];
  });
}

function hourSummary(slots) {
  if (!slots?.length) return 'Χωρίς ώρες';
  return DAYS.map((label, wd) => {
    const day = slots.filter((s) => Number(s.weekday) === wd);
    if (!day.length) return null;
    return `${label} ${day.map((s) => `${s.start_time}–${s.end_time}`).join(', ')}`;
  }).filter(Boolean).join(' · ');
}

export default function DropinSetup() {
  const [data, setData] = useState({ services: [], locations: [], staff: [], offers: [] });
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState(null);
  const [saving, setSaving] = useState(false);
  const [programSlots, setProgramSlots] = useState([]);

  const load = async () => {
    setLoading(true);
    try {
      const res = await api.get('/client-admin/dropin-setup');
      setData(res.data || { services: [], locations: [], staff: [], offers: [] });
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα φόρτωσης');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, []);

  useEffect(() => {
    if (!form?.service_id || !form?.location_id) {
      setProgramSlots([]);
      return undefined;
    }
    let cancelled = false;
    const serviceId = form.service_id;
    const locationId = form.location_id;
    const keepExisting = !!form.id;
    api.get(`/client-admin/services/${serviceId}/slot-schedules`, { params: { location_id: locationId } })
      .then((res) => {
        if (cancelled) return;
        const rows = res.data || [];
        setProgramSlots(rows);
        if (!keepExisting) {
          const svc = data.services.find((s) => s.id === serviceId);
          setForm((f) => (f && f.service_id === serviceId && f.location_id === locationId && !f.id
            ? { ...f, slots: slotsFromProgram(rows, svc?.duration_mins) }
            : f));
        }
      })
      .catch(() => { if (!cancelled) setProgramSlots([]); });
    return () => { cancelled = true; };
  }, [form?.service_id, form?.location_id, form?.id, data.services]);

  const fillFromProgram = () => {
    if (!form?.service_id || !form?.location_id) {
      toast.error('Διάλεξε πρώτα υπηρεσία και κατάστημα');
      return;
    }
    if (!programSlots.length) {
      toast.error('Δεν υπάρχει πρόγραμμα για αυτή την υπηρεσία σε αυτό το κατάστημα');
      return;
    }
    const svc = data.services.find((s) => s.id === form.service_id);
    setForm((f) => ({ ...f, slots: slotsFromProgram(programSlots, svc?.duration_mins) }));
  };

  const startNew = () => setForm({ ...EMPTY });

  const startEdit = (offer) => setForm({
    id: offer.id,
    service_id: offer.service_id,
    location_id: offer.location_id,
    price: String(offer.price_cents / 100),
    staff_ids: offer.staff_ids || [],
    slots: offer.slots || [],
  });

  const toggleStaff = (id) => {
    setForm((f) => ({
      ...f,
      staff_ids: f.staff_ids.includes(id) ? f.staff_ids.filter((x) => x !== id) : [...f.staff_ids, id],
    }));
  };

  const save = async (e) => {
    e.preventDefault();
    const euros = Number(form.price);
    if (!form.service_id || !form.location_id) return toast.error('Διάλεξε υπηρεσία και κατάστημα');
    if (!Number.isFinite(euros) || euros <= 0) return toast.error('Βάλε τιμή');
    setSaving(true);
    const payload = {
      service_id: form.service_id,
      location_id: form.location_id,
      price_cents: Math.round(euros * 100),
      staff_ids: form.staff_ids,
      slots: form.slots,
    };
    try {
      if (form.id) await api.put(`/client-admin/dropin-setup/${form.id}`, payload);
      else await api.post('/client-admin/dropin-setup', payload);
      toast.success('Το drop-in αποθηκεύτηκε');
      setForm(null);
      await load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };

  const remove = async (offer) => {
    if (!window.confirm(`Να αφαιρεθεί το drop-in ${offer.service_name} στο ${offer.location_name};`)) return;
    try {
      await api.delete(`/client-admin/dropin-setup/${offer.id}`);
      toast.success('Αφαιρέθηκε');
      if (form?.id === offer.id) setForm(null);
      await load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  return (
    <Layout title="Drop-in">
      <div className="page-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 16 }}>
        <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
          <div style={{ width: 44, height: 44, borderRadius: 14, background: '#fefce8', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Zap size={20} color="#ca8a04" />
          </div>
          <div>
            <h1 style={{ margin: 0, fontSize: '1.35rem' }}>Ρύθμιση drop-in</h1>
            <div className="text-muted" style={{ marginTop: 4 }}>
              Διάλεξε υπηρεσία, κατάστημα, τιμή, ώρες και ποιος το αναλαμβάνει.
            </div>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <Link to="/dropin-bookings" className="btn btn-secondary">Κρατήσεις</Link>
          <button type="button" className="btn btn-primary" onClick={startNew}>Νέο drop-in</button>
        </div>
      </div>

      {form && (
        <form onSubmit={save} className="card" style={{ padding: 20, marginBottom: 20 }}>
          <div className="form-grid-2">
            <div className="form-group">
              <label className="form-label">Υπηρεσία</label>
              <select className="form-input" value={form.service_id} onChange={(e) => setForm({ ...form, service_id: e.target.value })}>
                <option value="">Επίλεξε υπηρεσία</option>
                {data.services.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
              </select>
            </div>
            <div className="form-group">
              <label className="form-label">Κατάστημα</label>
              <select className="form-input" value={form.location_id} onChange={(e) => setForm({ ...form, location_id: e.target.value })}>
                <option value="">Επίλεξε κατάστημα</option>
                {data.locations.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}
              </select>
            </div>
          </div>
          <div className="form-group" style={{ maxWidth: 220 }}>
            <label className="form-label">Τιμή (€)</label>
            <input className="form-input" type="number" min="0" step="0.5" value={form.price}
              onChange={(e) => setForm({ ...form, price: e.target.value })} placeholder="π.χ. 15" />
          </div>
          <div className="form-group">
            <label className="form-label">Ποιος το αναλαμβάνει</label>
            {data.staff.length === 0 ? (
              <div className="text-muted">Δεν υπάρχουν trainers. Πρόσθεσέ τους από το Προσωπικό.</div>
            ) : (
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                {data.staff.map((s) => {
                  const on = form.staff_ids.includes(s.id);
                  return (
                    <button type="button" key={s.id} onClick={() => toggleStaff(s.id)}
                      style={{
                        padding: '6px 12px', borderRadius: 20, cursor: 'pointer',
                        border: `1.5px solid ${on ? '#76C043' : '#e2e8f0'}`,
                        background: on ? '#f0fdf4' : '#fff',
                        color: on ? '#3f6212' : '#64748b',
                        fontWeight: on ? 700 : 500,
                      }}>
                      {s.full_name}
                    </button>
                  );
                })}
              </div>
            )}
          </div>
          <div className="form-group">
            <label className="form-label">Διαθέσιμες ώρες</label>
            <div className="text-muted" style={{ fontSize: '0.8rem', marginBottom: 8 }}>
              Από το πρόγραμμα της υπηρεσίας σε αυτό το κατάστημα
              {form.service_id ? <> · <Link to={`/services/${form.service_id}/schedule`}>Άνοιγμα προγράμματος</Link></> : null}
            </div>
            <AvailabilityEditor
              slots={form.slots}
              onChange={(slots) => setForm((f) => ({ ...f, slots }))}
              fillLabel="Γέμισε από το πρόγραμμα της υπηρεσίας"
              onFill={fillFromProgram}
            />
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button type="submit" className="btn btn-primary" disabled={saving}>{saving ? 'Αποθήκευση...' : 'Αποθήκευση'}</button>
            <button type="button" className="btn btn-secondary" onClick={() => setForm(null)}>Ακύρωση</button>
          </div>
        </form>
      )}

      {loading ? <div className="text-muted">Φόρτωση...</div> : data.offers.length === 0 ? (
        <div className="card" style={{ padding: 28, color: '#64748b' }}>
          Δεν έχεις ρυθμίσει drop-in. Πάτα «Νέο drop-in» για να διαλέξεις υπηρεσία, κατάστημα, ώρες και trainer.
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {data.offers.map((offer) => (
            <div key={offer.id} className="card" style={{ padding: 16 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, alignItems: 'flex-start' }}>
                <div>
                  <div style={{ fontWeight: 800 }}>{offer.service_name}</div>
                  <div style={{ color: '#64748b', marginTop: 2 }}>{offer.location_name} · {(offer.price_cents / 100).toFixed(2)} €</div>
                  <div style={{ marginTop: 8, fontSize: '0.85rem' }}>{(offer.staff_names || []).join(', ') || 'Χωρίς trainer'}</div>
                  <div style={{ marginTop: 4, fontSize: '0.8rem', color: '#64748b' }}>{hourSummary(offer.slots)}</div>
                </div>
                <div style={{ display: 'flex', gap: 8 }}>
                  <button type="button" className="btn btn-secondary btn-sm" onClick={() => startEdit(offer)}>Επεξεργασία</button>
                  <button type="button" className="btn btn-secondary btn-sm" onClick={() => remove(offer)}>Αφαίρεση</button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </Layout>
  );
}
