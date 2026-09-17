import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import toast from 'react-hot-toast';

const FEATURES = [
  { icon: '📅', text: 'Κρατήσεις & Ραντεβού' },
  { icon: '👥', text: 'Διαχείριση Πελατών' },
  { icon: '💳', text: 'Πληρωμές & Πακέτα' },
  { icon: '📊', text: 'Αναφορές & Στατιστικά' },
];

export default function Login() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({ email: 'owner@demo.com', password: 'admin123' });
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      const role = await login(form.email, form.password);
      navigate(
        role === 'nutritionist' ? '/nutrition'
          : role === 'trainer' ? '/trainer'
            : '/',
      );
    } catch {
      toast.error('Λάθος email ή κωδικός');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-split">
      {/* ── Left hero panel ── */}
      <div className="login-hero">
        <div className="login-hero__inner">
          <img src="/omniplex-logo.png" alt="OmniPlex" className="login-hero__mark" />
          <div className="login-hero__wordmark">
            Omni<span>Plex</span>
          </div>
          <div className="login-hero__tagline">Flow for all</div>
          <p className="login-hero__desc">
            Μία πλατφόρμα για κάθε επαγγελματία που διαχειρίζεται χρόνο, πελάτες και υπηρεσίες.
          </p>
          <ul className="login-hero__features">
            {FEATURES.map(f => (
              <li key={f.text}>
                <span className="login-hero__feat-icon">{f.icon}</span>
                {f.text}
              </li>
            ))}
          </ul>
        </div>
        <div className="login-hero__blur1" />
        <div className="login-hero__blur2" />
      </div>

      {/* ── Right form panel ── */}
      <div className="login-form-panel">
        <div className="login-form-box">
          <div className="login-form-logo">
            <img src="/omniplex-logo.png" alt="OmniPlex" style={{ width: 40, height: 40, objectFit: 'contain' }} />
            <span>Omni<em>Plex</em></span>
          </div>
          <h1 className="login-form-title">Καλώς ήρθες</h1>
          <p className="login-form-sub">Συνδέσου στον λογαριασμό σου για να συνεχίσεις.</p>

          <form onSubmit={handleSubmit} style={{ marginTop: 28 }}>
            <div className="form-group">
              <label className="form-label">Email</label>
              <input className="form-input" type="email" value={form.email}
                onChange={e => setForm({ ...form, email: e.target.value })} required />
            </div>
            <div className="form-group">
              <label className="form-label">Κωδικός</label>
              <input className="form-input" type="password" value={form.password}
                onChange={e => setForm({ ...form, password: e.target.value })} required />
            </div>
            <button className="btn btn-primary" style={{ width: '100%', justifyContent: 'center', marginTop: 8 }} disabled={loading}>
              {loading ? 'Σύνδεση...' : 'Σύνδεση'}
            </button>
          </form>

          <p className="text-muted" style={{ marginTop: 24, fontSize: '0.75rem', lineHeight: 1.7 }}>
            <strong>Demo accounts:</strong><br />
            owner@demo.com / admin123<br />
            nutrition@demo.com / nutrition123<br />
            trainer@demo.com / trainer123
          </p>
        </div>
      </div>
    </div>
  );
}
