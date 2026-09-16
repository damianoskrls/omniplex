import { useEffect, useMemo, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import Layout from '../components/Layout';
import SubscriptionModal from '../components/SubscriptionModal';
import NutritionEnrollModal from '../components/NutritionEnrollModal';
import RecordPaymentModal from '../components/RecordPaymentModal';
import EditPaymentModal from '../components/EditPaymentModal';
import {
  isTrialMembership,
  pendingPaymentForMembership,
  filterPackageOptionsForClient,
  isGymPackageOption,
  membershipBalance,
} from '../utils/payment_helpers';
import ServiceIcon from '../components/ui/ServiceIcon';
import api from '../api/client';
import toast from 'react-hot-toast';
import { mediaUrl } from '../utils/media';
import {
  eur,
  paymentStatusLabel,
  paymentTypeLabel,
} from '../utils/payments';
import {
  ArrowLeft, Plus, Trash2, Pencil, Save, CalendarPlus, Check, Ban, RotateCcw,
  CreditCard, FlaskConical, Sparkles, RefreshCw, MessageSquare, AlertCircle, Dumbbell, X,
} from 'lucide-react';
import { fmtDate, fmtDateTime } from '../utils/dates';
import LocationCheckboxes from '../components/LocationCheckboxes';
import ClientBookingsSection from '../components/ClientBookingsSection';
import RenewalPaymentModal from '../components/RenewalPaymentModal';
import CancelSubscriptionModal from '../components/CancelSubscriptionModal';
import {
  ACCESS_STATE_LABELS,
  ACCESS_STATE_BADGE,
  canRenewMembership,
  canCancelMembership,
  canReactivateMembership,
} from '../utils/subscription_helpers';

const FITNESS_GOALS = [
  { id: '', label: '— Δεν έχει οριστεί —' },
  { id: 'weight_loss', label: 'Απώλεια βάρους' },
  { id: 'strength', label: 'Ενδυνάμωση' },
  { id: 'endurance', label: 'Αντοχή' },
  { id: 'flexibility', label: 'Ευλυγισία' },
  { id: 'rehabilitation', label: 'Αποκατάσταση' },
  { id: 'general', label: 'Γενική φυσική κατάσταση' },
];

const profileFromClient = (c) => ({
  full_name: c.full_name || '',
  phone: c.phone || '',
  date_of_birth: c.date_of_birth ? String(c.date_of_birth).slice(0, 10) : '',
  weight_kg: c.weight_kg != null ? String(c.weight_kg) : '',
  fitness_goal: c.fitness_goal || '',
  trainer_notes: c.trainer_notes || '',
  notes: c.notes || '',
  referred_by_user_id: c.referred_by_user_id || '',
});

export default function ClientDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [client, setClient] = useState(null);
  const [allClients, setAllClients] = useState([]);
  const [credits, setCredits] = useState([]);
  const [packageOptions, setPackageOptions] = useState([]);
  const [subscriptionOpen, setSubscriptionOpen] = useState(false);
  const [nutritionEnrollOpen, setNutritionEnrollOpen] = useState(false);
  const [activateTrialMembership, setActivateTrialMembership] = useState(null);
  const [recordingPayment, setRecordingPayment] = useState(null);
  const [editingPayment, setEditingPayment] = useState(null);
  const [editingCredit, setEditingCredit] = useState(null);
  const [renewalMembership, setRenewalMembership] = useState(null);
  const [cancelMembership, setCancelMembership] = useState(null);
  const [addPaymentFor, setAddPaymentFor] = useState(null);
  const [addPaymentForm, setAddPaymentForm] = useState({ amount: '', date: new Date().toISOString().slice(0, 10), method: 'cash', status: 'paid', period_start: '', period_end: '', period_month: '', period_day: '1' });
  const [payments, setPayments] = useState([]);
  const [clientPrograms, setClientPrograms] = useState([]);
  const [allPrograms, setAllPrograms] = useState([]);
  const [programAssignOpen, setProgramAssignOpen] = useState(false);
  const [assigningProgram, setAssigningProgram] = useState('');
  const [profileForm, setProfileForm] = useState(profileFromClient({}));
  const [savingProfile, setSavingProfile] = useState(false);
  const [locationIds, setLocationIds] = useState([]);
  const [editForm, setEditForm] = useState({
    total_sessions: 10,
    used_sessions: 0,
    valid_from: '',
    valid_until: '',
    notes: '',
    is_unlimited: false,
  });

  const paymentsByMembership = useMemo(() => {
    const map = new Map();
    for (const p of payments) {
      const keys = new Set([p.membership_id].filter(Boolean));
      for (const line of p.line_items || []) {
        if (line.membership_id) keys.add(line.membership_id);
      }
      if (!keys.size) keys.add(`orphan-${p.id}`);
      for (const key of keys) {
        if (!map.has(key)) map.set(key, []);
        map.get(key).push(p);
      }
    }
    return map;
  }, [payments]);

  const visibleCredits = useMemo(
    () => (credits || []).filter(c => c.service_category !== 'nutrition_consultation'),
    [credits],
  );

  const hasActiveNutrition = useMemo(
    () => (credits || []).some(c =>
      c.service_category === 'nutrition'
      && (c.membership_status !== 'trial')
      && (!c.valid_until || c.valid_until.slice(0, 10) >= new Date().toISOString().slice(0, 10)),
    ),
    [credits],
  );

  const gymPackageOptions = useMemo(
    () => (packageOptions || []).filter(isGymPackageOption),
    [packageOptions],
  );

  const selectableGymPackages = useMemo(
    () => filterPackageOptionsForClient(packageOptions, credits),
    [packageOptions, credits],
  );

  const allGymPackagesActive = gymPackageOptions.length > 0 && selectableGymPackages.length === 0;

  const openSubscription = () => {
    setActivateTrialMembership(null);
    if (allGymPackagesActive) {
      toast.error('Έχει ήδη ενεργό πακέτο για όλες τις υπηρεσίες γυμναστηρίου');
      return;
    }
    setSubscriptionOpen(true);
  };

  const openNutritionEnroll = () => {
    if (hasActiveNutrition) {
      toast.error('Υπάρχει ήδη ενεργό πακέτο διατροφής');
      return;
    }
    setNutritionEnrollOpen(true);
  };

  const openActivateTrial = (membership) => {
    setActivateTrialMembership(membership);
    setSubscriptionOpen(true);
  };

  const openRecordPayment = (membershipId) => {
    const pending = pendingPaymentForMembership(payments, membershipId);
    if (!pending) {
      toast.error('Δεν υπάρχει εκκρεμής χρέωση για αυτό το πακέτο');
      return;
    }
    setRecordingPayment(pending);
  };

  const openAddPayment = (credit) => {
    // Derive default amount: plan price → most recent linked payment → empty
    const linked = linkedPayments(credit.id);
    const defaultCents = credit.plan_price_cents
      || (linked.length ? linked[0].amount_cents : null);
    setAddPaymentForm({
      amount: defaultCents ? (defaultCents / 100).toFixed(2) : '',
      date: new Date().toISOString().slice(0, 10),
      method: 'cash',
      status: 'paid',
      period_start: credit.valid_from?.slice(0, 10) || '',
      period_end: credit.valid_until?.slice(0, 10) || '',
      period_month: credit.valid_from?.slice(0, 7) || '',
      period_day: credit.valid_from ? String(parseInt(credit.valid_from.slice(8, 10), 10)) : '1',
    });
    setAddPaymentFor(credit);
  };

  const submitAddPayment = async (e) => {
    e.preventDefault();
    if (!addPaymentFor) return;
    const amountCents = Math.round(Number((addPaymentForm.amount || '0').replace(',', '.')) * 100);
    if (!amountCents || amountCents <= 0) { toast.error('Δώσε έγκυρο ποσό'); return; }
    try {
      await api.post(`/client-admin/clients/${id}/payments`, {
        membership_id: addPaymentFor.id,
        description: (() => {
          const svc = addPaymentFor.service_name || addPaymentFor.plan_name || 'Πακέτο';
          if (addPaymentForm.period_start) {
            const [y, m] = addPaymentForm.period_start.split('-').map(Number);
            const monthYear = new Date(y, m - 1, 1).toLocaleDateString('el-GR', { month: 'long', year: 'numeric' });
            return `${svc} — Μήνας ${monthYear}`;
          }
          return `${svc} — Πληρωμή`;
        })(),
        amount_cents: amountCents,
        paid_amount_cents: addPaymentForm.status === 'paid' ? amountCents : 0,
        payment_date: addPaymentForm.status === 'paid' ? (addPaymentForm.date || null) : null,
        method: addPaymentForm.method,
        payment_type: 'subscription',
        period_start: addPaymentForm.period_start || null,
        period_end: addPaymentForm.period_end || null,
      });
      toast.success(addPaymentForm.status === 'paid' ? 'Η πληρωμή καταχωρήθηκε' : 'Η χρέωση καταχωρήθηκε — εκκρεμεί πληρωμή');
      setAddPaymentFor(null);
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const load = async () => {
    const [clientRes, clientsRes, creditsRes, optionsRes, paymentsRes, locRes, progRes, allProgRes] = await Promise.all([
      api.get(`/client-admin/clients/${id}`),
      api.get('/client-admin/clients'),
      api.get(`/client-admin/clients/${id}/credits`),
      api.get('/client-admin/package-options'),
      api.get(`/client-admin/clients/${id}/payments`),
      api.get(`/client-admin/clients/${id}/locations`).catch(() => ({ data: [] })),
      api.get(`/client-admin/clients/${id}/programs`).catch(() => ({ data: [] })),
      api.get('/client-admin/programs').catch(() => ({ data: [] })),
    ]);
    setClient(clientRes.data);
    setAllClients(clientsRes.data.filter(c => c.id !== id));
    setProfileForm(profileFromClient(clientRes.data));
    setCredits(creditsRes.data);
    setPackageOptions(optionsRes.data);
    setPayments(paymentsRes.data);
    setLocationIds(locRes.data || []);
    setClientPrograms(progRes.data || []);
    setAllPrograms(allProgRes.data || []);
  };

  useEffect(() => { load().catch(() => navigate('/clients')); }, [id]);

  const updateClientStatus = async (status) => {
    const labels = { active: 'εγκρίθηκε', suspended: 'απενεργοποιήθηκε' };
    try {
      await api.patch(`/client-admin/clients/${id}/status`, { status });
      toast.success(`Ο πελάτης ${labels[status] || 'ενημερώθηκε'}`);
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const moveToTrash = async () => {
    if (!client) return;
    if (!window.confirm(`Μεταφορά του ${client.full_name} στον κάδο;\n\nΤα ιστορικά διατηρούνται — μπορείς να τον επαναφέρεις αργότερα.`)) return;
    try {
      await api.delete(`/client-admin/clients/${id}`);
      toast.success('Ο πελάτης μεταφέρθηκε στον κάδο');
      navigate('/clients?status=trash');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const restoreClient = async () => {
    try {
      await api.post(`/client-admin/clients/${id}/restore`);
      toast.success('Ο πελάτης επανήλθε');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const permanentDelete = async () => {
    if (!client) return;
    if (!window.confirm(`ΟΡΙΣΤΙΚΗ διαγραφή του ${client.full_name};\n\nΘα διαγραφούν όλα τα δεδομένα. Δεν αναιρείται.`)) return;
    try {
      await api.delete(`/client-admin/clients/${id}/permanent`);
      toast.success('Ο πελάτης διαγράφηκε οριστικά');
      navigate('/clients');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const saveProfile = async () => {
    setSavingProfile(true);
    try {
      await api.patch(`/client-admin/clients/${id}`, {
        full_name: profileForm.full_name,
        phone: profileForm.phone || null,
        date_of_birth: profileForm.date_of_birth || null,
        weight_kg: profileForm.weight_kg !== '' ? Number(profileForm.weight_kg) : null,
        fitness_goal: profileForm.fitness_goal || null,
        trainer_notes: profileForm.trainer_notes || null,
        notes: profileForm.notes || null,
        referred_by_user_id: profileForm.referred_by_user_id || null,
      });
      await api.put(`/client-admin/clients/${id}/locations`, { location_ids: locationIds });
      toast.success('Το προφίλ αποθηκεύτηκε');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSavingProfile(false);
    }
  };

  const openEdit = (credit) => {
    const unlimited = credit.total_sessions >= 9999;
    setEditingCredit(credit);
    setEditForm({
      total_sessions: unlimited ? 10 : credit.total_sessions,
      used_sessions: credit.used_sessions ?? 0,
      valid_from: credit.valid_from?.slice(0, 10) || '',
      valid_until: credit.valid_until?.slice(0, 10) || '',
      notes: credit.notes || '',
      is_unlimited: unlimited,
    });
  };

  const saveEdit = async (e) => {
    e.preventDefault();
    if (!editingCredit) return;
    try {
      await api.patch(`/client-admin/clients/${id}/credits/${editingCredit.id}`, {
        total_sessions: editForm.is_unlimited ? 9999 : Number(editForm.total_sessions),
        used_sessions: Number(editForm.used_sessions),
        valid_from: editForm.valid_from,
        valid_until: editForm.valid_until,
        notes: editForm.notes || null,
      });
      toast.success('Το πακέτο ενημερώθηκε');
      setEditingCredit(null);
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const removePayment = async (payment) => {
    const pid = typeof payment === 'string' ? payment : payment.id;
    const label = typeof payment === 'object' ? (payment.description || payment.service_name || '') : '';
    if (!window.confirm(`Διαγραφή πληρωμής${label ? ` «${label}»` : ''};`)) return;
    try {
      await api.delete(`/client-admin/payments/${pid}`);
      toast.success('Η πληρωμή διαγράφηκε');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const removeCredit = async (mid) => {
    if (!window.confirm('Διαγραφή πακέτου;')) return;
    await api.delete(`/client-admin/clients/${id}/credits/${mid}`);
    toast.success('Διαγράφηκε');
    load();
  };

  const reactivateMembership = async (membership) => {
    if (!window.confirm(`Επανενεργοποίηση «${membership.service_name || membership.plan_name}»;`)) return;
    try {
      await api.patch(`/client-admin/clients/${id}/credits/${membership.id}/reactivate`, {});
      toast.success('Η συνδρομή επανενεργοποιήθηκε');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const sendPaymentReminder = async (paymentId) => {
    try {
      await api.post(`/client-admin/payments/${paymentId}/remind`);
      toast.success('Η υπενθύμιση στάλθηκε στον πελάτη');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const linkedPayments = (membershipId) => paymentsByMembership.get(membershipId) || [];

  const statusBadge = (status) => {
    const cls = {
      paid: 'badge-green',
      partial: 'badge-yellow',
      pending: 'badge-gray',
      overdue: 'badge-red',
    }[status] || 'badge-gray';
    return <span className={`badge ${cls}`}>{paymentStatusLabel(status)}</span>;
  };

  if (!client) return <Layout title="..."><div className="loading">Φόρτωση...</div></Layout>;

  const isDeleted = client.is_deleted;

  return (
    <Layout title={client.full_name}>
      <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
        <button className="btn btn-secondary btn-sm" onClick={() => navigate(isDeleted ? '/clients?status=trash' : '/clients')}>
          <ArrowLeft size={14} /> Πίσω
        </button>
        {!isDeleted && (client.account_status || 'active') === 'active' && (
          <>
            <button className="btn btn-primary btn-sm" onClick={() => navigate(`/bookings?for=${client.id}`)}>
              <CalendarPlus size={14} /> Νέα κράτηση
            </button>
            <button
              className="btn btn-secondary btn-sm"
              onClick={() => navigate(`/messages?client=${client.id}`)}
            >
              <MessageSquare size={14} /> Μήνυμα
            </button>
            <button
              className="btn btn-secondary btn-sm"
              onClick={() => navigate(`/bookings?for=${client.id}&trial=1`)}
            >
              <FlaskConical size={14} /> Δοκιμαστικό μάθημα
            </button>
          </>
        )}
        {!isDeleted && (
          <button className="btn btn-danger btn-sm" onClick={moveToTrash}>
            <Trash2 size={14} /> Στον κάδο
          </button>
        )}
        {isDeleted && (
          <>
            <button className="btn btn-primary btn-sm" onClick={restoreClient}>
              <RotateCcw size={14} /> Επαναφορά
            </button>
            <button className="btn btn-danger btn-sm" onClick={permanentDelete}>
              <Trash2 size={14} /> Οριστική διαγραφή
            </button>
          </>
        )}
      </div>

      {isDeleted && (
        <div className="card" style={{ marginBottom: 16 }}>
          <strong>Στον κάδο</strong>
          <div className="text-muted" style={{ marginTop: 4 }}>
            Ο πελάτης δεν εμφανίζεται στη λίστα και δεν μπορεί να συνδεθεί στην εφαρμογή.
            {client.deleted_at && (
              <> Διαγράφηκε {new Date(client.deleted_at).toLocaleString('el-GR')}.</>
            )}
          </div>
        </div>
      )}

      {!isDeleted && (
      <div
        className="card"
        style={{
          marginBottom: 16,
          background: client.account_status === 'pending' ? 'var(--warning-dim)'
            : client.account_status === 'suspended' ? 'var(--danger-dim)' : 'var(--success-dim)',
          borderColor: client.account_status === 'pending' ? 'rgba(255,178,36,0.25)'
            : client.account_status === 'suspended' ? 'rgba(255,87,87,0.25)' : 'rgba(52,211,153,0.25)',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 12 }}>
          <div>
            <div style={{ fontWeight: 700 }}>Λογαριασμός εφαρμογής</div>
            <div className="text-muted" style={{ marginTop: 4 }}>
              {client.account_status === 'pending' && 'Περιμένει έγκριση — δεν μπορεί να συνδεθεί στην εφαρμογή.'}
              {client.account_status === 'active' && 'Ενεργός — μπορεί να κάνει login και κρατήσεις.'}
              {client.account_status === 'suspended' && 'Απενεργοποιημένος — δεν μπορεί να συνδεθεί.'}
              {!client.account_status && 'Ενεργός'}
            </div>
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            {client.account_status === 'pending' && (
              <>
                <button type="button" className="btn btn-primary btn-sm" onClick={() => updateClientStatus('active')}>
                  <Check size={14} /> Έγκριση
                </button>
                <button
                  type="button"
                  className="btn btn-danger btn-sm"
                  onClick={() => {
                    if (window.confirm('Απόρριψη εγγραφής;')) updateClientStatus('suspended');
                  }}
                >
                  <Ban size={14} /> Απόρριψη
                </button>
              </>
            )}
            {client.account_status === 'active' && (
              <button
                type="button"
                className="btn btn-danger btn-sm"
                onClick={() => {
                  if (window.confirm(`Απενεργοποίηση του ${client.full_name};`)) updateClientStatus('suspended');
                }}
              >
                <Ban size={14} /> Απενεργοποίηση
              </button>
            )}
            {client.account_status === 'suspended' && (
              <button type="button" className="btn btn-secondary btn-sm" onClick={() => updateClientStatus('active')}>
                <RotateCcw size={14} /> Επανενεργοποίηση
              </button>
            )}
          </div>
        </div>
      </div>
      )}

      <div className="card" style={{ marginBottom: 16 }}>
        <h3 style={{ marginTop: 0, marginBottom: 16 }}>Στοιχεία πελάτη</h3>

        {client.birthday_today && (
          <div
            style={{
              marginBottom: 16,
              padding: '12px 14px',
              borderRadius: 10,
              background: 'rgba(34, 197, 94, 0.12)',
              border: '1px solid rgba(34, 197, 94, 0.35)',
              fontWeight: 600,
            }}
          >
            Σήμερα έχει γενέθλια — στείλε χρόνια πολλά!
          </div>
        )}
        {!client.birthday_today && client.days_until_birthday != null && client.days_until_birthday <= 7 && client.date_of_birth && (
          <div className="text-muted" style={{ marginBottom: 12, fontSize: '0.9rem' }}>
            Γενέθλια σε {client.days_until_birthday} ημέρ{client.days_until_birthday === 1 ? 'α' : 'ες'}
          </div>
        )}

        <div className="form-grid-2">
          <div className="form-group">
            <label className="form-label">Ονοματεπώνυμο *</label>
            <input
              className="form-input"
              value={profileForm.full_name}
              onChange={e => setProfileForm({ ...profileForm, full_name: e.target.value })}
              required
            />
          </div>
          <div className="form-group">
            <label className="form-label">Email</label>
            <input className="form-input" value={client.email} disabled />
          </div>
        </div>

        <div className="form-grid-2">
          <div className="form-group">
            <label className="form-label">Τηλέφωνο</label>
            <input
              className="form-input"
              value={profileForm.phone}
              onChange={e => setProfileForm({ ...profileForm, phone: e.target.value })}
            />
          </div>
          <div className="form-group">
            <label className="form-label">Ημερομηνία γέννησης</label>
            <input
              className="form-input"
              type="date"
              value={profileForm.date_of_birth}
              onChange={e => setProfileForm({ ...profileForm, date_of_birth: e.target.value })}
            />
            {client.age != null && (
              <div className="text-muted" style={{ fontSize: '0.8rem', marginTop: 4 }}>
                Ηλικία: {client.age} ετών
              </div>
            )}
          </div>
        </div>

        <div className="form-grid-2">
          <div className="form-group">
            <label className="form-label">Βάρος (kg)</label>
            <input
              className="form-input"
              type="number"
              step="0.1"
              min="0"
              placeholder="Προαιρετικό"
              value={profileForm.weight_kg}
              onChange={e => setProfileForm({ ...profileForm, weight_kg: e.target.value })}
            />
          </div>
          <div className="form-group">
            <label className="form-label">Στόχος πελάτη</label>
            <select
              className="form-select"
              value={profileForm.fitness_goal}
              onChange={e => setProfileForm({ ...profileForm, fitness_goal: e.target.value })}
            >
              {FITNESS_GOALS.map(g => (
                <option key={g.id || 'none'} value={g.id}>{g.label}</option>
              ))}
            </select>
          </div>
        </div>

        <div className="form-group">
          <label className="form-label">Σημειώσεις για γυμναστή</label>
          <textarea
            className="form-input"
            rows={3}
            placeholder="π.χ. πρόσφατο χειρουργείο γόνατος, περιορισμοί ώμου, τραυματισμός..."
            value={profileForm.trainer_notes}
            onChange={e => setProfileForm({ ...profileForm, trainer_notes: e.target.value })}
          />
        </div>

        <div className="form-group">
          <label className="form-label">Γενικά σχόλια (διαχείριση)</label>
          <textarea
            className="form-input"
            rows={2}
            placeholder="π.χ. Φίλος του Γιώργου, προτίμηση πρωινών ωρών..."
            value={profileForm.notes}
            onChange={e => setProfileForm({ ...profileForm, notes: e.target.value })}
          />
        </div>

        <div className="form-group">
          <label className="form-label">Προτάθηκε από πελάτη</label>
          <select
            className="form-select"
            value={profileForm.referred_by_user_id}
            onChange={e => setProfileForm({ ...profileForm, referred_by_user_id: e.target.value })}
          >
            <option value="">— Κανένας —</option>
            {allClients.map(c => (
              <option key={c.id} value={c.id}>{c.full_name}</option>
            ))}
          </select>
        </div>

        <LocationCheckboxes
          value={locationIds}
          onChange={setLocationIds}
          label="Γυμναστήρια πρόσβασης"
        />

        <button
          className="btn btn-primary btn-sm"
          onClick={saveProfile}
          disabled={savingProfile || !profileForm.full_name.trim() || isDeleted}
        >
          <Save size={14} /> {savingProfile ? 'Αποθήκευση...' : 'Αποθήκευση προφίλ'}
        </button>
      </div>

      <div className="page-header">
        <div>
          <h2 className="page-title" style={{ margin: 0 }}>Πακέτα</h2>
          <p className="text-muted" style={{ marginTop: 4, fontSize: '0.85rem' }}>
            Πακέτα γυμναστηρίου και διατροφής ξεχωριστά — μπορείς να έχεις και τα δύο.
            {allGymPackagesActive && !hasActiveNutrition && (
              <> Για αυτόν τον πελάτη, πρόσθεσε <strong>πακέτο διατροφής</strong>.</>
            )}
          </p>
        </div>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <button
            className="btn btn-primary btn-sm"
            onClick={openSubscription}
            disabled={allGymPackagesActive || isDeleted}
            title={isDeleted ? 'Ο πελάτης είναι στον κάδο' : (allGymPackagesActive ? 'Όλες οι υπηρεσίες γυμναστηρίου έχουν ενεργό πακέτο' : undefined)}
          >
            <Plus size={14} /> Πακέτο γυμναστηρίου
          </button>
          <button
            className={`btn btn-sm ${allGymPackagesActive && !hasActiveNutrition ? 'btn-primary' : 'btn-secondary'}`}
            onClick={openNutritionEnroll}
            disabled={hasActiveNutrition || isDeleted}
            title={isDeleted ? 'Ο πελάτης είναι στον κάδο' : (hasActiveNutrition ? 'Υπάρχει ήδη ενεργό πακέτο διατροφής' : undefined)}
          >
            <Plus size={14} /> Πακέτο διατροφής
          </button>
        </div>
      </div>

      <div className="card" style={{ marginBottom: 16 }}>
        {!visibleCredits.length ? (
          <div className="text-muted" style={{ padding: 32, textAlign: 'center' }}>
            Δεν υπάρχουν πακέτα — πρόσθεσε νέο πακέτο
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>
            {visibleCredits.map((c, ci) => {
              const linked = linkedPayments(c.id);
              const pending = pendingPaymentForMembership(payments, c.id);
              const trial = isTrialMembership(c);
              const accessState = c.access_state || (trial ? 'trial' : 'active');
              const img = mediaUrl(c.service_image_url);
              const inGrace = accessState === 'grace';
              const expired = accessState === 'expired';
              const cancelled = accessState === 'cancelled' || c.membership_status === 'cancelled';
              const isUnlimited = c.total_sessions >= 9999 || (c.total_sessions === 0 && c.membership_status === 'active');
              const sessionsUsed = isUnlimited ? null : c.used_sessions;
              const sessionsTotal = isUnlimited ? null : c.total_sessions;
              const sessionsPct = (sessionsTotal && sessionsTotal > 0) ? Math.min(100, Math.round((sessionsUsed / sessionsTotal) * 100)) : null;
              const daysLeft = c.days_until_expiry;
              const memBalance = membershipBalance(pending, c.id);
              const isPrepay = accessState === 'active' && daysLeft != null && daysLeft > 7 && !pending;
              const isDueRenewal = canRenewMembership(c) && !trial && !cancelled;
              return (
                <div key={c.id} style={{
                  borderTop: ci > 0 ? '1px solid var(--border)' : 'none',
                  padding: '18px 0',
                }}>
                  {/* Top row: service name + badges + action buttons */}
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: 10 }}>
                    <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12, flex: 1, minWidth: 0 }}>
                      {/* Color accent strip + icon */}
                      <div style={{
                        width: 44, height: 44, borderRadius: 12, flexShrink: 0,
                        background: trial ? 'var(--warning-dim)' : inGrace ? 'rgba(255,130,0,0.12)' : expired ? 'var(--danger-dim)' : cancelled ? 'var(--surface-3)' : 'var(--info-dim)',
                        display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden',
                      }}>
                        {img ? <img src={img} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : <ServiceIcon service={c} size={20} />}
                      </div>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ fontWeight: 700, fontSize: '0.97rem', display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
                          {c.plan_name || c.service_name || (c.service_category === 'nutrition' ? 'Διατροφή' : c.service_category) || 'Γενικό'}
                          {trial && <span className="badge badge-yellow">Δοκιμαστικό</span>}
                          {!trial && <span className={`badge ${ACCESS_STATE_BADGE[accessState] || 'badge-gray'}`}>{ACCESS_STATE_LABELS[accessState] || accessState}</span>}
                          {pending && !trial && <span className="badge badge-yellow">Εκκρεμεί {eur(memBalance)}</span>}
                        </div>
                        {/* Period info */}
                        {!trial && c.valid_from && (
                          <div style={{ fontSize: '0.82rem', color: 'var(--text-2)', marginTop: 4 }}>
                            <span style={{ fontWeight: 600 }}>{fmtDate(c.valid_from)}</span>
                            <span style={{ margin: '0 4px', color: 'var(--text-3)' }}>→</span>
                            <span style={{ fontWeight: 600, color: inGrace || expired ? 'var(--danger)' : 'var(--text)' }}>{fmtDate(c.valid_until)}</span>
                            {inGrace && c.days_in_grace_left != null && (
                              <span style={{ marginLeft: 8, color: 'var(--warning)', fontWeight: 600 }}>· Χάρις {c.days_in_grace_left} ημ.</span>
                            )}
                            {accessState === 'active' && daysLeft != null && daysLeft <= 7 && daysLeft > 0 && (
                              <span style={{ marginLeft: 8, color: 'var(--warning)', fontWeight: 600 }}>· Λήγει σε {daysLeft} ημ.</span>
                            )}
                          </div>
                        )}
                        {trial && c.trial_starts_at && (
                          <div style={{ fontSize: '0.82rem', color: 'var(--text-2)', marginTop: 4 }}>
                            Προγραμματισμένο: {fmtDateTime(c.trial_starts_at)}
                          </div>
                        )}
                        {c.cancellation_reason && (
                          <div style={{ fontSize: '0.78rem', color: 'var(--text-2)', marginTop: 3 }}>Λόγος: {c.cancellation_reason}</div>
                        )}
                        {c.notes && <div style={{ fontSize: '0.78rem', color: 'var(--text-2)', marginTop: 3 }}>{c.notes}</div>}
                      </div>
                    </div>

                    {/* Action buttons */}
                    <div style={{ display: 'flex', gap: 6, flexShrink: 0, alignItems: 'center' }}>
                      {trial && (
                        <button className="btn btn-primary btn-sm" onClick={() => openActivateTrial(c)}>
                          <Sparkles size={13} /> Ενεργοποίηση
                        </button>
                      )}
                      {canReactivateMembership(c) && (
                        <button className="btn btn-primary btn-sm" onClick={() => reactivateMembership(c)}>
                          <RotateCcw size={13} /> Επανενεργοποίηση
                        </button>
                      )}
                      {!trial && canCancelMembership(c) && (
                        <button className="btn btn-secondary btn-sm" onClick={() => setCancelMembership(c)} title="Διακοπή">
                          <Ban size={13} />
                        </button>
                      )}
                      <button className="btn btn-secondary btn-sm" onClick={() => openEdit(c)} title="Επεξεργασία">
                        <Pencil size={13} />
                      </button>
                      <button className="btn btn-danger btn-sm" onClick={() => removeCredit(c.id)} title="Διαγραφή">
                        <Trash2 size={13} />
                      </button>
                    </div>
                  </div>

                  {/* Sessions progress bar */}
                  {!trial && !cancelled && sessionsPct !== null && (
                    <div style={{ marginTop: 10, paddingLeft: 56 }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.75rem', color: 'var(--text-2)', marginBottom: 4 }}>
                        <span>Συνεδρίες</span>
                        <span style={{ fontWeight: 700 }}>{sessionsUsed}/{sessionsTotal}</span>
                      </div>
                      <div style={{ height: 6, borderRadius: 99, background: 'var(--surface-3)', overflow: 'hidden' }}>
                        <div style={{
                          height: '100%', borderRadius: 99,
                          width: `${sessionsPct}%`,
                          background: sessionsPct >= 90 ? 'var(--danger)' : sessionsPct >= 70 ? 'var(--warning)' : 'var(--success)',
                          transition: 'width 0.4s',
                        }} />
                      </div>
                    </div>
                  )}
                  {!trial && !cancelled && isUnlimited && (
                    <div style={{ marginTop: 6, paddingLeft: 56, fontSize: '0.75rem', color: 'var(--text-2)' }}>
                      ∞ απεριόριστες συνεδρίες
                    </div>
                  )}

                  {/* Renewal action area */}
                  {!cancelled && (
                    <div style={{
                      marginTop: 12, paddingLeft: 56,
                      display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap',
                    }}>
                      {/* Settle pending payment for this membership */}
                      {pending && (
                        <>
                          <button className="btn btn-primary btn-sm" onClick={() => openRecordPayment(c.id)}
                            style={{ background: '#ea580c', borderColor: '#ea580c' }}>
                            <CreditCard size={13} /> Εξόφληση {eur(memBalance)}
                          </button>
                          <button type="button" className="btn btn-secondary btn-sm"
                            onClick={() => sendPaymentReminder(pending.id)} title="Υπενθύμιση πληρωμής">
                            Υπενθύμιση
                          </button>
                        </>
                      )}
                      {/* Renewal — only show when current period is paid (no pending) */}
                      {isDueRenewal && !trial && !pending && (
                        <>
                          <button
                            className="btn btn-sm btn-secondary"
                            onClick={() => setRenewalMembership(c)}
                            title="Ανανέωση συνδρομής"
                          >
                            <RefreshCw size={13} /> Ανανέωση
                          </button>
                          {c.next_renewal && (
                            <span style={{ fontSize: '0.78rem', color: 'var(--text-2)' }}>
                              → {fmtDate(c.next_renewal.period_start)} – {fmtDate(c.next_renewal.period_end)}
                            </span>
                          )}
                        </>
                      )}
                    </div>
                  )}

                  {/* Payment history */}
                  {(linked.length > 0 || (!trial && !cancelled)) && (
                    <div style={{ marginTop: 12, paddingLeft: 56 }}>
                      <div style={{ fontSize: '0.72rem', fontWeight: 700, textTransform: 'uppercase', color: 'var(--text-2)', marginBottom: 6, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <span>Ιστορικό πληρωμών</span>
                        {!trial && !cancelled && linked.length === 0 && (
                          <button className="btn btn-secondary btn-sm" style={{ fontSize: '0.72rem', padding: '2px 8px' }} onClick={() => openAddPayment(c)} title="Καταχώρηση νέας πληρωμής">
                            <Plus size={11} /> Νέα χρέωση
                          </button>
                        )}
                      </div>
                      {linked.map(p => (
                        <div key={p.id} style={{
                          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                          flexWrap: 'wrap', gap: 6, padding: '6px 0', borderBottom: '1px solid #f8fafc',
                        }}>
                          <div>
                            <div style={{ fontWeight: 600, fontSize: '0.85rem' }}>{(p.description || '').replace(/\s*\(.*?\)\s*$/, '')}</div>
                            {(p.period_start || p.period_end) && (
                              <div style={{ fontSize: '0.75rem', color: 'var(--text-2)' }}>
                                Περίοδος: {p.period_start ? fmtDate(p.period_start) : '—'} → {p.period_end ? fmtDate(p.period_end) : '—'}
                              </div>
                            )}
                            {p.payment_date && (
                              <div style={{ fontSize: '0.75rem', color: 'var(--text-2)' }}>
                                Πληρωμή: {fmtDate(p.payment_date)}
                              </div>
                            )}
                            {!p.payment_date && p.created_at && (
                              <div style={{ fontSize: '0.75rem', color: 'var(--text-2)' }}>
                                Καταχώρηση: {fmtDate(p.created_at.slice(0, 10))}
                              </div>
                            )}
                          </div>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                            <span style={{ fontWeight: 600 }}>{eur(p.amount_cents)}</span>
                            {p.balance_cents > 0 && <span style={{ color: '#ea580c', fontSize: '0.82rem' }}>υπόλ. {eur(p.balance_cents)}</span>}
                            {statusBadge(p.status)}
                            {p.balance_cents > 0 && (
                              <button className="btn btn-primary btn-sm" onClick={() => setRecordingPayment(p)} title="Πληρωμή">
                                <CreditCard size={13} />
                              </button>
                            )}
                            <button className="btn btn-secondary btn-sm" onClick={() => setEditingPayment(p)} title="Επεξεργασία">
                              <Pencil size={13} />
                            </button>
                            <button className="btn btn-danger btn-sm" onClick={() => removePayment(p)} title="Διαγραφή">
                              <Trash2 size={13} />
                            </button>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>

      {client && (
        <ClientBookingsSection
          userId={id}
          clientName={client.full_name}
          memberships={visibleCredits}
          showCharts
          onReload={load}
        />
      )}

      {/* Programs section */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
          <div style={{ fontWeight: 700, fontSize: '0.9rem', display: 'flex', alignItems: 'center', gap: 8 }}>
            <Dumbbell size={16} color="#6366f1" /> Προγράμματα Άσκησης
          </div>
          <button className="btn btn-secondary btn-sm" onClick={() => setProgramAssignOpen(true)} disabled={isDeleted || allPrograms.length === 0}>
            <Plus size={13} /> Ανάθεση
          </button>
        </div>
        {clientPrograms.length === 0 ? (
          <div style={{ color: 'var(--text-2)', fontSize: '0.85rem', padding: '8px 0' }}>
            {allPrograms.length === 0 ? 'Δεν υπάρχουν προγράμματα — πήγαινε στα Προγράμματα για να φτιάξεις.' : 'Κανένα πρόγραμμα δεν έχει ανατεθεί.'}
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {clientPrograms.map(cp => (
              <div key={cp.id} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '6px 0', borderBottom: '1px solid #f1f5f9' }}>
                <Dumbbell size={14} color="#6366f1" />
                <div style={{ flex: 1 }}>
                  <span style={{ fontWeight: 600, fontSize: '0.88rem' }}>{cp.program_name}</span>
                  <span style={{ fontSize: '0.75rem', color: 'var(--text-2)', marginLeft: 8 }}>από {fmtDate(cp.assigned_at)}</span>
                  {cp.notes && <div style={{ fontSize: '0.75rem', color: 'var(--text-2)' }}>{cp.notes}</div>}
                </div>
                <button className="btn btn-danger btn-sm" onClick={async () => {
                  if (!confirm('Αφαίρεση προγράμματος;')) return;
                  await api.delete(`/client-admin/clients/${id}/programs/${cp.id}`);
                  load();
                }}>
                  <Trash2 size={12} />
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Program assign modal */}
      {programAssignOpen && (
        <div className="modal-overlay" onClick={() => setProgramAssignOpen(false)}>
          <div className="modal" style={{ maxWidth: 400 }} onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h2>Ανάθεση Προγράμματος</h2>
              <button className="modal-close" onClick={() => setProgramAssignOpen(false)}><X size={18} /></button>
            </div>
            <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              <div className="form-group" style={{ marginBottom: 0 }}>
                <label className="form-label">Πρόγραμμα</label>
                <select className="form-input" value={assigningProgram} onChange={e => setAssigningProgram(e.target.value)}>
                  <option value="">— Επίλεξε πρόγραμμα —</option>
                  {allPrograms.filter(p => p.is_active).map(p => <option key={p.id} value={p.id}>{p.name}</option>)}
                </select>
              </div>
              <div style={{ display: 'flex', gap: 8 }}>
                <button className="btn btn-secondary" style={{ flex: 1 }} onClick={() => setProgramAssignOpen(false)}>Ακύρωση</button>
                <button className="btn btn-primary" style={{ flex: 2 }} disabled={!assigningProgram} onClick={async () => {
                  await api.post(`/client-admin/clients/${id}/programs`, { program_id: assigningProgram });
                  toast.success('Πρόγραμμα ανατέθηκε');
                  setProgramAssignOpen(false);
                  setAssigningProgram('');
                  load();
                }}>Ανάθεση</button>
              </div>
            </div>
          </div>
        </div>
      )}

      {recordingPayment && client && (
        <RecordPaymentModal
          open
          payment={recordingPayment}
          clientName={client.full_name}
          onClose={() => setRecordingPayment(null)}
          onSuccess={() => { setRecordingPayment(null); load(); }}
        />
      )}

      {renewalMembership && client && (
        <RenewalPaymentModal
          open
          clientId={id}
          clientName={client.full_name}
          membership={renewalMembership}
          onClose={() => setRenewalMembership(null)}
          onSuccess={load}
        />
      )}

      {cancelMembership && client && (
        <CancelSubscriptionModal
          open
          clientId={id}
          clientName={client.full_name}
          membership={cancelMembership}
          onClose={() => setCancelMembership(null)}
          onSuccess={load}
        />
      )}

      {addPaymentFor && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setAddPaymentFor(null)}>
          <div className="modal cb-modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 440 }}>
            <div className="cb-modal-header">
              <div>
                <div className="cb-modal-title">Νέα χρέωση / πληρωμή</div>
                <div className="cb-modal-sub">{client?.full_name} · {addPaymentFor.service_name || addPaymentFor.plan_name || 'Πακέτο'}</div>
              </div>
              <button type="button" className="cb-icon-btn" onClick={() => setAddPaymentFor(null)}><X size={18} /></button>
            </div>
            <form onSubmit={submitAddPayment} style={{ padding: '20px 24px 24px' }}>
              <div className="form-grid-2" style={{ marginBottom: 16 }}>
                <div className="form-group" style={{ marginBottom: 0 }}>
                  <label className="form-label">Μήνας</label>
                  <select className="form-input" value={addPaymentForm.period_month} onChange={e => {
                    const month = e.target.value;
                    const day = addPaymentForm.period_day || '1';
                    const d = String(day).padStart(2, '0');
                    const newStart = month ? `${month}-${d}` : '';
                    const end = month ? (() => {
                      const [y, m] = month.split('-').map(Number);
                      const nextMonth = m === 12 ? 1 : m + 1;
                      const nextYear = m === 12 ? y + 1 : y;
                      return `${nextYear}-${String(nextMonth).padStart(2, '0')}-${d}`;
                    })() : '';
                    setAddPaymentForm({ ...addPaymentForm, period_month: month, period_day: addPaymentForm.period_day || '1', period_start: newStart, period_end: end });
                  }}>
                    <option value="">— επιλογή —</option>
                    {Array.from({ length: 12 }, (_, i) => {
                      const now = new Date();
                      const d = new Date(now.getFullYear(), now.getMonth() - 3 + i, 1);
                      const val = d.toISOString().slice(0, 7);
                      const label = d.toLocaleDateString('el-GR', { month: 'long', year: 'numeric' });
                      return <option key={val} value={val}>{label}</option>;
                    })}
                  </select>
                </div>
                <div className="form-group" style={{ marginBottom: 0 }}>
                  <label className="form-label">Ημέρα έναρξης</label>
                  <input className="form-input" type="number" min="1" max="31" placeholder="1"
                    value={addPaymentForm.period_day || ''}
                    onChange={e => {
                      const day = e.target.value;
                      const month = addPaymentForm.period_month;
                      if (!month || !day) {
                        setAddPaymentForm({ ...addPaymentForm, period_day: day, period_start: '', period_end: '' });
                        return;
                      }
                      const d = String(day).padStart(2, '0');
                      const [y, m] = month.split('-').map(Number);
                      const newStart = `${month}-${d}`;
                      const nextMonth = m === 12 ? 1 : m + 1;
                      const nextYear = m === 12 ? y + 1 : y;
                      const end = `${nextYear}-${String(nextMonth).padStart(2, '0')}-${d}`;
                      setAddPaymentForm({ ...addPaymentForm, period_day: day, period_start: newStart, period_end: end });
                    }} />
                </div>
              </div>
              {addPaymentForm.period_start && addPaymentForm.period_end && (
                <div style={{ fontSize: '0.78rem', color: 'var(--text-2)', marginBottom: 12, padding: '6px 10px', background: 'var(--surface-3)', borderRadius: 6 }}>
                  Περίοδος: {fmtDate(addPaymentForm.period_start)} → {fmtDate(addPaymentForm.period_end)}
                </div>
              )}
              <div className="form-group">
                <label className="form-label">Ποσό (€)</label>
                <input className="form-input" type="number" step="0.01" min="0.01" required
                  value={addPaymentForm.amount}
                  onChange={e => setAddPaymentForm({ ...addPaymentForm, amount: e.target.value })} />
              </div>
              <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
                <button type="button"
                  className={`btn btn-sm ${addPaymentForm.status === 'paid' ? 'btn-primary' : 'btn-secondary'}`}
                  style={addPaymentForm.status === 'paid' ? { flex: 1, background: '#10b981', borderColor: '#10b981' } : { flex: 1 }}
                  onClick={() => setAddPaymentForm({ ...addPaymentForm, status: 'paid' })}>
                  Εξοφλήθηκε
                </button>
                <button type="button"
                  className={`btn btn-sm ${addPaymentForm.status === 'pending' ? 'btn-primary' : 'btn-secondary'}`}
                  style={{ flex: 1 }}
                  onClick={() => setAddPaymentForm({ ...addPaymentForm, status: 'pending' })}>
                  Εκκρεμεί
                </button>
              </div>
              {addPaymentForm.status === 'paid' && (
                <div className="form-grid-2">
                  <div className="form-group">
                    <label className="form-label">Ημ/νία πληρωμής</label>
                    <input className="form-input" type="date" value={addPaymentForm.date}
                      onChange={e => setAddPaymentForm({ ...addPaymentForm, date: e.target.value })} />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Τρόπος</label>
                    <select className="form-input" value={addPaymentForm.method}
                      onChange={e => setAddPaymentForm({ ...addPaymentForm, method: e.target.value })}>
                      <option value="cash">Μετρητά</option>
                      <option value="card">Κάρτα</option>
                      <option value="bank_transfer">Τραπεζική μεταφορά</option>
                    </select>
                  </div>
                </div>
              )}
              <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end', marginTop: 8 }}>
                <button type="button" className="btn btn-secondary btn-sm" onClick={() => setAddPaymentFor(null)}>Άκυρο</button>
                <button type="submit" className="btn btn-primary btn-sm">Αποθήκευση</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {editingPayment && client && (
        <EditPaymentModal
          open
          payment={editingPayment}
          clientName={client.full_name}
          packageOptions={packageOptions}
          onClose={() => setEditingPayment(null)}
          onSuccess={() => { setEditingPayment(null); load(); }}
        />
      )}

      <SubscriptionModal
        open={subscriptionOpen}
        clientId={id}
        clientName={client.full_name}
        packageOptions={packageOptions}
        memberships={credits}
        activateTrialMembership={activateTrialMembership}
        onClose={() => { setSubscriptionOpen(false); setActivateTrialMembership(null); }}
        onSuccess={load}
        onOpenNutrition={() => {
          setSubscriptionOpen(false);
          setActivateTrialMembership(null);
          openNutritionEnroll();
        }}
        canAddNutrition={!hasActiveNutrition}
      />

      <NutritionEnrollModal
        open={nutritionEnrollOpen}
        clientId={id}
        clientName={client?.full_name}
        hasActiveNutrition={hasActiveNutrition}
        onClose={() => setNutritionEnrollOpen(false)}
        onSuccess={load}
      />

      {editingCredit && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setEditingCredit(null)}>
          <div className="modal">
            <div className="modal-title">Επεξεργασία πακέτου</div>
            <p className="text-muted" style={{ marginBottom: 16 }}>
              {editingCredit.service_name || editingCredit.service_category || editingCredit.notes || 'Πακέτο'}
            </p>
            <form onSubmit={saveEdit}>
              <div className="form-group">
                <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
                  <input
                    type="checkbox"
                    checked={editForm.is_unlimited}
                    onChange={e => setEditForm({ ...editForm, is_unlimited: e.target.checked })}
                  />
                  Απεριόριστες συνεδρίες
                </label>
              </div>
              {!editForm.is_unlimited && (
                <div className="form-grid-2">
                  <div className="form-group">
                    <label className="form-label">Σύνολο συνεδριών</label>
                    <input
                      className="form-input"
                      type="number"
                      min="1"
                      value={editForm.total_sessions}
                      onChange={e => setEditForm({ ...editForm, total_sessions: e.target.value })}
                      required
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Χρησιμοποιήθηκαν</label>
                    <input
                      className="form-input"
                      type="number"
                      min="0"
                      value={editForm.used_sessions}
                      onChange={e => setEditForm({ ...editForm, used_sessions: e.target.value })}
                      required
                    />
                  </div>
                </div>
              )}
              {editForm.is_unlimited && (
                <div className="form-group">
                  <label className="form-label">Χρησιμοποιήθηκαν (μόνο για στατιστικά)</label>
                  <input
                    className="form-input"
                    type="number"
                    min="0"
                    value={editForm.used_sessions}
                    onChange={e => setEditForm({ ...editForm, used_sessions: e.target.value })}
                  />
                </div>
              )}
              <div className="form-grid-2">
                <div className="form-group">
                  <label className="form-label">Από</label>
                  <input
                    className="form-input"
                    type="date"
                    value={editForm.valid_from}
                    onChange={e => setEditForm({ ...editForm, valid_from: e.target.value })}
                    required
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">Έως</label>
                  <input
                    className="form-input"
                    type="date"
                    value={editForm.valid_until}
                    onChange={e => setEditForm({ ...editForm, valid_until: e.target.value })}
                    required
                  />
                </div>
              </div>
              <div className="form-group">
                <label className="form-label">Σημειώσεις</label>
                <input
                  className="form-input"
                  value={editForm.notes}
                  onChange={e => setEditForm({ ...editForm, notes: e.target.value })}
                />
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setEditingCredit(null)}>Ακύρωση</button>
                <button type="submit" className="btn btn-primary">Αποθήκευση</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </Layout>
  );
}
