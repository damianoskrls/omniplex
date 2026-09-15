function isTrialMembership(membership) {
  return membership?.membership_status === 'trial';
}

/**
 * Γιατί δεν μπορεί να γίνει κανονική κράτηση όταν υπάρχει μόνο δοκιμαστικό.
 */
function trialBlockingInfo(membership) {
  if (!isTrialMembership(membership)) return null;

  const serviceName = membership.service_name || 'την υπηρεσία';
  const now = new Date();

  if (membership.trial_booking_id && membership.trial_starts_at) {
    const starts = new Date(membership.trial_starts_at);
    if (starts > now) {
      return {
        code: 'trial_scheduled',
        membership_id: membership.id,
        service_id: membership.service_id,
        service_name: membership.service_name,
        trial_starts_at: membership.trial_starts_at,
        message: `Ο πελάτης έχει προγραμματισμένο δοκιμαστικό για ${serviceName}. Περίμενε να πραγματοποιηθεί, μετά πέρασέ του ενεργό πακέτο και πάτα «Ενεργοποίηση» στο προφίλ του.`,
      };
    }
  }

  return {
    code: 'trial_needs_activation',
    membership_id: membership.id,
    service_id: membership.service_id,
    service_name: membership.service_name,
    trial_starts_at: membership.trial_starts_at || null,
    message: `Ο πελάτης έχει δοκιμαστικό για ${serviceName} χωρίς ενεργό πακέτο. Ολοκλήρωσε το δοκιμαστικό, πέρασέ του ενεργή συνδρομή και πάτα «Ενεργοποίηση» στο προφίλ του πριν κάνεις νέα κράτηση.`,
  };
}

module.exports = {
  isTrialMembership,
  trialBlockingInfo,
};
