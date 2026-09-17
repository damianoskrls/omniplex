import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { AnimatedCounter, WeekBarChart, DonutChart } from '../components/dashboard/DashboardCharts';
import {
  Calendar, Users, UserPlus, Package, Clock, ChevronRight, Dumbbell, AlertCircle, MapPin, FlaskConical,
  Pencil, Trash2, MessageSquarePlus, Check, X,
} from 'lucide-react';
import { groupBookingsBySlot, slotKey } from '../utils/groupBookingsBySlot';
import Avatar from '../components/ui/Avatar';
import TrialBookingModal from '../components/TrialBookingModal';
import ExpiringMembershipsModal from '../components/ExpiringMembershipsModal';

const KPI_STYLES = [
  { glow: '#76C043', icon: Calendar },
  { glow: '#65a838', icon: Calendar },
  { glow: '#4A8D2C', icon: Clock },
  { glow: '#14b8a6', icon: Users },
  { glow: '#f59e0b', icon: UserPlus },
  { glow: '#22c55e', icon: Package },
];

const STATUS_BADGE = {
  pending: 'badge-yellow',
  confirmed: 'badge-green',
  in_progress: 'badge-blue',
  completed: 'badge-green',
  cancelled: 'badge-gray',
};

const STATUS_LABEL = {
  pending: 'Αναμονή',
  confirmed: 'Επιβεβαιωμένη',
  in_progress: 'Σε εξέλιξη',
  completed: 'Ολοκληρωμένη',
  cancelled: 'Ακυρωμένη',
};

function formatTime(iso) {
  return new Date(iso).toLocaleTimeString('el-GR', { hour: '2-digit', minute: '2-digit' });
}

function relativeDate(iso) {
  const d = new Date(iso);
  const now = new Date();
  const diff = Math.floor((now - d) / 86400000);
  if (diff === 0) return 'Σήμερα';
  if (diff === 1) return 'Χθες';
  if (diff < 7) return `Πριν ${diff} μέρες`;
  return d.toLocaleDateString('el-GR', { day: 'numeric', month: 'short' });
}

function buildWeekChart(bookings, today) {
  const weekMap = {};
  for (const b of bookings) {
    if (['cancelled', 'no_show'].includes(b.status)) continue;
    const day = String(b.starts_at).slice(0, 10);
    weekMap[day] = (weekMap[day] || 0) + 1;
  }
  const days = [];
  const base = new Date(`${today}T12:00:00`);
  for (let i = 6; i >= 0; i -= 1) {
    const d = new Date(base);
    d.setDate(d.getDate() - i);
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    days.push({ day: key, count: weekMap[key] || 0 });
  }
  return days;
}

function buildServicesToday(sessions) {
  const map = new Map();
  for (const s of sessions) {
    const name = s.service_name || 'Άγνωστη';
    map.set(name, (map.get(name) || 0) + 1);
  }
  return [...map.entries()].map(([service_name, count]) => ({ service_name, count }));
}

async function enrichDashboardData(data) {
  const today = data.dates?.today || new Date().toISOString().slice(0, 10);
  const weekStart = data.dates?.week_start;
  const needsSessions = !data.today_sessions?.length && Number(data.today_bookings) > 0;
  const needsClients = !data.recent_clients?.length && Number(data.total_clients) > 0;
  const needsWeek = !data.week_chart?.length && Number(data.month_bookings) > 0;

  const tasks = [];
  if (needsSessions) tasks.push(api.get('/client-admin/bookings', { params: { date: today } }));
  if (needsClients) tasks.push(api.get('/client-admin/clients'));
  if (needsWeek) {
    tasks.push(api.get('/client-admin/bookings', {
      params: { from: weekStart || today, to: today },
    }));
  }

  if (!tasks.length) return data;

  const results = await Promise.all(tasks);
  let i = 0;
  let sessions = data.today_sessions || [];

  if (needsSessions) {
    const rows = results[i++]?.data || [];
    sessions = rows.map((b) => ({
      id: b.id,
      service_id: b.service_id,
      staff_id: b.staff_id,
      starts_at: b.starts_at,
      ends_at: b.ends_at,
      status: b.status,
      user_name: b.user_name,
      service_name: b.service_name,
      staff_name: b.staff_name,
      color_hex: b.color_hex,
    }));
  }

  if (needsClients) {
    data.recent_clients = (results[i++]?.data || []).slice(0, 6);
  }

  if (needsWeek) {
    data.week_chart = buildWeekChart(results[i++]?.data || [], today);
  }

  if (!data.services_today?.length && sessions.length) {
    data.services_today = buildServicesToday(sessions);
  }

  data.today_sessions = sessions;
  return data;
}

