import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import Layout from '../../components/Layout';
import api from '../../api/client';
import toast from 'react-hot-toast';
import { Calendar, Check, Clock, MapPin, User, X } from 'lucide-react';

const STATUS_LABEL = {
  pending: 'Αναμονή',
  confirmed: 'Επιβεβαιωμένη',
  cancelled: 'Ακυρωμένη',
  completed: 'Ολοκληρωμένη',
  no_show: 'Δεν προσήλθε',
};

const STATUS_BADGE = {
  pending: 'badge-yellow',
  confirmed: 'badge-green',
  cancelled: 'badge-gray',
  completed: 'badge-green',
  no_show: 'badge-red',
};

function localDayKey(d = new Date()) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function addDaysToKey(baseKey, n) {
  const d = new Date(`${baseKey}T12:00:00`);
  d.setDate(d.getDate() + n);
  return localDayKey(d);
}

function formatTimeRange(startsAt, endsAt) {
  const start = new Date(startsAt);
  const end = new Date(endsAt);
  return `${start.toLocaleTimeString('el-GR', { hour: '2-digit', minute: '2-digit' })} – ${end.toLocaleTimeString('el-GR', { hour: '2-digit', minute: '2-digit' })}`;
}

function groupByDayAndSlot(bookings) {
  const dayMap = new Map();
  for (const b of bookings) {
    const dayKey = new Date(b.starts_at).toISOString().slice(0, 10);
    const slotKey = `${b.starts_at}|${b.ends_at}|${b.service_id || b.service_name}`;
    if (!dayMap.has(dayKey)) dayMap.set(dayKey, new Map());
    const slotMap = dayMap.get(dayKey);
    if (!slotMap.has(slotKey)) {
      slotMap.set(slotKey, {
        starts_at: b.starts_at,
        ends_at: b.ends_at,
        service_name: b.service_name,
        schedule_label: b.schedule_label,
        room_name: b.room_name,
        duration_mins: b.duration_mins,
        bookings: [],
      });
    }
    slotMap.get(slotKey).bookings.push(b);
  }

  return [...dayMap.entries()]
    .sort((a, b) => a[0].localeCompare(b[0]))
    .map(([date, slotMap]) => ({
      date,
      slots: [...slotMap.values()]
        .sort((a, b) => a.starts_at.localeCompare(b.starts_at))
        .map((slot) => ({
          ...slot,
          bookings: slot.bookings.sort((a, b) => (a.user_name || '').localeCompare(b.user_name || '', 'el')),
        })),
    }));
}

