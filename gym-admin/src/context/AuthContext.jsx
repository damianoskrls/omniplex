import { createContext, useContext, useState, useEffect } from 'react';
import api from '../api/client';

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
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
