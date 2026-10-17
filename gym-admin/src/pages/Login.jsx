import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import toast from 'react-hot-toast';

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
      {/* ── Left photo panel ── */}
      <div className="login-hero" style={{ padding: 0, background: '#0a0a0a' }}>
        <img
          src="/login-hero.webp"
          alt="OmniPlex"
          style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
        />
        {/* Logo overlay */}
        <div style={{
          position: 'absolute', top: 36, left: 36,
          display: 'flex', alignItems: 'center', gap: 10,
        }}>
          <img src="/omniplex-logo.png" alt="OmniPlex" style={{ width: 36, height: 36, objectFit: 'contain' }} />
          <span style={{
            fontSize: 22, fontWeight: 700, color: '#fff',
            textShadow: '0 1px 8px rgba(0,0,0,0.5)',
            letterSpacing: '-0.3px',
          }}>
            Omni<span style={{ color: '#a78bfa' }}>Plex</span>
          </span>
        </div>
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

        </div>
      </div>
    </div>
  );
}