export default function TrainerSchedule() {
  const [overview, setOverview] = useState(null);
  const [bookings, setBookings] = useState([]);
  const [waitlist, setWaitlist] = useState([]);
  const [view, setView] = useState('today');
  const [loading, setLoading] = useState(true);
  const [serverDates, setServerDates] = useState(null);

  const today = serverDates?.today || localDayKey();
  const tomorrow = serverDates?.tomorrow || addDaysToKey(today, 1);
  const weekEnd = serverDates?.week_end || addDaysToKey(today, 6);

  const load = async () => {
    const ovRes = await api.get('/client-admin/trainer/overview');
    setOverview(ovRes.data);
    setServerDates(ovRes.data.dates || null);
    const dates = ovRes.data.dates || {};
    const params = view === 'today'
      ? { from: dates.today, to: dates.today }
      : view === 'tomorrow'
        ? { from: dates.tomorrow, to: dates.tomorrow }
        : { from: dates.today, to: dates.week_end };
    const bkRes = await api.get('/client-admin/trainer/bookings', { params });
    setBookings(bkRes.data);
    const wlRes = await api.get('/client-admin/trainer/waitlist', { params });
    setWaitlist(wlRes.data || []);
  };

  useEffect(() => {
    setLoading(true);
    load().catch(() => toast.error('Σφάλμα φόρτωσης')).finally(() => setLoading(false));
  }, [view]);

  const updateStatus = async (id, status) => {
    try {
      await api.patch(`/client-admin/trainer/bookings/${id}/status`, { status });
      toast.success('Ενημερώθηκε');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const markAttendance = async (id, attended) => {
    try {
      await api.patch(`/client-admin/trainer/bookings/${id}/attendance`, { attended });
      toast.success(attended ? 'Παρουσία καταχωρήθηκε' : 'Σημειώθηκε ως no-show');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const convertWaitlist = async (id) => {
    try {
      await api.post(`/client-admin/trainer/waitlist/${id}/convert`, { use_credit: true });
      toast.success('Η κράτηση επιβεβαιώθηκε — ο πελάτης ειδοποιήθηκε');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const removeWaitlist = async (id) => {
    if (!window.confirm('Απόρριψη από τη λίστα αναμονής;')) return;
    try {
      await api.delete(`/client-admin/trainer/waitlist/${id}`);
      toast.success('Απορρίφθηκε');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const grouped = useMemo(() => groupByDayAndSlot(bookings), [bookings]);

  if (loading && !overview) {
    return <Layout title="Πρόγραμμα" variant="trainer"><div className="loading">Φόρτωση...</div></Layout>;
  }

  return (
    <Layout title="Πρόγραμμα" variant="trainer">
      <div className="page-header">
        <div>
          <h1 className="page-title">Το πρόγραμμά μου</h1>
          <p className="text-muted" style={{ margin: '6px 0 0' }}>
            Σήμερα, αύριο & εβδομάδα — με ποιον προπονείσαι
          </p>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 20 }}>
        <div className="card" style={{ padding: 16 }}>
          <div className="text-muted" style={{ fontSize: '0.75rem', fontWeight: 700, textTransform: 'uppercase' }}>Σήμερα</div>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, marginTop: 6 }}>{overview?.today?.total || 0}</div>
          {(overview?.today?.pending || 0) > 0 && (
            <div style={{ color: '#b45309', fontSize: '0.82rem', marginTop: 4 }}>{overview.today.pending} σε αναμονή</div>
          )}
        </div>
        <div className="card" style={{ padding: 16 }}>
          <div className="text-muted" style={{ fontSize: '0.75rem', fontWeight: 700, textTransform: 'uppercase' }}>Αύριο</div>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, marginTop: 6 }}>{overview?.tomorrow?.total || 0}</div>
        </div>
        <div className="card" style={{ padding: 16 }}>
          <div className="text-muted" style={{ fontSize: '0.75rem', fontWeight: 700, textTransform: 'uppercase' }}>7 ημέρες</div>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, marginTop: 6 }}>{overview?.week_sessions || 0}</div>
        </div>
      </div>

      <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
        {[
          { id: 'today', label: 'Σήμερα' },
          { id: 'tomorrow', label: 'Αύριο' },
          { id: 'week', label: 'Εβδομάδα' },
        ].map(tab => (
          <button
            key={tab.id}
            type="button"
            className={`btn btn-sm ${view === tab.id ? 'btn-primary' : 'btn-secondary'}`}
            onClick={() => setView(tab.id)}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {waitlist.length > 0 && (
        <div className="card" style={{ marginBottom: 20, padding: 16, borderColor: '#fde68a', background: '#fffbeb' }}>
          <h3 style={{ fontSize: '0.95rem', fontWeight: 700, marginBottom: 12, color: '#b45309' }}>
            Λίστα αναμονής ({waitlist.length})
          </h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {waitlist.map((w) => (
              <div key={w.id} className="bk-waitlist-row" style={{ background: '#fff', borderRadius: 12, padding: '10px 12px' }}>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 700 }}>
                    {new Date(w.starts_at).toLocaleString('el-GR', {
                      weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit',
                    })}
                    {' — '}{w.service_name}
                  </div>
                  <div className="text-muted">{w.user_name} · θέση #{w.position}</div>
                </div>
                <span className={`badge ${w.status === 'offered' ? 'badge-green' : 'badge-yellow'}`}>
                  {w.status === 'offered' ? 'Προσφέρθηκε' : 'Αναμονή'}
                </span>
                <button type="button" className="btn btn-primary btn-sm" onClick={() => convertWaitlist(w.id)}>
                  <Check size={13} /> Αποδοχή
                </button>
                <button type="button" className="btn btn-danger btn-sm" onClick={() => removeWaitlist(w.id)}>
                  <X size={13} /> Απόρριψη
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {!grouped.length ? (
        <div className="card" style={{ padding: 40, textAlign: 'center' }}>
          <Calendar size={32} style={{ color: '#94a3b8', marginBottom: 12 }} />
          <p className="text-muted">Δεν υπάρχουν προπονήσεις σε αυτή την περίοδο</p>
        </div>
      ) : (
        grouped.map(({ date, slots }) => (
          <div key={date} style={{ marginBottom: 20 }}>
            <h3 style={{ fontSize: '0.95rem', fontWeight: 700, marginBottom: 10, color: '#475569' }}>
              {new Date(`${date}T12:00:00`).toLocaleDateString('el-GR', {
                weekday: 'long', day: 'numeric', month: 'long',
              })}
            </h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {slots.map((slot) => {
                const isPast = new Date(slot.ends_at) < new Date();
                const isNow = new Date(slot.starts_at) <= new Date() && new Date(slot.ends_at) >= new Date();
                const pendingCount = slot.bookings.filter((b) => b.status === 'pending').length;
                return (
                  <div
                    key={`${slot.starts_at}-${slot.ends_at}`}
                    className="card"
                    style={{
                      padding: 0,
                      overflow: 'hidden',
                      borderColor: isNow ? 'rgba(118,192,67,0.45)' : undefined,
                      boxShadow: isNow ? '0 4px 20px rgba(118,192,67,0.12)' : undefined,
                    }}
                  >
                    <div
                      style={{
                        padding: '14px 16px',
                        background: isNow ? 'linear-gradient(135deg, rgba(118,192,67,0.1), #fff)' : '#f8fafc',
                        borderBottom: '1px solid #e2e8f0',
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                        gap: 12,
                        flexWrap: 'wrap',
                      }}
                    >
                      <div>
                        <div style={{ fontWeight: 800, fontSize: '1.1rem', color: '#0f172a' }}>
                          {formatTimeRange(slot.starts_at, slot.ends_at)}
                        </div>
                        <div className="text-muted" style={{ fontSize: '0.88rem', marginTop: 4 }}>
                          {slot.service_name}
                          {slot.schedule_label ? ` · ${slot.schedule_label}` : ''}
                        </div>
                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12, marginTop: 6, fontSize: '0.82rem', color: '#64748b' }}>
                          {slot.room_name && (
                            <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                              <MapPin size={14} /> {slot.room_name}
                            </span>
                          )}
                          <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                            <Clock size={14} /> {slot.duration_mins || '—'} λεπτά
                          </span>
                          <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                            <User size={14} /> {slot.bookings.length} {slot.bookings.length === 1 ? 'άτομο' : 'άτομα'}
                          </span>
                        </div>
                      </div>
                      {pendingCount > 0 && (
                        <span className="badge badge-yellow">{pendingCount} σε αναμονή</span>
                      )}
                    </div>

                    <div style={{ display: 'flex', flexDirection: 'column' }}>
                      {slot.bookings.map((b, i) => (
                        <div
                          key={b.id}
                          style={{
                            padding: '14px 16px',
                            borderTop: i > 0 ? '1px solid #f1f5f9' : undefined,
                            opacity: isPast && !b.attendance_confirmed ? 0.75 : 1,
                          }}
                        >
                          <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
                            <div style={{ flex: 1, minWidth: 200 }}>
                              <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                                <Link to={`/trainer/clients/${b.user_id}`} style={{ fontWeight: 700, fontSize: '1.05rem', color: '#4A8D2C' }}>
                                  {b.user_name}
                                </Link>
                                <span className={`badge ${STATUS_BADGE[b.status] || 'badge-gray'}`}>
                                  {STATUS_LABEL[b.status] || b.status}
                                </span>
                                {b.is_trial ? <span className="badge badge-yellow">Δοκιμαστικό</span> : null}
                                {b.attendance_confirmed ? <span className="badge badge-green">Παρουσία</span> : null}
                              </div>
                              {b.user_phone && (
                                <div className="text-muted" style={{ fontSize: '0.82rem', marginTop: 4 }}>
                                  {b.user_phone}
                                </div>
                              )}
                              {b.preparation_tips && (
                                <div style={{ marginTop: 8, padding: '8px 10px', background: '#f0fdf4', borderRadius: 8, fontSize: '0.82rem' }}>
                                  <strong>Πριν:</strong> {b.preparation_tips}
                                </div>
                              )}
                              {b.fitness_goal && (
                                <div style={{ marginTop: 6, fontSize: '0.82rem', color: '#76C043' }}>
                                  Στόχος: {b.fitness_goal_label || b.fitness_goal}
                                </div>
                              )}
                            </div>
                            <div style={{ display: 'flex', flexDirection: 'column', gap: 6, alignItems: 'flex-end' }}>
                              {b.status === 'pending' && (
                                <>
                                  <button className="btn btn-primary btn-sm" onClick={() => updateStatus(b.id, 'confirmed')}>
                                    <Check size={14} /> Επιβεβαίωση
                                  </button>
                                  <button className="btn btn-danger btn-sm" onClick={() => updateStatus(b.id, 'cancelled')}>
                                    <X size={14} /> Ακύρωση
                                  </button>
                                </>
                              )}
                              {!b.attendance_confirmed && isPast && b.status !== 'cancelled' && (
                                <>
                                  <button className="btn btn-primary btn-sm" onClick={() => markAttendance(b.id, true)}>
                                    <Check size={14} /> Παρουσία
                                  </button>
                                  <button className="btn btn-secondary btn-sm" onClick={() => markAttendance(b.id, false)}>
                                    No-show
                                  </button>
                                </>
                              )}
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        ))
      )}
    </Layout>
  );
}
