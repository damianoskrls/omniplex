import { useState } from 'react';
import { Ban, X } from 'lucide-react';
import api from '../api/client';
import toast from 'react-hot-toast';

export default function CancelSubscriptionModal({
  open,
  onClose,
  onSuccess,
  clientId,
  clientName = '',
  membership,
}) {
  const [reason, setReason] = useState('');
  const [submitting, setSubmitting] = useState(false);

  if (!open || !membership) return null;

  const submit = async (e) => {
    e.preventDefault();
    if (!window.confirm('Επιβεβαίωση διακοπής συνδρομής; Ο πελάτης δεν θα μπορεί να κλείνει θέσεις.')) return;
    setSubmitting(true);
    try {
      await api.patch(
        `/client-admin/clients/${clientId}/credits/${membership.id}/cancel`,
        { reason: reason.trim() || null },
      );
      toast.success('Η συνδρομή διακόπηκε');
      onSuccess?.();
      onClose();
      setReason('');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="modal-overlay" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="modal cb-modal" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 480 }}>
        <div className="cb-modal-header">
          <div>
            <div className="cb-modal-title">Διακοπή συνδρομής</div>
            <div className="cb-modal-sub">
              {clientName ? `${clientName} · ` : ''}{membership.service_name || membership.plan_name}
            </div>
          </div>
          <button type="button" className="cb-icon-btn" onClick={onClose} aria-label="Κλείσιμο">
            <X size={18} />
          </button>
        </div>

        <form onSubmit={submit} className="cb-form">
          <p className="text-muted" style={{ fontSize: '0.9rem', lineHeight: 1.5 }}>
            Η συνδρομή θα σταματήσει. Ο πελάτης μπορεί να επανενεργοποιηθεί αργότερα από εσένα
            (π.χ. όταν επιστρέψει στο γυμναστήριο).
          </p>
          <div className="form-group">
            <label className="form-label">Λόγος διακοπής (προαιρετικό)</label>
            <textarea
              className="form-input"
              rows={3}
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder="π.χ. Μετακόμιση, οικονομικοί λόγοι..."
            />
          </div>
          <div className="cb-footer">
            <button type="button" className="btn btn-secondary" onClick={onClose}>Άκυρο</button>
            <button type="submit" className="btn btn-danger" disabled={submitting}>
              <Ban size={14} /> {submitting ? 'Αποθήκευση...' : 'Διακοπή συνδρομής'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
