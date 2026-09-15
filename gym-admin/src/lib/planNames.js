const PERIOD_LABELS = {
  monthly: 'μηνιαία',
  quarterly: 'τριμηνιαία',
  yearly: 'ετήσια',
  once: 'εφάπαξ',
  package: 'πακέτο',
};

export function buildPlanNamePreview(serviceName, form) {
  const parts = [serviceName || 'Πακέτο'];
  const sessions = form.sessions;
  const unlimited = sessions === '' || sessions === null || sessions === undefined
    || Number(sessions) <= 0;
  if (unlimited) {
    parts.push('απεριόριστες συνεδρίες');
  } else {
    parts.push(`${sessions} συνεδρίες/μήνα`);
    if (form.duration_mins) parts.push(`${form.duration_mins}λ`);
  }
  parts.push(PERIOD_LABELS[form.billing_period] || form.billing_period || 'μηνιαία');
  if (form.price_cents !== '' && form.price_cents != null) {
    parts.push(`€${Number(form.price_cents).toFixed(2)}`);
  }
  return parts.join(' · ');
}

export function buildNutritionPlanPreview(form) {
  const parts = ['Διατροφή'];
  const monthly = form.monthly_price_cents !== '' && form.monthly_price_cents != null
    ? Math.round(Number(form.monthly_price_cents) * 100) : null;
  const perSession = form.per_session_price_cents !== '' && form.per_session_price_cents != null
    ? Math.round(Number(form.per_session_price_cents) * 100) : null;
  const pkgPrice = form.package_price_cents !== '' && form.package_price_cents != null
    ? Math.round(Number(form.package_price_cents) * 100) : null;

  if (monthly) parts.push(`μηνιαία €${(monthly / 100).toFixed(2)}`);
  if (perSession) parts.push(`ανά συνεδρία €${(perSession / 100).toFixed(2)}`);
  if (form.package_sessions && pkgPrice) {
    parts.push(`πακέτο ${form.package_sessions} συν. €${(pkgPrice / 100).toFixed(2)}`);
  }
  return parts.join(' · ');
}
