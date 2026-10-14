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
        // Group all IDs per name to handle DB duplicates
        const idsByName = {};
        data.forEach(b => {
          const key = b.name.toLowerCase().trim();
          if (!idsByName[key]) idsByName[key] = [];
          idsByName[key].push(String(b.id));
        });
        const seen = new Set();
        const deduped = data.filter(b => {
          const key = b.name.toLowerCase().trim();
          if (seen.has(key)) return false;
          seen.add(key);
          return true;
        }).map(b => ({ ...b, siblingIds: idsByName[b.name.toLowerCase().trim()] }));
        setBranches(deduped);
      })
      .catch(() => setBranches([]));
  }, [isOwner, token]);

  // Reset on logout
  useEffect(() => {
    if (!token) {
      localStorage.removeItem('gym_admin_active_branch_id');
      localStorage.removeItem('gym_admin_active_branch_ids');
      setActiveBranchIdState(null);
    }
  }, [token]);

  const setActiveBranch = (id) => {
    if (id) {
      localStorage.setItem('gym_admin_active_branch_id', String(id));
      const branch = branches.find(b => String(b.id) === String(id));
      const allIds = branch?.siblingIds || [String(id)];
      localStorage.setItem('gym_admin_active_branch_ids', allIds.join(','));
    } else {
      localStorage.removeItem('gym_admin_active_branch_id');
      localStorage.removeItem('gym_admin_active_branch_ids');
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
