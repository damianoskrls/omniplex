import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { Calendar, Check, MapPin, QrCode, X } from 'lucide-react';
import api from '../api/client';
import toast from 'react-hot-toast';
import SessionProgressCharts from './SessionProgressChart';
import { fmtDateTime } from '../utils/dates';

const STATUS_LABELS = {
  pending: 'Εκκρεμής',
  confirmed: 'Επιβεβαιωμένη',
  in_progress: 'Σε εξέλιξη',
  completed: 'Ολοκληρωμένη',
  cancelled: 'Ακυρωμένη',
  no_show: 'Απόντας',
};

function shiftDate(days) {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
}


function statusBadge(status, attendanceConfirmed) {
  if (attendanceConfirmed) {
    return <span className="badge badge-green">Παρουσία ✓</span>;
  }
  const cls = {
    confirmed: 'badge-green',
    pending: 'badge-yellow',
    completed: 'badge-gray',
    cancelled: 'badge-gray',
    no_show: 'badge-red',
    in_progress: 'badge-yellow',
  }[status] || 'badge-gray';
  return <span className={`badge ${cls}`}>{STATUS_LABELS[status] || status}</span>;
}

function needsAttendanceConfirm(booking) {
  if (!booking || booking.attendance_confirmed) return false;
  if (['cancelled', 'no_show'].includes(booking.status)) return false;
  return new Date(booking.starts_at) < new Date();
}

function BookingRow({ booking, onConfirm, confirmingId, showUserName = false }) {
  const needsConfirm = needsAttendanceConfirm(booking);
  const busy = confirmingId === booking.id;

  return (
    <div className="cb-booking-row">
      <div className="cb-booking-row-main">
        <div className="cb-booking-row-time">
          <Calendar size={14} />
          {fmtDateTime(booking.starts_at)}
        </div>
        <div className="cb-booking-row-title">
          {showUserName && booking.user_name && (
            <span style={{ color: '#4338ca', marginRight: 8 }}>{booking.user_name} ·</span>
          )}
          {booking.service_name}
          {booking.is_trial ? <span className="badge badge-yellow" style={{ marginLeft: 6 }}>Δοκιμαστικό</span> : null}
        </div>
        <div className="cb-booking-row-meta">
          {booking.staff_name && <span>{booking.staff_name}</span>}
          {booking.room_name && <span> · {booking.room_name}</span>}
          {booking.schedule_label && <span> · {booking.schedule_label}</span>}
          {booking.location_name && (
            <span className="bk-location-badge" style={{ marginLeft: 6 }}>
              <MapPin size={11} />{booking.location_name}
            </span>
          )}
        </div>
      </div>
      <div className="cb-booking-row-actions">
        {statusBadge(booking.status, booking.attendance_confirmed)}
        {needsConfirm && (
          <>
            <button
              type="button"
              className="btn btn-primary btn-sm"
              disabled={busy}
              onClick={() => onConfirm(booking, true)}
              title="Επιβεβαίωση παρουσίας (όπως QR check-in)"
            >
              <Check size={14} /> {busy ? '...' : 'Παρουσία'}
            </button>
            <button
              type="button"
              className="btn btn-secondary btn-sm"
              disabled={busy}
              onClick={() => onConfirm(booking, false)}
              title="Δεν προσήλθε"
            >
              <X size={14} /> Απόντας
            </button>
          </>
        )}
        {booking.attendance_confirmed && (
          <span className="text-muted" style={{ fontSize: '0.75rem', display: 'flex', alignItems: 'center', gap: 4 }}>
            <QrCode size={12} /> Επιβεβαιώθηκε
          </span>
        )}
      </div>
    </div>
  );
}

