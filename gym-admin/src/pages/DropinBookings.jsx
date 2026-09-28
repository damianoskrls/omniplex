import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import { Zap, Check, X, CreditCard, Store, Euro } from 'lucide-react';

function fmtDate(iso) {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString('el-GR', { day: 'numeric', month: 'short', year: 'numeric' });
}
function fmtTime(t) {
  if (!t) return '—';
  return t.slice(0, 5);
}
function fmtEuro(cents) {
  return (cents / 100).toFixed(2) + ' €';
}

const STATUS_LABEL = { confirmed: 'Επιβεβαιωμένη', rejected: 'Απορρίφθηκε', attended: 'Παρευρέθηκε', cancelled: 'Ακυρώθηκε', pending: 'Αναμονή' };
const STATUS_BADGE = { confirmed: 'badge-green', rejected: 'badge-red', attended: 'badge-blue', cancelled: 'badge-gray', pending: 'badge-yellow' };
const PAY_LABEL   = { venue: 'Στο χώρο', card: 'Κάρτα' };
const PAY_STATUS  = { pending: 'Εκκρεμεί', paid: 'Πληρώθηκε', failed: 'Απέτυχε' };
const PAY_BADGE   = { pending: 'badge-yellow', paid: 'badge-green', failed: 'badge-red' };

