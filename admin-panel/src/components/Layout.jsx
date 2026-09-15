import { NavLink, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { LayoutDashboard, Building2, LogOut, Menu, X, Euro } from 'lucide-react';
import BrandLogo from './BrandLogo';
import { useEffect, useState } from 'react';

export default function Layout({ children, title }) {
  const { logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [navOpen, setNavOpen] = useState(false);

  useEffect(() => { setNavOpen(false); }, [location.pathname]);

  const handleLogout = () => { logout(); navigate('/login'); };

  return (
    <div className="layout">
      <div
        className={`sidebar-backdrop ${navOpen ? 'sidebar-backdrop--visible' : ''}`}
        onClick={() => setNavOpen(false)}
        aria-hidden={!navOpen}
      />
      <aside className={`sidebar ${navOpen ? 'sidebar--open' : ''}`}>
        <BrandLogo variant="sidebar" />
        <nav className="sidebar-nav">
          <NavLink to="/" end><LayoutDashboard size={16} /> Dashboard</NavLink>
          <NavLink to="/tenants"><Building2 size={16} /> Clients</NavLink>
        </nav>
        <div style={{ padding: '16px 20px', borderTop: '1px solid rgba(255,255,255,0.1)' }}>
          <button className="btn btn-secondary btn-sm" style={{ width: '100%' }} onClick={handleLogout}>
            <LogOut size={14} /> Logout
          </button>
        </div>
      </aside>

      <main className="main">
        <div className="topbar">
          <div className="topbar-left">
            <button
              type="button"
              className="mobile-menu-btn"
              onClick={() => setNavOpen(v => !v)}
              aria-label={navOpen ? 'Close menu' : 'Open menu'}
            >
              {navOpen ? <X size={22} /> : <Menu size={22} />}
            </button>
            <span className="topbar-title">{title}</span>
          </div>
          <span className="text-muted topbar-meta">Handstand Admin</span>
        </div>
        <div className="content">{children}</div>
      </main>
    </div>
  );
}
