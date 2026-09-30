const ACTIVE_MEMBERSHIP_SQL = `
  (um.valid_until IS NULL OR um.valid_until >= CURDATE())
  AND (um.membership_status IS NULL OR um.membership_status IN ('active', 'trial'))
`;

const MEMBERSHIP_MATCHES_SERVICE_SQL = `
  um.service_id = s.id
  OR bp.service_id = s.id
  OR psi.service_id = s.id
  OR spa.service_id = s.id
`;

async function memberServices(db, bizId, userId) {
  const [rows] = await db.query(
    `SELECT DISTINCT s.id, s.name
     FROM services s
     WHERE s.business_id = ? AND s.is_active = 1
       AND EXISTS (
         SELECT 1
         FROM user_memberships um
         LEFT JOIN business_plans bp ON bp.id = um.plan_id
         LEFT JOIN plan_service_items psi ON psi.plan_id = um.plan_id
         LEFT JOIN service_plan_assignments spa ON spa.plan_id = um.plan_id
         WHERE um.user_id = ? AND um.business_id = s.business_id
           AND ${ACTIVE_MEMBERSHIP_SQL}
           AND (${MEMBERSHIP_MATCHES_SERVICE_SQL})
       )
     ORDER BY s.name`,
    [bizId, userId],
  );
  return rows;
}

async function trainerServices(db, bizId, staffId) {
  const [rows] = await db.query(
    `SELECT s.id, s.name
     FROM staff_services ss
     JOIN services s ON s.id = ss.service_id AND s.business_id = ? AND s.is_active = 1
     WHERE ss.staff_id = ?
     ORDER BY s.name`,
    [bizId, staffId],
  );
  return rows;
}

async function memberSharesServiceWithStaff(db, bizId, userId, staffId) {
  const [rows] = await db.query(
    `SELECT 1
     FROM staff_services ss
     JOIN services s ON s.id = ss.service_id AND s.business_id = ? AND s.is_active = 1
     WHERE ss.staff_id = ?
       AND EXISTS (
         SELECT 1
         FROM user_memberships um
         LEFT JOIN business_plans bp ON bp.id = um.plan_id
         LEFT JOIN plan_service_items psi ON psi.plan_id = um.plan_id
         LEFT JOIN service_plan_assignments spa ON spa.plan_id = um.plan_id
         WHERE um.user_id = ? AND um.business_id = s.business_id
           AND ${ACTIVE_MEMBERSHIP_SQL}
           AND (${MEMBERSHIP_MATCHES_SERVICE_SQL})
       )
     LIMIT 1`,
    [bizId, staffId, userId],
  );
  return rows.length > 0;
}

module.exports = {
  memberServices,
  trainerServices,
  memberSharesServiceWithStaff,
};
