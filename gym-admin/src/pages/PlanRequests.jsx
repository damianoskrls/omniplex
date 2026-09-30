import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';

export default function PlanRequests() {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState('');
  const [trialFor, setTrialFor] = useState(null);
  const [when, setWhen] = useState({ date: '', time: '18:00' });

  async function load() {
    setLoading(true);
    setLoadError('');
    try {
      const r = await api.get('/client-admin/plan-requests');
      setRows(r.data || []);
    } catch (err) {
      const msg = err.response?.data?.error || 'Σφάλμα φόρτωσης';
      setLoadError(msg);
      toast.error(msg);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { load(); }, []);

  async function reject(id) {
    try {
      await api.post(`/client-admin/plan-requests/${id}/reject`);
      toast.success('Το αίτημα απορρίφθηκε');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  }

  async function acceptEnroll(id) {
    try {
      const r = await api.post(`/client-admin/plan-requests/${id}/accept`, {});
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
      const r = await api.post(`/client-admin/plan-requests/${trialFor.id}/accept`, {
        trial_date: when.date,
        trial_time: when.time,
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
      <p style={{ color: 'var(--text-2)', marginTop: -8, marginBottom: 16, maxWidth: 720 }}>
        Όταν ένα μέλος ζητάει άλλο πρόγραμμα, το βλέπεις εδώ. Αν ζητάει εγγραφή, η αποδοχή προσθέτει το πακέτο και η πληρωμή μένει εκκρεμής στην καρτέλα του. Αν ζητάει δοκιμαστικό, ορίζεις μέρα και ώρα.
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
            {row.phone ? ` · ${row.phone}` : ''}
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            {row.kind === 'trial' ? (
              <button className="btn btn-primary btn-sm" onClick={() => { setTrialFor(row); setWhen({ date: '', time: '18:00' }); }}>
                Κλείσε δοκιμαστικό
              </button>
            ) : (
              <button className="btn btn-primary btn-sm" onClick={() => acceptEnroll(row.id)}>Αποδοχή και εκκρεμής πληρωμή</button>
            )}
            <button className="btn btn-secondary btn-sm" onClick={() => reject(row.id)}>Απόρριψη</button>
          </div>
        </div>
      ))}

      {trialFor && (
        <form className="card" onSubmit={acceptTrial} style={{ marginTop: 8 }}>
          <div style={{ fontWeight: 700, marginBottom: 10 }}>Δοκιμαστικό για {trialFor.full_name}</div>
          <div style={{ display: 'flex', gap: 8 }}>
            <input className="form-input" type="date" required value={when.date} onChange={e => setWhen(w => ({ ...w, date: e.target.value }))} />
            <input className="form-input" type="time" required value={when.time} onChange={e => setWhen(w => ({ ...w, time: e.target.value }))} />
            <button className="btn btn-primary" type="submit">Αποδοχή</button>
            <button className="btn btn-secondary" type="button" onClick={() => setTrialFor(null)}>Άκυρο</button>
          </div>
        </form>
      )}

      {rest.length > 0 && (
        <div className="card" style={{ marginTop: 20 }}>
          <div style={{ fontWeight: 700, marginBottom: 8 }}>Ιστορικό</div>
          {rest.map(row => (
            <div key={row.id} style={{ padding: '8px 0', borderTop: '1px solid var(--border)', fontSize: '0.86rem' }}>
              {row.full_name} · {row.plan_name} · {row.status === 'accepted' ? 'Αποδεκτό' : 'Απορρίφθηκε'}
            </div>
          ))}
        </div>
      )}
    </Layout>
  );
}