export default function DropinBookings() {
  const [bookings, setBookings] = useState([]);
  const [stats, setStats]       = useState(null);
  const [loading, setLoading]   = useState(true);
  const [statusFilter, setStatusFilter] = useState('');
  const [acting, setActing]     = useState(null);
  const [error, setError]       = useState('');

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      const params = {};
      if (statusFilter) params.status = statusFilter;
      const res = await api.get('/client-admin/dropin-bookings', { params });
      setBookings(res.data.bookings || []);
      setStats(res.data.stats || null);
    } catch (e) {
      setError(e?.response?.data?.error || e?.message || 'Σφάλμα φόρτωσης');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, [statusFilter]);

  const handleAction = async (id, status) => {
    setActing(id + status);
    try {
      await api.patch(`/client-admin/dropin-bookings/${id}`, { status });
      await load();
    } catch {}
    finally { setActing(null); }
  };

  const markPaid = async (id) => {
    setActing(id + 'pay');
    try {
      await api.patch(`/client-admin/dropin-bookings/${id}`, { payment_status: 'paid' });
      await load();
    } catch {}
    finally { setActing(null); }
  };

  const FILTERS = [
    { value: '', label: 'Όλες' },
    { value: 'confirmed', label: 'Επιβεβαιωμένη' },
    { value: 'attended',  label: 'Παρευρέθηκε' },
    { value: 'rejected',  label: 'Απορρίφθηκε' },
    { value: 'cancelled', label: 'Ακυρώθηκε' },
  ];

  return (
    <Layout title="Drop-in Κρατήσεις">
      <div className="page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 44, height: 44, borderRadius: 14, background: '#fefce8', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Zap size={22} style={{ color: '#D97706' }} />
          </div>
          <div>
            <h1 className="page-title">Drop-in Κρατήσεις</h1>
            <p className="text-muted" style={{ marginTop: 2 }}>Μεμονωμένες συνεδρίες χωρίς συνδρομή</p>
          </div>
        </div>
      </div>

      {/* Stats */}
      {stats && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 20 }}>
          {[
            { label: 'Σύνολο',            value: stats.total,                        icon: <Zap size={16} />,        color: '#7C5CFC' },
            { label: 'Επιβεβαιωμένες',   value: stats.confirmed ?? 0,               icon: <Check size={16} />,      color: '#16A34A' },
            { label: 'Έσοδα (card)',      value: fmtEuro(stats.revenue_cents || 0),  icon: <CreditCard size={16} />, color: '#0EA5E9' },
            { label: 'Εκκρεμείς (χώρος)', value: fmtEuro(stats.pending_venue_cents || 0), icon: <Store size={16} />, color: '#D97706' },
          ].map(s => (
            <div key={s.label} className="card" style={{ padding: '14px 16px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: s.color, marginBottom: 6 }}>
                {s.icon}
                <span style={{ fontSize: 12, fontWeight: 600 }}>{s.label}</span>
              </div>
              <div style={{ fontSize: 22, fontWeight: 800 }}>{s.value}</div>
            </div>
          ))}
        </div>
      )}

      {/* Filters */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
        {FILTERS.map(f => (
          <button
            key={f.value}
            className={`btn ${statusFilter === f.value ? 'btn-primary' : 'btn-secondary'}`}
            onClick={() => setStatusFilter(f.value)}
          >
            {f.label}
          </button>
        ))}
      </div>

      {error && (
        <div style={{ background: '#FEE2E2', color: '#DC2626', padding: '12px 16px', borderRadius: 8, marginBottom: 16, fontSize: 14 }}>
          {error}
        </div>
      )}

      {loading ? (
        <div className="text-muted" style={{ padding: 32, textAlign: 'center' }}>Φόρτωση…</div>
      ) : !bookings.length ? (
        <div className="card" style={{ padding: 48, textAlign: 'center' }}>
          <Zap size={40} style={{ margin: '0 auto 12px', display: 'block', color: '#cbd5e1' }} />
          <div className="text-muted">Δεν υπάρχουν drop-in κρατήσεις</div>
        </div>
      ) : (
        <div className="card" style={{ padding: 0 }}>
          <table>
            <thead>
              <tr>
                <th>Πελάτης</th>
                <th>Υπηρεσία</th>
                <th>Ημ/νία & Ώρα</th>
                <th>Κατάσταση</th>
                <th>Πληρωμή</th>
                <th>Τιμή</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {bookings.map(bk => (
                <tr key={bk.id} style={{ verticalAlign: 'middle' }}>
                  <td style={{ verticalAlign: 'middle' }}>
                    <div style={{ fontWeight: 600 }}>{bk.guest_name || 'Χρήστης'}</div>
                    {bk.guest_email && <div className="text-muted" style={{ fontSize: 12 }}>{bk.guest_email}</div>}
                    {bk.guest_phone && <div className="text-muted" style={{ fontSize: 12 }}>{bk.guest_phone}</div>}
                  </td>
                  <td style={{ verticalAlign: 'middle', fontSize: 14 }}>
                    <div style={{ fontWeight: 500 }}>{bk.service_name || '—'}</div>
                    {bk.staff_name && <div className="text-muted" style={{ fontSize: 12 }}>{bk.staff_name}</div>}
                  </td>
                  <td style={{ verticalAlign: 'middle', fontSize: 13 }}>
                    <div>{fmtDate(bk.booking_date)}</div>
                    <div className="text-muted">{fmtTime(bk.booking_time)}</div>
                  </td>
                  <td style={{ verticalAlign: 'middle' }}>
                    <span className={`badge ${STATUS_BADGE[bk.status] || 'badge-gray'}`}>
                      {STATUS_LABEL[bk.status] || bk.status}
                    </span>
                  </td>
                  <td style={{ verticalAlign: 'middle' }}>
                    <div style={{ fontSize: 13, display: 'flex', alignItems: 'center', gap: 5 }}>
                      {bk.payment_method === 'card' ? <CreditCard size={13} /> : <Store size={13} />}
                      {PAY_LABEL[bk.payment_method]}
                    </div>
                    <span className={`badge ${PAY_BADGE[bk.payment_status] || 'badge-gray'}`} style={{ marginTop: 3 }}>
                      {PAY_STATUS[bk.payment_status]}
                    </span>
                  </td>
                  <td style={{ verticalAlign: 'middle', fontWeight: 700, fontSize: 14 }}>
                    {fmtEuro(bk.price_cents)}
                  </td>
                  <td style={{ verticalAlign: 'middle' }}>
                    <div style={{ display: 'flex', gap: 6, flexWrap: 'nowrap' }}>
                      {bk.status === 'confirmed' && (
                        <>
                          <button
                            className="btn btn-sm"
                            style={{ background: '#7C5CFC', color: '#fff', border: 'none' }}
                            disabled={!!acting}
                            onClick={() => handleAction(bk.id, 'attended')}
                          >
                            <Check size={13} /> Παρουσία
                          </button>
                          <button
                            className="btn btn-danger btn-sm"
                            disabled={!!acting}
                            onClick={() => handleAction(bk.id, 'rejected')}
                          >
                            <X size={13} />
                          </button>
                        </>
                      )}
                      {bk.payment_status === 'pending' && bk.payment_method === 'venue' && bk.status === 'confirmed' && (
                        <button
                          className="btn btn-sm"
                          style={{ background: '#DCFCE7', color: '#16A34A', border: '1px solid #bbf7d0' }}
                          disabled={!!acting}
                          onClick={() => markPaid(bk.id)}
                        >
                          <CreditCard size={13} /> Πληρώθηκε
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Layout>
  );
}
