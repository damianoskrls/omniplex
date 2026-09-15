import { useEffect, useState } from 'react';
import { RefreshCw, X, CheckCircle, Clock, Info } from 'lucide-react';
import api from '../api/client';
import toast from 'react-hot-toast';
import { fmtDate } from '../utils/dates';

const METHODS = [
  { value: 'cash', label: 'Μετρητά' },
  { value: 'card', label: 'Κάρτα' },
  { value: 'bank_transfer', label: 'Τραπεζική μεταφορά' },
];

export default function RenewalPaymentModal({ open, onClose, onSuccess, clientId, clientName = '', membership }) {
  const [paymentStatus, setPaymentStatus] = useState('paid');
  const [amount, setAmount] = useState('');
  const [paymentDate, setPaymentDate] = useState(new Date().toISOString().slice(0, 10));
  const [method, setMethod] = useState('cash');
  const [submitting, setSubmitting] = useState(false);

  const next = membership?.next_renewal;
  const daysLeft = membership?.days_until_expiry ?? null;
  const accessState = membership?.access_state;
  // Prepay = still well within active period; renewal = near/past expiry
  const isPrepay = accessState === 'active' && daysLeft != null && daysLeft > 7;

  useEffect(() => {
    if (!open) return;
    setPaymentStatus('paid');
    setAmount(membership?.plan_price_cents ? (membership.plan_price_cents / 100).toFixed(2) : '');
    setPaymentDate(new Date().toISOString().slice(0, 10));
    setMethod('cash');
  }, [open, membership?.id]);

  if (!open || !membership) return null;

  const serviceName = membership.service_name || membership.plan_name || 'Πακέτο';

  const submit = async (e) => {
    e.preventDefault();
    const amtCents = Math.round(Number((amount || '0').replace(',', '.')) * 100);
    if (amtCents <= 0) { toast.error('Δώσε έγκυρο ποσό'); return; }
    setSubmitting(true);
    try {
      const body = { months: 1 };
      if (!isPrepay && paymentStatus === 'pending') {
        body.paid_amount_cents = 0;
        body.due_date = next?.period_start || null;
      } else {
        body.paid_amount_cents = amtCents;
        body.payment_date = paymentDate || null;
        body.method = method;
      }
      await api.post(`/client-admin/clients/${clientId}/credits/${membership.id}/renewal-payment`, body);
      toast.success(
        (!isPrepay && paymentStatus === 'pending')
          ? 'Ανανέωση καταχωρήθηκε — εκκρεμεί πληρωμή'
          : 'Ανανέωση & πληρωμή καταχωρήθηκαν'
      );
      onSuccess?.();
      onClose();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="modal-overlay" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="modal cb-modal" style={{ maxWidth: 400 }} onClick={(e) => e.stopPropagation()}>
        <div className="cb-modal-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ width: 36, height: 36, borderRadius: 10, background: '#ecfdf5', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <RefreshCw size={18} color="#10b981" />
            </div>
            <div>
              <div className="cb-modal-title">Ανανέωση</div>
              <div className="cb-modal-sub">{serviceName}{clientName ? ` · ${clientName}` : ''}</div>
            </div>
          </div>
          <button type="button" className="cb-icon-btn" onClick={onClose}><X size={18} /></button>
        </div>

        <div style={{ padding: '0 24px 4px' }}>
          {/* Info banner when still active (prepay scenario) */}
          {isPrepay && (
            <div style={{
              display: 'flex', alignItems: 'flex-start', gap: 8,
              padding: '10px 12px', borderRadius: 8,
              background: '#eff6ff', border: '1px solid #bfdbfe',
              fontSize: '0.82rem', color: '#1e40af', marginBottom: 12,
            }}>
              <Info size={15} style={{ flexShrink: 0, marginTop: 1 }} />
              <span>
                Η συνδρομή δεν έχει λήξει ακόμα{daysLeft != null ? ` (${daysLeft} ημ. ακόμα)` : ''}.
                Μπορείς να προπληρώσεις τον επόμενο μήνα τώρα.
              </span>
            </div>
          )}

          {/* Next period info */}
          {next && (
            <div style={{ padding: '8px 12px', background: '#f8fafc', borderRadius: 8, border: '1px solid #e2e8f0', fontSize: '0.82rem', color: '#64748b', marginBottom: 12 }}>
              Νέα περίοδος: <strong style={{ color: '#1e293b' }}>{fmtDate(next.period_start)} → {fmtDate(next.period_end)}</strong>
            </div>
          )}
        </div>

        <form onSubmit={submit} style={{ padding: '0 24px 24px', display: 'flex', flexDirection: 'column', gap: 14 }}>
          {/* Paid / Pending toggle — only for non-prepay (expired/grace/near expiry) */}
          {!isPrepay && (
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
              <button type="button" onClick={() => setPaymentStatus('paid')} style={{
                padding: '12px', borderRadius: 10,
                border: `2px solid ${paymentStatus === 'paid' ? '#22c55e' : '#e2e8f0'}`,
                background: paymentStatus === 'paid' ? '#f0fdf4' : '#fafafa',
                cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 8,
              }}>
                <CheckCircle size={20} color={paymentStatus === 'paid' ? '#16a34a' : '#cbd5e1'} />
                <div style={{ textAlign: 'left' }}>
                  <div style={{ fontWeight: 700, fontSize: '0.85rem', color: paymentStatus === 'paid' ? '#15803d' : '#64748b' }}>Εξοφλήθηκε</div>
                  <div style={{ fontSize: '0.72rem', color: '#94a3b8' }}>Πλήρωσε τώρα</div>
                </div>
              </button>
              <button type="button" onClick={() => setPaymentStatus('pending')} style={{
                padding: '12px', borderRadius: 10,
                border: `2px solid ${paymentStatus === 'pending' ? '#f59e0b' : '#e2e8f0'}`,
                background: paymentStatus === 'pending' ? '#fffbeb' : '#fafafa',
                cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 8,
              }}>
                <Clock size={20} color={paymentStatus === 'pending' ? '#d97706' : '#cbd5e1'} />
                <div style={{ textAlign: 'left' }}>
                  <div style={{ fontWeight: 700, fontSize: '0.85rem', color: paymentStatus === 'pending' ? '#92400e' : '#64748b' }}>Εκκρεμεί</div>
                  <div style={{ fontSize: '0.72rem', color: '#94a3b8' }}>Θα πληρώσει αργότερα</div>
                </div>
              </button>
            </div>
          )}

          {/* Amount + date + method — always shown for prepay; shown when paid for regular renewal */}
          {(isPrepay || paymentStatus === 'paid') && (
            <>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
                <div className="form-group" style={{ marginBottom: 0 }}>
                  <label className="form-label">Ποσό (€)</label>
                  <input className="form-input" type="number" step="0.01" min="0.01" required
                    value={amount} onChange={(e) => setAmount(e.target.value)} placeholder="0.00" />
                </div>
                <div className="form-group" style={{ marginBottom: 0 }}>
                  <label className="form-label">Ημερομηνία</label>
                  <input className="form-input" type="date" value={paymentDate}
                    onChange={(e) => setPaymentDate(e.target.value)} />
                </div>
              </div>
              <div className="form-group" style={{ marginBottom: 0 }}>
                <label className="form-label">Τρόπος πληρωμής</label>
                <select className="form-input" value={method} onChange={(e) => setMethod(e.target.value)}>
                  {METHODS.map(m => <option key={m.value} value={m.value}>{m.label}</option>)}
                </select>
              </div>
            </>
          )}

          <div style={{ display: 'flex', gap: 8 }}>
            <button type="button" className="btn btn-secondary" onClick={onClose} style={{ flex: 1 }}>Ακύρωση</button>
            <button type="submit" className="btn btn-primary" disabled={submitting}
              style={{ flex: 2, background: '#10b981', borderColor: '#10b981' }}>
              <RefreshCw size={14} />
              {submitting ? 'Αποθήκευση...' : 'Ανανέωση'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
