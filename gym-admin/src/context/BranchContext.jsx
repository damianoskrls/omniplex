import { createContext, useContext, useState, useEffect } from 'react';
import { useAuth } from './AuthContext';
import api from '../api/client';

const BranchContext = createContext(null);

export function BranchProvider({ children }) {
  const { isOwner, token } = useAuth();
  const [branches, setBranches] = useState([]);
  const [activeBranchId, setActiveBranchIdState] = useState(() =>
    localStorage.getItem('gym_admin_active_branch_id') || null
  );

  useEffect(() => {
    if (!isOwner || !token) {
      setBranches([]);
      return;
    }
    api.get('/client-admin/locations')
      .then(r => {
        const data = r.data || [];
        const seen = new Set();
        setBranches(data.filter(b => {
          if (seen.has(b.id)) return false;
          seen.add(b.id);
          return true;
        }));
      })
      .catch(() => setBranches([]));
  }, [isOwner, token]);

  // Reset on logout
  useEffect(() => {
    if (!token) {
      localStorage.removeItem('gym_admin_active_branch_id');
      setActiveBranchIdState(null);
    }
  }, [token]);

  const setActiveBranch = (id) => {
    if (id) {
      localStorage.setItem('gym_admin_active_branch_id', String(id));
    } else {
      localStorage.removeItem('gym_admin_active_branch_id');
    }
    setActiveBranchIdState(id ? String(id) : null);
  };

  const activeBranch = branches.find(b => String(b.id) === String(activeBranchId)) || null;

  return (
    <BranchContext.Provider value={{ branches, activeBranch, activeBranchId, setActiveBranch }}>
      {children}
    </BranchContext.Provider>
  );
}

export const useBranch = () => useContext(BranchContext);
