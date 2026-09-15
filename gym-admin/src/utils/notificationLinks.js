export function parseNotificationPayload(notification) {
  const raw = notification?.payload;
  if (!raw) return null;
  if (typeof raw === 'object') return raw;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

export function getNotificationPath(notification) {
  const type = notification?.type || '';
  const payload = parseNotificationPayload(notification) || {};

  if (type === 'client_message' || payload.thread_id) {
    return '/messages';
  }

  if (payload.booking_id) {
    const params = new URLSearchParams({ id: payload.booking_id });
    if (payload.starts_at) params.set('date', String(payload.starts_at).slice(0, 10));
    return `/bookings?${params}`;
  }

  if (type.includes('waitlist') || payload.waitlist_id) {
    const params = new URLSearchParams({ mode: 'waitlist' });
    if (payload.starts_at) params.set('date', String(payload.starts_at).slice(0, 10));
    return `/bookings?${params}`;
  }

  if (payload.user_id) {
    if (type === 'client_pending_approval' || type.includes('client')) {
      return `/clients/${payload.user_id}`;
    }
    return `/clients/${payload.user_id}`;
  }

  if (type.includes('payment')) return '/payments';
  if (type.includes('nutrition')) return '/nutrition/bookings';
  if (type === 'staff_reassignment_pending') return '/bookings?reassignment=pending';

  return null;
}
