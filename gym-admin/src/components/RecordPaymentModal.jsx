import { useEffect, useState } from 'react';
import { CreditCard, X } from 'lucide-react';
import api from '../api/client';
import toast from 'react-hot-toast';
import { eur, parseEurInput } from '../utils/payments';

export default function RecordPaymentModal({
  open,
  onClose,
  onSuccess,
  payment,
  clientName = '',
}) {
  const [paidEur, setPaidEur] = useState('');
  const [paymentDate, setPaymentDate] = useState('');
  const [method, setMethod] = useState('cash');
  const [submitting, setSubmitting] = useState(false);

  const balanceCents = payment?.balance_cents ?? 0;
  const paidSoFar = payment?.paid_amount_cents ?? 0;
  const totalCents = payment?.amount_cents ?? 0;

  useEffect(() => {
    if (!open || !payment) return;
    setPaidEur((balanceCents / 100).toFixed(2));
    setPaymentDate(new Date().toISOString().slice(0, 10));
    setMethod(payment.method || 'cash');
  }, [open, payment, balanceCents]);

  const submit = async (e) => {
    e.preventDefault();
    if (!payment) return;

    const payNowEur = parseEurInput(paidEur);
    if (!Number.isFinite(payNowEur) || payNowEur <= 0) {
      toast.error('Δώσε έγκυρο ποσό πληρωμής');
      return;
    }
    const payNowCents = Math.round(payNowEur * 100);

    const newTotalPaid = paidSoFar + payNowCents;
    if (newTotalPaid > totalCents) {
      toast.error(`Το ποσό υπερβαίνει τη χρέωση (${eur(totalCents)})`);
      return;
    }

    setSubmitting(true);
    try {
      await api.patch(`/client-admin/payments/${payment.id}`, {
        paid_amount_cents: newTotalPaid,
        payment_date: paymentDate || null,
        method,
      });
      toast.success(newTotalPaid >= totalCents ? 'Η πληρωμή ολοκληρώθηκε' : 'Η μερική πληρωμή καταχωρήθηκε');
      onSuccess?.();
      onClose();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSubmitting(false);
    }
  };

  if (!open || !payment) return null;

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal cb-modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 480 }}>
        <div className="cb-modal-header">
          <div>
            <div className="cb-modal-title">Καταχώρηση πληρωμής</div>
            <div className="cb-modal-sub">
              {clientName ? `${clientName} · ` : ''}
              {payment.description || payment.service_name || 'Πακέτο'}
            </div>
          </div>
          <button type="button" className="cb-icon-btn" onClick={onClose} aria-label="Κλείσιμο">
            <X size={18} />
          </button>
        </div>

        <form onSubmit={submit} className="cb-form">
          <div className="sub-summary-card">
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
              <span className="text-muted">Χρέωση πακέτου</span>
              <span style={{ fontWeight: 700 }}>{eur(totalCents)}</span>
            </div>
            {paidSoFar > 0 && (
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
                <span className="text-muted">Ήδη πληρώθηκε</span>
                <span>{eur(paidSoFar)}</span>
              </div>
            )}
            <div style={{ display: 'flex', justifyContent: 'space-between', fontWeight: 700, color: '#ea580c' }}>
              <span>Υπόλοιπο</span>
              <span>{eur(balanceCents)}</span>
            </div>
          </div>

          <section className="cb-section">
            <div className="cb-section-label">
              <CreditCard size={16} /> Πληρωμή
            </div>
            <div className="form-grid-2">
              <div className="form-group">
                <label className="form-label">Ποσό πληρωμής (€)</label>
                <input
                  className="form-input"
                  type="text"
                  inputMode="decimal"
                  placeholder="0,00"
                  value={paidEur}
                  onChange={e => setPaidEur(e.target.value)}
                  required
                />
              </div>
              <div className="form-group">
                <label className="form-label">Ημ. πληρωμής</label>
                <input
                  className="form-input"
                  type="date"
                  value={paymentDate}
                  onChange={e => setPaymentDate(e.target.value)}
                  required
                />
              </div>
            </div>
            <div className="form-group">
              <label className="form-label">Τρόπος</label>
              <select className="form-select" value={method} onChange={e => setMethod(e.target.value)}>
                <option value="cash">Μετρητά</option>
                <option value="card">Κάρτα</option>
                <option value="transfer">Κατάθεση</option>
              </select>
            </div>
          </section>

          <div className="cb-footer">
            <button type="button" className="btn btn-secondary" onClick={onClose}>Ακύρωση</button>
            <button type="submit" className="btn btn-primary" disabled={submitting}>
              {submitting ? 'Αποθήκευση...' : 'Καταχώρηση πληρωμής'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
