import { useEffect, useState } from 'react';
import { UserCheck, UserX, Clock, Users } from 'lucide-react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { fmtDate } from '../utils/dates';

const STATUS_LABELS = { pending: 'Εκκρεμή', approved: 'Εγκεκριμένα', rejected: 'Απορριφθέντα', all: 'Όλα' };

const ROLE_LABELS = { member: 'Μέλος', staff: 'Trainer/Προσωπικό' };

export default function JoinRequests() {
  const [requests, setRequests] = useState([]);
  const [loading, setLoading]   = useState(true);
  const [filter, setFilter]     = useState('pending');

  async function load() {
    setLoading(true);
    try {
      const { data } = await api.get(`/client-admin/join-requests?status=${filter}`);
      setRequests(data);
    } catch (e) {
      toast.error(e.response?.data?.error || 'Σφάλμα φόρτωσης');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { load(); }, [filter]);

  async function decide(id, status) {
    try {
      await api.patch(`/client-admin/join-requests/${id}`, { status });
      toast.success(status === 'approved' ? 'Εγκρίθηκε' : 'Απορρίφθηκε');
      setRequests(prev => prev.filter(r => r.id !== id));
    } catch (e) {
      toast.error(e.response?.data?.error || 'Σφάλμα');
    }
  }

  return (
    <Layout title="Αιτήματα Εγγραφής">
      <div className="page-header">
        <div>
          <h2 className="page-title" style={{ margin: 0 }}>Αιτήματα Εγγραφής</h2>
          <p className="text-muted" style={{ marginTop: 4, fontSize: '0.9rem' }}>
            Χρήστες που ζήτησαν να γίνουν μέλη ή προσωπικό
          </p>
        </div>
      </div>

      {/* Filter tabs */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
        {['pending', 'approved', 'rejected', 'all'].map(s => (
          <button
            key={s}
            type="button"
            onClick={() => setFilter(s)}
            className={filter === s ? 'btn btn-primary btn-sm' : 'btn btn-secondary btn-sm'}
          >
            {STATUS_LABELS[s]}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="empty-state">
          <div className="spinner" style={{ width: 24, height: 24, borderWidth: 2 }} />
        </div>
      ) : requests.length === 0 ? (
        <div className="empty-state">
          <Users size={32} className="empty-state__icon" />
          <p>Δεν υπάρχουν αιτήματα</p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {requests.map(r => (
            <div key={r.id} className="card" style={{ padding: '14px 16px' }}>
              <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12, justifyContent: 'space-between' }}>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                    <span style={{ fontWeight: 700, fontSize: '0.95rem' }}>{r.full_name}</span>
                    {r.role === 'staff' ? (
                      <span style={{
                        background: 'rgba(62,230,255,0.12)', color: '#3EE6FF',
                        border: '1px solid rgba(62,230,255,0.3)',
                        fontSize: '0.72rem', fontWeight: 700, padding: '2px 8px', borderRadius: 20,
                      }}>
                        Trainer
                      </span>
                    ) : (
                      <span style={{
                        background: 'rgba(184,245,94,0.12)', color: 'var(--hs-primary-dark)',
                        border: '1px solid rgba(184,245,94,0.3)',
                        fontSize: '0.72rem', fontWeight: 700, padding: '2px 8px', borderRadius: 20,
                      }}>
                        Μέλος
                      </span>
                    )}
                    {r.status !== 'pending' && (
                      <span style={{
                        fontSize: '0.72rem', fontWeight: 600, padding: '2px 8px', borderRadius: 20,
                        background: r.status === 'approved' ? 'rgba(34,197,94,0.12)' : 'rgba(239,68,68,0.12)',
                        color: r.status === 'approved' ? '#22c55e' : '#ef4444',
                      }}>
                        {r.status === 'approved' ? 'Εγκρίθηκε' : 'Απορρίφθηκε'}
                      </span>
                    )}
                  </div>
                  <div className="text-muted" style={{ fontSize: '0.82rem', marginTop: 4 }}>
                    {r.email && <span>{r.email}</span>}
                    {r.email && r.phone && <span> · </span>}
                    {r.phone && <span>{r.phone}</span>}
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 4, marginTop: 4 }}>
                    <Clock size={12} color="#94a3b8" />
                    <span className="text-muted" style={{ fontSize: '0.75rem' }}>
                      {fmtDate(r.created_at)}
                    </span>
                  </div>
                  {r.admin_note && (
                    <p className="text-muted" style={{ fontSize: '0.78rem', marginTop: 4, fontStyle: 'italic' }}>
                      Σημείωση: {r.admin_note}
                    </p>
                  )}
                </div>

                {r.status === 'pending' && (
                  <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
                    <button
                      type="button"
                      className="btn btn-primary btn-sm"
                      style={{ display: 'flex', alignItems: 'center', gap: 5 }}
                      onClick={() => decide(r.id, 'approved')}
                    >
                      <UserCheck size={14} /> Έγκριση
                    </button>
                    <button
                      type="button"
                      className="btn btn-secondary btn-sm"
                      style={{ display: 'flex', alignItems: 'center', gap: 5 }}
                      onClick={() => decide(r.id, 'rejected')}
                    >
                      <UserX size={14} /> Απόρριψη
                    </button>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </Layout>
  );
}
