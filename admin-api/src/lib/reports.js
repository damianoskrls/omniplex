const { sqlGymServiceCategories } = require('./gym_services');
const { sqlActiveClients } = require('./client_soft_delete');
const { sqlActiveMembershipCredit } = require('./membership_sessions');
const { mapPaymentRow } = require('./payments');

function parseReportFilters(query = {}) {
  const year = new Date().getFullYear();
  const from = query.from ? String(query.from).slice(0, 10) : `${year}-01-01`;
  const to = query.to ? String(query.to).slice(0, 10) : new Date().toISOString().slice(0, 10);
  const inactiveDays = Math.max(7, Math.min(365, Number(query.inactive_days) || 30));
  return {
    from,
    to,
    locationId: query.location_id || null,
    serviceId: query.service_id || null,
    staffId: query.staff_id || null,
    planId: query.plan_id || null,
    inactiveDays,
  };
}

function bookingFilterSql(filters, alias = 'b') {
  const clauses = [
    `${alias}.business_id = ?`,
    `DATE(${alias}.starts_at) BETWEEN ? AND ?`,
    `${alias}.status NOT IN ('cancelled', 'no_show')`,
    sqlGymServiceCategories('sv'),
  ];
  const params = [filters.from, filters.to];
  if (filters.locationId) {
    clauses.push(`${alias}.location_id = ?`);
    params.push(filters.locationId);
  }
  if (filters.serviceId) {
    clauses.push(`${alias}.service_id = ?`);
    params.push(filters.serviceId);
  }
  if (filters.staffId) {
    clauses.push(`${alias}.staff_id = ?`);
    params.push(filters.staffId);
  }
  return { where: clauses.join(' AND '), params };
}

async function getReportFilterOptions(db, bizId) {
  const [locations] = await db.query(
    'SELECT id, name FROM locations WHERE business_id = ? ORDER BY name ASC',
    [bizId],
  );
  const [services] = await db.query(
    `SELECT id, name FROM services
     WHERE business_id = ? AND ${sqlGymServiceCategories(null)}
     ORDER BY name ASC`,
    [bizId],
  );
  const [staff] = await db.query(
    `SELECT id, full_name AS name FROM staff
     WHERE business_id = ? AND is_active = 1
     ORDER BY full_name ASC`,
    [bizId],
  );
  const [plans] = await db.query(
    `SELECT id, name, plan_type FROM business_plans
     WHERE business_id = ?
     ORDER BY name ASC`,
    [bizId],
  );
  return { locations, services, staff, plans };
}

