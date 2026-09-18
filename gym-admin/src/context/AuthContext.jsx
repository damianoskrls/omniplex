import { createContext, useContext, useState, useEffect } from 'react';
import api from '../api/client';

function hexLuminance(hex) {
  const c = hex.replace('#', '');
  const r = parseInt(c.substring(0, 2), 16) / 255;
  const g = parseInt(c.substring(2, 4), 16) / 255;
  const b = parseInt(c.substring(4, 6), 16) / 255;
  const toLinear = (v) => (v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4);
  return 0.2126 * toLinear(r) + 0.7152 * toLinear(g) + 0.0722 * toLinear(b);
}

function accentTextColor(hex) {
  if (!hex || hex.length < 7) return '#ffffff';
  return hexLuminance(hex) > 0.35 ? '#111111' : '#ffffff';
}

// Text color for active sidebar items (accent-dim background)
// Light accents (yellow): use near-black. Dark accents: use the accent itself.
function accentActiveText(hex) {
  if (!hex || hex.length < 7) return null;
  return hexLuminance(hex) > 0.20 ? '#111111' : null; // null = keep using var(--accent)
}

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [token, setToken] = useState(() => localStorage.getItem('gym_admin_token'));
  const [business, setBusiness] = useState(() => {
    const raw = localStorage.getItem('gym_admin_business');
    return raw ? JSON.parse(raw) : null;
  });
  const [role, setRole] = useState(() => localStorage.getItem('gym_admin_role') || 'client_admin');

  useEffect(() => {
    document.title = business?.name ? `${business.name} — OmniPlex` : 'OmniPlex';
  }, [business]);

  // Inject tenant CSS variables whenever business changes
  useEffect(() => {
    const root = document.documentElement;
    if (!business) {
      // Reset to OmniPlex defaults when logged out
      root.style.removeProperty('--tenant-primary');
      root.style.removeProperty('--tenant-accent');
      root.style.removeProperty('--tenant-secondary');
      root.style.removeProperty('--accent-text');
      root.style.removeProperty('--accent-active-text');
      return;
    }
    if (business.primary_color) {
      root.style.setProperty('--tenant-primary', business.primary_color);
      root.style.setProperty('--accent-text', accentTextColor(business.primary_color));
      const activeText = accentActiveText(business.primary_color);
      if (activeText) {
        root.style.setProperty('--accent-active-text', activeText);
      } else {
        root.style.removeProperty('--accent-active-text');
      }
    }
    if (business.accent_color)    root.style.setProperty('--tenant-accent',    business.accent_color);
    if (business.secondary_color) root.style.setProperty('--tenant-secondary', business.secondary_color);
  }, [business]);

  const login = async (email, password) => {
    const res = await api.post('/client-admin/login', { email, password });
    const userRole = res.data.role || 'client_admin';
    localStorage.setItem('gym_admin_token', res.data.token);
    localStorage.setItem('gym_admin_business', JSON.stringify(res.data.business));
    localStorage.setItem('gym_admin_role', userRole);
    setToken(res.data.token);
    setBusiness(res.data.business);
    setRole(userRole);
    return userRole;
  };

  const logout = () => {
    localStorage.removeItem('gym_admin_token');
    localStorage.removeItem('gym_admin_business');
    localStorage.removeItem('gym_admin_role');
    setToken(null);
    setBusiness(null);
    setRole('client_admin');
  };

  const isGym = !business?.type || business?.type === 'gym';

  return (
    <AuthContext.Provider value={{
      token,
      business,
      role,
      login,
      logout,
      isLoggedIn: !!token,
      isNutritionist: role === 'nutritionist',
      isTrainer: role === 'trainer',
      isOwner: role === 'client_admin',
      isGym,
      features: {
        programs: isGym && (business?.feature_programs ?? 1),
        trainers: isGym && (business?.feature_trainers ?? 1),
        nutrition: business?.feature_nutrition ?? 0,
        memberships: business?.feature_memberships ?? 1,
        waitlist: business?.feature_waitlist ?? 0,
      },
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
