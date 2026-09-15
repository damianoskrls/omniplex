import { useCallback, useEffect, useState } from 'react';
import api from '../api/client';

export default function useMessagesUnreadCount(pollMs = 5000) {
  const [unreadCount, setUnreadCount] = useState(0);

  const refresh = useCallback(async () => {
    try {
      const r = await api.get('/client-admin/messages/unread-count');
      setUnreadCount(r.data?.unread_count || 0);
    } catch {
      /* ignore */
    }
  }, []);

  useEffect(() => {
    refresh();
    const t = setInterval(refresh, pollMs);
    return () => clearInterval(t);
  }, [refresh, pollMs]);

  return { unreadCount, refresh };
}
