import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { useNavigate } from 'react-router-dom';
import { Bell } from 'lucide-react';
import api from '../api/client';
import { getNotificationPath } from '../utils/notificationLinks';

export default function NotificationBell() {
  const navigate = useNavigate();
  const buttonRef = useRef(null);
  const [open, setOpen] = useState(false);
  const [items, setItems] = useState([]);
  const [unread, setUnread] = useState(0);
  const [panelPos, setPanelPos] = useState({ top: 56, right: 16 });

  const load = async () => {
    try {
      const r = await api.get('/client-admin/notifications', { params: { limit: 20 } });
      setItems(r.data.notifications || []);
      setUnread(r.data.unread_count || 0);
    } catch {
      /* ignore */
    }
  };

  useEffect(() => {
    load();
    const t = setInterval(load, 30000);
    return () => clearInterval(t);
  }, []);

  useLayoutEffect(() => {
    if (!open || !buttonRef.current) return;
    const rect = buttonRef.current.getBoundingClientRect();
    const panelWidth = Math.min(360, window.innerWidth - 16);
    setPanelPos({
      top: rect.bottom + 8,
      right: Math.max(8, window.innerWidth - rect.right),
      width: panelWidth,
    });
  }, [open]);

  const markRead = async (id) => {
    await api.patch(`/client-admin/notifications/${id}/read`);
    load();
  };

  const markAll = async () => {
    await api.patch('/client-admin/notifications/read-all');
    load();
  };

  const openNotification = async (notification) => {
    if (!notification.is_read) {
      await markRead(notification.id);
    }
    setOpen(false);
    const path = getNotificationPath(notification);
    if (path) navigate(path);
  };

  return (
    <>
      <div className="notification-bell">
        <button
          ref={buttonRef}
          type="button"
          className="btn btn-secondary btn-sm notification-bell__btn"
          onClick={() => setOpen(v => !v)}
          aria-label="Ειδοποιήσεις"
          aria-expanded={open}
        >
          <Bell size={16} />
          {unread > 0 && (
            <span className="notification-bell__badge">
              {unread > 9 ? '9+' : unread}
            </span>
          )}
        </button>
      </div>

      {open && createPortal(
        <>
          <div
            className="notification-backdrop"
            onClick={() => setOpen(false)}
            aria-hidden="true"
          />
          <div
            className="notification-panel"
            style={{ top: panelPos.top, right: panelPos.right, width: panelPos.width }}
            role="dialog"
            aria-label="Ειδοποιήσεις"
          >
            <div className="notification-panel__head">
              <strong>Ειδοποιήσεις</strong>
              {unread > 0 && (
                <button type="button" className="btn btn-secondary btn-sm" onClick={markAll}>
                  Όλες διαβάστηκαν
                </button>
              )}
            </div>
            {items.length === 0 ? (
              <div className="text-muted notification-panel__empty">Καμία ειδοποίηση</div>
            ) : (
              items.map(n => {
                const path = getNotificationPath(n);
                return (
                  <button
                    key={n.id}
                    type="button"
                    onClick={() => openNotification(n)}
                    className={`notification-item ${n.is_read ? '' : 'notification-item--unread'} ${path ? 'notification-item--link' : ''}`}
                  >
                    <div className="notification-item__title">{n.title}</div>
                    {n.body && (
                      <div className="notification-item__body">{n.body}</div>
                    )}
                    <div className="notification-item__meta">
                      {new Date(n.created_at).toLocaleString('el-GR')}
                      {path && <span className="notification-item__hint">Πατήστε για μετάβαση →</span>}
                    </div>
                  </button>
                );
              })
            )}
          </div>
        </>,
        document.body,
      )}
    </>
  );
}
