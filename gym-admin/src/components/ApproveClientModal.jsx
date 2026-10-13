import { useEffect } from 'react';
import { Sparkles, UserCheck, UserX, MapPin } from 'lucide-react';

export default function ApproveClientModal({ open, client, onApprove, onReject, onClose, loading }) {
  useEffect(() => {
    if (!open) return;
    function onKey(e) { if (e.key === 'Escape') onClose(); }
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  if (!open || !client) return null;

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal modal--animated" style={{ maxWidth: 420 }} onClick={e => e.stopPropagation()}>

        {/* Header */}
        <div className="approve-modal-header">
          <div className="approve-modal-icon">
            <Sparkles size={22} />
          </div>
          <div>
            <div className="approve-modal-title">Έγκριση πελάτη</div>
            <div className="approve-modal-desc">
              Ο πελάτης θα ενημερωθεί αυτόματα και θα αποκτήσει πρόσβαση στο γυμναστήριο.
            </div>
          </div>
        </div>

        {/* Client card */}
        <div className="approve-modal-card">
          <div className="approve-modal-name">{client.name}</div>
          {client.locationName && (
            <div className="approve-modal-location">
              <MapPin size={12} />
              {client.locationName}
            </div>
          )}
          {client.phone && <div className="approve-modal-meta">{client.phone}</div>}
          {client.email && <div className="approve-modal-meta">{client.email}</div>}
        </div>

        {/* Footer */}
        <div className="modal-footer" style={{ marginTop: 20 }}>
          <button
            type="button"
            className="btn btn-secondary"
            style={{ color: 'var(--danger, #ef4444)' }}
            onClick={onReject}
            disabled={loading}
          >
            <UserX size={14} /> Απόρριψη
          </button>
          <button
            type="button"
            className="btn btn-primary"
            onClick={onApprove}
            disabled={loading}
          >
            {loading
              ? <span className="topbar-search__spinner" style={{ width: 14, height: 14 }} />
              : <><UserCheck size={14} /> Έγκριση</>
            }
          </button>
        </div>

      </div>
    </div>
  );
}
