import { useEffect, useState } from 'react';
import api from '../api/client';
import toast from 'react-hot-toast';
import { AlertTriangle, Trash2, UserCheck, X } from 'lucide-react';

function formatWhen(iso) {
  const d = new Date(iso);
  return `${d.toLocaleDateString('el-GR', { weekday: 'short', day: 'numeric', month: 'short' })} ${d.toLocaleTimeString('el-GR', { hour: '2-digit', minute: '2-digit' })}`;
}

export default function StaffDeleteModal({ staffId, staffName, open, onClose, onDeleted }) {
  const [preview, setPreview] = useState(null);
  const [transferTo, setTransferTo] = useState('');
  const [loading, setLoading] = useState(false);
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    if (open) setTransferTo('');
  }, [open, staffId]);

  useEffect(() => {
    if (!open || !staffId) return undefined;
    setLoading(true);
    const params = transferTo ? { transfer_to: transferTo } : {};
    api.get(`/client-admin/staff/${staffId}/deletion-preview`, { params })
      .then((r) => setPreview(r.data))
      .catch((err) => {
        toast.error(err.response?.data?.error || 'Σφάλμα φόρτωσης');
        onClose();
      })
      .finally(() => setLoading(false));
    return undefined;
  }, [open, staffId, transferTo, onClose]);

  const confirmDelete = async () => {
    if (!window.confirm(`Οριστική διαγραφή/αφαίρεση του ${staffName};`)) return;
    setDeleting(true);
    try {
      const r = await api.delete(`/client-admin/staff/${staffId}`, {
        data: { transfer_to_staff_id: transferTo || null },
      });
      const { transferred, pending, mode } = r.data;
      if (pending > 0) {
        toast.success(
          `Αφαιρέθηκε. ${transferred} μεταφέρθηκαν, ${pending} σε εκκρεμότητα (γενικό προσωπικό).`,
          { duration: 5000 },
        );
      } else if (transferred > 0) {
        toast.success(`Αφαιρέθηκε. ${transferred} κρατήσεις μεταφέρθηκαν.`);
      } else {
        toast.success(mode === 'deactivated' ? 'Ο γυμναστής απενεργοποιήθηκε' : 'Διαγράφηκε');
      }
      onDeleted?.();
      onClose();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα διαγραφής');
    } finally {
      setDeleting(false);
    }
  };

  if (!open) return null;

  return (
    <div className="modal-overlay" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="modal modal--wide">
        <div className="modal-title" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Trash2 size={18} color="#dc2626" />
          Διαγραφή προσωπικού — {staffName}
        </div>

        {loading ? (
          <div className="loading" style={{ padding: 24 }}>Φόρτωση...</div>
        ) : (
          <>
            <p className="text-muted" style={{ marginBottom: 16, fontSize: '0.9rem', lineHeight: 1.5 }}>
              {preview?.future_bookings_count > 0
                ? `Υπάρχουν ${preview.future_bookings_count} μελλοντικές κρατήσεις. Μπορείς να τις μεταφέρεις σε άλλον γυμναστή. Όσες δεν μπορούν να μεταφερθούν (λόγω διαθεσιμότητας) θα μπουν στο «${preview?.general_pool?.full_name || 'Γενικό προσωπικό'}» και θα ειδοποιηθείς.`
                : 'Δεν υπάρχουν μελλοντικές κρατήσεις. Ο γυμναστής θα αφαιρεθεί από το ενεργό προσωπικό.'}
              {preview?.history_bookings_count > 0 && (
                <span> Λόγω ιστορικού κρατήσεων, θα απενεργοποιηθεί αντί να διαγραφεί οριστικά.</span>
              )}
            </p>

            {preview?.future_bookings_count > 0 && (
              <div className="form-group">
                <label className="form-label">Μεταφορά κρατήσεων σε γυμναστή</label>
                <select
                  className="form-select"
                  value={transferTo}
                  onChange={(e) => setTransferTo(e.target.value)}
                >
                  <option value="">— Χωρίς μεταφορά (όλες σε εκκρεμότητα) —</option>
                  {preview?.candidates?.map((c) => (
                    <option key={c.id} value={c.id}>{c.full_name} ({c.role})</option>
                  ))}
                </select>
              </div>
            )}

            {preview?.transferable?.length > 0 && (
              <div style={{ marginBottom: 14 }}>
                <div style={{ fontWeight: 700, fontSize: '0.85rem', color: '#166534', marginBottom: 8, display: 'flex', alignItems: 'center', gap: 6 }}>
                  <UserCheck size={15} /> Θα μεταφερθούν ({preview.transferable.length})
                </div>
                <div style={{ maxHeight: 140, overflow: 'auto', border: '1px solid #bbf7d0', borderRadius: 10, background: '#f0fdf4' }}>
                  {preview.transferable.map((b) => (
                    <div key={b.id} style={{ padding: '8px 12px', borderBottom: '1px solid #dcfce7', fontSize: '0.82rem' }}>
                      <strong>{b.user_name}</strong> · {b.service_name} · {formatWhen(b.starts_at)}
                    </div>
                  ))}
                </div>
              </div>
            )}

            {preview?.pending?.length > 0 && (
              <div style={{ marginBottom: 14 }}>
                <div style={{ fontWeight: 700, fontSize: '0.85rem', color: '#b45309', marginBottom: 8, display: 'flex', alignItems: 'center', gap: 6 }}>
                  <AlertTriangle size={15} /> Εκκρεμότητα — χρειάζονται χειροκίνητη ανάθεση ({preview.pending.length})
                </div>
                <div style={{ maxHeight: 160, overflow: 'auto', border: '1px solid #fde68a', borderRadius: 10, background: '#fffbeb' }}>
                  {preview.pending.map((b) => (
                    <div key={b.id} style={{ padding: '8px 12px', borderBottom: '1px solid #fef3c7', fontSize: '0.82rem' }}>
                      <strong>{b.user_name}</strong> · {b.service_name} · {formatWhen(b.starts_at)}
                      <div className="text-muted" style={{ marginTop: 2 }}>{b.reason_label}</div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            <div className="modal-footer">
              <button type="button" className="btn btn-secondary" onClick={onClose}>
                <X size={14} /> Ακύρωση
              </button>
              <button type="button" className="btn btn-danger" disabled={deleting} onClick={confirmDelete}>
                {deleting ? 'Διαγραφή...' : 'Επιβεβαίωση διαγραφής'}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
