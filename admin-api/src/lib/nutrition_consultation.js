const { v4: uuidv4 } = require('uuid');

const CONSULTATION_SERVICE_NAME = 'Συνεδρία διατροφολόγου';
const CONSULTATION_CATEGORY = 'nutrition_consultation';
const DEFAULT_DURATION_MINS = 45;
const DEFAULT_CONSULTATION_TIMES = ['10:00:00', '11:00:00', '17:00:00'];
const DEFAULT_CONSULTATION_WEEKDAYS = [0, 1, 2, 3, 4];

async function isNutritionConsultationService(dbConn, serviceId) {
  if (!serviceId) return false;
  const [[row]] = await dbConn.query(
    'SELECT category FROM services WHERE id = ?',
    [serviceId],
  );
  return row?.category === CONSULTATION_CATEGORY;
}

async function ensureDefaultConsultationSchedules(dbConn, bizId, serviceId, staffId, locationId = null) {
  if (!serviceId || !staffId) return 0;

  const [[{ cnt }]] = await dbConn.query(
    `SELECT COUNT(*) AS cnt FROM service_slot_schedules
     WHERE service_id = ? AND business_id = ? AND staff_id = ?`,
    [serviceId, bizId, staffId],
  );
  if (Number(cnt) > 0) return 0;

  let created = 0;
  for (const weekday of DEFAULT_CONSULTATION_WEEKDAYS) {
    for (const start_time of DEFAULT_CONSULTATION_TIMES) {
      await dbConn.query(
        `INSERT INTO service_slot_schedules
          (id, service_id, business_id, location_id, weekday, start_time, label, max_capacity, staff_id, is_active)
         VALUES (?,?,?,?,?,?,?,?,?,1)`,
        [uuidv4(), serviceId, bizId, locationId, weekday, start_time, 'Συνεδρία', 1, staffId],
      );
      created += 1;
    }
  }
  return created;
}

async function listActiveNutritionists(dbConn, bizId) {
  const [rows] = await dbConn.query(
    `SELECT n.id, n.full_name, n.email, n.staff_id, n.location_id, n.is_active,
            l.name AS location_name
     FROM nutritionists n
     LEFT JOIN locations l ON l.id = n.location_id
     WHERE n.business_id = ? AND n.is_active = 1
     ORDER BY l.sort_order, l.name, n.full_name`,
    [bizId],
  );
  return rows;
}

async function getNutritionistById(dbConn, bizId, nutritionistId) {
  if (!nutritionistId) return null;
  const [[row]] = await dbConn.query(
    `SELECT n.id, n.full_name, n.email, n.staff_id, n.location_id, n.is_active,
            l.name AS location_name
     FROM nutritionists n
     LEFT JOIN locations l ON l.id = n.location_id
     WHERE n.id = ? AND n.business_id = ? AND n.is_active = 1`,
    [nutritionistId, bizId],
  );
  return row || null;
}

async function resolveNutritionistStaffId(dbConn, bizId, { nutritionist_id: nutritionistId, staff_id: staffId } = {}) {
  if (staffId) {
    const [[row]] = await dbConn.query(
      'SELECT staff_id FROM nutritionists WHERE staff_id = ? AND business_id = ? AND is_active = 1',
      [staffId, bizId],
    );
    return row?.staff_id || null;
  }
  if (nutritionistId) {
    const nut = await getNutritionistById(dbConn, bizId, nutritionistId);
    return nut?.staff_id || null;
  }
  const nutritionists = await listActiveNutritionists(dbConn, bizId);
  if (nutritionists.length === 1) return nutritionists[0].staff_id;
  return null;
}

async function findPendingConsultationBooking(dbConn, userId, bizId, serviceId) {
  if (!serviceId) return null;
  const [[row]] = await dbConn.query(
    `SELECT id, starts_at, ends_at, status
     FROM bookings
     WHERE user_id = ? AND business_id = ? AND service_id = ?
       AND status = 'pending'
       AND starts_at >= NOW()
     ORDER BY starts_at ASC
     LIMIT 1`,
    [userId, bizId, serviceId],
  );
  return row || null;
}

async function findUpcomingConfirmedConsultationBooking(dbConn, userId, bizId, serviceId) {
  if (!serviceId) return null;
  const [[row]] = await dbConn.query(
    `SELECT id, starts_at, ends_at, status
     FROM bookings
     WHERE user_id = ? AND business_id = ? AND service_id = ?
       AND status = 'confirmed'
       AND starts_at >= NOW()
     ORDER BY starts_at ASC
     LIMIT 1`,
    [userId, bizId, serviceId],
  );
  return row || null;
}