async function getReportsOverview(db, bizId, filters) {
  const bf = bookingFilterSql(filters, 'b');
  const bookingJoin = `
    FROM bookings b
    JOIN services sv ON sv.id = b.service_id
  `;
  const bookingWhere = `WHERE ${bf.where}`;
  const bookingParams = [bizId, ...bf.params];

  const [[bookingStats]] = await db.query(
    `SELECT COUNT(*) AS total_bookings,
            COUNT(DISTINCT b.user_id) AS unique_clients,
            SUM(CASE WHEN b.attendance_confirmed = 1 THEN 1 ELSE 0 END) AS attended
     ${bookingJoin}
     ${bookingWhere}`,
    bookingParams,
  );

  const [[activeMembers]] = await db.query(
    `SELECT COUNT(DISTINCT m.user_id) AS total
     FROM user_memberships m
     JOIN users u ON u.id = m.user_id AND u.business_id = m.business_id
     WHERE m.business_id = ?
       AND m.valid_until >= CURDATE()
       AND ${sqlActiveMembershipCredit('m')}
       AND ${sqlActiveClients('u')}`,
    [bizId],
  );

  const [bookingsTrend] = await db.query(
    `SELECT DATE_FORMAT(DATE(b.starts_at), '%Y-%m-%d') AS day, COUNT(*) AS count
     ${bookingJoin}
     ${bookingWhere}
     GROUP BY DATE_FORMAT(DATE(b.starts_at), '%Y-%m-%d')
     ORDER BY day ASC`,
    bookingParams,
  );

  const [serviceUsage] = await db.query(
    `SELECT sv.id AS service_id, sv.name AS service_name,
            COUNT(*) AS bookings,
            COUNT(DISTINCT b.user_id) AS unique_clients,
            SUM(CASE WHEN b.attendance_confirmed = 1 THEN 1 ELSE 0 END) AS attended
     ${bookingJoin}
     ${bookingWhere}
     GROUP BY sv.id, sv.name
     ORDER BY bookings DESC`,
    bookingParams,
  );

  const [trainerUsage] = await db.query(
    `SELECT st.id AS staff_id, COALESCE(st.full_name, 'Χωρίς γυμναστή') AS staff_name,
            COUNT(*) AS bookings,
            COUNT(DISTINCT b.user_id) AS unique_clients
     ${bookingJoin}
     LEFT JOIN staff st ON st.id = b.staff_id
     ${bookingWhere}
     GROUP BY st.id, st.full_name
     ORDER BY bookings DESC`,
    bookingParams,
  );

  const [locationUsage] = await db.query(
    `SELECT COALESCE(loc.id, '') AS location_id,
            COALESCE(loc.name, 'Χωρίς τοποθεσία') AS location_name,
            COUNT(*) AS bookings,
            COUNT(DISTINCT b.user_id) AS unique_clients
     ${bookingJoin}
     LEFT JOIN locations loc ON loc.id = b.location_id
     ${bookingWhere}
     GROUP BY loc.id, loc.name
     ORDER BY bookings DESC`,
    bookingParams,
  );

  const [timeOfDay] = await db.query(
    `SELECT
       CASE
         WHEN HOUR(b.starts_at) < 12 THEN 'morning'
         WHEN HOUR(b.starts_at) < 17 THEN 'afternoon'
         ELSE 'evening'
       END AS bucket,
       COUNT(*) AS bookings,
       COUNT(DISTINCT b.user_id) AS unique_clients
     ${bookingJoin}
     ${bookingWhere}
     GROUP BY bucket
     ORDER BY FIELD(bucket, 'morning', 'afternoon', 'evening')`,
    bookingParams,
  );

  const [morningClients] = await db.query(
    `SELECT u.id AS user_id, u.full_name, COUNT(*) AS morning_bookings,
            MAX(b.starts_at) AS last_morning_at
     ${bookingJoin}
     JOIN users u ON u.id = b.user_id
     ${bookingWhere}
       AND HOUR(b.starts_at) < 12
     GROUP BY u.id, u.full_name
     ORDER BY morning_bookings DESC, u.full_name ASC
     LIMIT 50`,
    bookingParams,
  );

  const [inactiveClients] = await db.query(
    `SELECT u.id AS user_id, u.full_name, lv.last_visit_at,
            DATEDIFF(CURDATE(), DATE(lv.last_visit_at)) AS days_inactive,
            (SELECT COUNT(*) FROM user_memberships m
             WHERE m.user_id = u.id AND m.business_id = u.business_id
               AND m.valid_until >= CURDATE()
               AND ${sqlActiveMembershipCredit('m')}) AS active_packages
     FROM users u
     JOIN (
       SELECT b.user_id, MAX(COALESCE(b.attendance_confirmed_at, b.starts_at)) AS last_visit_at
       FROM bookings b
       JOIN services sv ON sv.id = b.service_id
       WHERE b.business_id = ?
         AND b.attendance_confirmed = 1
         AND b.status NOT IN ('cancelled', 'no_show')
         AND ${sqlGymServiceCategories('sv')}
       GROUP BY b.user_id
     ) lv ON lv.user_id = u.id
     WHERE u.business_id = ?
       AND ${sqlActiveClients('u')}
       AND DATEDIFF(CURDATE(), DATE(lv.last_visit_at)) >= ?
     ORDER BY days_inactive DESC, u.full_name ASC
     LIMIT 50`,
    [bizId, bizId, filters.inactiveDays],
  );

  const [neverVisited] = await db.query(
    `SELECT u.id AS user_id, u.full_name, u.created_at,
            (SELECT COUNT(*) FROM user_memberships m
             WHERE m.user_id = u.id AND m.business_id = u.business_id
               AND m.valid_until >= CURDATE()
               AND ${sqlActiveMembershipCredit('m')}) AS active_packages
     FROM users u
     WHERE u.business_id = ?
       AND ${sqlActiveClients('u')}
       AND NOT EXISTS (
         SELECT 1 FROM bookings b
         JOIN services sv ON sv.id = b.service_id
         WHERE b.user_id = u.id AND b.business_id = u.business_id
           AND b.attendance_confirmed = 1
           AND b.status NOT IN ('cancelled', 'no_show')
           AND ${sqlGymServiceCategories('sv')}
       )
     ORDER BY u.created_at DESC
     LIMIT 30`,
    [bizId],
  );

  const [paymentRows] = await db.query(
    `SELECT p.*, u.full_name AS user_name, s.name AS service_name
     FROM payments p
     LEFT JOIN users u ON u.id = p.user_id
     LEFT JOIN services s ON s.id = p.service_id
     WHERE p.business_id = ?
     ORDER BY COALESCE(p.due_date, p.period_end, p.payment_date, p.created_at) ASC`,
    [bizId],
  );
  const payments = paymentRows.map(mapPaymentRow);
  const unpaidClientsMap = new Map();
  for (const p of payments) {
    if (p.status === 'paid' || p.balance_cents <= 0) continue;
    const key = p.user_id;
    if (!key) continue;
    const existing = unpaidClientsMap.get(key) || {
      user_id: key,
      full_name: p.user_name || '—',
      balance_cents: 0,
      overdue_count: 0,
      pending_count: 0,
      latest_due_date: null,
    };
    existing.balance_cents += p.balance_cents;
    if (p.status === 'overdue') existing.overdue_count += 1;
    else existing.pending_count += 1;
    const due = (p.due_date || p.period_end || '').toString().slice(0, 10);
    if (due && (!existing.latest_due_date || due > existing.latest_due_date)) {
      existing.latest_due_date = due;
    }
    unpaidClientsMap.set(key, existing);
  }
  const unpaidClients = [...unpaidClientsMap.values()]
    .sort((a, b) => b.balance_cents - a.balance_cents)
    .slice(0, 50);

  const packageParams = [bizId];
  let packageWhere = 'WHERE p.business_id = ?';
  if (filters.planId) {
    packageWhere += ' AND p.id = ?';
    packageParams.push(filters.planId);
  }
  const [packageRows] = await db.query(
    `SELECT p.id AS plan_id, p.name AS plan_name, p.plan_type,
            COUNT(DISTINCT m.user_id) AS active_clients,
            SUM(m.used_sessions) AS used_sessions,
            SUM(m.total_sessions) AS total_sessions
     FROM business_plans p
     LEFT JOIN user_memberships m ON m.plan_id = p.id AND m.business_id = p.business_id
       AND m.valid_until >= CURDATE()
       AND ${sqlActiveMembershipCredit('m')}
       AND COALESCE(m.membership_status, 'active') NOT IN ('cancelled')
     ${packageWhere}
     GROUP BY p.id, p.name, p.plan_type
     ORDER BY active_clients DESC, p.name ASC`,
    packageParams,
  );
  const packageUsage = packageRows;
  const [[nutritionFeature]] = await db.query(
    'SELECT feature_nutrition FROM business_configs WHERE business_id = ? LIMIT 1',
    [bizId],
  );
  let nutritionClients = [];
  if (nutritionFeature?.feature_nutrition) {
    const [rows] = await db.query(
      `SELECT u.id AS user_id, u.full_name, p.name AS plan_name, m.valid_until,
              m.used_sessions, m.total_sessions
       FROM user_memberships m
       JOIN users u ON u.id = m.user_id AND u.business_id = m.business_id
       JOIN business_plans p ON p.id = m.plan_id AND p.plan_type = 'nutrition'
       WHERE m.business_id = ?
         AND (m.valid_until IS NULL OR m.valid_until >= CURDATE())
         AND COALESCE(m.membership_status, 'active') NOT IN ('trial', 'cancelled')
         AND ${sqlActiveClients('u')}
       ORDER BY u.full_name ASC`,
      [bizId],
    );
    nutritionClients = rows;
  }

  const totalBookings = Number(bookingStats?.total_bookings || 0);
  const attended = Number(bookingStats?.attended || 0);
  const timeLabels = {
    morning: 'Πρωί (πριν 12:00)',
    afternoon: 'Απόγευμα (12:00–17:00)',
    evening: 'Βράδυ (μετά 17:00)',
  };

  return {
    filters,
    kpis: {
      total_bookings: totalBookings,
      unique_clients: Number(bookingStats?.unique_clients || 0),
      attendance_rate: totalBookings ? Math.round((attended / totalBookings) * 100) : 0,
      active_members: Number(activeMembers?.total || 0),
      inactive_clients: inactiveClients.length,
      never_visited: neverVisited.length,
      unpaid_clients: unpaidClients.length,
      morning_clients: morningClients.length,
      nutrition_clients: nutritionClients.length,
      outstanding_cents: unpaidClients.reduce((s, c) => s + c.balance_cents, 0),
    },
    bookings_trend: bookingsTrend.map((r) => ({
      day: r.day,
      count: Number(r.count),
    })),
    service_usage: serviceUsage.map((r) => ({
      service_id: r.service_id,
      service_name: r.service_name,
      bookings: Number(r.bookings),
      unique_clients: Number(r.unique_clients),
      attended: Number(r.attended),
      attendance_rate: Number(r.bookings)
        ? Math.round((Number(r.attended) / Number(r.bookings)) * 100)
        : 0,
    })),
    trainer_usage: trainerUsage.map((r) => ({
      staff_id: r.staff_id,
      staff_name: r.staff_name,
      bookings: Number(r.bookings),
      unique_clients: Number(r.unique_clients),
    })),
    location_usage: locationUsage.map((r) => ({
      location_id: r.location_id || null,
      location_name: r.location_name,
      bookings: Number(r.bookings),
      unique_clients: Number(r.unique_clients),
    })),
    time_of_day: timeOfDay.map((r) => ({
      bucket: r.bucket,
      label: timeLabels[r.bucket] || r.bucket,
      bookings: Number(r.bookings),
      unique_clients: Number(r.unique_clients),
    })),
    morning_clients: morningClients.map((r) => ({
      user_id: r.user_id,
      full_name: r.full_name,
      morning_bookings: Number(r.morning_bookings),
      last_morning_at: r.last_morning_at,
    })),
    inactive_clients: inactiveClients.map((r) => ({
      user_id: r.user_id,
      full_name: r.full_name,
      last_visit_at: r.last_visit_at,
      days_inactive: Number(r.days_inactive),
      active_packages: Number(r.active_packages),
    })),
    never_visited: neverVisited.map((r) => ({
      user_id: r.user_id,
      full_name: r.full_name,
      created_at: r.created_at,
      active_packages: Number(r.active_packages),
    })),
    unpaid_clients: unpaidClients,
    package_usage: packageUsage.map((r) => ({
      plan_id: r.plan_id,
      plan_name: r.plan_name,
      plan_type: r.plan_type,
      active_clients: Number(r.active_clients),
      used_sessions: Number(r.used_sessions || 0),
      total_sessions: Number(r.total_sessions || 0),
    })),
    nutrition_clients: nutritionClients.map((r) => ({
      user_id: r.user_id,
      full_name: r.full_name,
      plan_name: r.plan_name,
      valid_until: r.valid_until,
      used_sessions: Number(r.used_sessions || 0),
      total_sessions: Number(r.total_sessions || 0),
    })),
    feature_nutrition: !!nutritionFeature?.feature_nutrition,
    payment_summary: {
      count_paid: payments.filter((p) => p.status === 'paid').length,
      count_pending: payments.filter((p) => p.status === 'pending' || p.status === 'partial').length,
      count_overdue: payments.filter((p) => p.status === 'overdue').length,
      total_balance_cents: payments.reduce((s, p) => s + p.balance_cents, 0),
    },
  };
}

module.exports = {
  parseReportFilters,
  getReportFilterOptions,
  getReportsOverview,
};
