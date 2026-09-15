import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Check, Plus, Trash2, X } from 'lucide-react';
import NutritionCreateBookingModal from './NutritionCreateBookingModal';

const STATUS_LABEL = {
  pending: 'Αναμονή',
  confirmed: 'Επιβεβαιωμένη',
  cancelled: 'Ακυρωμένη',
  completed: 'Ολοκληρωμένη',
  no_show: 'Δεν προσήλθε',
};

export default function NutritionBookings() {
  const [bookings, setBookings] = useState([]);
  const [filter, setFilter] = useState('');
  const [loading, setLoading] = useState(true);
  const [createOpen, setCreateOpen] = useState(false);

  const load = async () => {
    const res = await api.get('/client-admin/nutrition/bookings', {
      params: filter ? { status: filter } : {},
    });
    setBookings(res.data);
  };

  useEffect(() => {
    setLoading(true);
    load().catch(() => toast.error('Σφάλμα')).finally(() => setLoading(false));
  }, [filter]);

  const updateStatus = async (id, status) => {
    try {
      await api.patch(`/client-admin/nutrition/bookings/${id}/status`, { status });
      toast.success(status === 'confirmed' ? 'Επιβεβαιώθηκε' : 'Ενημερώθηκε');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const deleteBooking = async (booking) => {
    if (!window.confirm(`Διαγραφή κράτησης για ${booking.client_name};`)) return;
    try {
      await api.delete(`/client-admin/nutrition/bookings/${booking.id}`);
      toast.success('Η κράτηση διαγράφηκε');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  if (loading) return <Layout title="Κρατήσεις διατροφής" variant="nutrition"><div className="loading">Φόρτωση...</div></Layout>;

  return (
    <Layout title="Κρατήσεις διατροφής" variant="nutrition">
      <div className="page-header">
        <div>
          <h1 className="page-title">Κρατήσεις διατροφολόγου</h1>
          <p className="text-muted" style={{ margin: '6px 0 0' }}>
            Επιβεβαίωση αιτημάτων ή νέα κράτηση για πελάτη με διαθέσιμες επισκέψεις
          </p>
        </div>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
          {['pending', 'confirmed', ''].map(f => (
            <button
              key={f || 'all'}
              type="button"
              className={`btn btn-sm ${filter === f ? 'btn-primary' : 'btn-secondary'}`}
              onClick={() => setFilter(f)}
            >
              {f === 'pending' ? 'Αναμονή' : f === 'confirmed' ? 'Επιβεβαιωμένες' : 'Όλες'}
            </button>
          ))}
          <button type="button" className="btn btn-primary btn-sm" onClick={() => setCreateOpen(true)}>
            <Plus size={14} /> Νέα κράτηση
          </button>
        </div>
      </div>

      <div className="card">
        <table>
          <thead>
            <tr><th>Πελάτης</th><th>Ημερομηνία</th><th>Κατάσταση</th><th></th></tr>
          </thead>
          <tbody>
            {bookings.map(b => {
              const dt = new Date(b.starts_at);
              return (
                <tr key={b.id}>
                  <td>
                    <div style={{ fontWeight: 600 }}>{b.client_name}</div>
                    <div className="text-muted" style={{ fontSize: '0.8rem' }}>{b.client_email}</div>
                  </td>
                  <td>
                    {dt.toLocaleString('el-GR')}
                    {b.nutritionist_name && (
                      <div className="text-muted" style={{ fontSize: '0.75rem' }}>{b.nutritionist_name}</div>
                    )}
                  </td>
                  <td><span className={`badge ${b.status === 'pending' ? 'badge-yellow' : 'badge-green'}`}>{STATUS_LABEL[b.status] || b.status}</span></td>
                  <td style={{ display: 'flex', gap: 6 }}>
                    {b.status === 'pending' && (
                      <>
                        <button className="btn btn-primary btn-sm" onClick={() => updateStatus(b.id, 'confirmed')}><Check size={14} /></button>
                        <button className="btn btn-danger btn-sm" onClick={() => updateStatus(b.id, 'cancelled')}><X size={14} /></button>
                      </>
                    )}
                    <button className="btn btn-danger btn-sm" onClick={() => deleteBooking(b)} title="Διαγραφή">
                      <Trash2 size={14} />
                    </button>
                  </td>
                </tr>
              );
            })}
            {!bookings.length && <tr><td colSpan={4} className="loading">Δεν υπάρχουν κρατήσεις</td></tr>}
          </tbody>
        </table>
      </div>

      <NutritionCreateBookingModal
        open={createOpen}
        onClose={() => setCreateOpen(false)}
        onSuccess={load}
      />
    </Layout>
  );
}
