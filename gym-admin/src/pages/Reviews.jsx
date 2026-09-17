import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import { Star, MessageSquare, ChevronLeft, ChevronRight } from 'lucide-react';

function StarRow({ rating, size = 15, interactive = false, onRate }) {
  const [hover, setHover] = useState(0);
  return (
    <span style={{ display: 'inline-flex', gap: 2 }}>
      {[1, 2, 3, 4, 5].map(s => {
        const filled = s <= (hover || rating);
        return (
          <Star
            key={s} size={size}
            fill={filled ? '#F59E0B' : 'none'}
            color={filled ? '#F59E0B' : '#D1D5DB'}
            strokeWidth={1.5}
            style={{ cursor: interactive ? 'pointer' : 'default', transition: 'transform 0.1s', transform: hover === s ? 'scale(1.2)' : 'scale(1)' }}
            onMouseEnter={() => interactive && setHover(s)}
            onMouseLeave={() => interactive && setHover(0)}
            onClick={() => interactive && onRate?.(s)}
          />
        );
      })}
    </span>
  );
}

function RatingBar({ count, total, stars }) {
  const pct = total > 0 ? (count / total) * 100 : 0;
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 12 }}>
      <span style={{ color: 'var(--text-3)', width: 14, textAlign: 'right', fontWeight: 500 }}>{stars}</span>
      <Star size={10} fill="#F59E0B" color="#F59E0B" />
      <div style={{ flex: 1, height: 6, background: 'var(--surface-2)', borderRadius: 99, overflow: 'hidden' }}>
        <div style={{ height: '100%', width: `${pct}%`, background: 'linear-gradient(90deg,#FCD34D,#F59E0B)', borderRadius: 99, transition: 'width 0.5s' }} />
      </div>
      <span style={{ color: 'var(--text-3)', width: 22, textAlign: 'right' }}>{count}</span>
    </div>
  );
}

function fmtDate(iso) {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString('el-GR', { day: 'numeric', month: 'short', year: 'numeric' });
}

function initials(name) {
  if (!name) return '?';
  return name.split(' ').map(w => w[0]).slice(0, 2).join('').toUpperCase();
}

const COLORS = ['#7C3AED','#2563EB','#0891B2','#10B981','#D97706','#DB2777'];

