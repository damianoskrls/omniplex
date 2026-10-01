import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import StoreFilter from '../components/StoreFilter';
import TrialSlotPicker from '../components/TrialSlotPicker';
import api from '../api/client';
import toast from 'react-hot-toast';

export default function PlanRequests() {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState('');
  const [trialFor, setTrialFor] = useState(null);
  const [when, setWhen] = useState({ date: '', time: '18:00', location_id: '' });
  const [locations, setLocations] = useState([]);
  const [locationId, setLocationId] = useState('');
  const [pickedStore, setPickedStore] = useState({});
  const [planServiceId, setPlanServiceId] = useState('');

  async function load() {
    setLoading(true);
    setLoadError('');
    try {
      const params = {};
      if (locationId) params.location_id = locationId;
      const r = await api.get('/client-admin/plan-requests', { params });
      setRows(r.data || []);
    } catch (err) {
      const msg = err.response?.data?.error || 'Σφάλμα φόρτωσης';
      setLoadError(msg);
      toast.error(msg);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { load(); }, [locationId]);
  useEffect(() => {
    if (!trialFor || trialFor.service_id) {
      setPlanServiceId('');
      return;
    }
    let cancel = false;
    api.get('/client-admin/plans').then(r => {
      if (cancel) return;
      const plan = (r.data || []).find(p => p.id === trialFor.plan_id);
      setPlanServiceId(plan?.service_id || plan?.service_items?.[0]?.service_id || '');
    }).catch(() => {});
    return () => { cancel = true; };
  }, [trialFor]);
  useEffect(() => {
    api.get('/client-admin/locations')
      .then(r => setLocations((r.data || []).filter(l => l.is_active !== 0 && l.is_active !== false)))
      .catch(() => {});
  }, []);

  async function reject(id) {
    try {
      await api.post(`/client-admin/plan-requests/${id}/reject`);
      toast.success('Το αίτημα απορρίφθηκε');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  }

  async function acceptEnroll(id, storeId) {
    if (locations.length > 1 && !storeId) {
      toast.error('Διάλεξε κατάστημα');
      return;
    }
    try {
      const r = await api.post(`/client-admin/plan-requests/${id}/accept`, {
        location_id: storeId || locations[0]?.id || null,
      });
      toast.success(r.data.message || 'Εγκρίθηκε');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  }

  async function acceptTrial(e) {
    e.preventDefault();
    if (!trialFor) return;
    try {
      if (locations.length > 1 && !when.location_id) {
        toast.error('Διάλεξε κατάστημα');
        return;
      }
      if (!when.date || !when.time) {
        toast.error('Διάλεξε ημέρα και ώρα από το πρόγραμμα');
        return;
      }
      const r = await api.post(`/client-admin/plan-requests/${trialFor.id}/accept`, {
        trial_date: when.date,
        trial_time: when.time,
        location_id: when.location_id || locations[0]?.id || null,
      });
      toast.success(r.data.message || 'Το δοκιμαστικό μπήκε');
      setTrialFor(null);
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  }

  const pending = rows.filter(r => r.status === 'pending');
  const rest = rows.filter(r => r.status !== 'pending');

  return (
    <Layout title="Αιτήματα πακέτων">
      <StoreFilter locations={locations} value={locationId} onChange={setLocationId} />
      <p style={{ color: 'var(--text-2)', marginTop: -8, marginBottom: 16, maxWidth: 720 }}>
        Όταν ένα μέλος ζητάει άλλο πρόγραμμα, το βλέπεις εδώ μαζί με το κατάστημα. Αν ζητάει εγγραφή, η αποδοχή προσθέτει το πακέτο και η πληρωμή μένει εκκρεμής στην καρτέλα του. Αν ζητάει δοκιμαστικό, ορίζεις μέρα, ώρα και κατάστημα.
      </p>
      {loading ? <div className="text-muted">Φόρτωση…</div> : loadError ? (
        <div className="card" style={{ color: 'var(--danger, #dc2626)' }}>{loadError}</div>
      ) : pending.length === 0 ? (
        <div className="card text-muted">Δεν υπάρχουν εκκρεμή αιτήματα.</div>
      ) : pending.map(row => (
        <div key={row.id} className="card" style={{ marginBottom: 12 }}>
          <div style={{ fontWeight: 800 }}>{row.full_name}</div>
          <div style={{ color: 'var(--text-2)', margin: '4px 0 10px' }}>
            {row.kind === 'trial' ? 'Θέλει πρώτα δοκιμαστικό' : 'Θέλει εγγραφή στο πακέτο'}
            {' · '}{row.plan_name}
            {row.service_name ? ` · ${row.service_name}` : ''}
            {' · '}
            <span style={{ fontWeight: 700, color: row.location_name ? '#92400E' : '#b45309' }}>
              {row.location_name || 'Χωρίς κατάστημα'}
            </span>
            {row.phone ? ` · ${row.phone}` : ''}
            {row.kind === 'trial' && row.trial_date ? ` · προτεινόμενη ώρα ${row.trial_date} ${row.trial_time || ''}` : ''}
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            {row.kind === 'trial' ? (
              <button className="btn btn-primary btn-sm" onClick={() => { setTrialFor(row); setWhen({ date: (row.trial_date || '').slice(0, 10), time: '', location_id: row.location_id || locationId || (locations.length === 1 ? locations[0].id : '') }); }}>
                Κλείσε δοκιμαστικό
              </button>
            ) : (
              <>
                {!row.location_id && locations.length > 1 && (
                  <select
                    className="form-select"
                    value={pickedStore[row.id] || ''}
                    onChange={e => setPickedStore(s => ({ ...s, [row.id]: e.target.value }))}
                    style={{ maxWidth: 200 }}
                  >
                    <option value="">— Κατάστημα —</option>
                    {locations.map(loc => <option key={loc.id} value={loc.id}>{loc.name}</option>)}
                  </select>
                )}
                <button className="btn btn-primary btn-sm" onClick={() => acceptEnroll(row.id, row.location_id || pickedStore[row.id] || locationId)}>Αποδοχή και εκκρεμής πληρωμή</button>
              </>
            )}
            <button className="btn btn-secondary btn-sm" onClick={() => reject(row.id)}>Απόρριψη</button>
          </div>
        </div>
      ))}

      {trialFor && (
        <form className="card" onSubmit={acceptTrial} style={{ marginTop: 8 }}>
          <div style={{ fontWeight: 700, marginBottom: 6 }}>Δοκιμαστικό για {trialFor.full_name}</div>
          <div style={{ fontSize: 13, color: 'var(--text-2)', marginBottom: 12 }}>
            Οι μέρες χωρίς μάθημα είναι σβηστές. Διάλεξε ώρα από το πρόγραμμα — αλλιώς η κράτηση απορρίπτεται.
          </div>
          {locations.length > 0 && (
            <label style={{ display: 'block', fontSize: 13, color: 'var(--text-2)', marginBottom: 12 }}>
              Κατάστημα
              <select className="form-select" value={when.location_id} onChange={e => setWhen(w => ({ ...w, location_id: e.target.value, time: '' }))} required={locations.length > 1} style={{ display: 'block', marginTop: 4, maxWidth: 280 }}>
                {locations.length > 1 && <option value="">— Κατάστημα —</option>}
                {locations.map(loc => <option key={loc.id} value={loc.id}>{loc.name}</option>)}
              </select>
            </label>
          )}
          <TrialSlotPicker
            serviceId={trialFor.service_id || planServiceId}
            locationId={when.location_id}
            locationRequired={locations.length > 1}
            date={when.date}
            time={when.time}
            suggestedDate={(trialFor.trial_date || '').slice(0, 10)}
            suggestedTime={(trialFor.trial_time || '').slice(0, 5)}
            onChange={({ date, time }) => setWhen(w => ({ ...w, date, time }))}
          />
          <div style={{ display: 'flex', gap: 8, marginTop: 14 }}>
            <button className="btn btn-primary" type="submit" disabled={!when.time}>Αποδοχή</button>
            <button className="btn btn-secondary" type="button" onClick={() => setTrialFor(null)}>Άκυρο</button>
          </div>
        </form>
      )}

      {rest.length > 0 && (
        <div className="card" style={{ marginTop: 20 }}>
          <div style={{ fontWeight: 700, marginBottom: 8 }}>Ιστορικό</div>
          {rest.map(row => (
            <div key={row.id} style={{ padding: '8px 0', borderTop: '1px solid var(--border)', fontSize: '0.86rem' }}>
              {row.full_name} · {row.plan_name}{row.location_name ? ` · ${row.location_name}` : ''} · {row.status === 'accepted' ? 'Αποδεκτό' : 'Απορρίφθηκε'}
            </div>
          ))}
        </div>
      )}
    </Layout>
  );
}
