import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import BrandLogo from '../components/BrandLogo';
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
    <div className="login-page">
      <div className="login-card">
        <BrandLogo variant="login" />
        <div className="login-subtitle">Διαχείριση Γυμναστηρίου</div>
        <form onSubmit={handleSubmit}>
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
          <button className="btn btn-primary" style={{ width: '100%', justifyContent: 'center' }} disabled={loading}>
            {loading ? 'Σύνδεση...' : 'Σύνδεση'}
          </button>
        </form>
        <p className="text-muted" style={{ marginTop: 16, fontSize: '0.8rem' }}>
          Ιδιοκτήτης: owner@demo.com / admin123<br />
          Διατροφολόγος: nutrition@demo.com / nutrition123<br />
          Γυμναστής (Μαρία): trainer@demo.com / trainer123<br />
          Γυμναστής (Γιάννης): yoga@demo.com / yoga123
        </p>
      </div>
    </div>
  );
}