export default function Reviews() {
  const [reviews, setReviews] = useState([]);
  const [total, setTotal] = useState(0);
  const [avgRating, setAvgRating] = useState(null);
  const [totalReviews, setTotalReviews] = useState(0);
  const [loading, setLoading] = useState(true);
  const [minRating, setMinRating] = useState(null);
  const [page, setPage] = useState(1);
  const limit = 20;

  // For breakdown
  const [breakdown, setBreakdown] = useState({});

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

  // compute breakdown from current reviews (approximate)
  useEffect(() => {
    const bd = {};
    reviews.forEach(r => { bd[r.feedback_rating] = (bd[r.feedback_rating] || 0) + 1; });
    setBreakdown(bd);
  }, [reviews]);

  const totalPages = Math.ceil(total / limit);
  const avgNum = Number(avgRating || 0);

  return (
    <Layout>
      <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 28 }}>
        <div style={{
          width: 48, height: 48, borderRadius: 16,
          background: 'linear-gradient(135deg,#FCD34D,#F59E0B)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          boxShadow: '0 8px 20px rgba(245,158,11,0.3)',
        }}>
          <Star size={22} color="#fff" fill="#fff" strokeWidth={0} />
        </div>
        <div>
          <h1 style={{ fontSize: 22, fontWeight: 800, color: 'var(--text)', letterSpacing: '-0.3px' }}>Αξιολογήσεις</h1>
          <p style={{ fontSize: 13, color: 'var(--text-3)', marginTop: 2 }}>Σχόλια μελών μετά από κάθε προπόνηση</p>
        </div>
      </div>

      {/* Summary card + filter */}
      {totalReviews > 0 && (
        <div style={{
          background: 'var(--surface)', borderRadius: 18, border: '1px solid var(--border)',
          padding: '20px 24px', marginBottom: 20, display: 'flex', alignItems: 'center', gap: 32, flexWrap: 'wrap',
        }}>
          {/* Big avg */}
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: 52, fontWeight: 900, color: 'var(--text)', letterSpacing: '-2px', lineHeight: 1 }}>
              {avgNum.toFixed(1)}
            </div>
            <StarRow rating={Math.round(avgNum)} size={18} />
            <div style={{ fontSize: 12, color: 'var(--text-3)', marginTop: 4 }}>{totalReviews} αξιολογήσεις</div>
          </div>
          {/* Breakdown bars */}
          <div style={{ flex: 1, minWidth: 180, display: 'flex', flexDirection: 'column', gap: 6 }}>
            {[5, 4, 3, 2, 1].map(s => (
              <RatingBar key={s} stars={s} count={breakdown[s] || 0} total={reviews.length} />
            ))}
          </div>
        </div>
      )}

      {/* Filter chips */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 20, flexWrap: 'wrap' }}>
        {[{ label: 'Όλες', val: null }, { label: '5★', val: 5 }, { label: '4★', val: 4 }, { label: '3★', val: 3 }, { label: '2★', val: 2 }, { label: '1★', val: 1 }].map(f => {
          const active = minRating === f.val;
          return (
            <button key={f.label} onClick={() => { setMinRating(f.val); setPage(1); }} style={{
              padding: '7px 18px', borderRadius: 99,
              border: `1.5px solid ${active ? '#F59E0B' : 'var(--border)'}`,
              background: active ? 'linear-gradient(135deg,#FEF3C7,#FDE68A)' : 'var(--surface)',
              color: active ? '#92400E' : 'var(--text-2)',
              fontWeight: active ? 700 : 500, fontSize: 13, cursor: 'pointer',
              boxShadow: active ? '0 2px 8px rgba(245,158,11,0.2)' : 'none',
              transition: 'all 0.15s',
            }}>
              {f.label}
            </button>
          );
        })}
      </div>

      {loading ? (
        <div style={{ display: 'flex', justifyContent: 'center', padding: 60 }}>
          <div style={{ width: 36, height: 36, borderRadius: '50%', border: '3px solid var(--border)', borderTopColor: '#F59E0B', animation: 'spin 0.8s linear infinite' }} />
        </div>
      ) : reviews.length === 0 ? (
        <div style={{
          background: 'var(--surface)', borderRadius: 18, border: '1.5px dashed var(--border)',
          padding: '60px 20px', textAlign: 'center',
        }}>
          <div style={{ width: 56, height: 56, borderRadius: '50%', background: 'var(--surface-2)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 14px' }}>
            <MessageSquare size={24} color="var(--text-3)" />
          </div>
          <p style={{ fontWeight: 600, fontSize: 15, color: 'var(--text-2)', marginBottom: 4 }}>Καμία αξιολόγηση ακόμα</p>
          <p style={{ fontSize: 13, color: 'var(--text-3)' }}>Οι αξιολογήσεις εμφανίζονται αφού τα μέλη ολοκληρώσουν κράτηση</p>
        </div>
      ) : (
        <>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {reviews.map((r, i) => (
              <div key={r.id} style={{
                background: 'var(--surface)', borderRadius: 16, border: '1px solid var(--border)',
                padding: '16px 20px', display: 'flex', gap: 14, alignItems: 'flex-start',
                transition: 'box-shadow 0.15s',
              }}
                onMouseEnter={e => e.currentTarget.style.boxShadow = '0 4px 16px rgba(0,0,0,0.06)'}
                onMouseLeave={e => e.currentTarget.style.boxShadow = 'none'}
              >
                {/* Avatar */}
                <div style={{
                  width: 40, height: 40, borderRadius: '50%', flexShrink: 0,
                  background: COLORS[i % COLORS.length],
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 14, fontWeight: 700, color: '#fff',
                }}>
                  {initials(r.member_name)}
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 8, marginBottom: 6 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                      <span style={{ fontWeight: 700, fontSize: 14, color: 'var(--text)' }}>{r.member_name || 'Ανώνυμο'}</span>
                      {r.service_name && (
                        <span style={{ fontSize: 11.5, fontWeight: 600, color: '#7C3AED', background: 'rgba(124,58,237,0.08)', padding: '2px 9px', borderRadius: 99 }}>
                          {r.service_name}
                        </span>
                      )}
                      {r.staff_name && (
                        <span style={{ fontSize: 11.5, fontWeight: 500, color: 'var(--text-3)' }}>· {r.staff_name}</span>
                      )}
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 3, flexShrink: 0 }}>
                      <StarRow rating={r.feedback_rating} size={14} />
                      <span style={{ fontSize: 11, color: 'var(--text-3)' }}>{fmtDate(r.starts_at)}</span>
                    </div>
                  </div>
                  {r.feedback_note && (
                    <p style={{ margin: 0, fontSize: 13.5, color: 'var(--text-2)', lineHeight: 1.6, fontStyle: 'italic' }}>
                      "{r.feedback_note}"
                    </p>
                  )}
                </div>
              </div>
            ))}
          </div>

          {totalPages > 1 && (
            <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 10, marginTop: 24 }}>
              <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1} style={{
                width: 36, height: 36, borderRadius: 10, border: '1px solid var(--border)',
                background: 'var(--surface)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center',
                opacity: page === 1 ? 0.4 : 1,
              }}>
                <ChevronLeft size={16} />
              </button>
              <span style={{ fontSize: 13, color: 'var(--text-2)', fontWeight: 600 }}>{page} / {totalPages}</span>
              <button onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page === totalPages} style={{
                width: 36, height: 36, borderRadius: 10, border: '1px solid var(--border)',
                background: 'var(--surface)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center',
                opacity: page === totalPages ? 0.4 : 1,
              }}>
                <ChevronRight size={16} />
              </button>
            </div>
          )}
        </>
      )}
      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </Layout>
  );
}
