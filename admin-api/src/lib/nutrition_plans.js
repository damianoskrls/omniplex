function parsePromoRules(raw) {
  if (!raw) return { rules: [] };
  if (typeof raw === 'object') return raw.rules ? raw : { rules: [] };
  try {
    const parsed = JSON.parse(raw);
    return parsed?.rules ? parsed : { rules: Array.isArray(parsed) ? parsed : [] };
  } catch {
    return { rules: [] };
  }
}

function normalizePromoRules(body) {
  const rules = Array.isArray(body?.rules) ? body.rules : [];
  return {
    rules: rules.map((r) => ({
      when_service_plan_billing_period: r.when_service_plan_billing_period || null,
      when_service_plan_ids: Array.isArray(r.when_service_plan_ids) ? r.when_service_plan_ids : [],
      when_package_months_min: r.when_package_months_min != null ? Number(r.when_package_months_min) : null,
      effect: r.effect || 'discount_percent',
      discount_percent: r.discount_percent != null ? Number(r.discount_percent) : null,
      free_months: r.free_months != null ? Number(r.free_months) : null,
      description: r.description || '',
    })),
  };
}

function addMonthsToDate(isoDate, months) {
  const [y, m, d] = isoDate.split('-').map(Number);
  const dt = new Date(y, m - 1 + months, d);
  const yy = dt.getFullYear();
  const mm = String(dt.getMonth() + 1).padStart(2, '0');
  const dd = String(dt.getDate()).padStart(2, '0');
  return `${yy}-${mm}-${dd}`;
}

/**
 * Evaluate promo rules when assigning nutrition alongside a gym service plan.
 */
function evaluateNutritionPromo(nutritionPlan, { servicePlan, paymentType, packageMonths, periodStart }) {
  const basePrice = nutritionPlan.price_cents || 0;
  const { rules } = parsePromoRules(nutritionPlan.promo_rules);
  let priceCents = basePrice;
  let bonusMonths = 0;
  let appliedRule = null;

  const gymBilling = servicePlan?.billing_period || null;
  const gymPlanId = servicePlan?.id || null;
  const pkgMonths = packageMonths != null ? Number(packageMonths) : null;

  for (const rule of rules) {
    const periodOk = !rule.when_service_plan_billing_period
      || rule.when_service_plan_billing_period === gymBilling
      || (rule.when_service_plan_billing_period === 'yearly' && paymentType === 'package' && pkgMonths >= 12);

    const planIds = rule.when_service_plan_ids || [];
    const planOk = !planIds.length || (gymPlanId && planIds.includes(gymPlanId));

    const monthsOk = rule.when_package_months_min == null
      || (pkgMonths != null && pkgMonths >= rule.when_package_months_min);

    if (!periodOk || !planOk || !monthsOk) continue;

    if (rule.effect === 'free') {
      return {
        priceCents: 0,
        bonusMonths: 0,
        appliedRule: rule,
        validUntil: nutritionValidUntil(periodStart, nutritionPlan.billing_period, 0),
        label: rule.description || 'Δωρεάν πακέτο διατροφής',
      };
    }

    if (rule.effect === 'free_months') {
      const months = rule.free_months || 0;
      appliedRule = rule;
      bonusMonths = months;
      break;
    }

    if (rule.effect === 'discount_percent' && rule.discount_percent != null) {
      priceCents = Math.round(basePrice * (1 - rule.discount_percent / 100));
      appliedRule = rule;
      break;
    }
  }

  const totalMonths = billingMonthsForPlan(nutritionPlan.billing_period, paymentType, packageMonths) + bonusMonths;
  return {
    priceCents,
    bonusMonths,
    appliedRule,
    validUntil: nutritionValidUntil(periodStart, nutritionPlan.billing_period, totalMonths),
    label: appliedRule?.description || null,
  };
}

function billingMonthsForPlan(billingPeriod, paymentType, packageMonths) {
  if (paymentType === 'package' && packageMonths) return Number(packageMonths);
  switch (billingPeriod) {
    case 'quarterly': return 3;
    case 'yearly': return 12;
    case 'once':
    case 'package': return 12;
    default: return 1;
  }
}

function nutritionValidUntil(periodStart, billingPeriod, monthsOverride) {
  const months = monthsOverride != null
    ? monthsOverride
    : billingMonthsForPlan(billingPeriod, 'monthly', null);
  return addMonthsToDate(periodStart, months);
}

function nutritionIncludesSummary(plan) {
  const parts = [];
  if (plan.nutrition_includes_meal_plan) parts.push('Πρόγραμμα διατροφής');
  if (plan.nutrition_includes_measurements) parts.push('Μετρήσεις');
  if (plan.nutrition_includes_food_diary) parts.push('Ημερολόγιο');
  if (plan.nutrition_includes_consultations) {
    parts.push(plan.nutrition_consultation_sessions
      ? `${plan.nutrition_consultation_sessions} συνεδρίες`
      : 'Συνεδρίες διατροφολόγου');
  }
  return parts;
}

module.exports = {
  parsePromoRules,
  normalizePromoRules,
  evaluateNutritionPromo,
  nutritionIncludesSummary,
  addMonthsToDate,
};
