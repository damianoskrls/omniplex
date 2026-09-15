/**
 * Συνεδρίες πακέτου: null στο πλάνο = απεριόριστες (9999).
 * Ενεργό membership με total_sessions=0 (π.χ. μηνιαία πρόσβαση) = απεριόριστες εντός περιόδου.
 * Δοκιμαστικό (trial) με 0 συνεδρίες δεν θεωρείται απεριόριστο — κλείνει με is_trial.
 */
function planSessionsToMembershipTotal(planSessions) {
  if (planSessions == null || planSessions === '') return 9999;
  const n = Number(planSessions);
  if (!Number.isFinite(n) || n <= 0) return 9999;
  return n;
}

function effectiveTotalSessions(membership) {
  if (!membership) return 0;
  const raw = Number(membership.total_sessions);
  if (!Number.isFinite(raw)) return 0;
  if (raw >= 9999) return 9999;
  if (raw === 0 && membership.membership_status !== 'trial') return 9999;
  return raw;
}

function membershipCredits(credit) {
  if (!credit) {
    return { remaining: 0, isUnlimited: false, canBook: false, hasMembership: false };
  }
  const total = effectiveTotalSessions(credit);
  const isUnlimited = total >= 9999;
  const used = Number(credit.used_sessions) || 0;
  const remaining = isUnlimited ? 9999 : Math.max(0, total - used);
  const canBook = isUnlimited || remaining > 0;
  return { remaining, isUnlimited, canBook, hasMembership: true };
}

function shouldDeductSession(membership) {
  return effectiveTotalSessions(membership) < 9999;
}

/** SQL: membership με διαθέσιμες συνεδρίες, απεριόριστο ή δοκιμαστικό */
function sqlActiveMembershipCredit(alias = 'm') {
  const p = alias ? `${alias}.` : '';
  const ms = `${p}membership_status`;
  const ts = `${p}total_sessions`;
  const us = `${p}used_sessions`;
  return `(
    ${ms} = 'trial'
    OR ${ts} >= 9999
    OR (${ts} = 0 AND COALESCE(${ms}, 'active') = 'active')
    OR (${ts} - ${us}) > 0
  )`;
}

module.exports = {
  planSessionsToMembershipTotal,
  effectiveTotalSessions,
  membershipCredits,
  shouldDeductSession,
  sqlActiveMembershipCredit,
};