export default function Dashboard() {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [trials, setTrials] = useState([]);
  const [trialModalOpen, setTrialModalOpen] = useState(false);
  const [expiringMemberships, setExpiringMemberships] = useState([]);
  const [expiringModalOpen, setExpiringModalOpen] = useState(false);
  const [editingTrial, setEditingTrial] = useState(null);
  const [showPast, setShowPast] = useState(false);
  const [noteTrialId, setNoteTrialId] = useState(null);
  const [noteText, setNoteText] = useState('');
  const [savingNote, setSavingNote] = useState(false);

  function loadTrials(past = showPast) {
    api.get(`/client-admin/trials${past ? '?past=1' : ''}`).then(r => setTrials(r.data || [])).catch(() => {});
  }

  async function deleteTrial(id) {
    if (!window.confirm('Να διαγραφεί το δοκιμαστικό;')) return;
    await api.delete(`/client-admin/trials/${id}`);
    loadTrials();
  }

  async function saveNote(id) {
    setSavingNote(true);
    try {
      await api.patch(`/client-admin/trials/${id}`, { notes: noteText });
      setNoteTrialId(null);
      setNoteText('');
      loadTrials();
    } catch { /* ignore */ } finally { setSavingNote(false); }
  }

  useEffect(() => {
    api.get('/client-admin/dashboard')
      .then(async (r) => enrichDashboardData(r.data))
      .then(setStats)
      .catch((err) => {
        console.error(err);
        toast.error(err.response?.data?.error || 'Δεν φορτώθηκε το dashboard');
      })
      .finally(() => setLoading(false));
    loadTrials(false);

    // Check for expiring memberships — show modal once per calendar day
    const todayKey = new Date().toISOString().slice(0, 10);
    const dismissed = localStorage.getItem('expiring_dismissed_date');
    if (dismissed !== todayKey) {
      api.get('/client-admin/expiring-memberships').then(r => {
        if (r.data && r.data.length > 0) {
          setExpiringMemberships(r.data);
          setExpiringModalOpen(true);
        }
      }).catch(() => {});
    }
  }, []);

  const cards = stats ? [
    { label: 'Κρατήσεις σήμερα', value: stats.today_bookings, link: `/bookings?date=${stats.dates?.today || ''}` },
    { label: 'Κρατήσεις μήνα', value: stats.month_bookings },
    { label: 'Αύριο', value: stats.tomorrow_bookings, link: `/bookings?date=${stats.dates?.tomorrow || ''}` },
    { label: 'Σύνολο πελατών', value: stats.total_clients, link: '/clients' },
    {
      label: 'Εκκρεμείς εγγραφές',
      value: stats.pending_clients,
      link: stats.pending_clients > 0 ? '/clients?status=pending' : null,
      warn: stats.pending_clients > 0,
    },
    { label: 'Πελάτες με πακέτο', value: stats.active_members, link: '/clients' },
    {
      label: 'Λίστα αναμονής',
      value: stats.waitlist_pending || 0,
      link: (stats.waitlist_pending || 0) > 0 ? '/bookings?mode=waitlist' : null,
      warn: (stats.waitlist_pending || 0) > 0,
    },
  ] : [];

  const now = new Date();

  return (
    <Layout title="Dashboard">
      {loading && !stats ? (
        <div className="loading">Φόρτωση...</div>
      ) : (
        <>
          <div className="dashboard-kpi-grid">
            {cards.map((c, i) => {
              const style = KPI_STYLES[i] || KPI_STYLES[0];
              const Icon = style.icon;
              const inner = (
                <>
                  <div className="dashboard-kpi__glow" style={{ background: style.glow }} />
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <Icon size={16} color={style.glow} />
                    <div className="dashboard-kpi__label">{c.label}</div>
                  </div>
                  <div className="dashboard-kpi__value" style={{ color: c.warn ? '#d97706' : undefined }}>
                    <AnimatedCounter value={c.value} />
                  </div>
                </>
              );
              return c.link ? (
                <Link key={c.label} to={c.link} className={`dashboard-kpi ${c.warn ? 'dashboard-kpi--warn' : ''}`}>
                  {inner}
                </Link>
              ) : (
                <div key={c.label} className="dashboard-kpi">{inner}</div>
              );
            })}
          </div>

          {/* Trials widget */}
          <div className="dash-trial-widget">
            <div className="dash-trial-widget__head">
              <span><FlaskConical size={16} style={{ color: '#76C043', marginRight: 6 }} />Δοκιμαστικά{trials.length > 0 ? ` (${trials.length})` : ''}</span>
              <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                <button
                  className="btn btn-secondary btn-sm"
                  onClick={() => { const next = !showPast; setShowPast(next); loadTrials(next); }}
                  style={{ fontSize: 12 }}
                >
                  {showPast ? 'Εκκρεμή' : 'Προηγούμενα'}
                </button>
                <button className="btn btn-primary btn-sm" onClick={() => { setEditingTrial(null); setTrialModalOpen(true); }}>+ Νέο</button>
              </div>
            </div>
            {trials.length === 0 ? (
              <p className="dash-trial-widget__empty">{showPast ? 'Δεν υπάρχουν προηγούμενα δοκιμαστικά' : 'Δεν υπάρχουν επερχόμενα δοκιμαστικά'}</p>
            ) : (
              <div className="dash-trial-list">
                {trials.map(t => {
                  const isPast = new Date(t.starts_at) < now;
                  return (
                    <div key={t.id} className="dash-trial-row" style={{ opacity: isPast ? 0.75 : 1 }}>
                      <FlaskConical size={14} style={{ color: '#76C043', flexShrink: 0, marginTop: 2 }} />
                      <div className="dash-trial-row__info" style={{ flex: 1 }}>
                        <span className="dash-trial-row__name">{t.user_name || '— Χωρίς πελάτη —'}</span>
                        <span className="dash-trial-row__meta">
                          {new Date(t.starts_at).toLocaleDateString('el-GR', { day: 'numeric', month: 'short' })}
                          {' · '}
                          {new Date(t.starts_at).toLocaleTimeString('el-GR', { hour: '2-digit', minute: '2-digit' })}
                          {t.service_name ? ` · ${t.service_name}` : ''}
                          {t.staff_name ? ` · ${t.staff_name}` : ''}
                        </span>
                        {/* Note display */}
                        {t.notes && noteTrialId !== t.id && (
                          <span style={{ fontSize: 12, color: '#475569', marginTop: 2, display: 'block', fontStyle: 'italic' }}>
                            💬 {t.notes}
                          </span>
                        )}
                        {/* Note editor */}
                        {noteTrialId === t.id && (
                          <div style={{ display: 'flex', gap: 6, marginTop: 6, alignItems: 'center' }}>
                            <input
                              className="form-input"
                              style={{ flex: 1, fontSize: 13, padding: '5px 10px' }}
                              placeholder="π.χ. Ήρθε, συζητήσαμε τιμές..."
                              value={noteText}
                              onChange={e => setNoteText(e.target.value)}
                              onKeyDown={e => { if (e.key === 'Enter') saveNote(t.id); if (e.key === 'Escape') { setNoteTrialId(null); setNoteText(''); } }}
                              autoFocus
                            />
                            <button className="btn btn-primary btn-sm" onClick={() => saveNote(t.id)} disabled={savingNote}>
                              <Check size={13} />
                            </button>
                            <button className="btn btn-secondary btn-sm" onClick={() => { setNoteTrialId(null); setNoteText(''); }}>
                              <X size={13} />
                            </button>
                          </div>
                        )}
                      </div>
                      {/* Actions */}
                      <div style={{ display: 'flex', gap: 4, alignItems: 'flex-start' }}>
                        <button title="Σχόλιο" style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#94a3b8', padding: 4 }}
                          onClick={() => { setNoteTrialId(t.id); setNoteText(t.notes || ''); }}>
                          <MessageSquarePlus size={15} />
                        </button>
                        <button title="Επεξεργασία" style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#94a3b8', padding: 4 }}
                          onClick={() => { setEditingTrial(t); setTrialModalOpen(true); }}>
                          <Pencil size={14} />
                        </button>
                        <button title="Διαγραφή" style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#f87171', padding: 4 }}
                          onClick={() => deleteTrial(t.id)}>
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          <TrialBookingModal
            open={trialModalOpen}
            editTrial={editingTrial}
            onClose={() => { setTrialModalOpen(false); setEditingTrial(null); }}
            onSuccess={() => loadTrials()}
          />

          <ExpiringMembershipsModal
            memberships={expiringModalOpen ? expiringMemberships : []}
            onClose={() => {
              setExpiringModalOpen(false);
              localStorage.setItem('expiring_dismissed_date', new Date().toISOString().slice(0, 10));
            }}
          />

          {(stats?.pending_bookings > 0) && (
            <Link to="/bookings?mode=all&status=pending" className="dash-alert">
              <AlertCircle size={18} />
              <span>{stats.pending_bookings} κράτηση/εις σε αναμονή επιβεβαίωσης</span>
              <ChevronRight size={16} />
            </Link>
          )}

          {(stats?.waitlist_pending > 0) && (
            <Link to="/bookings?mode=waitlist" className="dash-alert" style={{ borderColor: '#fbbf24', background: '#fffbeb' }}>
              <Clock size={18} color="#d97706" />
              <span>{stats.waitlist_pending} πελάτης/ες στη λίστα αναμονής — αποδοχή ή απόρριψη</span>
              <ChevronRight size={16} />
            </Link>
          )}

          <div className="dash-widgets">
            <section className="dash-widget dash-widget--wide">
              <div className="dash-widget__head">
                <div>
                  <h2 className="dash-widget__title"><Calendar size={18} /> Κρατήσεις σήμερα</h2>
                  <p className="dash-widget__sub">{stats?.today_sessions?.length || 0} ραντεβού στο πρόγραμμα</p>
                </div>
                <Link to="/bookings" className="btn btn-secondary btn-sm">Όλες οι κρατήσεις</Link>
              </div>
              {!stats?.today_sessions?.length ? (
                <div className="dash-empty">
                  <Calendar size={32} style={{ color: '#94a3b8', marginBottom: 8 }} />
                  <p>Δεν υπάρχουν κρατήσεις σήμερα</p>
                </div>
              ) : (
                <div className="dash-timeline">
                  {groupBookingsBySlot(stats.today_sessions).map((slot, i) => {
                    const isPast = new Date(slot.ends_at) < now;
                    const isNow = new Date(slot.starts_at) <= now && new Date(slot.ends_at) >= now;
                    return (
                      <div
                        key={slotKey(slot)}
                        className={`dash-timeline__slot ${isNow ? 'dash-timeline__slot--now' : ''} ${isPast ? 'dash-timeline__slot--past' : ''}`}
                        style={{ animationDelay: `${i * 50}ms` }}
                      >
                        <div className="dash-timeline__time">
                          <span>{formatTime(slot.starts_at)}</span>
                          <span className="dash-timeline__duration">{formatTime(slot.ends_at)}</span>
                        </div>
                        <div className="dash-timeline__dot" style={{ background: slot.color_hex || '#76C043' }} />
                        <div className="dash-timeline__body">
                          <div className="dash-timeline__meta">
                            {slot.location_name && (
                              <span className="dash-location-badge">
                                <MapPin size={12} />
                                {slot.location_name}
                              </span>
                            )}
                            <span>
                              {slot.service_name} · {slot.staff_name}
                              {slot.schedule_label ? ` · ${slot.schedule_label}` : ''}
                            </span>
                          </div>
                          <div className="dash-slot-participants">
                            {slot.bookings.map((b) => (
                              <Link
                                key={b.id}
                                to={`/bookings?id=${b.id}`}
                                className="dash-slot-person"
                                title={b.user_name}
                              >
                                <Avatar name={b.user_name} image={b.user_avatar_url} size={32} />
                                <span className="dash-slot-person__name">{b.user_name}</span>
                                <span className={`badge ${STATUS_BADGE[b.status] || 'badge-gray'}`}>
                                  {STATUS_LABEL[b.status] || b.status}
                                </span>
                              </Link>
                            ))}
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </section>

            {(stats?.waitlist_today?.length > 0) && (
              <section className="dash-widget">
                <div className="dash-widget__head">
                  <div>
                    <h2 className="dash-widget__title"><Clock size={18} /> Αναμονή σήμερα</h2>
                    <p className="dash-widget__sub">Πελάτες που περιμένουν θέση</p>
                  </div>
                  <Link to="/bookings?mode=waitlist" className="btn btn-secondary btn-sm">Όλη η λίστα</Link>
                </div>
                <div className="bk-waitlist-section" style={{ margin: 0, border: 'none', padding: 0 }}>
                  {stats.waitlist_today.map((w) => (
                    <div key={w.id} className="bk-waitlist-row">
                      <div style={{ flex: 1 }}>
                        <div style={{ fontWeight: 700 }}>
                          {new Date(w.starts_at).toLocaleTimeString('el-GR', { hour: '2-digit', minute: '2-digit' })}
                          {' — '}{w.service_name}
                        </div>
                        <div className="text-muted">{w.user_name} · #{w.position}</div>
                      </div>
                      <span className={`badge ${w.status === 'offered' ? 'badge-green' : 'badge-yellow'}`}>
                        {w.status === 'offered' ? 'Προσφέρθηκε' : 'Αναμονή'}
                      </span>
                    </div>
                  ))}
                </div>
              </section>
            )}

            <section className="dash-widget">
              <div className="dash-widget__head">
                <div>
                  <h2 className="dash-widget__title">Κρατήσεις 7 ημερών</h2>
                  <p className="dash-widget__sub">Εβδομαδιαία τάση</p>
                </div>
              </div>
              <WeekBarChart data={stats?.week_chart || []} />
            </section>

            <section className="dash-widget">
              <div className="dash-widget__head">
                <div>
                  <h2 className="dash-widget__title">Σήμερα ανά υπηρεσία</h2>
                  <p className="dash-widget__sub">Κατανομή συνεδριών</p>
                </div>
              </div>
              <DonutChart data={stats?.services_today || []} />
            </section>

            <section className="dash-widget">
              <div className="dash-widget__head">
                <div>
                  <h2 className="dash-widget__title"><Users size={18} /> Τελευταίοι πελάτες</h2>
                  <p className="dash-widget__sub">Πρόσφατες εγγραφές</p>
                </div>
                <Link to="/clients" className="btn btn-secondary btn-sm">Όλοι</Link>
              </div>
              {!stats?.recent_clients?.length ? (
                <div className="dash-empty"><p>Δεν υπάρχουν πελάτες ακόμα</p></div>
              ) : (
                <div className="dash-client-list">
                  {stats.recent_clients.map((c, i) => (
                    <Link
                      key={c.id}
                      to={`/clients/${c.id}`}
                      className="dash-client-list__item"
                      style={{ animationDelay: `${i * 40}ms` }}
                    >
                      <div
                        className="dash-client-list__avatar"
                        style={{ background: `hsl(${(c.full_name?.charCodeAt(0) || 0) * 3 % 360}, 45%, 45%)` }}
                      >
                        {c.full_name?.[0]?.toUpperCase()}
                      </div>
                      <div className="dash-client-list__info">
                        <div className="dash-client-list__name">{c.full_name}</div>
                        <div className="dash-client-list__meta">{c.email || c.phone || '—'}</div>
                      </div>
                      <div className="dash-client-list__date">{relativeDate(c.created_at)}</div>
                    </Link>
                  ))}
                </div>
              )}
            </section>
          </div>
        </>
      )}
    </Layout>
  );
}
