import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import { Star, MessageSquare } from 'lucide-react';

function Stars({ rating, size = 15 }) {
  return (
    <span style={{ display: 'inline-flex', gap: 2 }}>
      {[1, 2, 3, 4, 5].map(s => (
        <Star key={s} size={size} fill={s <= rating ? '#F59E0B' : 'none'} color={s <= rating ? '#F59E0B' : '#CBD5E1'} strokeWidth={1.5} />
      ))}
    </span>
  );
}

function fmtDate(iso) {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString('el-GR', { day: 'numeric', month: 'short', year: 'numeric' });
}

const STAR_FILTERS = [
  { label: 'Όλες', value: null },
  { label: '5★', value: 5 },
  { label: '4★', value: 4 },
  { label: '3★', value: 3 },
  { label: '2★', value: 2 },
  { label: '1★', value: 1 },
];

export default function Reviews() {
  const [reviews, setReviews] = useState([]);
  const [total, setTotal] = useState(0);
  const [avgRating, setAvgRating] = useState(null);
  const [totalReviews, setTotalReviews] = useState(0);
  const [loading, setLoading] = useState(true);
  const [minRating, setMinRating] = useState(null);
  const [page, setPage] = useState(1);
  const limit = 30;

  useEffect(() => {
    setLoading(true);
    const params = { page, limit };
    if (minRating) params.min_rating = minRating;
    api.get('/client-admin/reviews', { params })
      .then(r => {
        setReviews(r.data.reviews || []);
        setTotal(r.data.total || 0);
        setAvgRating(r.data.avg_rating);
        setTotalReviews(r.data.total_reviews || 0);
      })
      .catch(e => console.error('Reviews error:', e?.response?.data || e.message))
      .finally(() => setLoading(false));
  }, [page, minRating]);

  const handleFilter = (val) => {
    setMinRating(val);
    setPage(1);
  };

  const totalPages = Math.ceil(total / limit);

  return (
    <Layout>
      <div className="page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 44, height: 44, borderRadius: 14, background: 'linear-gradient(135deg,#fef9c3,#fde68a)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#D97706' }}>
            <Star size={22} fill="#F59E0B" color="#F59E0B" />
          </div>
          <div>
            <h1 className="page-title">Αξιολογήσεις</h1>
            <div className="text-muted" style={{ marginTop: 2 }}>Σχόλια μελών μετά προπόνηση</div>
          </div>
        </div>
        {avgRating && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, background: 'var(--color-surface)', border: '1px solid var(--color-border)', borderRadius: 12, padding: '10px 18px' }}>
            <div style={{ fontSize: 28, fontWeight: 800, color: '#F59E0B', lineHeight: 1 }}>{Number(avgRating).toFixed(1)}</div>
            <div>
              <Stars rating={Math.round(avgRating)} size={16} />
              <div style={{ fontSize: 11, color: '#94A3B8', marginTop: 2 }}>{totalReviews} αξιολογήσεις</div>
            </div>
          </div>
        )}
      </div>

      {/* Star filter chips */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 20, flexWrap: 'wrap' }}>
        {STAR_FILTERS.map(f => {
          const active = minRating === f.value;
          return (
            <button
              key={f.label}
              onClick={() => handleFilter(f.value)}
              style={{
                padding: '7px 16px', borderRadius: 999, border: `1.5px solid ${active ? '#F59E0B' : 'var(--color-border)'}`,
                background: active ? '#FEF3C7' : 'var(--color-surface)',
                color: active ? '#92400E' : 'var(--color-text-muted)',
                fontWeight: active ? 700 : 500, fontSize: 13, cursor: 'pointer', transition: 'all 0.15s',
              }}
            >
              {f.label}
            </button>
          );
        })}
      </div>

      {loading ? <div className="loading">Φόρτωση…</div> : reviews.length === 0 ? (
        <div className="bk-empty">
          <MessageSquare size={36} style={{ margin: '0 auto 10px', display: 'block', color: '#CBD5E1' }} />
          Δεν υπάρχουν αξιολογήσεις ακόμα
        </div>
      ) : (
        <>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {reviews.map(r => (
              <div key={r.id} className="bk-card" style={{ display: 'flex', gap: 16, alignItems: 'flex-start' }}>
                <div style={{ flexShrink: 0 }}>
                  <Stars rating={r.feedback_rating} size={17} />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 8, marginBottom: r.feedback_note ? 8 : 0 }}>
                    <div>
                      <span style={{ fontWeight: 600, fontSize: 14 }}>{r.member_name || 'Ανώνυμο'}</span>
                      {r.service_name && <span style={{ fontSize: 12, color: '#7C3AED', marginLeft: 8, background: '#EDE9FE', padding: '2px 8px', borderRadius: 99 }}>{r.service_name}</span>}
                      {r.staff_name && <span style={{ fontSize: 12, color: '#2563EB', marginLeft: 6 }}>· {r.staff_name}</span>}
                    </div>
                    <span style={{ fontSize: 12, color: '#94A3B8', whiteSpace: 'nowrap' }}>{fmtDate(r.starts_at)}</span>
                  </div>
                  {r.feedback_note && (
                    <p style={{ margin: 0, fontSize: 14, color: 'var(--color-text)', lineHeight: 1.6 }}>{r.feedback_note}</p>
                  )}
                </div>
              </div>
            ))}
          </div>

          {totalPages > 1 && (
            <div style={{ display: 'flex', justifyContent: 'center', gap: 8, marginTop: 24 }}>
              <button className="btn-secondary" onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}>← Προηγ.</button>
              <span style={{ lineHeight: '36px', fontSize: 13, color: '#64748B' }}>{page} / {totalPages}</span>
              <button className="btn-secondary" onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page === totalPages}>Επόμ. →</button>
            </div>
          )}
        </>
      )}
    </Layout>
  );
}
