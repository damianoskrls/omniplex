import { useEffect, useState } from 'react';
import Layout from '../../components/Layout';
import AvailabilityEditor from '../../components/AvailabilityEditor';
import api from '../../api/client';
import toast from 'react-hot-toast';
import { Clock, Save } from 'lucide-react';

function parseGymHours(raw) {
  if (!raw) return null;
  try { return typeof raw === 'string' ? JSON.parse(raw) : raw; } catch { return null; }
}

export default function TrainerAvailability() {
  const [services, setServices] = useState([]);
  const [activeServiceId, setActiveServiceId] = useState(null);
  const [approved, setApproved] = useState([]);
  const [draft, setDraft] = useState([]);
  const [pending, setPending] = useState(null);
  const [gymHours, setGymHours] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    api.get('/client-admin/trainer/bootstrap')
      .then(r => {
        setServices(r.data.services || []);
        setGymHours(parseGymHours(r.data.opening_hours));
        if (r.data.services?.length) setActiveServiceId(r.data.services[0].id);
      })
      .catch(() => toast.error('Σφάλμα φόρτωσης'))
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    if (!activeServiceId) return;
    api.get('/client-admin/trainer/availability', { params: { service_id: activeServiceId } })
      .then(r => {
        setApproved(r.data.approved || []);
        setPending(r.data.pending || null);
        setDraft(r.data.pending?.slots?.length ? r.data.pending.slots : (r.data.approved || []));
      })
      .catch(() => toast.error('Σφάλμα φόρτωσης διαθεσιμότητας'));
  }, [activeServiceId]);

  const submit = async () => {
    if (!activeServiceId) return;
    setSaving(true);
    try {
      await api.put('/client-admin/trainer/availability', {
        service_id: activeServiceId,
        slots: draft,
      });
      toast.success('Η αίτηση υποβλήθηκε — αναμονή έγκρισης από admin');
      const r = await api.get('/client-admin/trainer/availability', { params: { service_id: activeServiceId } });
      setApproved(r.data.approved || []);
      setPending(r.data.pending || null);
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return <Layout title="Διαθεσιμότητα" variant="trainer"><div className="loading">Φόρτωση...</div></Layout>;
  }

  const activeService = services.find(s => s.id === activeServiceId);

  return (
    <Layout title="Διαθεσιμότητα" variant="trainer">
      <div className="page-header">
        <div>
          <h1 className="page-title">Η διαθεσιμότητά μου</h1>
          <p className="text-muted" style={{ margin: '6px 0 0' }}>
            Οι αλλαγές υποβάλλονται για έγκριση από τον διαχειριστή
          </p>
        </div>
      </div>

      {pending && (
        <div className="card" style={{ marginBottom: 16, padding: 16, borderLeft: '4px solid #f59e0b', background: '#fffbeb' }}>
          <div style={{ fontWeight: 700, color: '#b45309', marginBottom: 4 }}>
            <Clock size={16} style={{ verticalAlign: -3, marginRight: 6 }} />
            Αίτηση σε αναμονή
          </div>
          <p className="text-muted" style={{ fontSize: '0.88rem', margin: 0 }}>
            Υπάρχει υποβληθείσα αλλαγή από {new Date(pending.submitted_at).toLocaleString('el-GR')}.
            Μπορείς να την ενημερώσεις και να την ξαναστείλεις.
          </p>
        </div>
      )}

      {!services.length ? (
        <div className="card" style={{ padding: 40, textAlign: 'center' }}>
          <p className="text-muted">Δεν σου έχουν ανατεθεί υπηρεσίες ακόμα. Επικοινώνησε με τον διαχειριστή.</p>
        </div>
      ) : (
        <>
          <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
            {services.map(s => (
              <button
                key={s.id}
                type="button"
                className={`btn btn-sm ${activeServiceId === s.id ? 'btn-primary' : 'btn-secondary'}`}
                onClick={() => setActiveServiceId(s.id)}
              >
                {s.name}
              </button>
            ))}
          </div>

          <div className="card" style={{ padding: 20, marginBottom: 16 }}>
            <h2 style={{ margin: '0 0 6px', fontSize: '1rem' }}>{activeService?.name}</h2>
            <p className="text-muted" style={{ fontSize: '0.85rem', marginBottom: 16 }}>
              Τρέχουσα εγκεκριμένη: {approved.length} slot{approved.length === 1 ? '' : 's'}
            </p>
            <AvailabilityEditor slots={draft} onChange={setDraft} gymHours={gymHours} />
          </div>

          <button type="button" className="btn btn-primary" disabled={saving} onClick={submit}>
            <Save size={16} /> {saving ? 'Υποβολή...' : pending ? 'Ενημέρωση αίτησης' : 'Υποβολή για έγκριση'}
          </button>
        </>
      )}
    </Layout>
  );
}
