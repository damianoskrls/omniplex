import { X, AlertTriangle, ChevronRight } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { fmtDate } from '../utils/dates';

function daysLeft(validUntil) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const exp = new Date(validUntil);
  exp.setHours(0, 0, 0, 0);
  return Math.round((exp - today) / 86400000);
}

export default function ExpiringMembershipsModal({ memberships, onClose }) {
  const navigate = useNavigate();
  if (!memberships || memberships.length === 0) return null;

  function goToClient(userId) {
    onClose();
    navigate(`/clients/${userId}`);
  }

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal cb-modal" style={{ maxWidth: 560 }} onClick={e => e.stopPropagation()}>

        {/* Header */}
        <div className="cb-modal-header" style={{ padding: '20px 28px', background: '#fffbeb', borderBottom: '1px solid #fde68a' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <AlertTriangle size={18} color="#d97706" />
            <div>
              <div style={{ fontWeight: 700, fontSize: '1rem', color: '#92400e' }}>
                Συνδρομές που λήγουν σύντομα
              </div>
              <div style={{ fontSize: '0.8rem', color: '#b45309', marginTop: 2 }}>
                {memberships.length} πελάτης/ες χρειάζεται/ονται ανανέωση
              </div>
            </div>
          </div>
          <button type="button" className="cb-modal-close" onClick={onClose}><X size={20} /></button>
        </div>

        {/* List */}
        <div style={{ maxHeight: 420, overflowY: 'auto', padding: '8px 0' }}>
          {memberships.map(m => {
            const left = daysLeft(m.valid_until);
            const urgency = left === 0 ? '#ef4444' : left === 1 ? '#f97316' : '#d97706';
            const sessions_left = m.total_sessions - m.used_sessions;
            return (
              <button
                key={m.membership_id}
                type="button"
                onClick={() => goToClient(m.user_id)}
                style={{
                  display: 'flex', alignItems: 'center', gap: 14,
                  width: '100%', padding: '14px 28px',
                  background: 'none', border: 'none', cursor: 'pointer',
                  borderBottom: '1px solid #f1f5f9',
                  textAlign: 'left', transition: 'background .12s',
                }}
                onMouseEnter={e => e.currentTarget.style.background = '#f8fafc'}
                onMouseLeave={e => e.currentTarget.style.background = 'none'}
              >
                {/* Avatar */}
                <div style={{
                  width: 40, height: 40, borderRadius: '50%', flexShrink: 0,
                  background: '#e2e8f0', display: 'flex', alignItems: 'center',
                  justifyContent: 'center', fontWeight: 700, fontSize: 15, color: '#64748b',
                }}>
                  {(m.full_name || '?').charAt(0).toUpperCase()}
                </div>

                {/* Info */}
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontWeight: 600, fontSize: '0.9rem', color: '#1e293b', marginBottom: 2 }}>
                    {m.full_name}
                  </div>
                  <div style={{ fontSize: '0.78rem', color: '#64748b' }}>
                    {m.plan_name || m.service_name || '—'}
                    {m.phone ? ` · ${m.phone}` : ''}
                  </div>
                  <div style={{ fontSize: '0.78rem', color: '#64748b', marginTop: 1 }}>
                    {sessions_left > 0 && sessions_left < 9999
                      ? `${sessions_left} συνεδρίες απομένουν · `
                      : ''}
                    Λήγει {fmtDate(m.valid_until)}
                    {m.plan_price ? ` · ${Number(m.plan_price).toFixed(0)}€` : ''}
                  </div>
                </div>

                {/* Badge + arrow */}
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexShrink: 0 }}>
                  <span style={{
                    background: urgency + '18', color: urgency,
                    fontWeight: 700, fontSize: '0.75rem',
                    padding: '3px 10px', borderRadius: 20,
                    border: `1px solid ${urgency}40`,
                    whiteSpace: 'nowrap',
                  }}>
                    {left === 0 ? 'Σήμερα!' : left === 1 ? '1 μέρα' : `${left} μέρες`}
                  </span>
                  <ChevronRight size={15} color="#94a3b8" />
                </div>
              </button>
            );
          })}
        </div>

        {/* Footer */}
        <div style={{ padding: '14px 28px', borderTop: '1px solid #f1f5f9', display: 'flex', justifyContent: 'flex-end' }}>
          <button className="btn btn-secondary" onClick={onClose}>Το είδα</button>
        </div>
      </div>
    </div>
  );
}
