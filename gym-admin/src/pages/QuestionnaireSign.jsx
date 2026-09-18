import { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import BrandLogo from '../components/BrandLogo';

const API = import.meta.env.VITE_API_URL || 'https://passionate-grace-production-98ad.up.railway.app/api';

export default function QuestionnaireSign() {
  const { token } = useParams();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [answers, setAnswers] = useState({});
  const [submitted, setSubmitted] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    fetch(`${API}/questionnaires/sign/${token}`)
      .then(r => r.json())
      .then(d => {
        if (d.error) { setError(d.error); }
        else {
          setData(d);
          if (d.already_answered) setSubmitted(true);
        }
        setLoading(false);
      })
      .catch(() => { setError('Σφάλμα σύνδεσης.'); setLoading(false); });
  }, [token]);

  function setAnswer(qId, value) {
    setAnswers(prev => ({ ...prev, [qId]: value }));
  }

  async function submit(e) {
    e.preventDefault();
    const unanswered = data.questions.filter(q => !answers[q.id] && answers[q.id] !== 0);
    if (unanswered.length) {
      alert(`Παρακαλώ απάντησε σε όλες τις ερωτήσεις (${unanswered.length} εκκρεμούν).`);
      return;
    }
    setSubmitting(true);
    try {
      const r = await fetch(`${API}/questionnaires/sign/${token}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ answers }),
      });
      const d = await r.json();
      if (d.error) throw new Error(d.error);
      setSubmitted(true);
    } catch (err) {
      alert(err.message || 'Σφάλμα αποστολής');
    } finally { setSubmitting(false); }
  }

  if (loading) return <div style={styles.center}>Φόρτωση…</div>;
  if (error) return (
    <div style={styles.center}>
      <div style={styles.errorBox}>{error}</div>
    </div>
  );

  if (submitted) return (
    <div style={styles.center}>
      <div style={styles.card}>
        <div style={{ fontSize: 48, marginBottom: 12 }}>✅</div>
        <h2 style={{ margin: '0 0 8px', fontSize: '1.2rem', fontWeight: 800 }}>Ευχαριστούμε!</h2>
        <p style={{ color: '#6b7280', margin: 0, fontSize: '0.9rem' }}>
          {data?.already_answered ? 'Έχεις ήδη συμπληρώσει αυτό το ερωτηματολόγιο.' : 'Οι απαντήσεις σου καταχωρήθηκαν επιτυχώς.'}
        </p>
      </div>
    </div>
  );

  return (
    <div style={styles.page}>
      <div style={styles.container}>
        <div style={{ textAlign: 'center', marginBottom: 28 }}>
          <div style={{ fontWeight: 800, fontSize: '1.3rem', marginBottom: 6 }}>{data.title}</div>
          {data.description && <div style={{ color: '#6b7280', fontSize: '0.9rem' }}>{data.description}</div>}
          {data.full_name && (
            <div style={{ marginTop: 12, fontSize: '0.85rem', color: '#374151' }}>
              Γεια σου, <strong>{data.full_name}</strong>! 👋
            </div>
          )}
        </div>

        <form onSubmit={submit}>
          {data.questions.map((q, i) => (
            <div key={q.id} style={styles.qBlock}>
              <label style={styles.qLabel}>
                <span style={styles.qNum}>{i + 1}</span>
                {q.label}
              </label>
              <QuestionInput q={q} value={answers[q.id]} onChange={v => setAnswer(q.id, v)} />
            </div>
          ))}

          <button type="submit" disabled={submitting} style={styles.submitBtn}>
            {submitting ? 'Αποστολή…' : 'Υποβολή απαντήσεων →'}
          </button>
        </form>
      </div>
    </div>
  );
}

function QuestionInput({ q, value, onChange }) {
  if (q.type === 'text') return (
    <textarea
      style={styles.textarea}
      rows={3}
      placeholder="Γράψε εδώ…"
      value={value || ''}
      onChange={e => onChange(e.target.value)}
    />
  );

  if (q.type === 'scale') return (
    <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginTop: 8 }}>
      {[1,2,3,4,5,6,7,8,9,10].map(n => (
        <button key={n} type="button" onClick={() => onChange(n)} style={{
          ...styles.scaleBtn,
          background: value === n ? '#4f46e5' : '#f3f4f6',
          color: value === n ? '#fff' : '#374151',
          borderColor: value === n ? '#4f46e5' : '#e5e7eb',
        }}>{n}</button>
      ))}
    </div>
  );

  if (q.type === 'yesno') return (
    <div style={{ display: 'flex', gap: 10, marginTop: 8 }}>
      {['Ναι', 'Όχι'].map(opt => (
        <button key={opt} type="button" onClick={() => onChange(opt)} style={{
          ...styles.choiceBtn,
          background: value === opt ? '#4f46e5' : '#f9fafb',
          color: value === opt ? '#fff' : '#374151',
          borderColor: value === opt ? '#4f46e5' : '#e5e7eb',
        }}>{opt}</button>
      ))}
    </div>
  );

  if (q.type === 'choice') return (
    <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 8 }}>
      {(q.options || []).map(opt => (
        <button key={opt} type="button" onClick={() => onChange(opt)} style={{
          ...styles.choiceBtn,
          background: value === opt ? '#4f46e5' : '#f9fafb',
          color: value === opt ? '#fff' : '#374151',
          borderColor: value === opt ? '#4f46e5' : '#e5e7eb',
        }}>{opt}</button>
      ))}
    </div>
  );

  return null;
}

const styles = {
  page: { minHeight: '100vh', background: '#f9fafb', padding: '24px 16px' },
  container: { maxWidth: 600, margin: '0 auto' },
  center: { minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24 },
  card: { background: '#fff', borderRadius: 18, padding: 40, textAlign: 'center', boxShadow: '0 4px 24px rgba(0,0,0,0.08)', maxWidth: 400 },
  errorBox: { background: '#fee2e2', color: '#dc2626', borderRadius: 12, padding: '16px 24px', fontWeight: 600 },
  qBlock: { background: '#fff', border: '1px solid #e5e7eb', borderRadius: 14, padding: '18px 20px', marginBottom: 14 },
  qLabel: { display: 'block', fontWeight: 600, fontSize: '0.95rem', color: '#111827', marginBottom: 4 },
  qNum: { display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 22, height: 22, borderRadius: '50%', background: '#4f46e5', color: '#fff', fontSize: '0.72rem', fontWeight: 700, marginRight: 8, flexShrink: 0 },
  textarea: { width: '100%', border: '1px solid #e5e7eb', borderRadius: 10, padding: '10px 12px', fontSize: '0.9rem', fontFamily: 'inherit', outline: 'none', resize: 'vertical', marginTop: 8, boxSizing: 'border-box', background: '#f9fafb' },
  scaleBtn: { width: 40, height: 40, borderRadius: 10, border: '1.5px solid', fontWeight: 700, fontSize: '0.88rem', cursor: 'pointer', transition: 'all 0.1s' },
  choiceBtn: { padding: '8px 16px', borderRadius: 10, border: '1.5px solid', fontWeight: 600, fontSize: '0.88rem', cursor: 'pointer', transition: 'all 0.1s' },
  submitBtn: {
    width: '100%', background: '#4f46e5', color: '#fff', border: 'none', borderRadius: 14,
    padding: '14px', fontSize: '0.95rem', fontWeight: 700, cursor: 'pointer', marginTop: 8,
    opacity: 1, transition: 'opacity 0.15s',
  },
};
