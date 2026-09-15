import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Save, UserPlus, ChevronRight, Trash2 } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { monthOptions } from '../utils/payments';

function formatLocalDate(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function addMonths(iso, months) {
  const [y, m, d] = iso.split('-').map(Number);
  const dt = new Date(y, m - 1 + months, d);
  return formatLocalDate(dt);
}

const defaultEnrollForm = () => ({
  user_id: '',
  plan_id: '',
  valid_from: formatLocalDate(new Date()),
  valid_until: addMonths(formatLocalDate(new Date()), 1),
  payment_type: 'package',
  package_months: 1,
  billing_month: monthOptions()[0].value,
  price_eur: '',
  discount_eur: '0',
  due_date: '',
  notes: '',
});

export default function NutritionClients() {
  const navigate = useNavigate();
  const { isOwner } = useAuth();
  const [clients, setClients] = useState([]);
  const [loading, setLoading] = useState(true);
  const [enrollOpen, setEnrollOpen] = useState(false);
  const [enrollable, setEnrollable] = useState([]);
  const [nutritionPlans, setNutritionPlans] = useState([]);
  const [enrollForm, setEnrollForm] = useState(defaultEnrollForm());
  const [enrolling, setEnrolling] = useState(false);
  const months = useMemo(() => monthOptions(), []);

  const selectedPlan = nutritionPlans.find(p => p.id === enrollForm.plan_id);

  const totalEur = () => {
    const price = Number(enrollForm.price_eur) || 0;
    const disc = Number(enrollForm.discount_eur) || 0;
    return Math.max(0, price - disc);
  };

  const load = async () => {
    const res = await api.get('/client-admin/nutrition/clients');
    setClients(res.data);
  };

  useEffect(() => {
    setLoading(true);
    load().catch(() => toast.error('Σφάλμα φόρτωσης')).finally(() => setLoading(false));
  }, []);

  const applyPlanDefaults = (planId, plans = nutritionPlans) => {
    const plan = plans.find(p => p.id === planId);
    if (!plan) return;
    const from = enrollForm.valid_from || formatLocalDate(new Date());
    const months = plan.billing_period === 'monthly' ? 1 : 3;
    setEnrollForm(f => ({
      ...f,
      plan_id: planId,
      payment_type: plan.billing_period === 'monthly' ? 'monthly' : 'package',
      package_months: months,
      valid_until: addMonths(from, months),
      price_eur: ((plan.price_cents || 0) / 100).toFixed(2),
    }));
  };

  const openEnroll = async () => {
    try {
      const [clientsRes, plansRes] = await Promise.all([
        api.get('/client-admin/nutrition/enrollable-clients'),
        api.get('/client-admin/nutrition/plans'),
      ]);
      setEnrollable(clientsRes.data);
      setNutritionPlans(plansRes.data);
      if (!plansRes.data.length) {
        toast.error('Δημιούργησε πρώτα πακέτο διατροφής');
        return;
      }
      const initial = defaultEnrollForm();
      initial.user_id = clientsRes.data[0]?.id || '';
      initial.plan_id = plansRes.data[0]?.id || '';
      if (plansRes.data[0]) {
        initial.price_eur = ((plansRes.data[0].price_cents || 0) / 100).toFixed(2);
        initial.payment_type = plansRes.data[0].billing_period === 'monthly' ? 'monthly' : 'package';
        initial.package_months = plansRes.data[0].billing_period === 'monthly' ? 1 : 3;
        initial.valid_until = addMonths(initial.valid_from, initial.package_months);
      }
      setEnrollForm(initial);
      setEnrollOpen(true);
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const enroll = async (e) => {
    e.preventDefault();
    if (!enrollForm.user_id || !enrollForm.plan_id) return;
    setEnrolling(true);
    try {
      const subtotalCents = Math.round((Number(enrollForm.price_eur) || 0) * 100);
      const discountCents = Math.round((Number(enrollForm.discount_eur) || 0) * 100);
      await api.post(`/client-admin/nutrition/clients/${enrollForm.user_id}/enroll`, {
        plan_id: enrollForm.plan_id,
        valid_from: enrollForm.valid_from,
        valid_until: enrollForm.valid_until,
        payment_type: enrollForm.payment_type,
        package_months: enrollForm.payment_type === 'package' ? Number(enrollForm.package_months) : undefined,
        billing_month: enrollForm.payment_type === 'monthly' ? enrollForm.billing_month : undefined,
        subtotal_cents: subtotalCents,
        discount_cents: discountCents,
        due_date: enrollForm.due_date || null,
        notes: enrollForm.notes || null,
      });
      toast.success('Ο πελάτης εντάχθηκε — εμφανίζεται και στα πακέτα του');
      setEnrollOpen(false);
      await load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setEnrolling(false);
    }
  };

  const removeClient = async (client, e) => {
    e.stopPropagation();
    if (!window.confirm(`Αφαίρεση του ${client.full_name} από τη λίστα διατροφής;\n\nΤο πακέτο διατροφής και οι επισκέψεις διατροφολόγου θα ακυρωθούν.`)) {
      return;
    }
    try {
      await api.post(`/client-admin/nutrition/clients/${client.id}/unenroll`);
      toast.success('Ο πελάτης αφαιρέθηκε');
      await load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const activeCount = useMemo(() => clients.length, [clients]);

  if (loading) {
    return <Layout title="Πελάτες διατροφής" variant="nutrition"><div className="loading">Φόρτωση...</div></Layout>;
  }

  return (
    <Layout title="Πελάτες διατροφής" variant="nutrition">
      <div className="page-header">
        <div>
          <h1 className="page-title">Πελάτες διατροφής</h1>
          <p className="text-muted" style={{ margin: '6px 0 0' }}>
            {activeCount} ενεργοί πελάτες · η ανάθεση διατροφής γίνεται από εδώ
          </p>
        </div>
        {isOwner && (
          <button className="btn btn-primary" type="button" onClick={openEnroll}>
            <UserPlus size={16} /> Προσθήκη πελάτη
          </button>
        )}
      </div>

      <div className="card">
        <table>
          <thead>
            <tr>
              <th>Πελάτης</th>
              <th>Email</th>
              <th>Πακέτο</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {clients.map(client => (
              <tr
                key={client.id}
                style={{ cursor: 'pointer' }}
                onClick={() => navigate(`/nutrition/clients/${client.id}`)}
              >
                <td style={{ fontWeight: 600 }}>{client.full_name}</td>
                <td>{client.email}</td>
                <td>{client.plan_name || 'Διατροφή'}</td>
                <td style={{ textAlign: 'right' }}>
                  <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                    <button
                        type="button"
                        className="btn btn-danger btn-sm"
                        title="Αφαίρεση από διατροφή"
                        onClick={(e) => removeClient(client, e)}
                      >
                        <Trash2 size={14} />
                      </button>
                    <ChevronRight size={16} color="#94a3b8" />
                  </div>
                </td>
              </tr>
            ))}
            {!clients.length && (
              <tr>
                <td colSpan={4} className="loading">
                  Δεν υπάρχουν πελάτες με ενεργό πακέτο διατροφής.
                  {isOwner && ' Πάτησε «Προσθήκη πελάτη» για να εντάξεις κάποιον.'}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {enrollOpen && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setEnrollOpen(false)}>
          <div className="modal" style={{ maxWidth: 520 }}>
            <div className="modal-title">Πακέτο διατροφής σε πελάτη</div>
            {!enrollable.length ? (
              <p className="text-muted">Όλοι οι πελάτες έχουν ήδη ενεργό πακέτο διατροφής.</p>
            ) : (
              <form onSubmit={enroll}>
                <div className="form-group">
                  <label className="form-label">Πελάτης</label>
                  <select
                    className="form-input"
                    value={enrollForm.user_id}
                    onChange={e => setEnrollForm({ ...enrollForm, user_id: e.target.value })}
                    required
                  >
                    {enrollable.map(c => (
                      <option key={c.id} value={c.id}>{c.full_name} ({c.email})</option>
                    ))}
                  </select>
                </div>
                <div className="form-group">
                  <label className="form-label">Πακέτο διατροφής</label>
                  <select
                    className="form-input"
                    value={enrollForm.plan_id}
                    onChange={e => applyPlanDefaults(e.target.value)}
                    required
                  >
                    {nutritionPlans.map(p => (
                      <option key={p.id} value={p.id}>
                        {p.name} — €{(p.price_cents / 100).toFixed(2)}
                        {(p.includes_summary || []).length ? ` (${p.includes_summary.join(', ')})` : ''}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="form-grid-2">
                  <div className="form-group">
                    <label className="form-label">Έναρξη</label>
                    <input
                      type="date"
                      className="form-input"
                      value={enrollForm.valid_from}
                      onChange={e => setEnrollForm({ ...enrollForm, valid_from: e.target.value })}
                      required
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Λήξη</label>
                    <input
                      type="date"
                      className="form-input"
                      value={enrollForm.valid_until}
                      onChange={e => setEnrollForm({ ...enrollForm, valid_until: e.target.value })}
                      required
                    />
                  </div>
                </div>
                <div className="form-group">
                  <label className="form-label">Τύπος χρέωσης</label>
                  <select
                    className="form-input"
                    value={enrollForm.payment_type}
                    onChange={e => setEnrollForm({ ...enrollForm, payment_type: e.target.value })}
                  >
                    <option value="package">Πακέτο (μήνες)</option>
                    <option value="monthly">Μηνιαία</option>
                  </select>
                </div>
                {enrollForm.payment_type === 'package' ? (
                  <div className="form-group">
                    <label className="form-label">Διάρκεια (μήνες)</label>
                    <input
                      type="number"
                      min="1"
                      className="form-input"
                      value={enrollForm.package_months}
                      onChange={e => setEnrollForm({ ...enrollForm, package_months: e.target.value })}
                    />
                  </div>
                ) : (
                  <div className="form-group">
                    <label className="form-label">Μήνας χρέωσης</label>
                    <select
                      className="form-input"
                      value={enrollForm.billing_month}
                      onChange={e => setEnrollForm({ ...enrollForm, billing_month: e.target.value })}
                    >
                      {months.map(m => (
                        <option key={m.value} value={m.value}>{m.label}</option>
                      ))}
                    </select>
                  </div>
                )}
                <div className="form-grid-2">
                  <div className="form-group">
                    <label className="form-label">Κόστος (€)</label>
                    <input
                      type="number"
                      step="0.01"
                      min="0"
                      className="form-input"
                      value={enrollForm.price_eur}
                      onChange={e => setEnrollForm({ ...enrollForm, price_eur: e.target.value })}
                      required
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Έκπτωση (€)</label>
                    <input
                      type="number"
                      step="0.01"
                      min="0"
                      className="form-input"
                      value={enrollForm.discount_eur}
                      onChange={e => setEnrollForm({ ...enrollForm, discount_eur: e.target.value })}
                    />
                  </div>
                </div>
                <div className="form-group">
                  <label className="form-label">Προθεσμία πληρωμής (προαιρετικά)</label>
                  <input
                    type="date"
                    className="form-input"
                    value={enrollForm.due_date}
                    onChange={e => setEnrollForm({ ...enrollForm, due_date: e.target.value })}
                  />
                </div>
                <div
                  style={{
                    marginTop: 8,
                    padding: '12px 14px',
                    background: '#f0fdf4',
                    borderRadius: 10,
                    border: '1px solid #bbf7d0',
                  }}
                >
                  <div style={{ fontWeight: 700 }}>
                    Σύνολο χρέωσης: €{totalEur().toFixed(2)}
                  </div>
                  <div className="text-muted" style={{ fontSize: '0.82rem', marginTop: 4 }}>
                    {selectedPlan?.name || 'Πακέτο διατροφής'} — μία εκκρεμής πληρωμή · θα εμφανιστεί στα πακέτα του πελάτη
                  </div>
                </div>
                <p className="text-muted" style={{ fontSize: '0.8rem', marginTop: 10 }}>
                  Για υπηρεσίες γυμναστηρίου, χρησιμοποίησε «Νέο πακέτο» στη σελίδα πελάτη.
                </p>
                <div className="modal-footer">
                  <button type="button" className="btn btn-secondary" onClick={() => setEnrollOpen(false)}>Ακύρωση</button>
                  <button type="submit" className="btn btn-primary" disabled={enrolling}>
                    <Save size={14} /> {enrolling ? 'Αποθήκευση...' : 'Ένταξη & χρέωση'}
                  </button>
                </div>
              </form>
            )}
          </div>
        </div>
      )}
    </Layout>
  );
}
