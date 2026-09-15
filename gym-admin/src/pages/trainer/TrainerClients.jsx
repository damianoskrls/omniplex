import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import Layout from '../../components/Layout';
import api from '../../api/client';
import toast from 'react-hot-toast';
import { ChevronRight, Target, User } from 'lucide-react';

export default function TrainerClients() {
  const [clients, setClients] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get('/client-admin/trainer/clients')
      .then(r => setClients(r.data))
      .catch(() => toast.error('Σφάλμα φόρτωσης'))
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return <Layout title="Πελάτες" variant="trainer"><div className="loading">Φόρτωση...</div></Layout>;
  }

  return (
    <Layout title="Πελάτες" variant="trainer">
      <div className="page-header">
        <div>
          <h1 className="page-title">Οι ασκούμενοί μου</h1>
          <p className="text-muted" style={{ margin: '6px 0 0' }}>
            Πελάτες με κρατήσεις στο πρόγραμμά σου — στόχοι & σημειώσεις
          </p>
        </div>
      </div>

      <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
        {!clients.length ? (
          <div className="loading" style={{ padding: 40 }}>Δεν υπάρχουν πελάτες ακόμα</div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Πελάτης</th>
                <th>Στόχος</th>
                <th>Επόμενη</th>
                <th>Συνεδρίες</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {clients.map(c => (
                <tr key={c.id}>
                  <td>
                    <div style={{ fontWeight: 700 }}>{c.full_name}</div>
                    <div className="text-muted" style={{ fontSize: '0.8rem' }}>{c.phone || c.email}</div>
                  </td>
                  <td>
                    {c.fitness_goal_label ? (
                      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontSize: '0.85rem' }}>
                        <Target size={14} /> {c.fitness_goal_label}
                      </span>
                    ) : (
                      <span className="text-muted">—</span>
                    )}
                  </td>
                  <td>
                    {c.next_session_at
                      ? new Date(c.next_session_at).toLocaleString('el-GR', {
                        day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit',
                      })
                      : '—'}
                  </td>
                  <td>{c.sessions_total}</td>
                  <td>
                    <Link to={`/trainer/clients/${c.id}`} className="btn btn-secondary btn-sm">
                      Προφίλ <ChevronRight size={14} />
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </Layout>
  );
}
