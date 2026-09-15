const {
  findMembershipForService,
  loadPlanServiceMap,
} = require('./create_booking');
const { membershipCredits } = require('./membership_sessions');
const { sqlActiveClients } = require('./client_soft_delete');
const { sqlGymServiceCategories } = require('./gym_services');
const { isTrialMembership, trialBlockingInfo } = require('./trial_membership');
const { canBookWithMembership, getGracePeriodDays } = require('./membership_lifecycle');

const GYM_MEMBERSHIP_EXCLUDE = `(
  m.service_category IS NULL
  OR m.service_category NOT IN ('nutrition', 'nutrition_consultation')
)`;

function membershipBookableForService(membership, service, planToServiceId) {
  if (!membership || !service) return null;
  const matched = findMembershipForService([membership], service, planToServiceId);
  if (!matched || matched.id !== membership.id) return null;

  if (membership.membership_status === 'trial') {
    return null;
  }

  const { canBook } = membershipCredits(matched);
  if (!canBook) return null;
  return {
    mode: 'package',
    membership: matched,
    remaining: matched.remaining_sessions,
  };
}

async function loadGymMemberships(dbConn, bizId) {
  const graceDays = await getGracePeriodDays(dbConn, bizId);
    const [rows] = await dbConn.query(
    `SELECT m.id, m.user_id, m.plan_id, m.service_id, m.service_category,
            m.total_sessions, m.used_sessions, m.valid_until, m.valid_from,
            m.membership_status, m.trial_booking_id,
            (m.total_sessions - m.used_sessions) AS remaining_sessions,
            s.name AS service_name,
            bp.name AS plan_name,
            tb.starts_at AS trial_starts_at,
            tb.status AS trial_booking_status
     FROM user_memberships m
     LEFT JOIN services s ON s.id = m.service_id
     LEFT JOIN business_plans bp ON bp.id = m.plan_id
     LEFT JOIN bookings tb ON tb.id = m.trial_booking_id
     WHERE m.business_id = ?
       AND m.membership_status IN ('active', 'trial')
       AND m.membership_status != 'cancelled'
       AND (
         m.valid_until >= CURDATE()
         OR DATE_ADD(m.valid_until, INTERVAL ? DAY) >= CURDATE()
       )
       AND ${GYM_MEMBERSHIP_EXCLUDE}`,
    [bizId, graceDays],
  );
  return rows.filter((m) => canBookWithMembership(m, graceDays));
}

/**
 * Πελάτες που μπορούν να κλείσουν ραντεβού (έχουν πακέτο ή δοκιμαστικό γυμναστηρίου).
 * @param {string|null} serviceId - αν δοθεί, φιλτράρει για συγκεκριμένη υπηρεσία
 */
async function listBookableGymClients(dbConn, bizId, { serviceId = null, q = '' } = {}) {
  const [users] = await dbConn.query(
    `SELECT u.id, u.full_name, u.email, u.phone, u.account_status
     FROM users u
     WHERE u.business_id = ?
       AND ${sqlActiveClients('u')}
       AND COALESCE(u.account_status, 'active') = 'active'
     ORDER BY u.full_name`,
    [bizId],
  );

  const memberships = await loadGymMemberships(dbConn, bizId);
  const planToServiceId = await loadPlanServiceMap(dbConn, memberships);

  let service = null;
  if (serviceId) {
    const [[row]] = await dbConn.query(
      'SELECT id, name, category FROM services WHERE id = ? AND business_id = ? AND is_active = 1',
      [serviceId, bizId],
    );
    service = row || null;
  }

  const byUser = new Map();
  for (const m of memberships) {
    if (!byUser.has(m.user_id)) byUser.set(m.user_id, []);
    byUser.get(m.user_id).push(m);
  }

  const needle = String(q || '').trim().toLowerCase();
  const results = [];

  for (const user of users) {
    const userMems = byUser.get(user.id) || [];
    if (!userMems.length) continue;

    let bookable = null;
    if (!service) {
      const hasTrial = userMems.some(m => m.membership_status === 'trial');
      const hasPackage = userMems.some(m => {
        if (m.membership_status === 'trial') return false;
        return membershipCredits(m).canBook;
      });
      if (!hasTrial && !hasPackage) continue;
      bookable = {
        mode: hasPackage ? 'package' : 'trial_pending',
        can_create_booking: hasPackage,
        package_count: userMems.filter(m => m.membership_status === 'active').length,
        has_trial: hasTrial,
      };
    } else {
      for (const m of userMems) {
        const match = membershipBookableForService(m, service, planToServiceId);
        if (match) {
          bookable = match;
          break;
        }
      }
      if (!bookable) continue;
    }

    const hay = `${user.full_name} ${user.email || ''} ${user.phone || ''}`.toLowerCase();
    if (needle && !hay.includes(needle)) continue;

    results.push({
      id: user.id,
      full_name: user.full_name,
      email: user.email,
      phone: user.phone,
      bookable_mode: bookable.mode,
      can_create_booking: bookable.can_create_booking !== false,
      has_trial: bookable.has_trial || bookable.mode === 'trial',
      package_count: bookable.package_count ?? (bookable.mode === 'package' ? 1 : 0),
      remaining_sessions: bookable.remaining ?? null,
      service_name: bookable.membership?.service_name || null,
    });
  }

  return results;
}

/**
 * Επιλογές κράτησης για συγκεκριμένο πελάτη — μόνο υπηρεσίες/πακέτα που έχει.
 */
async function listClientGymBookingOptions(dbConn, bizId, userId) {
  const memberships = (await loadGymMemberships(dbConn, bizId))
    .filter((m) => String(m.user_id) === String(userId));
  if (!memberships.length) return [];

  const planToServiceId = await loadPlanServiceMap(dbConn, memberships);

  const [services] = await dbConn.query(
    `SELECT s.id, s.name, s.category, s.duration_mins, s.image_url, s.hide_staff_selection
     FROM services s
     WHERE s.business_id = ? AND s.is_active = 1
       AND ${sqlGymServiceCategories('s')}
     ORDER BY s.name`,
    [bizId],
  );

  const options = [];
  const trialBlocks = [];
  const seen = new Set();
  const seenTrials = new Set();

  for (const m of memberships) {
    if (isTrialMembership(m)) {
      const block = trialBlockingInfo(m);
      if (block && !seenTrials.has(m.id)) {
        seenTrials.add(m.id);
        trialBlocks.push(block);
      }
    }
  }

  for (const service of services) {
    for (const m of memberships) {
      const match = membershipBookableForService(m, service, planToServiceId);
      if (!match) continue;

      const key = `${service.id}:${match.mode}:${match.membership.id}`;
      if (seen.has(key)) continue;
      seen.add(key);

      const label = match.membership.plan_name
        || match.membership.service_name
        || service.name;

      options.push({
        service_id: service.id,
        service_name: service.name,
        service_category: service.category,
        duration_mins: service.duration_mins,
        image_url: service.image_url,
        hide_staff_selection: !!service.hide_staff_selection,
        bookable_mode: match.mode,
        membership_id: match.membership.id,
        package_label: label,
        remaining_sessions: match.remaining ?? null,
        plan_name: match.membership.plan_name || null,
      });
    }
  }

  options.sort((a, b) => a.service_name.localeCompare(b.service_name, 'el'));

  return { options, trial_blocks: trialBlocks };
}

module.exports = {
  listBookableGymClients,
  listClientGymBookingOptions,
  membershipBookableForService,
};