export default function ClientBookingsSection({
  userId,
  clientName = '',
  memberships = [],
  showCharts = true,
  showTitle = true,
  compact = false,
  bookings: bookingsProp,
  onReload,
}) {
  const [bookings, setBookings] = useState(bookingsProp || []);
  const [loading, setLoading] = useState(!bookingsProp);
  const [confirmingId, setConfirmingId] = useState(null);

  const load = async () => {
    if (!userId) return;
    setLoading(true);
    try {
      const r = await api.get('/client-admin/bookings', {
        params: {
          user_id: userId,
          from: shiftDate(-90),
          to: shiftDate(120),
        },
      });
      setBookings(r.data || []);
    } catch {
      toast.error('Σφάλμα φόρτωσης κρατήσεων');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (bookingsProp) {
      setBookings(bookingsProp);
      setLoading(false);
      return;
    }
    load();
  }, [userId, bookingsProp]);

  const reloadBookings = async () => {
    if (bookingsProp) {
      onReload?.();
      return;
    }
    await load();
    onReload?.();
  };

  const now = useMemo(() => new Date(), [bookings]);

  const { upcoming, past, needsConfirmCount } = useMemo(() => {
    const up = [];
    const pa = [];
    let needs = 0;
    for (const b of bookings) {
      if (['cancelled'].includes(b.status)) continue;
      if (needsAttendanceConfirm(b)) needs += 1;
      if (new Date(b.starts_at) >= now) up.push(b);
      else pa.push(b);
    }
    up.sort((a, b) => String(a.starts_at).localeCompare(String(b.starts_at)));
    pa.sort((a, b) => String(b.starts_at).localeCompare(String(a.starts_at)));
    return { upcoming: up, past: pa, needsConfirmCount: needs };
  }, [bookings, now]);

  const confirmAttendance = async (booking, attended) => {
    setConfirmingId(booking.id);
    try {
      await api.patch(`/client-admin/bookings/${booking.id}/attendance`, { attended });
      toast.success(attended ? 'Η παρουσία επιβεβαιώθηκε' : 'Καταχωρήθηκε ως απόντας');
      await reloadBookings();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setConfirmingId(null);
    }
  };

  if (loading) {
    return <div className="loading" style={{ padding: 24 }}>Φόρτωση κρατήσεων...</div>;
  }

  return (
    <div className={compact ? '' : 'card'} style={compact ? undefined : { marginBottom: 16, padding: 20 }}>
      {showTitle && (
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 16, flexWrap: 'wrap', gap: 8 }}>
          <div>
            <h3 style={{ margin: 0 }}>Κρατήσεις{clientName ? ` — ${clientName}` : ''}</h3>
            <div className="text-muted" style={{ fontSize: '0.85rem', marginTop: 4 }}>
              {upcoming.length} επερχόμενες · {past.length} προηγούμενες
              {needsConfirmCount > 0 && (
                <span style={{ color: '#d97706', fontWeight: 600 }}> · {needsConfirmCount} χωρίς επιβεβαίωση παρουσίας</span>
              )}
            </div>
          </div>
          {userId && (
            <Link to={`/bookings?user_id=${userId}`} className="btn btn-secondary btn-sm">
              Όλες οι κρατήσεις
            </Link>
          )}
        </div>
      )}

      {showCharts && memberships.length > 0 && (
        <div style={{ marginBottom: 20 }}>
          <div className="cb-section-label" style={{ marginBottom: 12 }}>Υπόλοιπο συνεδριών</div>
          <SessionProgressCharts memberships={memberships} />
        </div>
      )}

      {needsConfirmCount > 0 && (
        <div className="cb-attendance-alert">
          <QrCode size={18} />
          <span>
            {needsConfirmCount} {needsConfirmCount === 1 ? 'κράτηση χρειάζεται' : 'κρατήσεις χρειάζονται'} επιβεβαίωση παρουσίας
            (αν ο πελάτης δεν έκανε QR check-in).
          </span>
        </div>
      )}

      <div className="cb-bookings-split">
        <div className="cb-bookings-col">
          <div className="cb-bookings-col-title">Επερχόμενες ({upcoming.length})</div>
          {upcoming.length === 0 ? (
            <div className="text-muted" style={{ padding: 12, fontSize: '0.88rem' }}>Δεν υπάρχουν επερχόμενες κρατήσεις</div>
          ) : (
            upcoming.map((b) => (
              <BookingRow
                key={b.id}
                booking={b}
                onConfirm={confirmAttendance}
                confirmingId={confirmingId}
                showUserName={!userId}
              />
            ))
          )}
        </div>
        <div className="cb-bookings-col">
          <div className="cb-bookings-col-title">Προηγούμενες ({past.length})</div>
          {past.length === 0 ? (
            <div className="text-muted" style={{ padding: 12, fontSize: '0.88rem' }}>Δεν υπάρχει ιστορικό</div>
          ) : (
            past.map((b) => (
              <BookingRow
                key={b.id}
                booking={b}
                onConfirm={confirmAttendance}
                confirmingId={confirmingId}
                showUserName={!userId}
              />
            ))
          )}
        </div>
      </div>
    </div>
  );
}
