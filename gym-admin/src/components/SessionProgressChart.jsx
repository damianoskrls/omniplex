import { isTrialMembership } from '../utils/payment_helpers';

function ringData(used, total) {
  const r = 40;
  const c = 2 * Math.PI * r;
  const pct = total > 0 ? Math.min(1, used / total) : 0;
  const usedDash = c * pct;
  return { r, c, usedDash, remaining: Math.max(0, total - used), pct: Math.round(pct * 100) };
}

export function SessionProgressRing({ used = 0, total, label, size = 100, unlimited = false }) {
  const { r, c, usedDash, remaining, pct } = ringData(used, total);
  const dim = size;

  if (unlimited || total >= 9999) {
    return (
      <div className="sess-ring" style={{ width: dim }}>
        <svg width={dim} height={dim} viewBox="0 0 100 100">
          <circle cx="50" cy="50" r={r} fill="none" stroke="rgba(184,245,94,0.15)" strokeWidth="12" />
          <circle cx="50" cy="50" r={r} fill="none" stroke="#B8F55E" strokeWidth="12" strokeDasharray={`${c} 0`} transform="rotate(-90 50 50)" />
          <text x="50" y="54" textAnchor="middle" fontSize="20" fontWeight="800" fill="#B8F55E">∞</text>
        </svg>
        {label && <div className="sess-ring-label">{label}</div>}
        <div className="sess-ring-sub">Απεριόριστες συνεδρίες</div>
      </div>
    );
  }

  return (
    <div className="sess-ring" style={{ width: dim }}>
      <svg width={dim} height={dim} viewBox="0 0 100 100">
        <circle cx="50" cy="50" r={r} fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth="12" />
        <circle
          cx="50"
          cy="50"
          r={r}
          fill="none"
          stroke="#B8F55E"
          strokeWidth="12"
          strokeDasharray={`${usedDash} ${c - usedDash}`}
          transform="rotate(-90 50 50)"
        />
        <text x="50" y="50" textAnchor="middle" fontSize="18" fontWeight="800" fill="#fff">{remaining}</text>
        <text x="50" y="64" textAnchor="middle" fontSize="9" fill="rgba(255,255,255,0.5)">απομένουν</text>
      </svg>
      {label && <div className="sess-ring-label">{label}</div>}
      <div className="sess-ring-sub">{used}/{total} χρησιμοποιήθηκαν · {pct}%</div>
    </div>
  );
}

export default function SessionProgressCharts({ memberships = [] }) {
  const active = memberships.filter((m) => {
    if (isTrialMembership(m)) return false;
    const until = m.valid_until?.slice(0, 10) || '';
    return until >= new Date().toISOString().slice(0, 10);
  });

  if (!active.length) {
    return <div className="text-muted" style={{ padding: 16, textAlign: 'center' }}>Δεν υπάρχουν ενεργά πακέτα με συνεδρίες</div>;
  }

  return (
    <div className="sess-charts-grid">
      {active.map((m) => {
        const unlimited = m.total_sessions >= 9999 || m.is_unlimited;
        const used = m.used_sessions || 0;
        const total = unlimited ? 9999 : (m.total_sessions || 0);
        return (
          <SessionProgressRing
            key={m.id}
            used={used}
            total={total}
            unlimited={unlimited}
            label={m.service_name || m.plan_name || 'Πακέτο'}
          />
        );
      })}
    </div>
  );
}
