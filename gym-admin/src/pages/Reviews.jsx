import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import { Star, MessageSquare, Filter } from 'lucide-react';

const biz = () => JSON.parse(localStorage.getItem('gym_admin_business') || '{}');

function Stars({ rating, size = 14 }) {
  return (
    <span style={{ display: 'inline-flex', gap: 2 }}>
      {[1, 2, 3, 4, 5].map(s => (
        <Star key={s} size={size} fill={s <= rating ? '#F59E0B' : 'none'} color={s <= rating ? '#F59E0B' : '#CBD5E1'} />
      ))}
    </span>
  );
}

function fmtDate(iso) {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString('el-GR', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
}

export default function Reviews() {
  const bizId = biz().id;
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [minRating, setMinRating] = useState('');
  const [page, setPage] = useState(1);
  const PAGE_SIZE = 30;

  const load = async () => {
    setLoading(true);
    try {
      const params = { page, limit: PAGE_SIZE };
      if (minRating) params.min_rating = minRating;
      const r = await api.get('/reviews', { params });
      setData(r.data);
    } catch { /* silent */ }
    finally { setLoading(false); }
  };

  useEffect(() => { load(); }, [page, minRating]);

  const totalPages = data ? Math.ceil(data.total / PAGE_SIZE) : 1;

  return (
    <Layout>
      <div className="page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 44, height: 44, borderRadius: 14, background: 'linear-gradient(135deg,#fef3c7,#fde68a)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#D97706' }}>
            <Star size={22} />
          </div>
          <div>
            <h1 className="page-title">Αξιολογήσεις</h1>
            <div className="text-muted" style={{ marginTop: 2 }}>Σχόλια μελών μετά προπόνηση</div>
          </div>
        </div>
      </div>

      {/* Summary bar */}
      {data && (
        <div style={{ display: 'flex', gap: 16, marginBottom: 24, flexWrap: 'wrap' }}>
          <div className="bk-card" style={{ flex: '0 0 auto', minWidth: 160, textAlign: 'center' }}>
            <div style={{ fontSize: 32, fontWeight: 800, color: '#D97706', lineHeight: 1 }}>
              {data.avg_rating ?? '—'}
            </div>
            <Stars rating={Math.round(data.avg_rating || 0)} size={16} />
            <div className="text-muted" style={{ fontSize: 12, marginTop: 4 }}>
              {data.total_reviews} αξιολογήσεις
            </div>
          </div>
          {[5,4,3,2,1].map(r => {
            const count = data.reviews.filter(rv => rv.feedback_rating === r).length;
            return (
              <div key={r} style={{ display: 'flex', alignItems: 'center', gap: 8, minWidth: 140 }}>
                <Stars rating={r} size={12} />
                <div style={{ flex: 1, height: 8, background: '#F1F5F9', borderRadius: 99, overflow: 'hidden' }}>
                  <div style={{ height: '100%', width: `${data.total_reviews ? (count / data.reviews.length) * 100 : 0}%`, background: '#F59E0B', borderRadius: 99 }} />
                </div>
                <span className="text-muted" style={{ fontSize: 12, minWidth: 20 }}>{count}</span>
              </div>
            );
          })}
        </div>
      )}

      {/* Filters */}
      <div style={{ display: 'flex', gap: 10, marginBottom: 18, alignItems: 'center' }}>
        <Filter size={15} style={{ color: '#94a3b8' }} />
        <select className="form-select" style={{ width: 160 }} value={minRating} onChange={e => { setMinRating(e.target.value); setPage(1); }}>
          <option value="">Όλες οι βαθμολογίες</option>
          <option value="5">5 αστέρια</option>
          <option value="4">4+ αστέρια</option>
          <option value="3">3+ αστέρια</option>
          <option value="1">Αρνητικές (1-2)</option>
        </select>
      </div>

      {loading ? (
        <div className="loading">Φόρτωση…</div>
      ) : !data?.reviews?.length ? (
        <div className="bk-empty">
          <MessageSquare size={40} style={{ margin: '0 auto 12px', display: 'block', color: '#94a3b8' }} />
          <div>Δεν υπάρχουν αξιολογήσεις ακόμα</div>
        </div>
      ) : (
        <>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {data.reviews.map(rv => (
              <div key={rv.id} className="bk-card" style={{ padding: '16px 20px' }}>
                <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
                  <div>
                    <div style={{ fontWeight: 700, fontSize: 15, marginBottom: 2 }}>{rv.member_name || 'Άγνωστο μέλος'}</div>
                    <div className="text-muted" style={{ fontSize: 13 }}>
                      {rv.service_name}
                      {rv.staff_name ? ` · ${rv.staff_name}` : ''}
                      {' · '}
                      {fmtDate(rv.starts_at)}
                    </div>
                  </div>
                  <Stars rating={rv.feedback_rating} size={18} />
                </div>
                {rv.feedback_note && (
                  <div style={{ marginTop: 12, padding: '10px 14px', background: '#F8FAFC', borderRadius: 8, borderLeft: '3px solid #E2E8F0', fontSize: 14, color: '#374151', lineHeight: 1.6 }}>
                    "{rv.feedback_note}"
                  </div>
                )}
              </div>
            ))}
          </div>

          {totalPages > 1 && (
            <div style={{ display: 'flex', justifyContent: 'center', gap: 8, marginTop: 20 }}>
              <button className="btn btn-secondary btn-sm" disabled={page === 1} onClick={() => setPage(p => p - 1)}>Προηγ.</button>
              <span style={{ display: 'flex', alignItems: 'center', fontSize: 13, color: '#64748b' }}>
                {page} / {totalPages}
              </span>
              <button className="btn btn-secondary btn-sm" disabled={page === totalPages} onClick={() => setPage(p => p + 1)}>Επόμ.</button>
            </div>
          )}
        </>
      )}
    </Layout>
  );
}
