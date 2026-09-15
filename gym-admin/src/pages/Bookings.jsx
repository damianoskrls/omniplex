import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import Layout from '../components/Layout';
import BookingsGroupedView from '../components/BookingsGroupedView';
import CreateBookingModal from '../components/CreateBookingModal';
import TrialBookingModal from '../components/TrialBookingModal';
import DropInBookingModal from '../components/DropInBookingModal';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Pencil, ChevronLeft, ChevronRight, Plus, CalendarOff, Trash2, MapPin, Search, X, FlaskConical, Zap } from 'lucide-react';
import { groupBookingsBySlot, slotKey } from '../utils/groupBookingsBySlot';
import ClientBookingsSection from '../components/ClientBookingsSection';

const STATUSES = ['pending', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show'];
const STATUS_LABELS = {
  pending: 'Εκκρεμής', confirmed: 'Επιβεβαιωμένη', in_progress: 'Σε εξέλιξη',
  completed: 'Ολοκληρωμένη', cancelled: 'Ακυρωμένη', no_show: 'Απόντας',
};

const HOURS = Array.from({ length: 15 }, (_, i) => 7 + i);

function parseBookingDateTime(startsAt) {
  const dt = new Date(startsAt);
  const date = `${dt.getFullYear()}-${String(dt.getMonth()+1).padStart(2,'0')}-${String(dt.getDate()).padStart(2,'0')}`;
  const time = `${String(dt.getHours()).padStart(2,'0')}:${String(dt.getMinutes()).padStart(2,'0')}`;
  return { date, time };
}

function shiftDate(dateStr, days) {
  const d = new Date(`${dateStr}T12:00:00`);
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
}

function localToday() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function shiftDateStr(dateStr, days) {
  const d = new Date(`${dateStr}T12:00:00`);
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
}

function bookingHour(startsAt) {
  const { time } = parseBookingDateTime(startsAt);
  return parseInt(time.split(':')[0], 10);
}

export default function Bookings() {
  const [searchParams, setSearchParams] = useSearchParams();
  const [mode, setMode] = useState('grouped');
  const [groupBy, setGroupBy] = useState('service');
  const [groupFilter, setGroupFilter] = useState(null);
  const [date, setDate] = useState(localToday);
  const [bookings, setBookings] = useState([]);
  const [calendar, setCalendar] = useState(null);
  const [waitlist, setWaitlist] = useState([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState(null);
  const [creating, setCreating] = useState(false);
  const [dropInOpen, setDropInOpen] = useState(false);
  const [showClosures, setShowClosures] = useState(false);
  const [closures, setClosures] = useState([]);
  const [closureForm, setClosureForm] = useState({ date_from: '', date_to: '', time_from: '', time_to: '', reason: '' });
  const [savingClosure, setSavingClosure] = useState(false);
  const [presetUserId, setPresetUserId] = useState('');
  const [presetTrial, setPresetTrial] = useState(false);
  const [trialModalOpen, setTrialModalOpen] = useState(false);
  const [trialPresetClient, setTrialPresetClient] = useState(null);
  const [trialEditBooking, setTrialEditBooking] = useState(null);
  const [slots, setSlots] = useState([]);
  const [slotsLoading, setSlotsLoading] = useState(false);
  const [editForm, setEditForm] = useState({ date: '', time: '', staff_id: '', status: 'confirmed' });
  const [locationId, setLocationId] = useState('');
  const [locations, setLocations] = useState([]);
  const [clientQuery, setClientQuery] = useState('');
  const [clientUserId, setClientUserId] = useState('');
  const [clientUserName, setClientUserName] = useState('');
  const [clientPickerOpen, setClientPickerOpen] = useState(false);
  const [clientSuggestions, setClientSuggestions] = useState([]);
  const [clientSearchBookings, setClientSearchBookings] = useState([]);
  const [clientSearchLoading, setClientSearchLoading] = useState(false);
  const [clientCredits, setClientCredits] = useState([]);
  const [confirmingId, setConfirmingId] = useState(null);

  const clientSearchActive = !!(clientUserId || (clientQuery.trim().length >= 2));

  useEffect(() => {
    api.get('/client-admin/locations')
      .then((r) => setLocations((r.data || []).filter((l) => l.is_active)))
      .catch(() => {});
  }, []);

  const locationOptions = (calendar?.locations?.length ? calendar.locations : locations)
    .filter((l) => l.is_active !== 0 && l.is_active !== false);

  const loadList = async () => {
    const params = { ...(mode === 'day' ? { date } : mode === 'calendar' || mode === 'waitlist' || mode === 'grouped' ? { date } : {}) };
    if (locationId) params.location_id = locationId;
    const r = await api.get('/client-admin/bookings', { params });
    setBookings(r.data);
  };

  const loadCalendar = async () => {
    const params = { date };
    if (locationId) params.location_id = locationId;
    const r = await api.get('/client-admin/calendar', { params });
    setCalendar(r.data);
  };

  const loadWaitlist = async () => {
    const r = await api.get('/client-admin/waitlist', { params: { date } });
    setWaitlist(r.data);
  };

  const load = async () => {
    setLoading(true);
    try {
      if (mode === 'calendar' || mode === 'grouped') {
        await Promise.all([loadCalendar(), loadList()]);
      } else if (mode === 'waitlist') {
        await Promise.all([loadWaitlist(), loadList()]);
      } else {
        await loadList();
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { if (!clientSearchActive) load(); }, [date, mode, locationId, clientSearchActive]);

  const loadClientBookings = async ({ userId, q } = {}) => {
    setClientSearchLoading(true);
    try {
      const params = {
        from: shiftDateStr(localToday(), -90),
        to: shiftDateStr(localToday(), 120),
      };
      if (locationId) params.location_id = locationId;
      if (userId) params.user_id = userId;
      else if (q) params.q = q;
      const r = await api.get('/client-admin/bookings', { params });
      setClientSearchBookings(r.data || []);
    } catch {
      toast.error('Σφάλμα αναζήτησης κρατήσεων');
      setClientSearchBookings([]);
    } finally {
      setClientSearchLoading(false);
    }
  };

  useEffect(() => {
    const uid = searchParams.get('user_id');
    if (uid) {
      setClientUserId(uid);
      setClientQuery('');
      api.get(`/client-admin/clients/${uid}`)
        .then((r) => setClientUserName(r.data?.full_name || ''))
        .catch(() => setClientUserName(''));
      setSearchParams({}, { replace: true });
    }
  }, []);

  useEffect(() => {
    if (!clientSearchActive) {
      setClientSearchBookings([]);
      return undefined;
    }
    const timer = setTimeout(() => {
      if (clientUserId) {
        loadClientBookings({ userId: clientUserId });
      } else if (clientQuery.trim().length >= 2) {
        loadClientBookings({ q: clientQuery.trim() });
      }
    }, 350);
    return () => clearTimeout(timer);
  }, [clientUserId, clientQuery, clientSearchActive, locationId]);

  useEffect(() => {
    if (!clientUserId) {
      setClientCredits([]);
      return;
    }
    api.get(`/client-admin/clients/${clientUserId}/credits`)
      .then((r) => setClientCredits(r.data || []))
      .catch(() => setClientCredits([]));
  }, [clientUserId]);

  useEffect(() => {
    const q = clientQuery.trim();
    if (q.length < 2) {
      setClientSuggestions([]);
      return undefined;
    }
    const timer = setTimeout(() => {
      api.get('/client-admin/bookings/bookable-clients', { params: { q } })
        .then((r) => setClientSuggestions((r.data || []).slice(0, 8)))
        .catch(() => setClientSuggestions([]));
    }, 250);
    return () => clearTimeout(timer);
  }, [clientQuery]);

  const selectClientFilter = (client) => {
    setClientUserId(client.id || client.user_id);
    setClientUserName(client.full_name || client.user_name || '');
    setClientQuery(client.full_name || client.user_name || '');
    setClientPickerOpen(false);
  };

  const clearClientSearch = () => {
    setClientQuery('');
    setClientUserId('');
    setClientUserName('');
    setClientSearchBookings([]);
    setClientSuggestions([]);
    setClientPickerOpen(false);
  };

  const confirmAttendance = async (booking, attended) => {
    setConfirmingId(booking.id);
    try {
      await api.patch(`/client-admin/bookings/${booking.id}/attendance`, { attended });
      toast.success(attended ? 'Η παρουσία επιβεβαιώθηκε' : 'Καταχωρήθηκε ως απόντας');
      if (clientSearchActive) {
        await loadClientBookings(clientUserId ? { userId: clientUserId } : { q: clientQuery.trim() });
      } else {
        await load();
      }
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setConfirmingId(null);
    }
  };

  useEffect(() => {
    const forUser = searchParams.get('for');
    const trial = searchParams.get('trial') === '1';
    if (forUser && trial) {
      setSearchParams({}, { replace: true });
      api.get(`/client-admin/clients/${forUser}`).then(r => {
        const c = r.data;
        setTrialPresetClient({ id: c.id, full_name: c.full_name, phone: c.phone || '' });
        setTrialModalOpen(true);
      }).catch(() => {
        setTrialPresetClient(null);
        setTrialModalOpen(true);
      });
    } else if (forUser) {
      setPresetUserId(forUser);
      setPresetTrial(false);
      setCreating(true);
      setSearchParams({}, { replace: true });
    }
  }, []);

  useEffect(() => {
    const modeParam = searchParams.get('mode');
    const dateParam = searchParams.get('date');
    const bookingId = searchParams.get('id');

    if (modeParam) setMode(modeParam);
    if (dateParam) setDate(dateParam);

    if (!bookingId) {
      if (modeParam || dateParam) setSearchParams({}, { replace: true });
      return;
    }

    const openFromNotification = async () => {
      try {
        const params = { id: bookingId };
        if (dateParam) params.date = dateParam;
        const r = await api.get('/client-admin/bookings', { params });
        const booking = r.data[0];
        if (!booking) {
          toast.error('Η κράτηση δεν βρέθηκε');
          return;
        }
        const { date: bookingDate } = parseBookingDateTime(booking.starts_at);
        setDate(bookingDate);
        setMode('grouped');
        const { date: d, time } = parseBookingDateTime(booking.starts_at);
        setEditing(booking);
        setEditForm({
          date: d,
          time,
          staff_id: booking.staff_id,
          status: booking.status,
        });
        loadSlots(booking, d);
      } catch {
        toast.error('Σφάλμα φόρτωσης κράτησης');
      } finally {
        setSearchParams({}, { replace: true });
      }
    };

    openFromNotification();
  }, [searchParams]);

  const loadSlots = async (booking, selectedDate) => {
    setSlotsLoading(true);
    try {
      const r = await api.get('/client-admin/booking-slots', {
        params: {
          service_id: booking.service_id,
          date: selectedDate,
          exclude_booking_id: booking.id,
          ...(booking.location_id ? { location_id: booking.location_id } : {}),
        },
      });
      let loaded = r.data.slots || [];
      const original = parseBookingDateTime(booking.starts_at);
      if (selectedDate === original.date && original.time) {
        const hasTime = loaded.some(s => s.time === original.time);
        if (!hasTime) {
          loaded = [{
            time: original.time,
            available_staff: [{ id: booking.staff_id, full_name: booking.staff_name }],
          }, ...loaded].sort((a, b) => a.time.localeCompare(b.time));
        }
      }
      setSlots(loaded);
    } catch {
      setSlots([]);
      toast.error('Δεν φορτώθηκαν οι διαθέσιμες ώρες');
    } finally {
      setSlotsLoading(false);
    }
  };

  const openCreate = (userId = '') => {
    setPresetUserId(userId);
    setCreating(true);
  };

  const loadClosures = () => api.get('/client-admin/closures').then(r => setClosures(r.data)).catch(() => {});

  const openClosures = () => { loadClosures(); setShowClosures(true); };

  const addClosure = async (e) => {
    e.preventDefault();
    if (!closureForm.date_from || !closureForm.date_to) return toast.error('Βάλε ημερομηνίες');
    setSavingClosure(true);
    try {
      await api.post('/client-admin/closures', closureForm);
      setClosureForm({ date_from: '', date_to: '', time_from: '', time_to: '', reason: '' });
      loadClosures();
      toast.success('Αποκλεισμός προστέθηκε');
    } catch (err) { toast.error(err.response?.data?.error || 'Σφάλμα'); }
    finally { setSavingClosure(false); }
  };

  const deleteClosure = async (id) => {
    await api.delete(`/client-admin/closures/${id}`);
    loadClosures();
    toast.success('Διαγράφηκε');
  };

  const openEdit = (booking) => {
    if (booking.is_trial) {
      setTrialEditBooking(booking);
      setTrialModalOpen(true);
      return;
    }
    const { date: d, time } = parseBookingDateTime(booking.starts_at);
    setEditing(booking);
    setEditForm({
      date: d,
      time,
      staff_id: booking.staff_id,
      status: booking.status,
    });
    loadSlots(booking, d);
  };

  const onDateChange = (newDate) => {
    setEditForm(prev => ({ ...prev, date: newDate, time: '', staff_id: '' }));
    if (editing) loadSlots(editing, newDate);
  };

  const onTimeChange = (newTime) => {
    const slot = slots.find(s => s.time === newTime);
    const staffList = slot?.available_staff || [];
    setEditForm(prev => ({
      ...prev,
      time: newTime,
      staff_id: staffList.some(s => s.id === prev.staff_id)
        ? prev.staff_id
        : (staffList[0]?.id || ''),
    }));
  };

  const staffForSelectedTime = () => {
    const slot = slots.find(s => s.time === editForm.time);
    return slot?.available_staff || [];
  };

  const saveEdit = async (e) => {
    e.preventDefault();
    if (!editing) return;
    try {
      await api.patch(`/client-admin/bookings/${editing.id}`, {
        date: editForm.date,
        time: editForm.time,
        staff_id: editForm.staff_id,
        status: editForm.status,
      });
      toast.success('Η κράτηση ενημερώθηκε');
      setEditing(null);
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const updateStatus = async (id, status) => {
    await api.patch(`/client-admin/bookings/${id}/status`, { status });
    toast.success('Ενημερώθηκε');
    load();
  };

  const deleteBooking = async (booking) => {
    const label = `${booking.user_name} — ${booking.service_name}`;
    if (!window.confirm(`Διαγραφή κράτησης;\n\n${label}\n\nΗ ενέργεια δεν αναιρείται. Αν είχε χρεωθεί επίσκεψη, επιστρέφεται στο πακέτο.`)) return;
    try {
      await api.delete(`/client-admin/bookings/${booking.id}`);
      toast.success('Η κράτηση διαγράφηκε');
      if (editing?.id === booking.id) setEditing(null);
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const convertWaitlist = async (id, force = false) => {
    try {
      await api.post(`/client-admin/waitlist/${id}/convert`, { force, use_credit: true });
      toast.success(force ? 'Κράτηση δημιουργήθηκε (υπέρβαση χωρητικότητας)' : 'Κράτηση από αναμονή');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const removeWaitlist = async (id) => {
    if (!window.confirm('Αφαίρεση από λίστα αναμονής;')) return;
    await api.delete(`/client-admin/waitlist/${id}`);
    toast.success('Αφαιρέθηκε');
    load();
  };

  const fmt = (iso) => new Date(iso).toLocaleString('el-GR', {
    weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit',
  });

  const fmtDateLabel = (d) => new Date(`${d}T12:00:00`).toLocaleDateString('el-GR', {
    weekday: 'long', day: 'numeric', month: 'long',
  });

  const reassignmentPending = searchParams.get('reassignment') === 'pending';
  const visibleBookings = reassignmentPending
    ? bookings.filter((b) => b.staff_assignment_status === 'pending_reassignment')
    : bookings;

  const todayBookings = visibleBookings.filter(b => !['cancelled', 'no_show'].includes(b.status));

  const handleGroupByChange = (next) => {
    setGroupBy(next);
    setGroupFilter(null);
  };

  const calendarView = () => {
    const items = calendar?.bookings || todayBookings;
    const waitItems = calendar?.waitlist || waitlist;

    const resolveLoc = (booking) => {
      if (booking?.location_name) return booking.location_name;
      if (booking?.location_id) {
        const found = locationOptions.find((l) => String(l.id) === String(booking.location_id));
        if (found?.name) return found.name;
      }
      if (locationOptions.length === 1) return locationOptions[0].name;
      return null;
    };

    return (
      <div style={{ display: 'grid', gridTemplateColumns: '64px 1fr', gap: 0 }}>
        {HOURS.map(hour => {
          const hourBookings = items.filter(b => bookingHour(b.starts_at) === hour);
          return (
            <div key={hour} style={{ display: 'contents' }}>
              <div
                style={{
                  padding: '8px 4px',
                  fontSize: '0.8rem',
                  color: '#64748b',
                  borderTop: '1px solid #e2e8f0',
                  textAlign: 'right',
                }}
              >
                {String(hour).padStart(2, '0')}:00
              </div>
              <div style={{ borderTop: '1px solid #e2e8f0', padding: 8, minHeight: 52 }}>
                {groupBookingsBySlot(hourBookings).map((slot) => {
                  const loc = resolveLoc(slot.bookings[0]) || slot.location_name;
                  return (
                  <div
                    key={slotKey(slot)}
                    style={{
                      padding: '8px 12px',
                      marginBottom: 6,
                      borderRadius: 10,
                      background: '#f8fafc',
                      border: '1px solid #e2e8f0',
                      borderLeft: `4px solid ${loc ? '#3b82f6' : (slot.color_hex || '#607D8B')}`,
                    }}
                  >
                    <div style={{ fontWeight: 700, fontSize: '0.9rem', marginBottom: 6, display: 'flex', alignItems: 'center', flexWrap: 'wrap', gap: 8 }}>
                      <span>
                        {parseBookingDateTime(slot.starts_at).time} — {slot.service_name}
                        {slot.schedule_label ? ` · ${slot.schedule_label}` : ''}
                      </span>
                      {loc && (
                        <span className="bk-location-badge prominent">
                          <MapPin size={13} />
                          {loc}
                        </span>
                      )}
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                      {slot.bookings.map((b) => (
                        <div
                          key={b.id}
                          style={{
                            display: 'flex',
                            alignItems: 'center',
                            gap: 8,
                            padding: '6px 8px',
                            borderRadius: 8,
                            background: '#fff',
                          }}
                        >
                          <div style={{ flex: 1 }}>
                            <div style={{ fontWeight: 600, fontSize: '0.85rem' }}>{b.user_name}</div>
                            <div className="text-muted" style={{ fontSize: '0.78rem' }}>{b.staff_name}</div>
                          </div>
                          <button className="btn btn-secondary btn-sm" onClick={() => openEdit(b)}>
                            <Pencil size={14} />
                          </button>
                          <button className="btn btn-danger btn-sm" onClick={() => deleteBooking(b)} title="Διαγραφή">
                            <Trash2 size={14} />
                          </button>
                        </div>
                      ))}
                    </div>
                  </div>
                  );
                })}
                {hourBookings.length === 0 && (
                  <div className="text-muted" style={{ fontSize: '0.75rem', padding: '4px 0' }}>—</div>
                )}
              </div>
            </div>
          );
        })}
        {waitItems.length > 0 && (
          <div style={{ gridColumn: '1 / -1', marginTop: 16 }}>
            <div className="modal-title" style={{ fontSize: '0.95rem', marginBottom: 8 }}>
              Λίστα αναμονής σήμερα
            </div>
            {waitItems.map(w => (
              <div
                key={w.id}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 8,
                  padding: '8px 12px',
                  marginBottom: 6,
                  borderRadius: 10,
                  background: '#fff7ed',
                  border: '1px solid #fed7aa',
                }}
              >
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 600 }}>{parseBookingDateTime(w.starts_at).time} — {w.service_name}</div>
                  <div className="text-muted" style={{ fontSize: '0.82rem' }}>
                    {w.user_name} · θέση #{w.position} · {w.status === 'offered' ? 'προσφέρθηκε θέση' : 'αναμονή'}
                  </div>
                </div>
                <button className="btn btn-primary btn-sm" onClick={() => convertWaitlist(w.id)}>
                  Κράτηση
                </button>
                <button className="btn btn-secondary btn-sm" onClick={() => convertWaitlist(w.id, true)} title="Υπέρβαση χωρητικότητας">
                  + Force
                </button>
              </div>
            ))}
          </div>
        )}
      </div>
    );
  };

  return (
    <Layout title="Κρατήσεις">
      <div className="page-header">
        <h1 className="page-title">
          {mode === 'calendar' || mode === 'grouped'
            ? `${fmtDateLabel(date)}`
            : `Κρατήσεις (${bookings.length})`}
        </h1>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
          {locationOptions.length > 1 && (
            <label className="bk-location-filter">
              <MapPin size={16} aria-hidden />
              <span className="bk-location-filter-label">Φίλτρο:</span>
              <select
                className="form-select bk-location-filter-select"
                value={locationId}
                onChange={(e) => setLocationId(e.target.value)}
              >
                <option value="">Όλες οι τοποθεσίες</option>
                {locationOptions.map((loc) => (
                  <option key={loc.id} value={loc.id}>{loc.name}</option>
                ))}
              </select>
            </label>
          )}
          <button type="button" className="btn btn-secondary" onClick={openClosures}>
            <CalendarOff size={16} /> Κλειστές ημέρες
          </button>
          <button type="button" className="btn btn-secondary" onClick={() => { setTrialPresetClient(null); setTrialModalOpen(true); }}>
            <FlaskConical size={16} /> Νέο Δοκιμαστικό
          </button>
          <button type="button" className="btn btn-secondary" onClick={() => setDropInOpen(true)}>
            <Zap size={16} /> Drop-in
          </button>
          <button type="button" className="btn btn-primary" onClick={() => openCreate()}>
            <Plus size={16} /> Νέα κράτηση
          </button>
          <select className="form-select" style={{ width: 170 }} value={mode} onChange={e => setMode(e.target.value)}>
            <option value="grouped">Ομαδοποιημένα</option>
            <option value="calendar">Ημερολόγιο</option>
            <option value="day">Λίστα ημέρας</option>
            <option value="all">Όλες</option>
            <option value="waitlist">Αναμονή</option>
          </select>
          {mode !== 'all' && (
            <>
              <button type="button" className="btn btn-secondary btn-sm" onClick={() => setDate(shiftDate(date, -1))}>
                <ChevronLeft size={14} />
              </button>
              <input className="form-input" type="date" value={date} onChange={e => setDate(e.target.value)} style={{ width: 160 }} />
              <button type="button" className="btn btn-secondary btn-sm" onClick={() => setDate(shiftDate(date, 1))}>
                <ChevronRight size={14} />
              </button>
              <button type="button" className="btn btn-secondary btn-sm" onClick={() => setDate(localToday())}>
                Σήμερα
              </button>
            </>
          )}
        </div>
      </div>

      {reassignmentPending && (
        <div className="dash-alert" style={{ marginBottom: 16 }}>
          <span>Εμφανίζονται μόνο κρατήσεις που χρειάζονται ανάθεση γυμναστή ({visibleBookings.length})</span>
          <button type="button" className="btn btn-secondary btn-sm" onClick={() => setSearchParams({})}>
            Όλες οι κρατήσεις
          </button>
        </div>
      )}

      <div className="bk-client-search-wrap" style={{ marginBottom: 16 }}>
        <div className="bk-client-search">
          <Search size={18} className="bk-client-search-icon" />
          <input
            type="search"
            className="form-input bk-client-search-input"
            placeholder="Αναζήτηση πελάτη (όνομα, τηλέφωνο)..."
            value={clientQuery}
            onChange={(e) => {
              setClientQuery(e.target.value);
              setClientUserId('');
              setClientUserName('');
              setClientPickerOpen(true);
            }}
            onFocus={() => setClientPickerOpen(true)}
          />
          {clientSearchActive && (
            <button type="button" className="bk-client-search-clear" onClick={clearClientSearch} aria-label="Καθαρισμός">
              <X size={16} />
            </button>
          )}
        </div>
        {clientPickerOpen && clientSuggestions.length > 0 && clientQuery.trim().length >= 2 && !clientUserId && (
          <div className="bk-client-suggestions">
            {clientSuggestions.map((c) => (
              <button
                key={c.id}
                type="button"
                className="bk-client-suggestion"
                onClick={() => selectClientFilter(c)}
              >
                <span className="bk-client-suggestion-name">{c.full_name}</span>
                {c.phone && <span className="text-muted">{c.phone}</span>}
              </button>
            ))}
          </div>
        )}
      </div>

      {clientSearchActive && (
        <div className="card" style={{ marginBottom: 16, padding: 20 }}>
          {clientSearchLoading ? (
            <div className="loading">Αναζήτηση κρατήσεων...</div>
          ) : (
            <ClientBookingsSection
              userId={clientUserId || undefined}
              clientName={clientUserName || (clientQuery.trim() && !clientUserId ? `Αποτελέσματα για «${clientQuery.trim()}»` : '')}
              bookings={clientSearchBookings}
              memberships={clientCredits}
              showCharts={!!clientUserId}
              showTitle
              compact
              onReload={() => loadClientBookings(clientUserId ? { userId: clientUserId } : { q: clientQuery.trim() })}
            />
          )}
        </div>
      )}

      {!clientSearchActive && mode === 'grouped' && (
        <div className="card" style={{ marginBottom: 16 }}>
          {locationId && (
            <div className="bk-active-filter">
              <MapPin size={14} />
              Εμφανίζονται κρατήσεις: <strong>{locationOptions.find(l => String(l.id) === String(locationId))?.name || '—'}</strong>
              <button type="button" className="cb-text-btn" onClick={() => setLocationId('')}>Καθαρισμός</button>
            </div>
          )}
          <div style={{ display: 'flex', gap: 16, marginBottom: 16, flexWrap: 'wrap' }}>
            <div>
              <div className="text-muted" style={{ fontSize: '0.8rem' }}>Κρατήσεις</div>
              <div style={{ fontSize: '1.5rem', fontWeight: 800 }}>{todayBookings.length}</div>
            </div>
            <div>
              <div className="text-muted" style={{ fontSize: '0.8rem' }}>Αναμονή</div>
              <div style={{ fontSize: '1.5rem', fontWeight: 800 }}>{(calendar?.waitlist || []).length}</div>
            </div>
          </div>
          {loading ? <div className="loading">Φόρτωση...</div> : (
            <BookingsGroupedView
              bookings={calendar?.bookings || todayBookings}
              waitlist={calendar?.waitlist || waitlist}
              catalogs={{
                services: calendar?.services || [],
                staff: calendar?.staff || [],
                locations: locationOptions,
              }}
              groupBy={groupBy}
              onGroupByChange={handleGroupByChange}
              filterId={groupFilter}
              onFilterChange={setGroupFilter}
              onEdit={openEdit}
              onDelete={deleteBooking}
              onConvertWaitlist={convertWaitlist}
              onRemoveWaitlist={removeWaitlist}
              onConfirmAttendance={confirmAttendance}
              confirmingId={confirmingId}
            />
          )}
        </div>
      )}

      {!clientSearchActive && mode === 'calendar' && (
        <div className="card" style={{ marginBottom: 16 }}>
          <div style={{ display: 'flex', gap: 16, marginBottom: 16, flexWrap: 'wrap' }}>
            <div>
              <div className="text-muted" style={{ fontSize: '0.8rem' }}>Κρατήσεις</div>
              <div style={{ fontSize: '1.5rem', fontWeight: 800 }}>{todayBookings.length}</div>
            </div>
            <div>
              <div className="text-muted" style={{ fontSize: '0.8rem' }}>Αναμονή</div>
              <div style={{ fontSize: '1.5rem', fontWeight: 800 }}>{(calendar?.waitlist || []).length}</div>
            </div>
          </div>
          {loading ? <div className="loading">Φόρτωση...</div> : calendarView()}
        </div>
      )}

      {!clientSearchActive && mode === 'waitlist' && (
        <div className="card" style={{ marginBottom: 16 }}>
          {loading ? <div className="loading">Φόρτωση...</div> : (
            <table>
              <thead>
                <tr>
                  <th>Ημερομηνία / Ώρα</th><th>Πελάτης</th><th>Υπηρεσία</th><th>Θέση</th><th>Κατάσταση</th><th></th>
                </tr>
              </thead>
              <tbody>
                {waitlist.map(w => (
                  <tr key={w.id}>
                    <td>{fmt(w.starts_at)}</td>
                    <td>
                      <div style={{ fontWeight: 600 }}>{w.user_name}</div>
                      <div className="text-muted">{w.user_phone || '—'}</div>
                    </td>
                    <td>{w.service_name}</td>
                    <td>#{w.position}</td>
                    <td>
                      <span className={`badge ${w.status === 'offered' ? 'badge-green' : 'badge-gray'}`}>
                        {w.status === 'offered' ? 'Προσφέρθηκε' : 'Αναμονή'}
                      </span>
                    </td>
                    <td style={{ display: 'flex', gap: 6 }}>
                      <button className="btn btn-primary btn-sm" onClick={() => convertWaitlist(w.id)}>Αποδοχή</button>
                      <button className="btn btn-danger btn-sm" onClick={() => removeWaitlist(w.id)}>Απόρριψη</button>
                    </td>
                  </tr>
                ))}
                {!waitlist.length && <tr><td colSpan={6} className="text-muted">Καμία εγγραφή αναμονής</td></tr>}
              </tbody>
            </table>
          )}
        </div>
      )}

      {!clientSearchActive && (mode === 'day' || mode === 'all') && (
        <div className="card">
          {loading ? <div className="loading">Φόρτωση...</div> : (
            <table>
              <thead>
                <tr>
                  <th>Ημερομηνία / Ώρα</th>
                  <th>Πελάτης</th>
                  <th>Υπηρεσία</th>
                  <th>Γυμναστής</th>
                  <th>Πηγή</th>
                  <th>Κατάσταση</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {visibleBookings.map(b => (
                  <tr key={b.id}>
                    <td>
                      <div style={{ fontWeight: 600 }}>{fmt(b.starts_at)}</div>
                      <div className="text-muted">{b.duration_mins} λεπτά</div>
                    </td>
                    <td>
                      <div style={{ fontWeight: 600 }}>{b.user_name}</div>
                      <div className="text-muted">{b.user_phone || '—'}</div>
                    </td>
                    <td>{b.service_name}</td>
                    <td>
                      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
                        <span style={{ width: 10, height: 10, borderRadius: '50%', background: b.color_hex || '#607D8B' }} />
                        {b.staff_name}
                        {b.staff_assignment_status === 'pending_reassignment' && (
                          <span className="badge badge-yellow" title="Χρειάζεται ανάθεση γυμναστή">Εκκρεμής ανάθεση</span>
                        )}
                      </span>
                    </td>
                    <td><span className="badge badge-gray">{b.source || 'app'}</span></td>
                    <td>
                      <select className="form-select" value={b.status} onChange={e => updateStatus(b.id, e.target.value)}>
                        {STATUSES.map(s => <option key={s} value={s}>{STATUS_LABELS[s]}</option>)}
                      </select>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: 6 }}>
                      <button className="btn btn-secondary btn-sm" onClick={() => openEdit(b)} title="Επεξεργασία">
                        <Pencil size={14} />
                      </button>
                      <button className="btn btn-danger btn-sm" onClick={() => deleteBooking(b)} title="Διαγραφή">
                        <Trash2 size={14} />
                      </button>
                      </div>
                    </td>
                  </tr>
                ))}
                {!bookings.length && <tr><td colSpan={7} className="loading">Δεν υπάρχουν κρατήσεις</td></tr>}
              </tbody>
            </table>
          )}
        </div>
      )}

      <DropInBookingModal
        open={dropInOpen}
        onClose={() => setDropInOpen(false)}
        onSuccess={load}
        initialDate={date}
      />

      <CreateBookingModal
        open={creating}
        onClose={() => { setCreating(false); setPresetUserId(''); setPresetTrial(false); }}
        initialDate={date}
        presetUserId={presetUserId}
        presetTrial={presetTrial}
        onSuccess={load}
      />

      <TrialBookingModal
        open={trialModalOpen}
        editTrial={trialEditBooking}
        presetClient={trialPresetClient}
        initialDate={date}
        onClose={() => { setTrialModalOpen(false); setTrialPresetClient(null); setTrialEditBooking(null); }}
        onSuccess={load}
      />

      {editing && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setEditing(null)}>
          <div className="modal" style={{ maxWidth: 520 }}>
            <div className="modal-title">Επεξεργασία κράτησης</div>
            <p className="text-muted" style={{ marginBottom: 16 }}>
              {editing.user_name} — {editing.service_name}
            </p>
            <form onSubmit={saveEdit}>
              <div className="form-group">
                <label className="form-label">Ημερομηνία *</label>
                <input
                  className="form-input"
                  type="date"
                  value={editForm.date}
                  onChange={e => onDateChange(e.target.value)}
                  required
                />
              </div>
              <div className="form-group">
                <label className="form-label">Ώρα *</label>
                {slotsLoading ? (
                  <div className="text-muted">Φόρτωση ωρών...</div>
                ) : (
                  <select
                    className="form-select"
                    value={editForm.time}
                    onChange={e => onTimeChange(e.target.value)}
                    required
                  >
                    <option value="">— Επίλεξε ώρα —</option>
                    {slots.map(s => (
                      <option key={s.time} value={s.time}>
                        {s.time}
                        {s.label ? ` — ${s.label}` : ''}
                        {s.room_name ? ` (${s.room_name})` : ''}
                        {s.booked_count != null ? ` [${s.booked_count}/${s.capacity}]` : ''}
                      </option>
                    ))}
                  </select>
                )}
              </div>
              <div className="form-group">
                <label className="form-label">Γυμναστής *</label>
                <select
                  className="form-select"
                  value={editForm.staff_id}
                  onChange={e => setEditForm({ ...editForm, staff_id: e.target.value })}
                  required
                  disabled={!editForm.time}
                >
                  <option value="">— Επίλεξε γυμναστή —</option>
                  {staffForSelectedTime().map(s => (
                    <option key={s.id} value={s.id}>{s.full_name}</option>
                  ))}
                </select>
              </div>
              <div className="form-group">
                <label className="form-label">Κατάσταση</label>
                <select
                  className="form-select"
                  value={editForm.status}
                  onChange={e => setEditForm({ ...editForm, status: e.target.value })}
                >
                  {STATUSES.map(s => <option key={s} value={s}>{STATUS_LABELS[s]}</option>)}
                </select>
              </div>
              <div className="modal-footer" style={{ justifyContent: 'space-between' }}>
                <button
                  type="button"
                  className="btn btn-danger"
                  onClick={() => deleteBooking(editing)}
                >
                  <Trash2 size={14} /> Διαγραφή
                </button>
                <div style={{ display: 'flex', gap: 8 }}>
                <button type="button" className="btn btn-secondary" onClick={() => setEditing(null)}>Ακύρωση</button>
                <button type="submit" className="btn btn-primary" disabled={!editForm.time || !editForm.staff_id}>
                  Αποθήκευση
                </button>
                </div>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Closures modal */}
      {showClosures && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setShowClosures(false)}>
          <div className="modal" style={{ maxWidth: 560 }}>
            <div className="modal-title" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <CalendarOff size={18} /> Κλειστές ημέρες / Αργίες
            </div>
            <p className="text-muted" style={{ fontSize: '0.85rem', marginBottom: 16 }}>
              Οι ημερομηνίες που ορίζεις εδώ δεν θα δέχονται κρατήσεις από πελάτες.
            </p>

            {/* Add form */}
            <form onSubmit={addClosure} style={{ background: '#f8fafc', borderRadius: 10, padding: 14, marginBottom: 20 }}>
              <div className="form-grid-2" style={{ marginBottom: 10 }}>
                <div className="form-group" style={{ marginBottom: 0 }}>
                  <label className="form-label">Από ημερομηνία *</label>
                  <input type="date" className="form-input" value={closureForm.date_from}
                    onChange={e => setClosureForm({ ...closureForm, date_from: e.target.value, date_to: closureForm.date_to || e.target.value })} />
                </div>
                <div className="form-group" style={{ marginBottom: 0 }}>
                  <label className="form-label">Έως ημερομηνία *</label>
                  <input type="date" className="form-input" value={closureForm.date_to}
                    min={closureForm.date_from}
                    onChange={e => setClosureForm({ ...closureForm, date_to: e.target.value })} />
                </div>
              </div>

              {/* Optional time range */}
              <div className="form-grid-2" style={{ marginBottom: 10 }}>
                <div className="form-group" style={{ marginBottom: 0 }}>
                  <label className="form-label">Ώρα από (προαιρετικό)</label>
                  <input type="time" className="form-input" value={closureForm.time_from}
                    onChange={e => setClosureForm({ ...closureForm, time_from: e.target.value })} />
                </div>
                <div className="form-group" style={{ marginBottom: 0 }}>
                  <label className="form-label">Ώρα έως</label>
                  <input type="time" className="form-input" value={closureForm.time_to}
                    onChange={e => setClosureForm({ ...closureForm, time_to: e.target.value })} />
                </div>
              </div>
              <div className="form-group" style={{ marginBottom: 10 }}>
                <label className="form-label">Αιτία</label>
                <input className="form-input" placeholder="π.χ. Πρωτοχρονιά, Τεχνική συντήρηση"
                  value={closureForm.reason}
                  onChange={e => setClosureForm({ ...closureForm, reason: e.target.value })} />
              </div>
              <button type="submit" className="btn btn-primary btn-sm" disabled={savingClosure}>
                <Plus size={13} /> Προσθήκη
              </button>
            </form>

            {/* List */}
            {closures.length === 0 ? (
              <div className="text-muted">Δεν υπάρχουν καταχωρημένες κλειστές ημέρες.</div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                {closures.map(c => (
                  <div key={c.id} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 14px', background: '#fef2f2', borderRadius: 8, border: '1px solid #fecaca' }}>
                    <CalendarOff size={15} style={{ color: '#ef4444', flexShrink: 0 }} />
                    <div style={{ flex: 1 }}>
                      <div style={{ fontWeight: 600, fontSize: '0.9rem' }}>
                        {new Date(c.date_from).toLocaleDateString('el-GR')}
                        {c.date_from !== c.date_to && ` — ${new Date(c.date_to).toLocaleDateString('el-GR')}`}
                        {c.time_from && <span style={{ fontWeight: 400, color: '#64748b', marginLeft: 8 }}>{c.time_from.slice(0,5)}–{c.time_to?.slice(0,5)}</span>}
                      </div>
                      {c.reason && <div style={{ fontSize: '0.8rem', color: '#64748b' }}>{c.reason}</div>}
                    </div>
                    <button onClick={() => deleteClosure(c.id)} style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#ef4444' }}>
                      ×
                    </button>
                  </div>
                ))}
              </div>
            )}

            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setShowClosures(false)}>Κλείσιμο</button>
            </div>
          </div>
        </div>
      )}
    </Layout>
  );
}