async function hasActiveConsultationBooking(dbConn, userId, bizId, serviceId) {
  if (!serviceId) return false;
  const [[row]] = await dbConn.query(
    `SELECT 1 FROM bookings
     WHERE user_id = ? AND business_id = ? AND service_id = ?
       AND status IN ('pending', 'confirmed')
       AND starts_at >= NOW()
     LIMIT 1`,
    [userId, bizId, serviceId],
  );
  return !!row;
}

async function getConsultationServiceId(db, bizId) {
  const [[cfg]] = await db.query(
    'SELECT nutrition_consultation_service_id FROM business_configs WHERE business_id=?',
    [bizId]
  );
  return cfg?.nutrition_consultation_service_id || null;
}

async function ensureNutritionConsultationSetup(db, bizId, nutritionist) {
  if (!nutritionist?.id || !nutritionist?.full_name) {
    return { serviceId: null, staffId: null };
  }

  let staffId = nutritionist.staff_id || null;
  if (staffId) {
    const [[staff]] = await db.query(
      'SELECT id FROM staff WHERE id=? AND business_id=?',
      [staffId, bizId]
    );
    if (!staff) staffId = null;
  }

  if (!staffId) {
    staffId = uuidv4();
    await db.query(
      `INSERT INTO staff (id, business_id, full_name, role, color_hex, is_active, is_nutritionist)
       VALUES (?,?,?,?,?,1,1)`,
      [staffId, bizId, nutritionist.full_name, 'Διατροφολόγος', '#0d9488']
    );
    await db.query('UPDATE nutritionists SET staff_id=? WHERE id=?', [staffId, nutritionist.id]);
  } else {
    await db.query(
      'UPDATE staff SET full_name=?, is_active=?, is_nutritionist=1 WHERE id=? AND business_id=?',
      [nutritionist.full_name, nutritionist.is_active ? 1 : 0, staffId, bizId]
    );
  }

  let serviceId = await getConsultationServiceId(db, bizId);
  if (serviceId) {
    const [[svc]] = await db.query(
      'SELECT id FROM services WHERE id=? AND business_id=?',
      [serviceId, bizId]
    );
    if (!svc) serviceId = null;
  }

  if (!serviceId) {
    const [[existing]] = await db.query(
      `SELECT id FROM services
       WHERE business_id=? AND category=? AND is_active=1
       ORDER BY name ASC LIMIT 1`,
      [bizId, CONSULTATION_CATEGORY],
    );
    if (existing) {
      serviceId = existing.id;
      await db.query(
        'UPDATE business_configs SET nutrition_consultation_service_id=? WHERE business_id=?',
        [serviceId, bizId],
      );
    }
  }

  if (!serviceId) {
    serviceId = uuidv4();
    await db.query(
      `INSERT INTO services
        (id, business_id, name, description, duration_mins, price_cents, category, hide_staff_selection, slot_label_mode, is_active)
       VALUES (?,?,?,?,?,?,?,?,?,1)`,
      [
        serviceId, bizId, CONSULTATION_SERVICE_NAME,
        'Κράτηση για μέτρηση ή συνεδρία με τον διατροφολόγο',
        DEFAULT_DURATION_MINS, 0, CONSULTATION_CATEGORY, 1, 'time_only',
      ]
    );
    await db.query(
      'UPDATE business_configs SET nutrition_consultation_service_id=? WHERE business_id=?',
      [serviceId, bizId]
    );
  }

  await db.query(
    'INSERT IGNORE INTO staff_services (staff_id, service_id) VALUES (?,?)',
    [staffId, serviceId]
  );

  await ensureDefaultConsultationSchedules(
    db, bizId, serviceId, staffId, nutritionist.location_id || null,
  );

  return { serviceId, staffId };
}

async function resolveConsultationServiceId(dbConn, bizId) {
  let serviceId = await getConsultationServiceId(dbConn, bizId);
  if (serviceId) {
    const [[svc]] = await dbConn.query(
      'SELECT id FROM services WHERE id=? AND business_id=? AND is_active=1',
      [serviceId, bizId],
    );
    if (svc) return serviceId;
  }

  const [[fallback]] = await dbConn.query(
    `SELECT id FROM services
     WHERE business_id=? AND category=? AND is_active=1
     ORDER BY name LIMIT 1`,
    [bizId, CONSULTATION_CATEGORY],
  );
  if (!fallback?.id) return null;

  await dbConn.query(
    'UPDATE business_configs SET nutrition_consultation_service_id=? WHERE business_id=?',
    [fallback.id, bizId],
  );
  return fallback.id;
}

