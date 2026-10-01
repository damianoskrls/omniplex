const { v4: uuidv4 } = require('uuid');
const { sqlActiveClients } = require('./client_soft_delete');
const { phoneLast10Eq } = require('./phone_sql');
const { createUserNotification } = require('./user_notifications');
const { sendFcm, getGlobalUserFcmTokens } = require('./push');

function staffKindClause(kind) {
  if (kind === 'nutritionist') {
    return `(COALESCE(s.is_nutritionist, 0) = 1 OR s.role LIKE '%διατροφ%' OR s.role LIKE '%nutri%')`;
  }
  if (kind === 'physiotherapist') {
    return `(s.role LIKE '%φυσιο%' OR s.role LIKE '%physio%')`;
  }
  if (kind === 'trainer') {
    return `(COALESCE(s.is_nutritionist, 0) = 0
      AND (s.role IS NULL OR (
        s.role NOT LIKE '%φυσιο%' AND s.role NOT LIKE '%physio%'
        AND s.role NOT LIKE '%διατροφ%' AND s.role NOT LIKE '%nutri%'
      )))`;
  }
  return '1=1';
}

function normalizeAudienceInput(input = {}) {
  let audience = input.audience || '';
  let clientScope = input.client_scope || '';
  const filterType = input.filter_type || '';

  if (audience === 'all') {
    audience = 'clients';
    if (!clientScope) clientScope = 'all';
  } else if (audience === 'active') {
    audience = 'clients';
    clientScope = 'active';
  }

  if (!audience) {
    if (filterType === 'staff') audience = 'staff';
    else audience = 'clients';
  }
  if (audience !== 'staff' && !clientScope) {
    if (['active_members', 'at_risk', 'no_active_package', 'active', 'all'].includes(filterType)) {
      clientScope = filterType === 'all' ? 'all' : filterType;
    } else {
      clientScope = 'all';
    }
  }

  let serviceId = input.service_id || null;
  if (!serviceId && filterType === 'service') serviceId = input.filter_value || null;

  return {
    audience: audience === 'staff' ? 'staff' : 'clients',
    locationId: input.location_id || null,
    serviceId: serviceId || null,
    staffKind: input.staff_kind || null,
    clientScope: audience === 'staff' ? null : (clientScope || 'all'),
  };
}

async function listClientRecipients(dbConn, bizId, { locationId, serviceId, clientScope }) {
  const where = ['u.business_id = ?', sqlActiveClients('u')];
  const params = [bizId];

  if (clientScope === 'active') {
    where.push("(u.account_status IS NULL OR u.account_status = 'active')");
  }
  if (clientScope === 'active_members') {
    where.push(`EXISTS (
      SELECT 1 FROM user_memberships m
      WHERE m.user_id = u.id AND m.business_id = u.business_id
        AND m.membership_status = 'active'
    )`);
  }
  if (clientScope === 'no_active_package') {
    where.push(`NOT EXISTS (
      SELECT 1 FROM user_memberships m
      WHERE m.user_id = u.id AND m.business_id = u.business_id
        AND m.membership_status = 'active'
    )`);
  }
  if (clientScope === 'at_risk') {
    where.push("(u.account_status IS NULL OR u.account_status = 'active')");
    where.push(`u.id NOT IN (
      SELECT DISTINCT b.user_id FROM bookings b
      WHERE b.business_id = ? AND b.starts_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
        AND b.user_id IS NOT NULL
    )`);
    params.push(bizId);
  }
  if (locationId) {
    where.push(`(
      EXISTS (SELECT 1 FROM user_locations ul WHERE ul.user_id = u.id AND ul.location_id = ?)
      OR EXISTS (
        SELECT 1 FROM bookings b
        WHERE b.user_id = u.id AND b.business_id = u.business_id
          AND b.location_id = ? AND b.status <> 'cancelled'
      )
    )`);
    params.push(locationId, locationId);
  }
  if (serviceId) {
    where.push(`(
      EXISTS (
        SELECT 1 FROM user_memberships um
        LEFT JOIN business_plans bp ON bp.id = um.plan_id
        LEFT JOIN plan_service_items psi ON psi.plan_id = um.plan_id
        LEFT JOIN service_plan_assignments spa ON spa.plan_id = um.plan_id
        WHERE um.user_id = u.id AND um.business_id = u.business_id
          AND (um.membership_status IS NULL OR um.membership_status = 'active')
          AND (
            um.service_id = ?
            OR bp.service_id = ?
            OR psi.service_id = ?
            OR spa.service_id = ?
          )
      )
      OR EXISTS (
        SELECT 1 FROM bookings b
        WHERE b.user_id = u.id AND b.business_id = u.business_id
          AND b.service_id = ? AND b.status <> 'cancelled'
          AND b.starts_at >= DATE_SUB(NOW(), INTERVAL 120 DAY)
      )
    )`);
    params.push(serviceId, serviceId, serviceId, serviceId, serviceId);
  }

  const [rows] = await dbConn.query(
    `SELECT DISTINCT u.id, u.full_name, u.email, u.phone, u.global_user_id
     FROM users u
     WHERE ${where.join(' AND ')}`,
    params,
  );
  return rows.map((row) => ({ ...row, kind: 'client' }));
}

