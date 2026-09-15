export const ACCESS_STATE_LABELS = {
  active: 'Ενεργή',
  grace: 'Περίοδος χάριτος',
  expired: 'Έληξε',
  cancelled: 'Διακομμένη',
  trial: 'Δοκιμαστικό',
};

export const ACCESS_STATE_BADGE = {
  active: 'badge-green',
  grace: 'badge-yellow',
  expired: 'badge-red',
  cancelled: 'badge-gray',
  trial: 'badge-yellow',
};

export function isMonthlyMembership(membership) {
  if (!membership || membership.membership_status === 'trial') return false;
  if (membership.service_category === 'nutrition') return false;
  return membership.billing_period === 'monthly'
    || membership.total_sessions >= 9999
    || membership.access_state === 'active'
    || membership.access_state === 'grace';
}

export function canRenewMembership(membership) {
  if (!membership || membership.membership_status === 'trial') return false;
  if (membership.membership_status === 'cancelled') return false;
  return membership.can_prepay || membership.access_state === 'grace' || membership.access_state === 'active';
}

export function canCancelMembership(membership) {
  if (!membership || membership.membership_status === 'trial') return false;
  return membership.membership_status !== 'cancelled' && membership.access_state !== 'cancelled';
}

export function canReactivateMembership(membership) {
  return membership?.membership_status === 'cancelled' || membership?.access_state === 'cancelled';
}