async function findConsultationMembership(db, userId, bizId) {
  const [[row]] = await db.query(
    `SELECT id, plan_id, service_id, total_sessions, used_sessions,
            (total_sessions - used_sessions) AS remaining_sessions, valid_until
     FROM user_memberships
     WHERE user_id=? AND business_id=? AND service_category=?
       AND valid_until >= CURDATE()
       AND COALESCE(membership_status, 'active') NOT IN ('trial', 'cancelled')
       AND (total_sessions >= 9999 OR (total_sessions - used_sessions) > 0)
     ORDER BY valid_until DESC
     LIMIT 1`,
    [userId, bizId, CONSULTATION_CATEGORY],
  );
  if (!row) return null;

  const serviceId = await resolveConsultationServiceId(db, bizId);
  if (serviceId && row.service_id !== serviceId) {
    await db.query('UPDATE user_memberships SET service_id=? WHERE id=?', [serviceId, row.id]);
    row.service_id = serviceId;
  }
  return row;
}

async function ensureConsultationCreditsFromNutritionPlan(conn, bizId, userId) {
  let membership = await findConsultationMembership(conn, userId, bizId);
  if (membership) return membership;

  const [[program]] = await conn.query(
    `SELECT m.valid_from, m.valid_until, p.*
     FROM user_memberships m
     JOIN business_plans p ON p.id = m.plan_id AND p.plan_type = 'nutrition'
     WHERE m.user_id=? AND m.business_id=?
       AND (m.valid_until IS NULL OR m.valid_until >= CURDATE())
       AND COALESCE(m.membership_status, 'active') NOT IN ('trial', 'cancelled')
     ORDER BY m.valid_until DESC
     LIMIT 1`,
    [userId, bizId],
  );
  if (!program?.nutrition_includes_consultations) return null;

  await grantConsultationCredits(conn, {
    bizId,
    userId,
    plan: program,
    valid_from: program.valid_from,
    valid_until: program.valid_until,
    notes: `${program.name} — επισκέψεις`,
  });
  return findConsultationMembership(conn, userId, bizId);
}

async function grantConsultationCredits(conn, {
  bizId, userId, plan, valid_from, valid_until, notes,
}) {
  if (!plan?.nutrition_includes_consultations) return null;

  const serviceId = await resolveConsultationServiceId(conn, bizId);
  if (!serviceId) return null;

  const sessions = plan.nutrition_consultation_sessions || 4;
  const [existing] = await conn.query(
    `SELECT id FROM user_memberships
     WHERE user_id=? AND business_id=? AND service_category=?
       AND valid_until >= CURDATE()
       AND COALESCE(membership_status, 'active') NOT IN ('trial', 'cancelled')`,
    [userId, bizId, CONSULTATION_CATEGORY]
  );

  const label = notes || `${sessions} ${sessions === 1 ? 'επίσκεψη' : 'επισκέψεις'} με διατροφολόγο`;

  if (existing.length) {
    await conn.query(
      `UPDATE user_memberships SET
        plan_id=NULL, total_sessions=?, used_sessions=0, valid_from=?, valid_until=?, notes=?
       WHERE id=?`,
      [sessions, valid_from, valid_until, label, existing[0].id]
    );
    return existing[0].id;
  }

  const id = uuidv4();
  await conn.query(
    `INSERT INTO user_memberships
      (id, user_id, business_id, plan_id, service_id, service_category, total_sessions, used_sessions, valid_from, valid_until, notes)
     VALUES (?,?,?,NULL,?,?,?,0,?,?,?)`,
    [id, userId, bizId, serviceId, CONSULTATION_CATEGORY, sessions, valid_from, valid_until, label]
  );
  return id;
}

function consultationCreditsSummary(membership) {
  if (!membership) {
    return { has_access: false, remaining: 0, total: 0, is_unlimited: false, can_book: false };
  }
  const isUnlimited = membership.total_sessions >= 9999;
  const remaining = isUnlimited
    ? 9999
    : Math.max(0, membership.total_sessions - membership.used_sessions);
  return {
    has_access: true,
    remaining,
    total: membership.total_sessions,
    used: membership.used_sessions,
    is_unlimited: isUnlimited,
    can_book: isUnlimited || remaining > 0,
    valid_until: membership.valid_until,
  };
}

module.exports = {
  CONSULTATION_SERVICE_NAME,
  CONSULTATION_CATEGORY,
  getConsultationServiceId,
  resolveConsultationServiceId,
  ensureNutritionConsultationSetup,
  ensureConsultationCreditsFromNutritionPlan,
  findConsultationMembership,
  grantConsultationCredits,
  consultationCreditsSummary,
  isNutritionConsultationService,
  ensureDefaultConsultationSchedules,
  findPendingConsultationBooking,
  findUpcomingConfirmedConsultationBooking,
  hasActiveConsultationBooking,
  listActiveNutritionists,
  getNutritionistById,
  resolveNutritionistStaffId,
};
