const { v4: uuidv4 } = require('uuid');
const { planSessionsToMembershipTotal } = require('./membership_sessions');
const { createAdminNotification } = require('./notifications');

function ymd(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function addMonthsEnd(startYmd, months) {
  const d = new Date(`${startYmd}T12:00:00`);
  d.setMonth(d.getMonth() + Number(months || 1));
  d.setDate(d.getDate() - 1);
  return ymd(d);
}

function periodMonths(billing) {
  if (billing === 'quarterly') return 3;
  if (billing === 'yearly' || billing === 'once' || billing === 'package') return 12;
  return 1;
}

async function memberCoveredServiceIds(db, bizId, userId) {
  const [memberships] = await db.query(
    `SELECT plan_id, service_id FROM user_memberships
     WHERE user_id = ? AND business_id = ?
       AND (valid_until IS NULL OR valid_until >= CURDATE())
       AND (membership_status IS NULL OR membership_status IN ('active', 'trial'))`,
    [userId, bizId],
  );
  const ids = new Set(memberships.map((m) => m.service_id).filter(Boolean).map(String));
  const planIds = [...new Set(memberships.map((m) => m.plan_id).filter(Boolean))];
  if (!planIds.length) return ids;

  const [linked] = await db.query(
    `SELECT service_id FROM plan_service_items WHERE plan_id IN (?)
     UNION
     SELECT service_id FROM service_plan_assignments WHERE plan_id IN (?)
     UNION
     SELECT service_id FROM business_plans WHERE id IN (?) AND service_id IS NOT NULL`,
    [planIds, planIds, planIds],
  );
  for (const row of linked) {
    if (row.service_id) ids.add(String(row.service_id));
  }
  return ids;
}

async function listExtraServices(db, bizId, userId) {
  const covered = await memberCoveredServiceIds(db, bizId, userId);
  const [services] = await db.query(
    `SELECT id, name, description, category, duration_mins, image_url
     FROM services
     WHERE business_id = ? AND is_active = 1
       AND COALESCE(category, '') NOT IN ('nutrition', 'nutrition_consultation')
     ORDER BY name`,
    [bizId],
  );
  const extra = services.filter((s) => !covered.has(String(s.id)));
  if (!extra.length) return [];

  const [plans] = await db.query(
    `SELECT bp.id, bp.name, bp.sessions, bp.price_cents, bp.billing_period,
            bp.service_id, psi.service_id AS item_service_id, spa.service_id AS assigned_service_id
     FROM business_plans bp
     LEFT JOIN plan_service_items psi ON psi.plan_id = bp.id
     LEFT JOIN service_plan_assignments spa ON spa.plan_id = bp.id
     WHERE bp.business_id = ? AND bp.is_active = 1
       AND (bp.plan_type IS NULL OR bp.plan_type = 'service')`,
    [bizId],
  );

  const byService = new Map(extra.map((s) => [String(s.id), []]));
  const seen = new Set();
  for (const plan of plans) {
    const targets = [plan.service_id, plan.item_service_id, plan.assigned_service_id]
      .filter(Boolean)
      .map(String);
    for (const sid of targets) {
      if (!byService.has(sid)) continue;
      const key = `${sid}:${plan.id}`;
      if (seen.has(key)) continue;
      seen.add(key);
      byService.get(sid).push({
        id: plan.id,
        name: plan.name,
        sessions: plan.sessions,
        price_cents: Number(plan.price_cents) || 0,
        billing_period: plan.billing_period,
      });
    }
  }

  return extra.map((s) => ({
    ...s,
    plans: byService.get(String(s.id)) || [],
  }));
}

async function loadPlanForBusiness(db, bizId, planId) {
  const [[plan]] = await db.query(
    `SELECT * FROM business_plans
     WHERE id = ? AND business_id = ? AND is_active = 1
       AND (plan_type IS NULL OR plan_type = 'service')`,
    [planId, bizId],
  );
  if (!plan) return null;

  const serviceIds = new Set();
  if (plan.service_id) serviceIds.add(String(plan.service_id));
  const [items] = await db.query(
    'SELECT service_id FROM plan_service_items WHERE plan_id = ?',
    [planId],
  );
  for (const item of items) {
    if (item.service_id) serviceIds.add(String(item.service_id));
  }
  if (!serviceIds.size) {
    const [assigned] = await db.query(
      'SELECT service_id FROM service_plan_assignments WHERE plan_id = ?',
      [planId],
    );
    for (const row of assigned) {
      if (row.service_id) serviceIds.add(String(row.service_id));
    }
  }
  plan.service_ids = [...serviceIds];
  return plan;
}

async function grantPlanMembership(conn, { bizId, userId, plan, paid, intentId, locationId = null }) {
  const today = ymd(new Date());
  const until = addMonthsEnd(today, periodMonths(plan.billing_period));
  const sessions = planSessionsToMembershipTotal(plan.sessions);
  const primaryService = plan.service_ids?.[0] || plan.service_id || null;
  const multi = (plan.service_ids || []).length > 1;
  const [[svc]] = primaryService
    ? await conn.query(
      'SELECT category, name FROM services WHERE id = ? AND business_id = ?',
      [primaryService, bizId],
    )
    : [[]];

  const membershipId = uuidv4();
  await conn.query(
    `INSERT INTO user_memberships
      (id, user_id, business_id, plan_id, service_id, service_category,
       total_sessions, used_sessions, valid_from, valid_until, notes)
     VALUES (?,?,?,?,?,?,?,0,?,?,?)`,
    [
      membershipId, userId, bizId, plan.id,
      multi ? null : primaryService,
      svc?.category || null,
      sessions, today, until, plan.name,
    ],
  );

  const amount = Number(plan.price_cents) || 0;
  const paymentId = uuidv4();
  try {
    await conn.query(
      `INSERT INTO payments
        (id, business_id, user_id, amount_cents, paid_amount_cents, status,
         description, payment_date, method, service_id, plan_id, payment_type,
         period_start, period_end, membership_id, notes)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [
        paymentId, bizId, userId, amount, paid ? amount : 0, paid ? 'paid' : 'pending',
        plan.name, paid ? today : null, paid ? 'card' : 'cash',
        multi ? null : primaryService, plan.id,
        plan.billing_period === 'monthly' ? 'monthly' : 'package',
        today, until, membershipId,
        intentId ? `stripe:${intentId}` : 'Αγορά από την εφαρμογή',
      ],
    );
  } catch (err) {
    console.warn('member plan payment skipped:', err.message);
  }

  const [[user]] = await conn.query(
    'SELECT full_name FROM users WHERE id = ? AND business_id = ?',
    [userId, bizId],
  );
  try {
    await createAdminNotification(conn, {
      businessId: bizId,
      type: 'package_purchase',
      title: 'Νέο πακέτο από την εφαρμογή',
      body: `${user?.full_name || 'Πελάτης'} πήρε το πακέτο ${plan.name}${svc?.name ? ` (${svc.name})` : ''}.`,
      locationId,
      userId: locationId ? null : userId,
      payload: { user_id: userId, plan_id: plan.id, membership_id: membershipId, paid: !!paid, location_id: locationId },
    });
  } catch (err) {
    console.warn('member plan notification skipped:', err.message);
  }

  return {
    membership_id: membershipId,
    valid_until: until,
    paid: !!paid,
    service_name: svc?.name || null,
    plan_name: plan.name,
  };
}

module.exports = {
  memberCoveredServiceIds,
  listExtraServices,
  loadPlanForBusiness,
  grantPlanMembership,
};
