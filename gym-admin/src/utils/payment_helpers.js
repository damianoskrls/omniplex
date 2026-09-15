import { optionKey } from './payments';

export function blocksNewPackageOption(membership, today = new Date().toISOString().slice(0, 10)) {
  const status = membership?.membership_status || 'active';
  if (status === 'trial') return true;
  const until = membership?.valid_until?.slice(0, 10) || '';
  return until >= today && status === 'active';
}

export function isTrialMembership(membership) {
  return membership?.membership_status === 'trial';
}

export function isGymPackageOption(opt) {
  if (!opt?.plan_id) return false;
  if (['nutrition', 'nutrition_consultation'].includes(opt.service_category)) return false;
  if (opt.service_name === 'Συνεδρία διατροφολόγου') return false;
  return true;
}

function membershipBlocksOption(membership, opt) {
  if (!blocksNewPackageOption(membership)) return false;

  // Check if the option's service is covered by any of the membership's plan services
  if (opt.service_id) {
    const planServiceIds = membership.plan_service_ids || (membership.service_id ? [membership.service_id] : []);
    if (planServiceIds.some(sid => String(sid) === String(opt.service_id))) return true;
  }

  const memKey = optionKey({
    service_id: membership.service_id || `name:${membership.service_name || membership.service_category || 'unknown'}`,
    plan_id: membership.plan_id,
  });
  if (memKey === optionKey(opt)) return true;

  if (!membership.service_id) {
    if (membership.service_name && membership.service_name === opt.service_name) return true;
    if (membership.service_category && membership.service_category === opt.service_name) return true;
  }

  return false;
}

/** Γιατί μια επιλογή πακέτου δεν είναι διαθέσιμη (null = διαθέσιμη) */
export function getPackageBlockReason(memberships, opt, today = new Date().toISOString().slice(0, 10)) {
  if (!isGymPackageOption(opt)) return null;

  const blocker = (memberships || []).find(m => membershipBlocksOption(m, opt));
  if (!blocker) return null;

  if (blocker.membership_status === 'trial') {
    return 'Υπάρχει δοκιμαστικό — ενεργοποίησέ το ή διέγραψέ το πρώτα';
  }

  const until = blocker.valid_until?.slice(0, 10) || '—';
  const label = blocker.service_name || opt.service_name || 'Υπηρεσία';
  return `Ενεργό πακέτο ${label} έως ${until}`;
}

/** Υπηρεσίες/πλάνα που ο πελάτης μπορεί να προσθέσει τώρα */
export function filterPackageOptionsForClient(packageOptions, memberships = []) {
  return (packageOptions || []).filter((opt) => {
    if (!isGymPackageOption(opt)) return false;
    return !getPackageBlockReason(memberships, opt);
  });
}

/** Μόνο υπηρεσίες/πλάνα που ανήκουν στην πληρωμή που επεξεργαζόμαστε */
export function packageOptionsForPayment(payment, packageOptions = []) {
  if (!payment) return [];

  const targets = [];
  if (payment.service_id) {
    targets.push({ service_id: payment.service_id, plan_id: payment.plan_id });
  }
  for (const li of payment.line_items || []) {
    if (li.service_id) {
      targets.push({ service_id: li.service_id, plan_id: li.plan_id });
    }
  }
  if (!targets.length) return [];

  const matchesTarget = (opt, t) => {
    if (String(t.service_id) !== String(opt.service_id)) return false;
    if (t.plan_id) return String(t.plan_id) === String(opt.plan_id);
    return true;
  };

  const exact = (packageOptions || []).filter((opt) =>
    targets.some((t) => matchesTarget(opt, t))
  );
  if (exact.length) return exact;

  const serviceIds = new Set(targets.map((t) => String(t.service_id)));
  return (packageOptions || []).filter((opt) => serviceIds.has(String(opt.service_id)));
}

export function pendingPaymentForMembership(payments, membershipId) {
  return (payments || [])
    .filter((p) => {
      if (p.balance_cents <= 0) return false;
      if (p.membership_id === membershipId) return true;
      return (p.line_items || []).some((li) => li.membership_id === membershipId);
    })
    .sort((a, b) => String(b.created_at || '').localeCompare(String(a.created_at || '')))[0] || null;
}

export function firstPendingPayment(payments) {
  return (payments || [])
    .filter(p => p.balance_cents > 0)
    .sort((a, b) => String(b.created_at || '').localeCompare(String(a.created_at || '')))[0] || null;
}

/**
 * Outstanding balance attributable to a specific membership within a (possibly multi-membership) payment.
 * Uses line_items when present; falls back to the full balance for single-membership payments.
 */
export function membershipBalance(pending, membershipId) {
  if (!pending) return 0;
  const lineItems = (pending.line_items || []).filter(li => li.membership_id === membershipId);
  if (lineItems.length) {
    const liTotal = lineItems.reduce((s, li) => s + (li.amount_cents || 0), 0);
    const ratio = pending.amount_cents > 0 ? liTotal / pending.amount_cents : 1;
    return Math.round(pending.balance_cents * ratio);
  }
  return pending.balance_cents;
}
