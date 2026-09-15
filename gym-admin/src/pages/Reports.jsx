import { useCallback, useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { AnimatedCounter, WeekBarChart, DonutChart } from '../components/dashboard/DashboardCharts';
import { HorizontalBarChart, TimeOfDayChart } from '../components/reports/ReportCharts';
import {
  BarChart3, Calendar, Users, CreditCard, Sun, Apple, MapPin, Dumbbell,
  AlertTriangle, UserX, Package, TrendingUp, ChevronRight,
} from 'lucide-react';

const TABS = [
  { id: 'overview', label: 'Επισκόπηση', icon: BarChart3 },
  { id: 'services', label: 'Υπηρεσίες', icon: Dumbbell },
  { id: 'clients', label: 'Πελάτες', icon: Users },
  { id: 'payments', label: 'Πληρωμές', icon: CreditCard },
  { id: 'nutrition', label: 'Διατροφή', icon: Apple },
];

const YEAR = new Date().getFullYear();

function formatEuro(cents) {
  return new Intl.NumberFormat('el-GR', { style: 'currency', currency: 'EUR' }).format((cents || 0) / 100);
}

function formatDate(iso) {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString('el-GR', { day: 'numeric', month: 'short', year: 'numeric' });
}

function KpiCard({ icon: Icon, label, value, sub, color = '#76C043' }) {
  return (
    <div className="reports-kpi" style={{ '--kpi-color': color }}>
      <div className="reports-kpi__icon"><Icon size={22} /></div>
      <div className="reports-kpi__value"><AnimatedCounter value={value} /></div>
      <div className="reports-kpi__label">{label}</div>
      {sub && <div className="reports-kpi__sub">{sub}</div>}
    </div>
  );
}

function ReportTable({ columns, rows, emptyLabel = 'Δεν υπάρχουν δεδομένα' }) {
  if (!rows?.length) {
    return <div className="text-muted reports-empty">{emptyLabel}</div>;
  }
  return (
    <div className="reports-table-wrap">
      <table className="reports-table">
        <thead>
          <tr>
            {columns.map((c) => <th key={c.key}>{c.label}</th>)}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, i) => (
            <tr key={row.id || row.user_id || i}>
              {columns.map((c) => (
                <td key={c.key}>{c.render ? c.render(row) : row[c.key]}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function Panel({ title, icon: Icon, children, className = '' }) {
  return (
    <div className={`reports-panel ${className}`}>
      <div className="reports-panel__head">
        {Icon && <Icon size={18} className="reports-panel__icon" />}
        <h3>{title}</h3>
      </div>
      {children}
    </div>
  );
}

export default function Reports() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState('overview');
  const [from, setFrom] = useState(`${YEAR}-01-01`);
  const [to, setTo] = useState(new Date().toISOString().slice(0, 10));
  const [locationId, setLocationId] = useState('');
  const [serviceId, setServiceId] = useState('');
  const [staffId, setStaffId] = useState('');
  const [planId, setPlanId] = useState('');
  const [inactiveDays, setInactiveDays] = useState('30');

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const params = { from, to, inactive_days: inactiveDays };
      if (locationId) params.location_id = locationId;
      if (serviceId) params.service_id = serviceId;
      if (staffId) params.staff_id = staffId;
      if (planId) params.plan_id = planId;
      const res = await api.get('/client-admin/reports', { params });
      setData(res.data);
    } catch (err) {
      toast.error(err.response?.data?.error || 'Αποτυχία φόρτωσης αναφορών');
    } finally {
      setLoading(false);
    }
  }, [from, to, locationId, serviceId, staffId, planId, inactiveDays]);

  useEffect(() => { load(); }, [load]);

  const opts = data?.filter_options || {};
  const kpis = data?.kpis || {};
  const trend = useMemo(() => {
    const rows = data?.bookings_trend || [];
    if (rows.length <= 14) return rows;
    return rows.slice(-14);
  }, [data]);

  const periodLabel = `${formatDate(from)} – ${formatDate(to)}`;

  return (
    <Layout>
      <div className="reports-page">
        <header className="reports-header">
          <div>
            <h1 className="page-title">Αναφορές</h1>
            <p className="text-muted">Πλήρη εικόνα της επιχείρησής σου — κρατήσεις, πελάτες, πληρωμές, ώρες</p>
          </div>
        </header>

        <div className="reports-filters card">
          <div className="reports-filters__row">
            <label>
              <span>Από</span>
              <input type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
            </label>
            <label>
              <span>Έως</span>
              <input type="date" value={to} onChange={(e) => setTo(e.target.value)} />
            </label>
            <label>
              <span>Τοποθεσία</span>
              <select value={locationId} onChange={(e) => setLocationId(e.target.value)}>
                <option value="">Όλες</option>
                {(opts.locations || []).map((l) => (
                  <option key={l.id} value={l.id}>{l.name}</option>
                ))}
              </select>
            </label>
            <label>
              <span>Υπηρεσία</span>
              <select value={serviceId} onChange={(e) => setServiceId(e.target.value)}>
                <option value="">Όλες</option>
                {(opts.services || []).map((s) => (
                  <option key={s.id} value={s.id}>{s.name}</option>
                ))}
              </select>
            </label>
            <label>
              <span>Γυμναστής</span>
              <select value={staffId} onChange={(e) => setStaffId(e.target.value)}>
                <option value="">Όλοι</option>
                {(opts.staff || []).map((s) => (
                  <option key={s.id} value={s.id}>{s.name}</option>
                ))}
              </select>
            </label>
            <label>
              <span>Πακέτο</span>
              <select value={planId} onChange={(e) => setPlanId(e.target.value)}>
                <option value="">Όλα</option>
                {(opts.plans || []).map((p) => (
                  <option key={p.id} value={p.id}>{p.name}</option>
                ))}
              </select>
            </label>
            <label>
              <span>Αδρανείς (ημέρες)</span>
              <select value={inactiveDays} onChange={(e) => setInactiveDays(e.target.value)}>
                <option value="14">14+</option>
                <option value="30">30+</option>
                <option value="60">60+</option>
                <option value="90">90+</option>
              </select>
            </label>
          </div>
          <div className="reports-filters__presets">
            <button type="button" className="btn-ghost btn-sm" onClick={() => {
              setFrom(`${YEAR}-01-01`);
              setTo(new Date().toISOString().slice(0, 10));
            }}>Από την αρχή του έτους</button>
            <button type="button" className="btn-ghost btn-sm" onClick={() => {
              const d = new Date();
              setFrom(new Date(d.getFullYear(), d.getMonth(), 1).toISOString().slice(0, 10));
              setTo(d.toISOString().slice(0, 10));
            }}>Τρέχων μήνας</button>
            <button type="button" className="btn-ghost btn-sm" onClick={() => {
              const d = new Date();
              d.setDate(d.getDate() - 29);
              setFrom(d.toISOString().slice(0, 10));
              setTo(new Date().toISOString().slice(0, 10));
            }}>Τελευταίες 30 μέρες</button>
          </div>
        </div>

        <div className="reports-tabs">
          {TABS.filter((t) => t.id !== 'nutrition' || data?.feature_nutrition !== false).map((t) => {
            const Icon = t.icon;
            return (
              <button
                key={t.id}
                type="button"
                className={`reports-tab ${tab === t.id ? 'reports-tab--active' : ''}`}
                onClick={() => setTab(t.id)}
              >
                <Icon size={16} />
                {t.label}
              </button>
            );
          })}
        </div>

        {loading ? (
          <div className="reports-loading">Φόρτωση αναφορών…</div>
        ) : (
          <>
            <div className="reports-kpi-grid">
              <KpiCard icon={Calendar} label="Κρατήσεις" value={kpis.total_bookings} sub={periodLabel} />
              <KpiCard icon={Users} label="Μοναδικοί αθλητές" value={kpis.unique_clients} color="#14b8a6" />
              <KpiCard icon={TrendingUp} label="Προσέλευση %" value={kpis.attendance_rate} sub="επιβεβαιωμένες" color="#22c55e" />
              <KpiCard icon={Package} label="Ενεργά μέλη" value={kpis.active_members} color="#65a838" />
              <KpiCard icon={Sun} label="Πρωινοί αθλητές" value={kpis.morning_clients} sub="πριν 12:00" color="#f59e0b" />
              <KpiCard icon={UserX} label="Αδρανείς" value={kpis.inactive_clients} sub={`${inactiveDays}+ ημέρες`} color="#ef4444" />
              <KpiCard icon={CreditCard} label="Οφειλές" value={kpis.unpaid_clients} sub={formatEuro(kpis.outstanding_cents)} color="#dc2626" />
              {data?.nutrition_clients?.length > 0 && (
                <KpiCard icon={Apple} label="Διατροφή" value={kpis.nutrition_clients} color="#84cc16" />
              )}
            </div>

            {tab === 'overview' && (
              <div className="reports-grid">
                <Panel title="Τάση κρατήσεων" icon={TrendingUp} className="reports-grid--wide">
                  <WeekBarChart data={trend} />
                </Panel>
                <Panel title="Κρατήσεις ανά ώρα" icon={Sun}>
                  <TimeOfDayChart data={data?.time_of_day || []} />
                </Panel>
                <Panel title="Κορυφαίες υπηρεσίες" icon={Dumbbell}>
                  <DonutChart
                    data={(data?.service_usage || []).slice(0, 6).map((s) => ({
                      service_name: s.service_name,
                      count: s.bookings,
                    }))}
                    centerLabel="κρατήσεις"
                  />
                </Panel>
                <Panel title="Ανά τοποθεσία" icon={MapPin}>
                  <HorizontalBarChart
                    data={data?.location_usage || []}
                    nameKey="location_name"
                    valueKey="bookings"
                  />
                </Panel>
                <Panel title="Ανά γυμναστή" icon={Users}>
                  <HorizontalBarChart
                    data={data?.trainer_usage || []}
                    nameKey="staff_name"
                    valueKey="bookings"
                  />
                </Panel>
              </div>
            )}

            {tab === 'services' && (
              <div className="reports-grid">
                <Panel title="Χρήση υπηρεσιών" icon={Dumbbell} className="reports-grid--full">
                  <ReportTable
                    columns={[
                      { key: 'name', label: 'Υπηρεσία', render: (r) => r.service_name },
                      { key: 'bookings', label: 'Κρατήσεις' },
                      { key: 'clients', label: 'Αθλητές', render: (r) => r.unique_clients },
                      { key: 'attended', label: 'Προσέλευση' },
                      { key: 'rate', label: '%', render: (r) => `${r.attendance_rate}%` },
                    ]}
                    rows={data?.service_usage || []}
                  />
                </Panel>
                <Panel title="Πακέτα & συνδρομές" icon={Package} className="reports-grid--full">
                  <ReportTable
                    columns={[
                      { key: 'name', label: 'Πακέτο', render: (r) => r.plan_name },
                      { key: 'type', label: 'Τύπος', render: (r) => r.plan_type === 'nutrition' ? 'Διατροφή' : 'Γυμναστήριο' },
                      { key: 'active', label: 'Ενεργοί', render: (r) => r.active_clients },
                      { key: 'sessions', label: 'Συνεδρίες', render: (r) => `${r.used_sessions} / ${r.total_sessions || '∞'}` },
                    ]}
                    rows={data?.package_usage || []}
                  />
                </Panel>
              </div>
            )}

            {tab === 'clients' && (
              <div className="reports-grid">
                <Panel title={`Πρωινοί αθλητές (${periodLabel})`} icon={Sun} className="reports-grid--full">
                  <ReportTable
                    columns={[
                      {
                        key: 'name',
                        label: 'Αθλητής',
                        render: (r) => (
                          <Link to={`/clients/${r.user_id}`} className="reports-link">
                            {r.full_name} <ChevronRight size={14} />
                          </Link>
                        ),
                      },
                      { key: 'bookings', label: 'Πρωινές κρατήσεις', render: (r) => r.morning_bookings },
                      { key: 'last', label: 'Τελευταία', render: (r) => formatDate(r.last_morning_at) },
                    ]}
                    rows={data?.morning_clients || []}
                    emptyLabel="Κανένας αθλητής με πρωινές κρατήσεις στο διάστημα"
                  />
                </Panel>
                <Panel title={`Αδρανείς (${inactiveDays}+ ημέρες)`} icon={AlertTriangle} className="reports-grid--full">
                  <ReportTable
                    columns={[
                      {
                        key: 'name',
                        label: 'Αθλητής',
                        render: (r) => (
                          <Link to={`/clients/${r.user_id}`} className="reports-link">
                            {r.full_name} <ChevronRight size={14} />
                          </Link>
                        ),
                      },
                      { key: 'last', label: 'Τελευταία επίσκεψη', render: (r) => formatDate(r.last_visit_at) },
                      { key: 'days', label: 'Ημέρες', render: (r) => r.days_inactive },
                      { key: 'packages', label: 'Ενεργά πακέτα', render: (r) => r.active_packages },
                    ]}
                    rows={data?.inactive_clients || []}
                    emptyLabel="Κανένας αδρανής πελάτης με αυτό το κριτήριο"
                  />
                </Panel>
                <Panel title="Ποτέ δεν ήρθαν (με ενεργό πακέτο)" icon={UserX} className="reports-grid--full">
                  <ReportTable
                    columns={[
                      {
                        key: 'name',
                        label: 'Αθλητής',
                        render: (r) => (
                          <Link to={`/clients/${r.user_id}`} className="reports-link">
                            {r.full_name} <ChevronRight size={14} />
                          </Link>
                        ),
                      },
                      { key: 'since', label: 'Εγγραφή', render: (r) => formatDate(r.created_at) },
                      { key: 'packages', label: 'Ενεργά πακέτα', render: (r) => r.active_packages },
                    ]}
                    rows={data?.never_visited || []}
                    emptyLabel="Όλοι οι ενεργοί πελάτες έχουν έρθει τουλάχιστον μία φορά"
                  />
                </Panel>
              </div>
            )}

            {tab === 'payments' && (
              <div className="reports-grid">
                <div className="reports-pay-summary">
                  <div className="reports-pay-stat">
                    <span className="badge badge-green">Εξοφλημένες</span>
                    <strong>{data?.payment_summary?.count_paid || 0}</strong>
                  </div>
                  <div className="reports-pay-stat">
                    <span className="badge badge-gray">Εκκρεμείς</span>
                    <strong>{data?.payment_summary?.count_pending || 0}</strong>
                  </div>
                  <div className="reports-pay-stat">
                    <span className="badge badge-red">Ληξιπρόθεσμες</span>
                    <strong>{data?.payment_summary?.count_overdue || 0}</strong>
                  </div>
                  <div className="reports-pay-stat reports-pay-stat--total">
                    <span>Σύνολο οφειλών</span>
                    <strong>{formatEuro(data?.payment_summary?.total_balance_cents)}</strong>
                  </div>
                </div>
                <Panel title="Πελάτες με οφειλές" icon={CreditCard} className="reports-grid--full">
                  <ReportTable
                    columns={[
                      {
                        key: 'name',
                        label: 'Πελάτης',
                        render: (r) => (
                          <Link to={`/clients/${r.user_id}`} className="reports-link">
                            {r.full_name} <ChevronRight size={14} />
                          </Link>
                        ),
                      },
                      { key: 'balance', label: 'Υπόλοιπο', render: (r) => formatEuro(r.balance_cents) },
                      { key: 'overdue', label: 'Ληξιπρόθεσμες', render: (r) => r.overdue_count },
                      { key: 'pending', label: 'Εκκρεμείς', render: (r) => r.pending_count },
                      { key: 'due', label: 'Τελευταία προθεσμία', render: (r) => formatDate(r.latest_due_date) },
                    ]}
                    rows={data?.unpaid_clients || []}
                    emptyLabel="Όλοι οι πελάτες είναι ενήμεροι 🎉"
                  />
                </Panel>
              </div>
            )}

            {tab === 'nutrition' && (
              <Panel title="Ενεργοί πελάτες διατροφής" icon={Apple} className="reports-grid--full">
                <ReportTable
                  columns={[
                    {
                      key: 'name',
                      label: 'Πελάτης',
                      render: (r) => (
                        <Link to={`/nutrition/clients/${r.user_id}`} className="reports-link">
                          {r.full_name} <ChevronRight size={14} />
                        </Link>
                      ),
                    },
                    { key: 'plan', label: 'Πακέτο', render: (r) => r.plan_name },
                    { key: 'until', label: 'Ισχύει έως', render: (r) => formatDate(r.valid_until) },
                    { key: 'sessions', label: 'Συνεδρίες', render: (r) => `${r.used_sessions} / ${r.total_sessions || '∞'}` },
                  ]}
                  rows={data?.nutrition_clients || []}
                  emptyLabel="Δεν υπάρχουν ενεργοί πελάτες διατροφής"
                />
              </Panel>
            )}
          </>
        )}
      </div>
    </Layout>
  );
}
