import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import Layout from '../components/Layout';
import RecordPaymentModal from '../components/RecordPaymentModal';
import EditPaymentModal from '../components/EditPaymentModal';
import { firstPendingPayment, pendingPaymentForMembership } from '../utils/payment_helpers';
import ServiceIcon from '../components/ui/ServiceIcon';
import Avatar from '../components/ui/Avatar';
import api from '../api/client';
import toast from 'react-hot-toast';
import { mediaUrl } from '../utils/media';
import {
  eur,
  monthOptions,
  paymentStatusLabel,
  paymentTypeLabel,
} from '../utils/payments';
import {
  AlertTriangle, Bell, Check, ChevronDown, ChevronRight, CreditCard,
  LayoutList, Pencil, Plus, Search, Settings, Trash2, TrendingUp, Users,
} from 'lucide-react';

const FILTERS = [
  { id: 'all', label: 'Όλες' },
  { id: 'due_soon', label: 'Λήγουν σύντομα' },
  { id: 'overdue', label: 'Ληξιπρόθεσμες' },
  { id: 'pending', label: 'Εκκρεμείς' },
];

function normalize(str) {
  return String(str || '').toLowerCase().normalize('NFD').replace(/\p{M}/gu, '');
}

export default function Payments() {
  const [data, setData] = useState(null);
  const [filter, setFilter] = useState('all');
  const [month, setMonth] = useState('');
  const [view, setView] = useState('clients');
  const [search, setSearch] = useState('');
  const [expanded, setExpanded] = useState({});
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [reminderDays, setReminderDays] = useState(3);
  const [gracePeriodDays, setGracePeriodDays] = useState(15);
  const [savingSettings, setSavingSettings] = useState(false);
  const [packageOptions, setPackageOptions] = useState([]);
  const [allClients, setAllClients] = useState([]);
  const [recordingPayment, setRecordingPayment] = useState(null);
  const [editingPayment, setEditingPayment] = useState(null);
  const [clientPickerOpen, setClientPickerOpen] = useState(false);
  const [clientQuery, setClientQuery] = useState('');

  const months = useMemo(() => [{ value: '', label: 'Όλοι οι μήνες' }, ...monthOptions()], []);

  const load = async () => {
    const params = { filter };
    if (month) params.month = month;
    const [overviewRes, settingsRes, optionsRes, clientsRes] = await Promise.all([
      api.get('/client-admin/payments/overview', { params }),
      api.get('/client-admin/payment-settings'),
      api.get('/client-admin/package-options'),
      api.get('/client-admin/clients', { params: { status: 'active' } }),
    ]);
    setData(overviewRes.data);
    setReminderDays(settingsRes.data.payment_reminder_days ?? 3);
    setGracePeriodDays(settingsRes.data.grace_period_days ?? 15);
    setPackageOptions(optionsRes.data);
    setAllClients(clientsRes.data || []);
    const groups = overviewRes.data?.clients_grouped || [];
    setExpanded(Object.fromEntries(groups.map(g => [g.user_id, true])));
  };

  useEffect(() => { load().catch(() => toast.error('Σφάλμα φόρτωσης')); }, [filter, month]);

  const saveSettings = async () => {
    setSavingSettings(true);
    try {
      await api.patch('/client-admin/payment-settings', {
        payment_reminder_days: Number(reminderDays),
        grace_period_days: Number(gracePeriodDays),
      });
      toast.success('Οι ρυθμίσεις αποθηκεύτηκαν');
      setSettingsOpen(false);
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSavingSettings(false);
    }
  };

  const openClientPayment = async ({ userId, userName, membershipId = '', payment = null }) => {
    try {
      if (payment) {
        setRecordingPayment({ payment, clientName: userName || payment.user_name });
        setClientPickerOpen(false);
        setClientQuery('');
        return;
      }
      const res = await api.get(`/client-admin/clients/${userId}/payments`);
      const clientPayments = res.data || [];
      const pending = membershipId
        ? pendingPaymentForMembership(clientPayments, membershipId)
        : firstPendingPayment(clientPayments);
      if (!pending) {
        toast.error('Δεν υπάρχει εκκρεμής χρέωση — πρόσθεσε πρώτα πακέτο στη σελίδα πελάτη');
        return;
      }
      setRecordingPayment({ payment: pending, clientName: userName });
      setClientPickerOpen(false);
      setClientQuery('');
    } catch {
      toast.error('Δεν φορτώθηκαν οι πληρωμές του πελάτη');
    }
  };

  const removePayment = async (payment) => {
    if (!window.confirm(`Διαγραφή πληρωμής «${payment.description || payment.service_name || ''}»;`)) return;
    try {
      await api.delete(`/client-admin/payments/${payment.id}`);
      toast.success('Η πληρωμή διαγράφηκε');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const sendReminder = async (paymentId) => {
    try {
      await api.post(`/client-admin/payments/${paymentId}/remind`);
      toast.success('Η υπενθύμιση στάλθηκε στον πελάτη');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const summary = data?.summary;
  const payments = data?.payments || [];
  const clientsGrouped = data?.clients_grouped || [];
  const expiring = data?.expiring_memberships || [];

  const filteredClients = useMemo(() => {
    const q = normalize(search).trim();
    if (!q) return clientsGrouped;
    return clientsGrouped.filter(c => {
      const hay = normalize(`${c.user_name} ${c.user_phone || ''} ${c.user_email || ''}`);
      return hay.includes(q);
    });
  }, [clientsGrouped, search]);

  const pickerClients = useMemo(() => {
    const q = normalize(clientQuery).trim();
    const list = allClients.filter(c => (c.account_status || 'active') === 'active');
    if (!q) return list.slice(0, 20);
    return list.filter(c => {
      const hay = normalize(`${c.full_name} ${c.phone || ''} ${c.email || ''}`);
      return hay.includes(q);
    }).slice(0, 30);
  }, [allClients, clientQuery]);

  const toggleExpanded = (userId) => {
    setExpanded(prev => ({ ...prev, [userId]: !prev[userId] }));
  };

  const statusBadge = (status) => {
    const cls = {
      paid: 'badge-green',
      partial: 'badge-yellow',
      pending: 'badge-gray',
      overdue: 'badge-red',
    }[status] || 'badge-gray';
    return <span className={`badge ${cls}`}>{paymentStatusLabel(status)}</span>;
  };

  const renderPaymentRow = (p, compact = false) => {
    const due = (p.due_date || p.period_end || '').toString().slice(0, 10);
    const img = mediaUrl(p.service_image_url);
    return (
      <div key={p.id} className={`pay-item-row ${compact ? 'compact' : ''}`}>
        <div className="pay-client-cell">
          {!compact && (
            <div className="pay-service-thumb">
              {img ? <img src={img} alt="" /> : <ServiceIcon service={{ name: p.service_name }} size={22} />}
            </div>
          )}
          <div>
            <div style={{ fontWeight: 600, fontSize: compact ? '0.88rem' : undefined }}>
              {p.description || p.service_name || '—'}
            </div>
            <div className="text-muted" style={{ fontSize: '0.78rem' }}>
              {[
                p.payment_type ? paymentTypeLabel(p.payment_type) : null,
                p.period_start && p.period_end
                  ? `${String(p.period_start).slice(0, 10)} → ${String(p.period_end).slice(0, 10)}`
                  : null,
                due ? `λήξη ${due}` : null,
              ].filter(Boolean).join(' · ')}
            </div>
          </div>
        </div>
        <div className="pay-item-amounts">
          <span>{eur(p.amount_cents)}</span>
          {p.balance_cents > 0 && (
            <span className="pay-item-balance">υπόλ. {eur(p.balance_cents)}</span>
          )}
          {statusBadge(p.status)}
        </div>
        <div className="pay-item-actions">
          {p.balance_cents > 0 && (
            <button
              type="button"
              className="btn btn-primary btn-sm"
              title="Καταχώρηση πληρωμής"
              onClick={() => setRecordingPayment({ payment: p, clientName: p.user_name })}
            >
              <CreditCard size={14} />
            </button>
          )}
          <button
            type="button"
            className="btn btn-secondary btn-sm"
            title="Επεξεργασία"
            onClick={() => setEditingPayment(p)}
          >
            <Pencil size={14} />
          </button>
          {p.status !== 'paid' && p.user_id && (
            <button
              type="button"
              className="btn btn-secondary btn-sm"
              title="Υπενθύμιση"
              onClick={() => sendReminder(p.id)}
            >
              <Bell size={14} />
            </button>
          )}
          <button
            type="button"
            className="btn btn-danger btn-sm"
            title="Διαγραφή"
            onClick={() => removePayment(p)}
          >
            <Trash2 size={14} />
          </button>
        </div>
      </div>
    );
  };

  return (
    <Layout title="Πληρωμές">
      <div className="page-header">
        <div>
          <h2 className="page-title" style={{ margin: 0 }}>Επισκόπηση πληρωμών</h2>
          <p className="text-muted" style={{ marginTop: 4, fontSize: '0.9rem' }}>
            Πελάτες ομαδοποιημένοι · εκκρεμότητες · καταχώρηση πληρωμών
          </p>
        </div>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <button type="button" className="btn btn-primary btn-sm" onClick={() => setClientPickerOpen(true)}>
            <Plus size={14} /> Νέα πληρωμή
          </button>
          <button type="button" className="btn btn-secondary btn-sm" onClick={() => setSettingsOpen(true)}>
            <Settings size={14} /> Υπενθύμιση {reminderDays} ημ. πριν
          </button>
        </div>
      </div>

      {summary && (
        <div className="pay-kpi-grid">
          <div className="pay-kpi">
            <div className="pay-kpi-label">Σύνολο χρεώσεων</div>
            <div className="pay-kpi-value">{eur(summary.total_amount_cents)}</div>
          </div>
          <div className="pay-kpi ok">
            <div className="pay-kpi-label">Εισπράχθηκαν</div>
            <div className="pay-kpi-value">{eur(summary.total_paid_cents)}</div>
          </div>
          <div className="pay-kpi warn">
            <div className="pay-kpi-label">Υπόλοιπο</div>
            <div className="pay-kpi-value">{eur(summary.total_balance_cents)}</div>
          </div>
          <div className="pay-kpi">
            <div className="pay-kpi-label">Πελάτες</div>
            <div className="pay-kpi-value">{clientsGrouped.length}</div>
          </div>
          <div className="pay-kpi danger">
            <div className="pay-kpi-label">Ληξιπρόθεσμες</div>
            <div className="pay-kpi-value">{summary.count_overdue}</div>
          </div>
          <div className="pay-kpi warn">
            <div className="pay-kpi-label">Λήγουν σε {reminderDays} ημ.</div>
            <div className="pay-kpi-value">{summary.count_due_soon + summary.expiring_memberships}</div>
          </div>
        </div>
      )}

      <div className="pay-filters">
        {FILTERS.map(f => (
          <button
            key={f.id}
            type="button"
            className={`pay-filter-pill ${filter === f.id ? 'active' : ''}`}
            onClick={() => setFilter(f.id)}
          >
            {f.label}
          </button>
        ))}
        <select
          className="form-select"
          style={{ width: 'auto', minWidth: 180 }}
          value={month}
          onChange={e => setMonth(e.target.value)}
        >
          {months.map(m => (
            <option key={m.value || 'all'} value={m.value}>{m.label}</option>
          ))}
        </select>
        <div className="pay-view-toggle">
          <button
            type="button"
            className={`pay-filter-pill ${view === 'clients' ? 'active' : ''}`}
            onClick={() => setView('clients')}
          >
            <Users size={14} /> Ανά πελάτη
          </button>
          <button
            type="button"
            className={`pay-filter-pill ${view === 'list' ? 'active' : ''}`}
            onClick={() => setView('list')}
          >
            <LayoutList size={14} /> Λίστα
          </button>
        </div>
      </div>

      {view === 'clients' && (
        <div className="cb-search" style={{ marginBottom: 16 }}>
          <Search size={18} className="cb-search-icon" />
          <input
            className="cb-search-input"
            placeholder="Αναζήτηση πελάτη..."
            value={search}
            onChange={e => setSearch(e.target.value)}
          />
        </div>
      )}

      {expiring.length > 0 && filter !== 'overdue' && (
        <div className="card" style={{ marginBottom: 16, borderColor: '#fde68a', background: '#fffbeb' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12, fontWeight: 700 }}>
            <AlertTriangle size={18} color="#d97706" />
            Πακέτα που λήγουν τις επόμενες {reminderDays} ημέρες
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {expiring.map(m => (
              <div
                key={m.membership_id}
                style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 8 }}
              >
                <div>
                  <Link to={`/clients/${m.user_id}`} style={{ fontWeight: 600 }}>{m.user_name}</Link>
                  <span className="text-muted" style={{ marginLeft: 8, fontSize: '0.85rem' }}>
                    {m.service_name} · λήγει {String(m.valid_until).slice(0, 10)}
                  </span>
                </div>
                <button
                  type="button"
                  className="btn btn-primary btn-sm"
                  onClick={() => openClientPayment({ userId: m.user_id, userName: m.user_name, membershipId: m.membership_id })}
                >
                  <CreditCard size={14} /> Καταχώρηση πληρωμής
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {view === 'clients' ? (
        <div className="pay-clients-list">
          {filteredClients.map(client => {
            const isOpen = expanded[client.user_id] !== false;
            const hasIssue = client.count_overdue > 0 || client.total_balance_cents > 0;
            return (
              <div key={client.user_id} className={`pay-client-card ${hasIssue ? 'has-balance' : ''}`}>
                <div className="pay-client-card-head">
                  <button
                    type="button"
                    className="pay-client-toggle"
                    onClick={() => toggleExpanded(client.user_id)}
                  >
                    {isOpen ? <ChevronDown size={18} /> : <ChevronRight size={18} />}
                  </button>
                  <Avatar name={client.user_name} size={44} />
                  <div className="pay-client-card-info">
                    <Link to={`/clients/${client.user_id}`} className="pay-client-name">
                      {client.user_name}
                    </Link>
                    <div className="text-muted" style={{ fontSize: '0.82rem' }}>
                      {client.user_phone || client.user_email || '—'}
                      {' · '}
                      {client.payments.length} πληρωμ{client.payments.length === 1 ? 'ή' : 'ές'}
                    </div>
                    <div className="pay-client-stats">
                      <span className="pay-stat ok">Εισπράχθηκαν {eur(client.total_paid_cents)}</span>
                      {client.total_balance_cents > 0 && (
                        <span className="pay-stat warn">Εκκρεμεί {eur(client.total_balance_cents)}</span>
                      )}
                      {client.count_overdue > 0 && (
                        <span className="pay-stat danger">{client.count_overdue} ληξιπρόθ.</span>
                      )}
                      {client.count_pending > 0 && client.count_overdue === 0 && (
                        <span className="pay-stat muted">{client.count_pending} εκκρεμείς</span>
                      )}
                    </div>
                  </div>
                  <button
                    type="button"
                    className="btn btn-primary btn-sm"
                    onClick={() => openClientPayment({ userId: client.user_id, userName: client.user_name })}
                  >
                    <Plus size={14} /> Πληρωμή
                  </button>
                </div>
                {isOpen && (
                  <div className="pay-client-card-body">
                    {client.payments.map(p => renderPaymentRow(p, true))}
                  </div>
                )}
              </div>
            );
          })}
          {!filteredClients.length && (
            <div className="card text-muted" style={{ textAlign: 'center', padding: 40 }}>
              <Users size={36} style={{ opacity: 0.25, marginBottom: 10 }} />
              <div>Δεν βρέθηκαν πελάτες με πληρωμές</div>
              <button
                type="button"
                className="btn btn-primary btn-sm"
                style={{ marginTop: 16 }}
                onClick={() => setClientPickerOpen(true)}
              >
                <Plus size={14} /> Καταχώρηση πρώτης πληρωμής
              </button>
            </div>
          )}
        </div>
      ) : (
        <div className="card">
          <table>
            <thead>
              <tr>
                <th>Πελάτης</th>
                <th>Υπηρεσία / Περίοδος</th>
                <th>Ποσό</th>
                <th>Υπόλοιπο</th>
                <th>Λήξη / Προθεσμία</th>
                <th>Κατάσταση</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {payments.map(p => {
                const due = (p.due_date || p.period_end || '').toString().slice(0, 10);
                const img = mediaUrl(p.service_image_url);
                return (
                  <tr key={p.id}>
                    <td>
                      <Link to={`/clients/${p.user_id}`} style={{ fontWeight: 600 }}>
                        {p.user_name || '—'}
                      </Link>
                      {p.user_phone && (
                        <div className="text-muted" style={{ fontSize: '0.8rem' }}>{p.user_phone}</div>
                      )}
                    </td>
                    <td>
                      <div className="pay-client-cell">
                        <div className="pay-service-thumb">
                          {img ? <img src={img} alt="" /> : <ServiceIcon service={{ name: p.service_name }} size={22} />}
                        </div>
                        <div>
                          <div style={{ fontWeight: 600 }}>{p.description || p.service_name || '—'}</div>
                          <div className="text-muted" style={{ fontSize: '0.8rem' }}>
                            {[
                              p.payment_type ? paymentTypeLabel(p.payment_type) : null,
                              p.period_start && p.period_end
                                ? `${String(p.period_start).slice(0, 10)} → ${String(p.period_end).slice(0, 10)}`
                                : null,
                            ].filter(Boolean).join(' · ')}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td>{eur(p.amount_cents)}</td>
                    <td style={{ color: p.balance_cents > 0 ? '#ea580c' : undefined, fontWeight: p.balance_cents > 0 ? 600 : 400 }}>
                      {eur(p.balance_cents)}
                    </td>
                    <td>{due || '—'}</td>
                    <td>{statusBadge(p.status)}</td>
                    <td style={{ display: 'flex', gap: 4 }}>
                      <button
                        type="button"
                        className="btn btn-secondary btn-sm"
                        title="Επεξεργασία"
                        onClick={() => setEditingPayment(p)}
                      >
                        <Pencil size={14} />
                      </button>
                      {p.status !== 'paid' && p.user_id && (
                        <button
                          type="button"
                          className="btn btn-secondary btn-sm"
                          title="Υπενθύμιση"
                          onClick={() => sendReminder(p.id)}
                        >
                          <Bell size={14} />
                        </button>
                      )}
                      <button
                        type="button"
                        className="btn btn-primary btn-sm"
                        title="Καταχώρηση πληρωμής"
                        disabled={!p.balance_cents}
                        onClick={() => openClientPayment({
                          userId: p.user_id,
                          userName: p.user_name,
                          payment: p.balance_cents > 0 ? p : null,
                          membershipId: p.membership_id || '',
                        })}
                      >
                        <Plus size={14} />
                      </button>
                      <button
                        type="button"
                        className="btn btn-danger btn-sm"
                        title="Διαγραφή"
                        onClick={() => removePayment(p)}
                      >
                        <Trash2 size={14} />
                      </button>
                    </td>
                  </tr>
                );
              })}
              {!payments.length && (
                <tr>
                  <td colSpan={7} className="text-muted" style={{ textAlign: 'center', padding: 32 }}>
                    <TrendingUp size={32} style={{ opacity: 0.3, marginBottom: 8 }} />
                    <div>Δεν βρέθηκαν πληρωμές</div>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      {clientPickerOpen && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setClientPickerOpen(false)}>
          <div className="modal cb-modal" style={{ maxWidth: 480 }} onClick={e => e.stopPropagation()}>
            <div className="cb-modal-header">
              <div>
                <div className="cb-modal-title">Νέα πληρωμή</div>
                <div className="cb-modal-sub">Επίλεξε πελάτη για καταχώρηση</div>
              </div>
            </div>
            <div className="cb-form">
              <div className="cb-search open">
                <Search size={18} className="cb-search-icon" />
                <input
                  className="cb-search-input"
                  placeholder="Αναζήτηση πελάτη..."
                  value={clientQuery}
                  onChange={e => setClientQuery(e.target.value)}
                  autoFocus
                />
              </div>
              <div className="cb-client-list" style={{ marginTop: 10 }}>
                {pickerClients.length === 0 && (
                  <div className="cb-empty-inline">Δεν βρέθηκε πελάτης</div>
                )}
                {pickerClients.map(c => (
                  <button
                    key={c.id}
                    type="button"
                    className="cb-client-item"
                    onClick={() => openClientPayment({ userId: c.id, userName: c.full_name })}
                  >
                    <Avatar name={c.full_name} size={40} />
                    <div className="cb-client-item-text">
                      <div className="cb-client-item-name">{c.full_name}</div>
                      <div className="cb-client-item-meta">
                        {c.phone || c.email || '—'}
                        {c.active_packages > 0 && ` · ${c.active_packages} ενεργά πακέτα`}
                      </div>
                    </div>
                    <Check size={18} className="cb-check" style={{ opacity: 0 }} />
                  </button>
                ))}
              </div>
              <div className="cb-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setClientPickerOpen(false)}>
                  Ακύρωση
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {settingsOpen && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setSettingsOpen(false)}>
          <div className="modal" style={{ maxWidth: 420 }}>
            <div className="modal-title">Ρυθμίσεις πληρωμών & συνδρομών</div>
            <p className="text-muted" style={{ marginBottom: 16 }}>
              Υπενθυμίσεις πριν τη λήξη και περίοδος χάριτος μετά τη λήξη (μέχρι τότε μπορεί ακόμα κράτηση).
            </p>
            <div className="form-group">
              <label className="form-label">Ημέρες πριν τη λήξη (υπενθύμιση)</label>
              <input
                className="form-input"
                type="number"
                min="0"
                max="60"
                value={reminderDays}
                onChange={e => setReminderDays(e.target.value)}
              />
            </div>
            <div className="form-group">
              <label className="form-label">Περίοδος χάριτος μετά τη λήξη (ημέρες)</label>
              <input
                className="form-input"
                type="number"
                min="0"
                max="90"
                value={gracePeriodDays}
                onChange={e => setGracePeriodDays(e.target.value)}
              />
              <div className="text-muted" style={{ fontSize: '0.8rem', marginTop: 6 }}>
                Μετά τη λήξη, ο πελάτης μπορεί ακόμα να κλείνει θέσεις. Μετά από αυτές τις ημέρες, μπλοκάρεται.
              </div>
            </div>
            <div className="modal-footer">
              <button type="button" className="btn btn-secondary" onClick={() => setSettingsOpen(false)}>Ακύρωση</button>
              <button type="button" className="btn btn-primary" onClick={saveSettings} disabled={savingSettings}>
                {savingSettings ? 'Αποθήκευση...' : 'Αποθήκευση'}
              </button>
            </div>
          </div>
        </div>
      )}

      {editingPayment && (
        <EditPaymentModal
          open
          payment={editingPayment}
          clientName={editingPayment.user_name}
          packageOptions={packageOptions}
          onClose={() => setEditingPayment(null)}
          onSuccess={() => { setEditingPayment(null); load(); }}
        />
      )}

      {recordingPayment && (
        <RecordPaymentModal
          open
          payment={recordingPayment.payment}
          clientName={recordingPayment.clientName}
          onClose={() => setRecordingPayment(null)}
          onSuccess={() => { setRecordingPayment(null); load(); }}
        />
      )}
    </Layout>
  );
}
