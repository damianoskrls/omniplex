import { useCallback, useEffect, useState } from 'react';
import api from '../api/client';

export default function useMarketplacePending(pollMs = 30000) {
  const [pendingCount, setPendingCount] = useState(0);

  const refresh = useCallback(async () => {
    try {
      const r = await api.get('/client-admin/dashboard-extras');
      setPendingCount(r.data?.marketplace?.pending_orders || 0);
    } catch { /* ignore */ }
  }, []);

  useEffect(() => {
    refresh();
    const t = setInterval(refresh, pollMs);
    return () => clearInterval(t);
  }, [refresh, pollMs]);

  return { pendingCount };
}
