import { useEffect, useRef, useState } from 'react';
import { useParams } from 'react-router-dom';
import { CheckCircle, AlertCircle } from 'lucide-react';

const API = import.meta.env.VITE_API_URL || 'https://passionate-grace-production-98ad.up.railway.app/api';

export default function GdprSign() {
  const { token } = useParams();
  const [data, setData] = useState(null);
  const [error, setError] = useState('');
  const [signed, setSigned] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [agreed, setAgreed] = useState(false);
  const canvasRef = useRef(null);
  const [drawing, setDrawing] = useState(false);
  const [hasSignature, setHasSignature] = useState(false);

  useEffect(() => {
    fetch(`${API}/gdpr/sign/${token}`)
      .then(r => r.json())
      .then(d => {
        if (d.error) { setError(d.error); return; }
        setData(d);
        if (d.signed_at) setSigned(true);
      })
      .catch(() => setError('Σφάλμα σύνδεσης'));
  }, [token]);

  // Canvas drawing
  function getPos(e, canvas) {
    const r = canvas.getBoundingClientRect();
    const touch = e.touches?.[0];
    return {
      x: ((touch?.clientX ?? e.clientX) - r.left) * (canvas.width / r.width),
      y: ((touch?.clientY ?? e.clientY) - r.top) * (canvas.height / r.height),
    };
  }

  function startDraw(e) {
    e.preventDefault();
    const canvas = canvasRef.current;
    const ctx = canvas.getContext('2d');
    const pos = getPos(e, canvas);
    ctx.beginPath();
    ctx.moveTo(pos.x, pos.y);
    setDrawing(true);
    setHasSignature(true);
  }

  function draw(e) {
    if (!drawing) return;
    e.preventDefault();
    const canvas = canvasRef.current;
    const ctx = canvas.getContext('2d');
    ctx.lineWidth = 2.5;
    ctx.lineCap = 'round';
    ctx.strokeStyle = '#1e293b';
    const pos = getPos(e, canvas);
    ctx.lineTo(pos.x, pos.y);
    ctx.stroke();
  }

  function stopDraw() { setDrawing(false); }

  function clearCanvas() {
    const canvas = canvasRef.current;
    canvas.getContext('2d').clearRect(0, 0, canvas.width, canvas.height);
    setHasSignature(false);
  }

  async function submit() {
    if (!hasSignature) return alert('Παρακαλώ υπογράψτε πρώτα.');
    if (!agreed) return alert('Παρακαλώ επιβεβαιώστε ότι συμφωνείτε.');
    setSubmitting(true);
    try {
      const signatureData = canvasRef.current.toDataURL('image/png');
      const res = await fetch(`${API}/gdpr/sign/${token}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ signature_data: signatureData }),
      });
      const d = await res.json();
      if (d.ok) setSigned(true);
      else alert(d.error || 'Σφάλμα');
    } catch { alert('Σφάλμα αποστολής'); }
    finally { setSubmitting(false); }
  }

  if (error) return (
    <GdprShell>
      <div style={{ textAlign: 'center', padding: '40px 20px', color: '#dc2626' }}>
        <AlertCircle size={40} style={{ marginBottom: 12 }} />
        <div style={{ fontWeight: 700, fontSize: '1.1rem', marginBottom: 6 }}>Ο σύνδεσμος δεν είναι έγκυρος</div>
        <div style={{ color: '#64748b', fontSize: '0.9rem' }}>{error}</div>
      </div>
    </GdprShell>
  );

  if (!data) return <GdprShell><div style={{ textAlign: 'center', padding: 40, color: '#64748b' }}>Φόρτωση…</div></GdprShell>;

  if (signed) return (
    <GdprShell gymName={data.gym_name}>
      <div style={{ textAlign: 'center', padding: '40px 20px', color: '#16a34a' }}>
        <CheckCircle size={48} style={{ marginBottom: 16 }} />
        <div style={{ fontWeight: 800, fontSize: '1.3rem', marginBottom: 8, color: '#14532d' }}>Ευχαριστούμε!</div>
        <div style={{ color: '#166534', fontSize: '0.95rem' }}>Η συναίνεσή σας καταγράφηκε επιτυχώς.</div>
      </div>
    </GdprShell>
  );

  const paragraphs = data.gdpr_text.split('\n').filter(l => l.trim());

  return (
    <GdprShell gymName={data.gym_name}>
      <div style={{ marginBottom: 20 }}>
        <div style={{ fontSize: '0.85rem', color: '#64748b', marginBottom: 4 }}>Πελάτης</div>
        <div style={{ fontWeight: 700, fontSize: '1.1rem' }}>{data.full_name}</div>
      </div>

      <div style={{ background: '#f8fafc', borderRadius: 12, padding: '16px 20px', marginBottom: 24, maxHeight: 320, overflowY: 'auto', border: '1px solid #e2e8f0' }}>
        {paragraphs.map((p, i) => (
          <p key={i} style={{ margin: '0 0 10px', fontSize: '0.84rem', color: '#374151', lineHeight: 1.65,
            fontWeight: p.startsWith('**') ? 700 : 400 }}>
            {p.replace(/\*\*/g, '')}
          </p>
        ))}
      </div>

      <div style={{ marginBottom: 20 }}>
        <div style={{ fontWeight: 600, fontSize: '0.9rem', marginBottom: 8 }}>Υπογραφή</div>
        <div style={{ border: '2px solid #e2e8f0', borderRadius: 12, overflow: 'hidden', background: '#fff', touchAction: 'none' }}>
          <canvas
            ref={canvasRef}
            width={560}
            height={140}
            style={{ width: '100%', height: 140, display: 'block', cursor: 'crosshair' }}
            onMouseDown={startDraw}
            onMouseMove={draw}
            onMouseUp={stopDraw}
            onMouseLeave={stopDraw}
            onTouchStart={startDraw}
            onTouchMove={draw}
            onTouchEnd={stopDraw}
          />
        </div>
        <button onClick={clearCanvas} style={{ marginTop: 6, fontSize: '0.78rem', color: '#64748b', background: 'none', border: 'none', cursor: 'pointer', padding: 0 }}>
          Εκκαθάριση
        </button>
      </div>

      <label style={{ display: 'flex', alignItems: 'flex-start', gap: 10, marginBottom: 20, cursor: 'pointer' }}>
        <input type="checkbox" checked={agreed} onChange={e => setAgreed(e.target.checked)} style={{ marginTop: 3, flexShrink: 0 }} />
        <span style={{ fontSize: '0.84rem', color: '#374151', lineHeight: 1.55 }}>
          Διάβασα και κατανοώ τους όρους επεξεργασίας προσωπικών δεδομένων και συναινώ σε αυτούς.
        </span>
      </label>

      <button
        onClick={submit}
        disabled={submitting || !agreed || !hasSignature}
        style={{ width: '100%', padding: '14px', borderRadius: 12, border: 'none', background: '#76C043', color: '#fff', fontWeight: 700, fontSize: '1rem', cursor: 'pointer', opacity: (submitting || !agreed || !hasSignature) ? 0.5 : 1 }}
      >
        {submitting ? 'Αποστολή…' : 'Υπογραφή & Αποδοχή'}
      </button>
    </GdprShell>
  );
}

function GdprShell({ children, gymName }) {
  return (
    <div style={{ minHeight: '100vh', background: '#f1f5f9', display: 'flex', alignItems: 'flex-start', justifyContent: 'center', padding: '20px 16px' }}>
      <div style={{ width: '100%', maxWidth: 600 }}>
        {gymName && (
          <div style={{ textAlign: 'center', marginBottom: 20 }}>
            <div style={{ fontWeight: 800, fontSize: '1.2rem', color: '#1e293b' }}>{gymName}</div>
            <div style={{ fontSize: '0.78rem', color: '#64748b' }}>Δήλωση GDPR — Προστασία Προσωπικών Δεδομένων</div>
          </div>
        )}
        <div style={{ background: '#fff', borderRadius: 18, padding: 28, boxShadow: '0 4px 24px rgba(0,0,0,0.08)' }}>
          {children}
        </div>
      </div>
    </div>
  );
}
