import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import { Zap, Check, X, Clock, CreditCard, Store, Euro } from 'lucide-react';

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
const STATUS_COLOR = { confirmed: '#16A34A', rejected: '#DC2626', attended: '#7C5CFC', cancelled: '#9CA3AF', pending: '#D97706' };
const STATUS_BG   = { confirmed: '#DCFCE7', rejected: '#FEE2E2', attended: '#EDE9FE', cancelled: '#F3F4F6', pending: '#FEF3C7' };
const PAY_LABEL   = { venue: 'Στο χώρο', card: 'Κάρτα' };
const PAY_STATUS  = { pending: 'Εκκρεμεί', paid: 'Πληρώθηκε', failed: 'Απέτυχε' };
const PAY_COLOR   = { pending: '#D97706', paid: '#16A34A', failed: '#DC2626' };

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
    } catch { /* silent */ }
    finally { setActing(null); }
  };

  const markPaid = async (id) => {
    setActing(id + 'pay');
    try {
      await api.patch(`/client-admin/dropin-bookings/${id}`, { payment_status: 'paid' });
      await load();
    } catch { /* silent */ }
    finally { setActing(null); }
  };

  return (
    <Layout>
      <div className="page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 44, height: 44, borderRadius: 14, background: 'linear-gradient(135deg,#fefce8,#fde68a)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#D97706' }}>
            <Zap size={22} />
          </div>
          <div>
            <h1 className="page-title">Drop-in Κρατήσεις</h1>
            <div className="text-muted" style={{ marginTop: 2 }}>Μεμονωμένες συνεδρίες χωρίς συνδρομή</div>
          </div>
        </div>
      </div>

      {/* Stats */}
      {stats && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 20 }}>
          {[
            { label: 'Σύνολο', value: stats.total, icon: <Zap size={16} />, color: '#7C5CFC' },
            { label: 'Επιβεβαιωμένες', value: stats.confirmed, icon: <Check size={16} />, color: '#16A34A' },
            { label: 'Έσοδα (card)', value: fmtEuro(stats.revenue_cents || 0), icon: <CreditCard size={16} />, color: '#0EA5E9' },
            { label: 'Εκκρεμείς (χώρος)', value: fmtEuro(stats.pending_venue_cents || 0), icon: <Store size={16} />, color: '#D97706' },
          ].map(s => (
            <div key={s.label} className="bk-card" style={{ padding: '14px 16px' }}>
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
        {['', 'confirmed', 'attended', 'rejected', 'cancelled'].map(s => (
          <button
            key={s}
            className={`bk-tag ${statusFilter === s ? 'active' : ''}`}
            onClick={() => setStatusFilter(s)}
          >
            {s === '' ? 'Όλες' : STATUS_LABEL[s]}
          </button>
        ))}
      </div>

      {error && (
        <div style={{ background: '#FEE2E2', color: '#DC2626', padding: '12px 16px', borderRadius: 8, marginBottom: 16, fontSize: 14 }}>
          {error}
        </div>
      )}

      {loading ? (
        <div className="loading">Φόρτωση…</div>
      ) : !bookings.length ? (
        <div className="bk-empty">
          <Zap size={40} style={{ margin: '0 auto 12px', display: 'block', color: '#94a3b8' }} />
          <div>Δεν υπάρχουν drop-in κρατήσεις</div>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {bookings.map(bk => (
            <div key={bk.id} className="bk-card" style={{ padding: '14px 18px' }}>
              <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4, flexWrap: 'wrap' }}>
                    <span style={{ fontWeight: 700, fontSize: 15 }}>
                      {bk.guest_name || bk.user_id || 'Χρήστης'}
                    </span>
                    <span style={{
                      fontSize: 11, fontWeight: 700, padding: '2px 8px', borderRadius: 99,
                      background: STATUS_BG[bk.status], color: STATUS_COLOR[bk.status],
                    }}>
                      {STATUS_LABEL[bk.status] || bk.status}
                    </span>
                    <span style={{
                      fontSize: 11, fontWeight: 600, padding: '2px 8px', borderRadius: 99,
                      background: '#F0FDF4', color: PAY_COLOR[bk.payment_status],
                    }}>
                      {PAY_STATUS[bk.payment_status]}
                    </span>
                  </div>
                  <div className="text-muted" style={{ fontSize: 13 }}>
                    <strong>{bk.service_name}</strong>
                    {' · '}
                    {fmtDate(bk.booking_date)} {fmtTime(bk.booking_time)}
                    {bk.staff_name && ` · ${bk.staff_name}`}
                  </div>
                  <div className="text-muted" style={{ fontSize: 12, marginTop: 4, display: 'flex', gap: 12, flexWrap: 'wrap' }}>
                    {bk.guest_email && <span>✉ {bk.guest_email}</span>}
                    {bk.guest_phone && <span>📞 {bk.guest_phone}</span>}
                    <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                      {bk.payment_method === 'card' ? <CreditCard size={12} /> : <Store size={12} />}
                      {PAY_LABEL[bk.payment_method]}
                      {' · '}
                      <Euro size={12} />{fmtEuro(bk.price_cents)}
                    </span>
                  </div>
                </div>

                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center' }}>
                  {bk.status === 'confirmed' && (
                    <>
                      <button
                        className="bk-btn bk-btn-sm"
                        style={{ background: '#7C5CFC', color: '#fff', border: 'none' }}
                        disabled={!!acting}
                        onClick={() => handleAction(bk.id, 'attended')}
                      >
                        <Check size={13} /> Παρουσία
                      </button>
                      <button
                        className="bk-btn bk-btn-sm"
                        style={{ background: '#FEE2E2', color: '#DC2626', border: 'none' }}
                        disabled={!!acting}
                        onClick={() => handleAction(bk.id, 'rejected')}
                      >
                        <X size={13} /> Απόρριψη
                      </button>
                    </>
                  )}
                  {bk.payment_status === 'pending' && bk.payment_method === 'venue' && bk.status === 'confirmed' && (
                    <button
                      className="bk-btn bk-btn-sm"
                      style={{ background: '#DCFCE7', color: '#16A34A', border: 'none' }}
                      disabled={!!acting}
                      onClick={() => markPaid(bk.id)}
                    >
                      <CreditCard size={13} /> Πληρώθηκε
                    </button>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </Layout>
  );
}