async function listStaffRecipients(dbConn, bizId, { locationId, serviceId, staffKind }) {
  const where = [
    's.business_id = ?',
    's.is_active = 1',
    'COALESCE(s.is_general_pool, 0) = 0',
    staffKindClause(staffKind),
  ];
  const params = [bizId];
  if (locationId) {
    where.push('EXISTS (SELECT 1 FROM staff_locations sl WHERE sl.staff_id = s.id AND sl.location_id = ?)');
    params.push(locationId);
  }
  if (serviceId) {
    where.push(`(
      EXISTS (SELECT 1 FROM staff_services ss WHERE ss.staff_id = s.id AND ss.service_id = ?)
      OR EXISTS (SELECT 1 FROM staff_location_services sls WHERE sls.staff_id = s.id AND sls.service_id = ?)
    )`);
    params.push(serviceId, serviceId);
  }
  const [rows] = await dbConn.query(
    `SELECT s.id, s.full_name, s.portal_email AS email, s.phone, s.global_user_id, s.role
     FROM staff s
     WHERE ${where.join(' AND ')}`,
    params,
  );
  return rows.map((row) => ({ ...row, kind: 'staff' }));
}

async function resolveAudience(dbConn, bizId, input) {
  const opts = normalizeAudienceInput(input);
  if (opts.audience === 'staff') return listStaffRecipients(dbConn, bizId, opts);
  return listClientRecipients(dbConn, bizId, opts);
}

async function resolveStaffGlobalId(conn, staff) {
  if (staff.global_user_id) return staff.global_user_id;
  const digits = String(staff.phone || '').replace(/\D/g, '');
  if (digits.length < 10) return null;
  try {
    const [[gu]] = await conn.query(
      `SELECT id FROM global_users WHERE ${phoneLast10Eq('phone')} LIMIT 1`,
      [digits],
    );
    return gu?.id || null;
  } catch (err) {
    console.error('staff global user lookup failed:', err.message);
    return null;
  }
}

async function deliverAnnouncement(conn, people, { businessId, title, body, imageUrl, payload }) {
  let sent = 0;
  let pushed = 0;
  for (const person of people) {
    if (person.kind === 'staff') {
      const gid = await resolveStaffGlobalId(conn, person);
      if (!gid) continue;
      const id = uuidv4();
      await conn.query(
        `INSERT INTO global_user_notifications (id, global_user_id, type, title, body)
         VALUES (?, ?, 'announcement', ?, ?)`,
        [id, gid, title, body],
      );
      const tokens = await getGlobalUserFcmTokens(conn, gid);
      const result = await sendFcm(tokens, {
        title,
        body,
        imageUrl,
        data: { type: 'announcement', notification_id: id, ...(payload || {}) },
      });
      sent += 1;
      pushed += result.sent > 0 ? 1 : 0;
    } else {
      const note = await createUserNotification(conn, {
        businessId,
        userId: person.id,
        type: 'announcement',
        title,
        body,
        imageUrl,
        payload,
      });
      sent += 1;
      pushed += note.sentPush ? 1 : 0;
    }
  }
  return { sent, pushed, total: people.length, unreachable: people.length - sent };
}

module.exports = {
  normalizeAudienceInput,
  resolveAudience,
  deliverAnnouncement,
};
