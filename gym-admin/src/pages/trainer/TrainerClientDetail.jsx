import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import Layout from '../../components/Layout';
import api from '../../api/client';
import toast from 'react-hot-toast';
import { ArrowLeft, Save, Target, MessageSquare } from 'lucide-react';

const STATUS_LABEL = {
  pending: 'Αναμονή',
  confirmed: 'Επιβεβαιωμένη',
  cancelled: 'Ακυρωμένη',
  completed: 'Ολοκληρωμένη',
  no_show: 'Δεν προσήλθε',
};

export default function TrainerClientDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [data, setData] = useState(null);
  const [goalOptions, setGoalOptions] = useState([]);
  const [notes, setNotes] = useState('');
  const [fitnessGoal, setFitnessGoal] = useState('');
  const [weight, setWeight] = useState('');
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(true);

  const load = async () => {
    const [detailRes, goalsRes] = await Promise.all([
      api.get(`/client-admin/trainer/clients/${id}`),
      api.get('/client-admin/trainer/fitness-goals'),
    ]);
    setData(detailRes.data);
    setGoalOptions(goalsRes.data);
    setNotes(detailRes.data.client.trainer_notes || '');
    setFitnessGoal(detailRes.data.client.fitness_goal || '');
    setWeight(detailRes.data.client.weight_kg != null ? String(detailRes.data.client.weight_kg) : '');
  };

  useEffect(() => {
    load().catch(() => toast.error('Σφάλμα')).finally(() => setLoading(false));
  }, [id]);

  const save = async () => {
    setSaving(true);
    try {
      await api.patch(`/client-admin/trainer/clients/${id}`, {
        trainer_notes: notes,
        fitness_goal: fitnessGoal || null,
        weight_kg: weight.trim() === '' ? null : Number(weight.replace(',', '.')),
      });
      toast.success('Αποθηκεύτηκε');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };

  if (loading || !data) {
    return <Layout title="Πελάτης" variant="trainer"><div className="loading">Φόρτωση...</div></Layout>;
  }

  const { client, sessions, memberships, stats } = data;

  return (
    <Layout title={client.full_name} variant="trainer">
      <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
        <Link to="/trainer/clients" className="btn btn-secondary btn-sm">
          <ArrowLeft size={14} /> Πίσω
        </Link>
        <button
          type="button"
          className="btn btn-primary btn-sm"
          onClick={() => navigate(`/messages?client=${client.id}`)}
        >
          <MessageSquare size={14} /> Μήνυμα
        </button>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 16, marginBottom: 16 }}>
        <div className="card" style={{ padding: 20 }}>
          <h2 style={{ margin: '0 0 12px', fontSize: '1.2rem' }}>{client.full_name}</h2>
          <div className="text-muted" style={{ fontSize: '0.88rem', lineHeight: 1.6 }}>
            {client.phone && <div>📞 {client.phone}</div>}
            {client.email && <div>✉️ {client.email}</div>}
            {client.age != null && <div>Ηλικία: {client.age}</div>}
            {client.weight_kg != null && <div>Βάρος: {client.weight_kg} kg</div>}
          </div>
        </div>

        <div className="card" style={{ padding: 20 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
            <Target size={18} color="#76C043" />
            <h3 style={{ margin: 0, fontSize: '1rem' }}>Στόχος προπονήσεων</h3>
          </div>
          {stats ? (
            <>
              <div style={{ fontSize: '1.5rem', fontWeight: 800 }}>
                {stats.sessions_this_month} / {stats.goal?.target_sessions || 6}
              </div>
              <div className="text-muted" style={{ fontSize: '0.85rem', marginTop: 4 }}>
                Προπονήσεις αυτόν τον μήνα · {stats.goal_progress_pct}% προόδου
              </div>
              {stats.goal_met && (
                <span className="badge badge-green" style={{ marginTop: 8 }}>Στόχος επιτεύχθηκε!</span>
              )}
            </>
          ) : (
            <span className="text-muted">—</span>
          )}
        </div>
      </div>

      <div className="card" style={{ padding: 20, marginBottom: 16 }}>
        <h3 style={{ margin: '0 0 14px' }}>Στόχος & σημειώσεις γυμναστή</h3>
        <div style={{ display: 'grid', gap: 14, maxWidth: 560 }}>
          <div>
            <label className="form-label">Στόχος φυσικής κατάστασης</label>
            <select className="form-input" value={fitnessGoal} onChange={e => setFitnessGoal(e.target.value)}>
              <option value="">— Δεν έχει οριστεί —</option>
              {goalOptions.map(g => (
                <option key={g.id} value={g.id}>{g.label}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="form-label">Βάρος (kg)</label>
            <input className="form-input" value={weight} onChange={e => setWeight(e.target.value)} placeholder="π.χ. 78.5" />
          </div>
          <div>
            <label className="form-label">Σημειώσεις γυμναστή (ιδιωτικές)</label>
            <textarea
              className="form-input"
              rows={4}
              value={notes}
              onChange={e => setNotes(e.target.value)}
              placeholder="Τραυματισμοί, προτιμήσεις, πρόοδος..."
            />
          </div>
          <button className="btn btn-primary" onClick={save} disabled={saving}>
            <Save size={14} /> {saving ? 'Αποθήκευση...' : 'Αποθήκευση'}
          </button>
        </div>
      </div>

      {memberships?.length > 0 && (
        <div className="card" style={{ padding: 20, marginBottom: 16 }}>
          <h3 style={{ margin: '0 0 12px' }}>Ενεργά πακέτα</h3>
          {memberships.map(m => (
            <div key={m.id} style={{ padding: '8px 0', borderBottom: '1px solid #f1f5f9', fontSize: '0.9rem' }}>
              <strong>{m.service_name || m.plan_name}</strong>
              <span className="text-muted">
                {' · '}{m.valid_from?.slice(0, 10)} → {m.valid_until?.slice(0, 10)}
                {' · '}{m.total_sessions >= 9999 ? '∞' : `${m.total_sessions - m.used_sessions}/${m.total_sessions}`} συν.
              </span>
            </div>
          ))}
        </div>
      )}

      <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
        <div style={{ padding: '16px 20px', borderBottom: '1px solid #e2e8f0' }}>
          <h3 style={{ margin: 0 }}>Ιστορικό συνεδριών μαζί σου</h3>
        </div>
        <table>
          <thead>
            <tr><th>Ημερομηνία</th><th>Υπηρεσία</th><th>Κατάσταση</th><th>Health</th></tr>
          </thead>
          <tbody>
            {sessions.map(s => (
              <tr key={s.id}>
                <td>{new Date(s.starts_at).toLocaleString('el-GR')}</td>
                <td>{s.service_name}{s.schedule_label ? ` · ${s.schedule_label}` : ''}</td>
                <td>{STATUS_LABEL[s.status] || s.status}</td>
                <td className="text-muted" style={{ fontSize: '0.82rem' }}>
                  {s.health_calories_kcal
                    ? `${s.health_calories_kcal} kcal · ${s.health_duration_mins || '—'}′`
                    : '—'}
                </td>
              </tr>
            ))}
            {!sessions.length && <tr><td colSpan={4} className="loading">Καμία συνεδρία</td></tr>}
          </tbody>
        </table>
      </div>
    </Layout>
  );
}
