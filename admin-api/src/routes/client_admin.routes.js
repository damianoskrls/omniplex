// ============================================================
// FILE: src/routes/client_admin.routes.js
// Endpoints for the business owner (gym/barber/salon admin)
// Separate from Master Admin — scoped to one business_id
// ============================================================

const express = require('express');
const bcrypt  = require('bcryptjs');
const jwt     = require('jsonwebtoken');
const path    = require('path');
const fs      = require('fs');
const multer  = require('multer');
const { v4: uuidv4 } = require('uuid');
const db      = require('../db');
const {
  computeAvailableSlots,
  buildSlotsPayload,
  assertSlotCapacity,
  assertStaffAvailable,
  findStaffForSlot,
} = require('../lib/slots');
const { notifyWaitlistOnCancel, convertWaitlistEntry, cancelWaitlistEntry } = require('../lib/waitlist');
const { createAdminNotification } = require('../lib/notifications');
const {
  previewStaffDeletion,
  deleteStaffWithReassignment,
} = require('../lib/staff_reassignment');
const { GYM_STAFF_WHERE, GYM_STAFF_WHERE_ALIAS } = require('../lib/gym_staff');
const {
  listLocations,
  replaceStaffLocations,
  replaceUserLocations,
  replaceServiceLocations,
  getStaffLocationIds,
  getUserLocationIds,
  getServiceLocationIds,
  ensureDefaultLocation,
  getDefaultLocationId,
} = require('../lib/locations');
const { createOneBooking, chargeBookingMembershipOnConfirm, refundBookingMembershipOnRemove } = require('../lib/create_booking');
const { sqlGymServiceCategories } = require('../lib/gym_services');
const { deleteBookingForBusiness } = require('../lib/booking_delete');
const { listBookableGymClients, listClientGymBookingOptions } = require('../lib/bookable_gym_clients');
const {
  getConsultationServiceId,
  resolveConsultationServiceId,
  ensureNutritionConsultationSetup,
  grantConsultationCredits,
  findConsultationMembership,
  consultationCreditsSummary,
  ensureConsultationCreditsFromNutritionPlan,
  findPendingConsultationBooking,
  listActiveNutritionists,
  getNutritionistById,
} = require('../lib/nutrition_consultation');
const {
  buildServicePlanName,
  normalizePlanSessions,
  buildNutritionPlanName,
  defaultValidUntil,
} = require('../lib/plan_names');
const { planSessionsToMembershipTotal, sqlActiveMembershipCredit } = require('../lib/membership_sessions');
const {
  enrichMembershipLifecycle,
  computeRenewalPeriod,
  getGracePeriodDays,
  bookingBlockMessage,
  canBookWithMembership,
} = require('../lib/membership_lifecycle');
const {
  normalizePromoRules,
  parsePromoRules,
  evaluateNutritionPromo,
  nutritionIncludesSummary,
} = require('../lib/nutrition_plans');
const { parseDateTimeParts } = require('../lib/datetime');
const {
  MEAL_TYPE_LABELS,
  PORTION_UNITS,
  normalizeMealPlanPayload,
  mondayOfWeek,
  formatDateOnly,
  fetchMealPlanForDate,
  fetchMealPlanTemplate,
  listMealPlanVersions,
  fetchMealPlanVersionById,
  listProgramTemplates,
  fetchProgramTemplate,
  createProgramTemplate,
  updateProgramTemplate,
  deleteProgramTemplate,
  applyProgramTemplateToClient,
  insertMealPlanSlotItems,
  buildSmartShoppingList,
  fetchFoodLogsForDate,
  fetchNutritionGoals,
  fetchNutritionMeasurements,
  fetchNutritionProgress,
  insertNutritionMeasurement,
  parseLocalDate,
  dayOfWeekFromDate,
  normalizeHeight,
  normalizeBodyFat,
} = require('../lib/nutrition');
const {
  deriveStatus,
  mapPaymentRow,
  computePeriodEnd,
  buildPaymentDescription,
  computePaymentTotal,
  paymentBalance,
  assertNoDuplicatePayment,
  toDateString,
  toBillingMonthDate,
  formatBillingMonth,
} = require('../lib/payments');
const { createUserNotification } = require('../lib/user_notifications');
const { getUserStats } = require('../lib/loyalty');
const { mountTrainerPortal } = require('./trainer_portal.routes');
const messagesStaffRoutes = require('./messages_staff.routes');
const {
  enrichClientProfile,
  normalizeFitnessGoal,
  normalizeWeight,
  FITNESS_GOAL_LABELS,
} = require('../lib/client_profile');
const { sqlActiveClients, sqlTrashClients } = require('../lib/client_soft_delete');
const { syncRoomFromId } = require('../lib/rooms');
const {
  parseReportFilters,
  getReportFilterOptions,
  getReportsOverview,
} = require('../lib/reports');

const router = express.Router();

const BOOKING_ENRICHED_SELECT = `
  SELECT b.id, b.user_id, b.service_id, b.staff_id, b.location_id, b.staff_assignment_status,
         b.starts_at, b.ends_at, b.status, b.source, b.is_trial,
         b.attendance_confirmed, b.attendance_confirmed_at,
         b.health_calories_kcal, b.health_duration_mins, b.health_avg_heart_rate,
         b.health_activity_label, b.health_source,
         COALESCE(u.full_name, IF(b.is_trial=1,'— Χωρίς πελάτη —', NULL)) AS user_name, u.phone AS user_phone,
         st.full_name AS staff_name, st.color_hex, st.avatar_url AS staff_avatar_url,
         COALESCE(sv.name, IF(b.is_trial=1,'Δοκιμαστικό', NULL)) AS service_name, sv.duration_mins, sv.category AS service_category,
         sv.image_url AS service_image_url,
         loc.name AS location_name,
         COALESCE(b.room_id, sss.room_id) AS room_id,
         COALESCE(rm.name, sss.room_name) AS room_name,
         rm.photo_url AS room_photo_url,
         rm.short_info AS room_short_info,
         sss.label AS schedule_label, sss.icon_key
`;

const BOOKING_ENRICHED_FROM = `
  FROM bookings b
  LEFT JOIN users u ON u.id = b.user_id
  LEFT JOIN staff st ON st.id = b.staff_id
  LEFT JOIN services sv ON sv.id = b.service_id
  LEFT JOIN locations loc ON loc.id = b.location_id
  LEFT JOIN service_slot_schedules sss ON sss.service_id = b.service_id
    AND sss.business_id = b.business_id
    AND sss.weekday = WEEKDAY(b.starts_at)
    AND sss.start_time = TIME(b.starts_at)
    AND sss.is_active = 1
    AND (sss.location_id IS NULL OR sss.location_id = b.location_id)
    AND (sss.staff_id IS NULL OR sss.staff_id = b.staff_id)
  LEFT JOIN rooms rm ON rm.id = COALESCE(b.room_id, sss.room_id)
`;

const { r2Multer } = require('../lib/r2_upload');

const IMAGE_MIMES = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif'];

const staffPhotoUpload = r2Multer({
  keyFn: (req, file) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    return `uploads/${req.admin.businessId}/staff/${req.params.id}${ext}`;
  },
  allowedMimes: IMAGE_MIMES,
  maxSizeMb: 5,
});

const servicePhotoUpload = r2Multer({
  keyFn: (req, file) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    return `uploads/${req.admin.businessId}/services/${req.params.id}${ext}`;
  },
  allowedMimes: [...IMAGE_MIMES, 'image/svg+xml'],
  maxSizeMb: 5,
});

const serviceSvgUpload = r2Multer({
  keyFn: (req, file) => `uploads/${req.admin.businessId}/services/svg/${req.params.id}_icon.svg`,
  allowedMimes: ['image/svg+xml'],
  maxSizeMb: 2,
});

const notificationImageUpload = r2Multer({
  keyFn: (req, file) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    return `uploads/${req.admin.businessId}/notifications/${uuidv4()}${ext}`;
  },
  allowedMimes: IMAGE_MIMES,
  maxSizeMb: 5,
});

const nutritionImageUpload = r2Multer({
  keyFn: (req, file) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    return `uploads/${req.admin.businessId}/nutrition/${uuidv4()}${ext}`;
  },
  allowedMimes: IMAGE_MIMES,
  maxSizeMb: 8,
});

const roomPhotoUpload = r2Multer({
  keyFn: (req, file) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    return `uploads/${req.admin.businessId}/rooms/${req.params.id}${ext}`;
  },
  allowedMimes: IMAGE_MIMES,
  maxSizeMb: 5,
});

// ── Auth middleware scoped to business ────────────────────────
function requireClientAdmin(req, res, next) {
  const header = req.headers['authorization'];
  if (!header) return res.status(401).json({ error: 'No token' });
  const token = header.startsWith('Bearer ') ? header.slice(7) : header;
  try {
    const d = jwt.verify(token, process.env.JWT_SECRET);
    if (d.role !== 'client_admin') return res.status(403).json({ error: 'Not a business admin' });
    req.admin = d;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

function requireNutritionStaff(req, res, next) {
  const header = req.headers['authorization'];
  if (!header) return res.status(401).json({ error: 'No token' });
  const token = header.startsWith('Bearer ') ? header.slice(7) : header;
  try {
    const d = jwt.verify(token, process.env.JWT_SECRET);
    if (d.role !== 'client_admin' && d.role !== 'nutritionist') {
      return res.status(403).json({ error: 'Not authorized' });
    }
    req.admin = d;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

// ============================================================
// POST /api/client-admin/login
// Body: { email, password }
// For now: uses owner_email from businesses table + stored password
// ============================================================
async function businessLoginPayload(businessId, fallbackName, slug, type) {
  const [[cfg]] = await db.query(
    `SELECT app_name, logo_url,
            primary_color, secondary_color, accent_color,
            background_color, surface_color, font_family,
            feature_online_booking, feature_loyalty_points,
            feature_memberships, feature_waitlist, feature_nutrition
     FROM business_configs WHERE business_id = ? LIMIT 1`,
    [businessId],
  );
  const displayName = (cfg?.app_name || fallbackName || '').trim();
  const isGym = !type || type === 'gym';
  return {
    id: businessId,
    name: displayName,
    slug,
    type: type || 'gym',
    logo_url: cfg?.logo_url || null,
    primary_color:    cfg?.primary_color    || '#B8F55E',
    secondary_color:  cfg?.secondary_color  || '#7C5CFC',
    accent_color:     cfg?.accent_color     || '#FF6D00',
    background_color: cfg?.background_color || '#0F0F12',
    surface_color:    cfg?.surface_color    || '#1A1A22',
    font_family:      cfg?.font_family      || 'Inter',
    feature_programs: isGym ? 1 : 0,
    feature_trainers: isGym ? 1 : 0,
    feature_online_booking: cfg?.feature_online_booking ?? 1,
    feature_loyalty_points: cfg?.feature_loyalty_points ?? 0,
    feature_memberships: cfg?.feature_memberships ?? 1,
    feature_waitlist: cfg?.feature_waitlist ?? 0,
    feature_nutrition: cfg?.feature_nutrition ?? 0,
  };
}

router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) return res.status(400).json({ error: 'Email and password required' });

  try {
    // Find business by owner email
    const [rows] = await db.query(`
      SELECT b.id AS business_id, b.name, b.slug, b.business_type,
             p.password_hash
      FROM businesses b
      LEFT JOIN client_admin_passwords p ON p.business_id = b.id
      WHERE b.owner_email = ? AND b.is_active = 1
    `, [email]);

    if (rows.length) {
      const biz = rows[0];
      const hash  = biz.password_hash || await bcrypt.hash('admin123', 10);
      const valid = await bcrypt.compare(password, hash);
      if (!valid) return res.status(401).json({ error: 'Invalid credentials' });

      const token = jwt.sign(
        { businessId: biz.business_id, email, role: 'client_admin', name: biz.name },
        process.env.JWT_SECRET,
        { expiresIn: '12h' }
      );

      return res.json({
        token,
        role: 'client_admin',
        business: await businessLoginPayload(biz.business_id, biz.name, biz.slug, biz.business_type),
      });
    }

    const [nutRows] = await db.query(`
      SELECT n.id AS nutritionist_id, n.business_id, n.full_name, n.email,
             p.password_hash, b.name, b.slug, b.business_type
      FROM nutritionists n
      JOIN businesses b ON b.id = n.business_id
      LEFT JOIN nutritionist_passwords p ON p.nutritionist_id = n.id
      WHERE n.email = ? AND n.is_active = 1 AND b.is_active = 1
    `, [email]);

    if (!nutRows.length) {
      const [trainerRows] = await db.query(`
        SELECT s.id AS staff_id, s.business_id, s.full_name, s.portal_email,
               p.password_hash, b.name, b.slug, b.business_type
        FROM staff s
        JOIN businesses b ON b.id = s.business_id
        LEFT JOIN staff_passwords p ON p.staff_id = s.id
        WHERE s.portal_email = ? AND s.is_active = 1 AND b.is_active = 1
      `, [email]);

      if (!trainerRows.length) return res.status(401).json({ error: 'Invalid credentials' });

      const trainer = trainerRows[0];
      if (!trainer.password_hash) {
        return res.status(401).json({ error: 'Invalid credentials' });
      }
      const trainerValid = await bcrypt.compare(password, trainer.password_hash);
      if (!trainerValid) return res.status(401).json({ error: 'Invalid credentials' });

      const token = jwt.sign(
        {
          businessId: trainer.business_id,
          email,
          role: 'trainer',
          name: trainer.full_name,
          staffId: trainer.staff_id,
        },
        process.env.JWT_SECRET,
        { expiresIn: '12h' },
      );

      return res.json({
        token,
        role: 'trainer',
        business: await businessLoginPayload(
          trainer.business_id,
          trainer.name,
          trainer.slug,
          trainer.business_type,
        ),
      });
    }

    const nut = nutRows[0];
    const nutHash = nut.password_hash || await bcrypt.hash('nutrition123', 10);
    const nutValid = await bcrypt.compare(password, nutHash);
    if (!nutValid) return res.status(401).json({ error: 'Invalid credentials' });

    const token = jwt.sign(
      {
        businessId: nut.business_id,
        email,
        role: 'nutritionist',
        name: nut.full_name,
        nutritionistId: nut.nutritionist_id,
      },
      process.env.JWT_SECRET,
      { expiresIn: '12h' }
    );

    return res.json({
      token,
      role: 'nutritionist',
      business: await businessLoginPayload(nut.business_id, nut.name, nut.slug, nut.business_type),
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// GET /api/client-admin/dashboard
// ============================================================
router.get('/dashboard', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  try {
    const [[todayBookings]] = await db.query(
      "SELECT COUNT(*) AS total FROM bookings WHERE business_id=? AND DATE(starts_at)=CURDATE() AND status NOT IN ('cancelled','no_show')",
      [bizId]
    );
    const [[monthBookings]] = await db.query(
      `SELECT COUNT(*) AS total FROM bookings
       WHERE business_id=? AND MONTH(starts_at)=MONTH(NOW()) AND YEAR(starts_at)=YEAR(NOW())
         AND status NOT IN ('cancelled', 'no_show')`,
      [bizId]
    );
    const [[clients]] = await db.query(
      `SELECT COUNT(*) AS total FROM users WHERE business_id=? AND ${sqlActiveClients()}`,
      [bizId]
    );
    const [[pendingClients]] = await db.query(
      `SELECT COUNT(*) AS total FROM users WHERE business_id=? AND account_status='pending' AND ${sqlActiveClients()}`,
      [bizId]
    );
    const [[activeMembers]] = await db.query(
      `SELECT COUNT(DISTINCT m.user_id) AS total
       FROM user_memberships m
       JOIN users u ON u.id = m.user_id AND u.business_id = m.business_id
       WHERE m.business_id = ?
         AND m.valid_until >= CURDATE()
         AND ${sqlActiveMembershipCredit('m')}
         AND u.deleted_at IS NULL`,
      [bizId]
    );
    const [[pendingBookings]] = await db.query(
      "SELECT COUNT(*) AS total FROM bookings WHERE business_id=? AND status='pending' AND starts_at > NOW()",
      [bizId]
    );
    const [[tomorrowBookings]] = await db.query(
      "SELECT COUNT(*) AS total FROM bookings WHERE business_id=? AND DATE(starts_at)=DATE_ADD(CURDATE(), INTERVAL 1 DAY) AND status NOT IN ('cancelled','no_show')",
      [bizId]
    );

    const [todaySessions] = await db.query(
      `SELECT b.id, b.service_id, b.staff_id, b.location_id, b.starts_at, b.ends_at, b.status,
              u.full_name AS user_name, sv.name AS service_name,
              COALESCE(st.full_name, 'Χωρίς γυμναστή') AS staff_name,
              COALESCE(st.color_hex, '#76C043') AS color_hex,
              loc.name AS location_name
       FROM bookings b
       JOIN users u ON u.id = b.user_id
       JOIN services sv ON sv.id = b.service_id
       LEFT JOIN staff st ON st.id = b.staff_id
       LEFT JOIN locations loc ON loc.id = b.location_id
       WHERE b.business_id = ? AND DATE(b.starts_at) = CURDATE()
         AND b.status NOT IN ('cancelled', 'no_show')
       ORDER BY b.starts_at ASC
       LIMIT 15`,
      [bizId],
    );

    const [recentClients] = await db.query(
      `SELECT id, full_name, email, phone, created_at, account_status
       FROM users WHERE business_id = ?
       ORDER BY created_at DESC LIMIT 6`,
      [bizId],
    );

    const [weekRows] = await db.query(
      `SELECT DATE_FORMAT(DATE(starts_at), '%Y-%m-%d') AS day, COUNT(*) AS count
       FROM bookings
       WHERE business_id = ? AND DATE(starts_at) >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)
         AND DATE(starts_at) <= CURDATE()
         AND status NOT IN ('cancelled', 'no_show')
       GROUP BY DATE_FORMAT(DATE(starts_at), '%Y-%m-%d')
       ORDER BY day ASC`,
      [bizId],
    );

    const [[dates]] = await db.query(
      `SELECT DATE_FORMAT(CURDATE(), '%Y-%m-%d') AS today,
              DATE_FORMAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY), '%Y-%m-%d') AS tomorrow,
              DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 6 DAY), '%Y-%m-%d') AS week_start`,
    );
    const weekMap = Object.fromEntries(weekRows.map((r) => [r.day, Number(r.count)]));
    const [dayRows] = await db.query(
      `SELECT DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL seq DAY), '%Y-%m-%d') AS day
       FROM (
         SELECT 6 AS seq UNION SELECT 5 UNION SELECT 4 UNION SELECT 3
         UNION SELECT 2 UNION SELECT 1 UNION SELECT 0
       ) s
       ORDER BY day ASC`,
    );
    const weekChart = dayRows.map((r) => ({ day: r.day, count: Number(weekMap[r.day] || 0) }));

    const [servicesToday] = await db.query(
      `SELECT sv.name AS service_name, COUNT(*) AS count
       FROM bookings b
       JOIN services sv ON sv.id = b.service_id
       WHERE b.business_id = ? AND DATE(b.starts_at) = CURDATE()
         AND b.status NOT IN ('cancelled', 'no_show')
       GROUP BY sv.id, sv.name
       ORDER BY count DESC
       LIMIT 6`,
      [bizId],
    );

    const [[waitlistPending]] = await db.query(
      `SELECT COUNT(*) AS total FROM waitlist_entries
       WHERE business_id = ? AND status IN ('waiting', 'offered')
         AND DATE(starts_at) >= CURDATE()`,
      [bizId],
    );

    const [waitlistToday] = await db.query(
      `SELECT w.id, w.starts_at, w.status, w.position, u.full_name AS user_name,
              sv.name AS service_name
       FROM waitlist_entries w
       JOIN users u ON u.id = w.user_id
       JOIN services sv ON sv.id = w.service_id
       WHERE w.business_id = ? AND status IN ('waiting', 'offered')
         AND DATE(w.starts_at) = CURDATE()
       ORDER BY w.starts_at ASC, w.position ASC
       LIMIT 8`,
      [bizId],
    );

    return res.json({
      today_bookings: Number(todayBookings.total),
      month_bookings: Number(monthBookings.total),
      total_clients: Number(clients.total),
      pending_clients: Number(pendingClients.total),
      active_members: Number(activeMembers.total),
      pending_bookings: Number(pendingBookings.total),
      tomorrow_bookings: Number(tomorrowBookings.total),
      dates,
      today_sessions: todaySessions,
      recent_clients: recentClients.map(enrichClientProfile),
      week_chart: weekChart,
      services_today: servicesToday.map((r) => ({
        service_name: r.service_name,
        count: Number(r.count),
      })),
      waitlist_pending: Number(waitlistPending?.total || 0),
      waitlist_today: waitlistToday,
    });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// GET /api/client-admin/dashboard-extras
// App installs, messages unread, marketplace pending orders + revenue
router.get('/dashboard-extras', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  try {
    const [[appTotal]] = await db.query(
      'SELECT COUNT(DISTINCT user_id) AS total FROM device_tokens WHERE business_id=?',
      [bizId]
    );
    const [appByPlatform] = await db.query(
      'SELECT platform, COUNT(DISTINCT user_id) AS cnt FROM device_tokens WHERE business_id=? GROUP BY platform',
      [bizId]
    );
    const [[messagesUnread]] = await db.query(
      `SELECT COUNT(*) AS total FROM messages m
       JOIN message_threads mt ON mt.id = m.thread_id
       WHERE mt.business_id=? AND m.sender_type='customer' AND m.is_read=0`,
      [bizId]
    ).catch(() => [[{ total: 0 }]]);
    const [recentMessages] = await db.query(
      `SELECT mt.id AS thread_id, u.full_name, u.phone,
              m.body, m.created_at, m.is_read
       FROM message_threads mt
       JOIN users u ON u.id = mt.user_id
       JOIN messages m ON m.id = (
         SELECT id FROM messages WHERE thread_id=mt.id ORDER BY created_at DESC LIMIT 1
       )
       WHERE mt.business_id=?
       ORDER BY m.created_at DESC LIMIT 5`,
      [bizId]
    ).catch(() => [[]]).then(r => r[0]);
    const [[ordersPending]] = await db.query(
      "SELECT COUNT(*) AS total FROM orders WHERE business_id=? AND status IN ('pending','paid')",
      [bizId]
    ).catch(() => [[{ total: 0 }]]);
    const [recentOrders] = await db.query(
      `SELECT o.id, o.status, o.total_cents, o.created_at,
              o.customer_name, o.customer_phone
       FROM orders WHERE business_id=?
       ORDER BY created_at DESC LIMIT 5`,
      [bizId]
    ).catch(() => [[]]).then(r => r[0]);
    const [[ordersRevenue]] = await db.query(
      "SELECT COALESCE(SUM(total_cents),0) AS total FROM orders WHERE business_id=? AND status NOT IN ('cancelled','refunded') AND MONTH(created_at)=MONTH(NOW())",
      [bizId]
    ).catch(() => [[{ total: 0 }]]);

    const platforms = {};
    for (const r of appByPlatform) platforms[r.platform] = Number(r.cnt);

    res.json({
      app: { total: Number(appTotal.total), ios: platforms.ios || 0, android: platforms.android || 0 },
      messages: { unread: Number(messagesUnread.total), recent: recentMessages || [] },
      marketplace: {
        pending_orders: Number(ordersPending.total),
        month_revenue_cents: Number(ordersRevenue.total),
        recent_orders: recentOrders || [],
      },
    });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.get('/reports', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  try {
    const filters = parseReportFilters(req.query);
    const [overview, filterOptions] = await Promise.all([
      getReportsOverview(db, bizId, filters),
      getReportFilterOptions(db, bizId),
    ]);
    return res.json({ ...overview, filter_options: filterOptions });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// GET /api/client-admin/search?q= — Quick global search
// ============================================================
router.get('/search', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const q = (req.query.q || '').trim();
  if (!q) return res.json([]);
  const like = `%${q}%`;
  try {
    const [rows] = await db.query(`
      SELECT u.id, u.full_name, u.phone, u.email, u.account_status,
             COUNT(DISTINCT m.id) AS active_packages
      FROM users u
      LEFT JOIN user_memberships m ON m.user_id = u.id AND m.business_id = u.business_id
                                   AND m.membership_status IN ('active','trial')
      WHERE u.business_id = ? AND u.deleted_at IS NULL
        AND (u.full_name LIKE ? OR u.phone LIKE ? OR u.email LIKE ?)
      GROUP BY u.id
      ORDER BY u.full_name
      LIMIT 8
    `, [bizId, like, like, like]);
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// GET /api/client-admin/clients — All clients with credits
// ============================================================
router.get('/clients', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { status, view } = req.query;
  const inTrash = view === 'trash';
  try {
    let q = `
      SELECT
        u.id, u.full_name, u.email, u.phone, u.loyalty_points, u.created_at,
        u.account_status, u.deleted_at, u.notes, u.referred_by_user_id, u.date_of_birth, u.weight_kg,
        u.fitness_goal, u.trainer_notes,
        ref.full_name AS referred_by_name,
        COUNT(DISTINCT b.id)  AS total_bookings,
        COUNT(DISTINCT m.id)  AS active_packages
      FROM users u
      LEFT JOIN users ref ON ref.id = u.referred_by_user_id
      LEFT JOIN bookings b ON b.user_id = u.id AND b.business_id = u.business_id
      LEFT JOIN user_memberships m ON m.user_id = u.id AND m.business_id = u.business_id
                                   AND m.valid_until >= CURDATE()
                                   AND ${sqlActiveMembershipCredit('m')}
      WHERE u.business_id = ?
        AND ${inTrash ? sqlTrashClients('u') : sqlActiveClients('u')}
    `;
    const params = [bizId];
    if (status && !inTrash) {
      q += ' AND u.account_status = ?';
      params.push(status);
    }
    q += `
      GROUP BY u.id, u.account_status, u.deleted_at, u.notes, u.referred_by_user_id, u.date_of_birth, u.weight_kg,
               u.fitness_goal, u.trainer_notes, ref.full_name
      ORDER BY
        ${inTrash ? 'u.deleted_at DESC' : `
        CASE u.account_status WHEN 'pending' THEN 0 WHEN 'active' THEN 1 ELSE 2 END,
        u.full_name`}
    `;
    const [clients] = await db.query(q, params);
    return res.json(clients.map(enrichClientProfile));
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// GET /api/client-admin/clients/:userId
// ============================================================
router.get('/clients/:userId', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  try {
    const [[client]] = await db.query(`
      SELECT
        u.id, u.full_name, u.email, u.phone, u.loyalty_points, u.created_at,
        u.account_status, u.deleted_at, u.notes, u.referred_by_user_id, u.date_of_birth, u.weight_kg,
        u.fitness_goal, u.trainer_notes,
        ref.full_name AS referred_by_name
      FROM users u
      LEFT JOIN users ref ON ref.id = u.referred_by_user_id
      WHERE u.id = ? AND u.business_id = ?
    `, [req.params.userId, bizId]);
    if (!client) return res.status(404).json({ error: 'Ο πελάτης δεν βρέθηκε' });
    return res.json(enrichClientProfile(client));
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// PATCH /api/client-admin/clients/:userId — client profile
// ============================================================
router.patch('/clients/:userId', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const {
    full_name,
    phone,
    notes,
    referred_by_user_id,
    date_of_birth,
    weight_kg,
    fitness_goal,
    trainer_notes,
  } = req.body;

  try {
    const [[existing]] = await db.query(
      'SELECT id FROM users WHERE id = ? AND business_id = ?',
      [req.params.userId, bizId]
    );
    if (!existing) return res.status(404).json({ error: 'Ο πελάτης δεν βρέθηκε' });

    if (referred_by_user_id) {
      if (referred_by_user_id === req.params.userId) {
        return res.status(400).json({ error: 'Ο πελάτης δεν μπορεί να προτείνει τον εαυτό του' });
      }
      const [[referrer]] = await db.query(
        'SELECT id FROM users WHERE id = ? AND business_id = ?',
        [referred_by_user_id, bizId]
      );
      if (!referrer) return res.status(400).json({ error: 'Ο συσχετιζόμενος πελάτης δεν βρέθηκε' });
    }

    const normalizedWeight = normalizeWeight(weight_kg);
    const normalizedGoal = normalizeFitnessGoal(fitness_goal);

    const fieldMap = {
      full_name: full_name !== undefined ? (full_name?.trim() || null) : undefined,
      phone: phone !== undefined ? (phone?.trim() || null) : undefined,
      notes: notes !== undefined ? (notes || null) : undefined,
      referred_by_user_id: referred_by_user_id !== undefined ? (referred_by_user_id || null) : undefined,
      date_of_birth: date_of_birth !== undefined ? (date_of_birth || null) : undefined,
      weight_kg: normalizedWeight,
      fitness_goal: normalizedGoal,
      trainer_notes: trainer_notes !== undefined ? (trainer_notes || null) : undefined,
    };

    const updates = [];
    const params = [];
    for (const [col, val] of Object.entries(fieldMap)) {
      if (val !== undefined) {
        updates.push(`${col} = ?`);
        params.push(val);
      }
    }

    if (!updates.length) {
      return res.status(400).json({ error: 'Δεν δόθηκαν πεδία για ενημέρωση' });
    }

    params.push(req.params.userId, bizId);
    await db.query(
      `UPDATE users SET ${updates.join(', ')} WHERE id = ? AND business_id = ?`,
      params
    );

    const [[updated]] = await db.query(`
      SELECT u.*, ref.full_name AS referred_by_name
      FROM users u
      LEFT JOIN users ref ON ref.id = u.referred_by_user_id
      WHERE u.id = ? AND u.business_id = ?
    `, [req.params.userId, bizId]);

    return res.json(enrichClientProfile(updated));
  } catch (err) {
    return res.status(400).json({ error: err.message });
  }
});

// PATCH /api/client-admin/clients/:userId/status
// GET /api/client-admin/clients/pending — registration requests awaiting approval
router.get('/clients/pending', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  try {
    const [rows] = await db.query(
      `SELECT id, full_name, email, phone, created_at
       FROM users WHERE business_id = ? AND account_status = 'pending' AND deleted_at IS NULL
       ORDER BY created_at DESC`,
      [bizId]
    );
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/client-admin/clients/:userId/approve — approve + SMS
router.post('/clients/:userId/approve', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { sendSms } = require('../lib/sms');
  try {
    const [[user]] = await db.query(
      'SELECT id, full_name, phone, account_status FROM users WHERE id = ? AND business_id = ?',
      [req.params.userId, bizId]
    );
    if (!user) return res.status(404).json({ error: 'Ο πελάτης δεν βρέθηκε' });
    if (user.account_status === 'active') return res.json({ ok: true, already_active: true });

    await db.query(
      'UPDATE users SET account_status = ? WHERE id = ?',
      ['active', user.id]
    );

    // Send SMS if phone exists — include PIN hint (last 4 digits of phone)
    if (user.phone) {
      const [[cfg]] = await db.query(
        'SELECT app_name FROM business_configs WHERE business_id = ? LIMIT 1',
        [bizId]
      );
      const gymName = cfg?.app_name || 'Το γυμναστήριό σας';
      const normalised = String(user.phone).replace(/[\s\-().]/g, '');
      const pinHint = normalised.slice(-4);
      await sendSms(
        user.phone,
        `${gymName}: O logarismos sas egkrthike! Syndethite me: Kinito: ${normalised}, PIN: ${pinHint}. Allaxte to PIN apo tin efarmogi.`
      );
    }

    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/client-admin/clients/:userId/reject — reject registration request
router.post('/clients/:userId/reject', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { sendSms } = require('../lib/sms');
  try {
    const [[user]] = await db.query(
      'SELECT id, full_name, phone FROM users WHERE id = ? AND business_id = ?',
      [req.params.userId, bizId]
    );
    if (!user) return res.status(404).json({ error: 'Ο πελάτης δεν βρέθηκε' });

    await db.query('UPDATE users SET deleted_at = NOW() WHERE id = ?', [user.id]);

    if (user.phone) {
      const [[cfg]] = await db.query(
        'SELECT app_name FROM business_configs WHERE business_id = ? LIMIT 1',
        [bizId]
      );
      const gymName = cfg?.app_name || 'Το γυμναστήριό σας';
      await sendSms(
        user.phone,
        `${gymName}: H aitisi egrafis sas den egkrithike. Epikoinwniste me to gymnastirio gia perissoteres plirofories.`
      );
    }

    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// Body: { status: 'active' | 'pending' | 'suspended' }
router.patch('/clients/:userId/status', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { status } = req.body;
  const allowed = ['active', 'pending', 'suspended'];
  if (!allowed.includes(status)) {
    return res.status(400).json({ error: 'Μη έγκυρη κατάσταση λογαριασμού' });
  }

  try {
    const [[existing]] = await db.query(
      'SELECT id, full_name, email, account_status, deleted_at FROM users WHERE id = ? AND business_id = ?',
      [req.params.userId, bizId]
    );
    if (!existing) return res.status(404).json({ error: 'Ο πελάτης δεν βρέθηκε' });
    if (existing.deleted_at) {
      return res.status(400).json({ error: 'Ο πελάτης είναι στον κάδο — επανέφερέ τον πρώτα' });
    }

    await db.query(
      'UPDATE users SET account_status = ? WHERE id = ? AND business_id = ?',
      [status, req.params.userId, bizId]
    );

    const [[updated]] = await db.query(`
      SELECT u.*, ref.full_name AS referred_by_name
      FROM users u
      LEFT JOIN users ref ON ref.id = u.referred_by_user_id
      WHERE u.id = ? AND u.business_id = ?
    `, [req.params.userId, bizId]);

    return res.json(enrichClientProfile(updated));
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// DELETE /api/client-admin/clients/:userId — μεταφορά στον κάδο (soft delete)
router.delete('/clients/:userId', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  try {
    const [[user]] = await db.query(
      'SELECT id, full_name, deleted_at FROM users WHERE id = ? AND business_id = ?',
      [req.params.userId, bizId]
    );
    if (!user) return res.status(404).json({ error: 'Ο πελάτης δεν βρέθηκε' });
    if (user.deleted_at) {
      return res.status(400).json({ error: 'Ο πελάτης είναι ήδη στον κάδο' });
    }

    await db.query(
      'UPDATE users SET deleted_at = CURRENT_TIMESTAMP WHERE id = ? AND business_id = ?',
      [req.params.userId, bizId]
    );
    return res.json({ ok: true, message: `Ο πελάτης ${user.full_name} μεταφέρθηκε στον κάδο` });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/client-admin/clients/:userId/restore — επαναφορά από κάδο
router.post('/clients/:userId/restore', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  try {
    const [[user]] = await db.query(
      'SELECT id, full_name, deleted_at FROM users WHERE id = ? AND business_id = ?',
      [req.params.userId, bizId]
    );
    if (!user) return res.status(404).json({ error: 'Ο πελάτης δεν βρέθηκε' });
    if (!user.deleted_at) {
      return res.status(400).json({ error: 'Ο πελάτης δεν είναι στον κάδο' });
    }

    await db.query(
      'UPDATE users SET deleted_at = NULL WHERE id = ? AND business_id = ?',
      [req.params.userId, bizId]
    );

    const [[updated]] = await db.query(`
      SELECT u.*, ref.full_name AS referred_by_name
      FROM users u
      LEFT JOIN users ref ON ref.id = u.referred_by_user_id
      WHERE u.id = ? AND u.business_id = ?
    `, [req.params.userId, bizId]);

    return res.json({
      ok: true,
      message: `Ο πελάτης ${user.full_name} επανήλθε`,
      client: enrichClientProfile(updated),
    });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// DELETE /api/client-admin/clients/:userId/permanent — οριστική διαγραφή (μόνο από κάδο)
router.delete('/clients/:userId/permanent', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  try {
    const [[user]] = await db.query(
      'SELECT id, full_name, deleted_at FROM users WHERE id = ? AND business_id = ?',
      [req.params.userId, bizId]
    );
    if (!user) return res.status(404).json({ error: 'Ο πελάτης δεν βρέθηκε' });
    if (!user.deleted_at) {
      return res.status(400).json({ error: 'Μόνο πελάτες στον κάδο μπορούν να διαγραφούν οριστικά' });
    }

    await db.query('DELETE FROM users WHERE id = ? AND business_id = ?', [req.params.userId, bizId]);
    return res.json({ ok: true, message: `Ο πελάτης ${user.full_name} διαγράφηκε οριστικά` });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.get('/fitness-goals', requireClientAdmin, (_req, res) => {
  return res.json(
    Object.entries(FITNESS_GOAL_LABELS).map(([id, label]) => ({ id, label }))
  );
});

async function upsertMembershipFromPayment(conn, {
  bizId, userId, service_id, plan_id, period_start, period_end, paymentDescription,
}) {
  if (!service_id || !period_start || !period_end) return null;

  let sessions = 9999;
  let serviceCategory = null;

  if (plan_id) {
    const [[plan]] = await conn.query(
      'SELECT sessions FROM business_plans WHERE id = ? AND business_id = ?',
      [plan_id, bizId]
    );
    sessions = planSessionsToMembershipTotal(plan?.sessions);
  }

  const [[svc]] = await conn.query(
    'SELECT category FROM services WHERE id = ? AND business_id = ?',
    [service_id, bizId]
  );
  serviceCategory = svc?.category || null;

  const [[trial]] = await conn.query(`
    SELECT id FROM user_memberships
    WHERE user_id = ? AND business_id = ? AND service_id = ?
      AND membership_status = 'trial'
    LIMIT 1
  `, [userId, bizId, service_id]);

  if (trial) {
    await conn.query(`
      UPDATE user_memberships SET
        membership_status = 'active',
        plan_id = COALESCE(?, plan_id),
        service_category = COALESCE(?, service_category),
        total_sessions = ?,
        used_sessions = 0,
        valid_from = ?,
        valid_until = ?,
      WHERE id = ?
    `, [plan_id || null, serviceCategory, sessions ?? 9999, period_start, period_end, trial.id]);
    return trial.id;
  }

  const [active] = await conn.query(`
    SELECT id FROM user_memberships
    WHERE user_id = ? AND business_id = ? AND service_id = ?
      AND valid_until >= CURDATE()
      AND (membership_status IS NULL OR membership_status = 'active')
    ORDER BY valid_until DESC
    LIMIT 1
  `, [userId, bizId, service_id]);

  if (active.length) {
    await conn.query(`
      UPDATE user_memberships SET
        plan_id = COALESCE(?, plan_id),
        valid_from = LEAST(valid_from, ?),
        valid_until = GREATEST(valid_until, ?),
      WHERE id = ?
    `, [plan_id || null, period_start, period_end, active[0].id]);
    return active[0].id;
  }

  const membershipId = uuidv4();
  await conn.query(`
    INSERT INTO user_memberships
      (id, user_id, business_id, plan_id, service_id, service_category, total_sessions, used_sessions, valid_from, valid_until)
    VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
  `, [
    membershipId, userId, bizId, plan_id || null, service_id, serviceCategory,
    sessions ?? 9999, period_start, period_end,
  ]);
  return membershipId;
}

async function createNutritionMembership(conn, {
  bizId, userId, nutrition_plan_id, valid_from, valid_until, notes,
}) {
  const [[plan]] = await conn.query(
    `SELECT id, name FROM business_plans
     WHERE id = ? AND business_id = ? AND plan_type = 'nutrition' AND is_active = 1`,
    [nutrition_plan_id, bizId]
  );
  if (!plan) throw new Error('Το πακέτο διατροφής δεν βρέθηκε');

  const [existing] = await conn.query(
    `SELECT m.id FROM user_memberships m
     JOIN business_plans p ON p.id = m.plan_id AND p.plan_type = 'nutrition'
     WHERE m.user_id = ? AND m.business_id = ?
       AND (m.valid_until IS NULL OR m.valid_until >= CURDATE())`,
    [userId, bizId]
  );
  if (existing.length) throw new Error('Ο πελάτης έχει ήδη ενεργό πακέτο διατροφής');

  const membershipId = uuidv4();
  const finalNotes = notes || plan.name;
  await conn.query(
    `INSERT INTO user_memberships
      (id, user_id, business_id, plan_id, service_id, service_category, total_sessions, used_sessions, valid_from, valid_until, notes)
     VALUES (?,?,?,?,?,?,?,0,?,?,?)`,
    [membershipId, userId, bizId, plan.id, null, 'nutrition', 9999, valid_from, valid_until, finalNotes]
  );
  return membershipId;
}

// ============================================================
// GET /api/client-admin/clients/:userId/active-service-ids — service_ids with active memberships
router.get('/clients/:userId/active-service-ids', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  try {
    const [rows] = await db.query(`
      SELECT DISTINCT service_id FROM user_memberships
      WHERE user_id = ? AND business_id = ?
        AND membership_status IN ('active', 'trial')
        AND service_id IS NOT NULL
    `, [req.params.userId, bizId]);
    return res.json(rows.map(r => r.service_id));
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// GET /api/client-admin/clients/:userId/credits
// ============================================================
router.get('/clients/:userId/credits', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  try {
    const graceDays = await getGracePeriodDays(db, bizId);
    const [memberships] = await db.query(`
      SELECT
        m.id, m.plan_id, m.service_id, m.total_sessions, m.used_sessions,
        (m.total_sessions - m.used_sessions) AS remaining,
        m.valid_from, m.valid_until, m.notes,
        m.membership_status, m.trial_booking_id,
        m.cancelled_at, m.cancellation_reason, m.reactivated_at,
        s.name AS service_name, s.category, s.image_url AS service_image_url,
        m.service_category,
        bp.name AS plan_name, bp.billing_period, bp.price_cents AS plan_price_cents,
        tb.starts_at AS trial_starts_at,
        (SELECT COUNT(*) FROM payments p WHERE p.membership_id = m.id) AS payment_count,
        (SELECT p.id FROM payments p WHERE p.membership_id = m.id
         ORDER BY COALESCE(p.payment_date, p.created_at) DESC LIMIT 1) AS latest_payment_id
      FROM user_memberships m
      LEFT JOIN services s ON s.id = m.service_id
      LEFT JOIN business_plans bp ON bp.id = m.plan_id
      LEFT JOIN bookings tb ON tb.id = m.trial_booking_id
      WHERE m.user_id = ? AND m.business_id = ?
      ORDER BY m.valid_until DESC
    `, [req.params.userId, bizId]);

    const [pendingPayments] = await db.query(`
      SELECT p.id, p.membership_id, p.description, p.amount_cents, p.paid_amount_cents,
             p.period_start, p.period_end, p.status
      FROM payments p
      WHERE p.business_id = ? AND p.user_id = ?
        AND (p.amount_cents - COALESCE(p.paid_amount_cents, 0)) > 0
        AND p.status IN ('pending', 'partial', 'overdue')
    `, [bizId, req.params.userId]);

    // Fetch all services for plans that have multiple services (combo plans)
    const planIds = [...new Set(memberships.map(m => m.plan_id).filter(Boolean))];
    let planServiceMap = {};
    if (planIds.length > 0) {
      const placeholders = planIds.map(() => '?').join(',');
      const [planSvcRows] = await db.query(
        `SELECT plan_id, service_id FROM service_plan_assignments WHERE plan_id IN (${placeholders})`,
        planIds
      );
      planSvcRows.forEach(row => {
        if (!planServiceMap[row.plan_id]) planServiceMap[row.plan_id] = [];
        planServiceMap[row.plan_id].push(row.service_id);
      });
    }

    const enriched = memberships.map((m) => {
      const pending = (pendingPayments || []).find((p) => p.membership_id === m.id);
      const base = enrichMembershipLifecycle(m, graceDays, pending || null);
      base.plan_service_ids = planServiceMap[m.plan_id] || (m.service_id ? [m.service_id] : []);
      return base;
    });
    return res.json(enriched);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// POST /api/client-admin/clients/:userId/credits
// Add a new package/membership for a client
// Body: { service_id?, service_category?, total_sessions, valid_from, valid_until, notes }
// ============================================================
router.post('/clients/:userId/credits', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { plan_id, service_id, service_category, total_sessions, valid_from, valid_until, notes } = req.body;

  if (!valid_from || !valid_until) {
    return res.status(400).json({ error: 'valid_from, valid_until required' });
  }

  try {
    let finalSessions  = total_sessions;
    let finalServiceId = service_id;
    let finalCategory  = service_category;
    let finalNotes     = notes;

    // If a plan_id is provided, fetch plan details automatically
    if (plan_id) {
      const [[plan]] = await db.query(
        'SELECT * FROM business_plans WHERE id=? AND business_id=?',
        [plan_id, bizId]
      );
      if (!plan) return res.status(404).json({ error: 'Πλάνο δεν βρέθηκε' });

      finalSessions = planSessionsToMembershipTotal(plan.sessions);

      if (service_id) {
        const [[svc]] = await db.query(
          'SELECT id, name, category FROM services WHERE id=? AND business_id=?',
          [service_id, bizId]
        );
        if (!svc) return res.status(404).json({ error: 'Η υπηρεσία δεν βρέθηκε' });
        finalServiceId = svc.id;
        finalCategory  = svc.category;
        if (!finalNotes) {
          finalNotes = `${svc.name} — ${plan.name} (€${(plan.price_cents/100).toFixed(2)})`;
        }
      } else {
        // Fallback: first linked service (legacy)
        const [[assignment]] = await db.query(
          `SELECT spa.service_id, s.name AS service_name, s.category
           FROM service_plan_assignments spa
           JOIN services s ON s.id = spa.service_id
           WHERE spa.plan_id = ?
           LIMIT 1`,
          [plan_id]
        );

        if (assignment) {
          finalServiceId = assignment.service_id;
          finalCategory  = assignment.category;
          if (!finalNotes) {
            finalNotes = `${assignment.service_name} — ${plan.name} (€${(plan.price_cents/100).toFixed(2)})`;
          }
        } else if (!finalNotes) {
          finalNotes = `${plan.name} (€${(plan.price_cents/100).toFixed(2)})`;
        }
      }
    } else if (service_id) {
      const [[svc]] = await db.query(
        'SELECT id, name, category FROM services WHERE id=? AND business_id=?',
        [service_id, bizId]
      );
      if (!svc) return res.status(404).json({ error: 'Η υπηρεσία δεν βρέθηκε' });
      finalServiceId = svc.id;
      finalCategory  = svc.category;
    }

    const id = uuidv4();
    await db.query(`
      INSERT INTO user_memberships
        (id, user_id, business_id, plan_id, service_id, service_category, total_sessions, used_sessions, valid_from, valid_until, notes)
      VALUES (?,?,?,?,?,?,?,0,?,?,?)
    `, [id, req.params.userId, bizId, plan_id || null, finalServiceId || null,
        finalCategory || null, planSessionsToMembershipTotal(finalSessions), valid_from, valid_until, finalNotes || null]);

    return res.status(201).json({ id, message: 'Πακέτο προστέθηκε' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// PATCH /api/client-admin/clients/:userId/credits/:membershipId
// Edit sessions or dates
// ============================================================
router.patch('/clients/:userId/credits/:membershipId', requireClientAdmin, async (req, res) => {
  const { total_sessions, used_sessions, valid_from, valid_until, notes } = req.body;
  try {
    const [[existing]] = await db.query(
      'SELECT total_sessions, used_sessions FROM user_memberships WHERE id = ? AND business_id = ?',
      [req.params.membershipId, req.admin.businessId]
    );
    if (!existing) return res.status(404).json({ error: 'Το πακέτο δεν βρέθηκε' });

    const nextTotal = total_sessions !== undefined ? total_sessions : existing.total_sessions;
    const nextUsed  = used_sessions !== undefined ? used_sessions : existing.used_sessions;

    if (nextTotal < 9999 && nextUsed > nextTotal) {
      return res.status(400).json({ error: 'Οι χρησιμοποιημένες συνεδρίες δεν μπορούν να ξεπερνούν το σύνολο' });
    }

    await db.query(`
      UPDATE user_memberships SET
        total_sessions = COALESCE(?, total_sessions),
        used_sessions  = COALESCE(?, used_sessions),
        valid_from     = COALESCE(?, valid_from),
        valid_until    = COALESCE(?, valid_until),
        notes          = COALESCE(?, notes)
      WHERE id = ? AND business_id = ?
    `, [total_sessions, used_sessions, valid_from, valid_until, notes,
        req.params.membershipId, req.admin.businessId]);
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// POST /api/client-admin/clients/:userId/credits/:membershipId/renewal-payment
router.post('/clients/:userId/credits/:membershipId/renewal-payment', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const userId = req.params.userId;
  const membershipId = req.params.membershipId;
  const months = Math.min(12, Math.max(1, Number(req.body.months) || 1));
  const { paid_amount_cents, payment_date, method, notes, due_date } = req.body;

  try {
    const [[membership]] = await db.query(`
      SELECT m.*, s.name AS service_name, bp.price_cents AS plan_price_cents, bp.name AS plan_name
      FROM user_memberships m
      LEFT JOIN services s ON s.id = m.service_id
      LEFT JOIN business_plans bp ON bp.id = m.plan_id
      WHERE m.id = ? AND m.user_id = ? AND m.business_id = ?
    `, [membershipId, userId, bizId]);
    if (!membership) return res.status(404).json({ error: 'Το πακέτο δεν βρέθηκε' });
    if (membership.membership_status === 'cancelled') {
      return res.status(400).json({ error: 'Η συνδρομή είναι διακομμένη — επανενεργοποίησέ την πρώτα' });
    }
    if (membership.membership_status === 'trial') {
      return res.status(400).json({ error: 'Για δοκιμαστικό χρησιμοποίησε Ενεργοποίηση' });
    }

    const period = computeRenewalPeriod(membership, months);
    const pricePerMonth = membership.plan_price_cents || 0;
    const amountCents = months === 1
      ? pricePerMonth
      : Math.round(pricePerMonth * months * (months >= 6 ? 0.9 : months >= 3 ? 0.95 : 1));

    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();

      await assertNoDuplicatePayment(conn, {
        bizId,
        userId,
        serviceId: membership.service_id,
        paymentType: months === 1 ? 'monthly' : 'package',
        billingMonth: period.billing_month,
        periodStart: period.period_start,
      });

      const paymentType = months === 1 ? 'monthly' : 'package';
      const description = months === 1
        ? `${membership.service_name} — Μήνας ${formatBillingMonth(period.billing_month)} (${period.period_start} → ${period.period_end})`
        : `${membership.service_name} — Ανανέωση ${months} μηνών (${period.period_start} → ${period.period_end})`;

      const payId = uuidv4();
      const paidCents = Math.min(amountCents, Math.max(0, Number(paid_amount_cents) || 0));
      const status = deriveStatus(amountCents, paidCents, due_date || period.period_start);

      await conn.query(`
        INSERT INTO payments
          (id, business_id, user_id, service_id, plan_id, membership_id, description,
           amount_cents, paid_amount_cents, payment_type, billing_month, package_months,
           period_start, period_end, payment_date, due_date, notes, method, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `, [
        payId, bizId, userId, membership.service_id, membership.plan_id, membershipId,
        description, amountCents, paidCents, paymentType,
        paymentType === 'monthly' ? period.billing_month : null,
        paymentType === 'package' ? months : null,
        period.period_start, period.period_end,
        payment_date || null, due_date || period.period_start,
        notes || null, method || 'cash', status,
      ]);

      await conn.query(`
        UPDATE user_memberships SET
          valid_until = GREATEST(valid_until, ?),
          membership_status = 'active',
          cancelled_at = NULL,
          cancellation_reason = NULL
        WHERE id = ?
      `, [period.period_end, membershipId]);

      await conn.commit();
      return res.status(201).json({
        id: payId,
        membership_id: membershipId,
        period,
        amount_cents: amountCents,
        message: months === 1 ? 'Η ανανέωση μήνα καταχωρήθηκε' : `Η ανανέωση ${months} μηνών καταχωρήθηκε`,
      });
    } catch (err) {
      await conn.rollback();
      if (err.code === 'DUPLICATE_PAYMENT') {
        return res.status(409).json({ error: err.message });
      }
      throw err;
    } finally {
      conn.release();
    }
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// PATCH /api/client-admin/clients/:userId/credits/:membershipId/cancel
router.patch('/clients/:userId/credits/:membershipId/cancel', requireClientAdmin, async (req, res) => {
  const { reason } = req.body;
  const bizId = req.admin.businessId;
  try {
    const [[mem]] = await db.query(
      'SELECT id, membership_status FROM user_memberships WHERE id = ? AND user_id = ? AND business_id = ?',
      [req.params.membershipId, req.params.userId, bizId],
    );
    if (!mem) return res.status(404).json({ error: 'Το πακέτο δεν βρέθηκε' });
    if (mem.membership_status === 'cancelled') {
      return res.status(400).json({ error: 'Η συνδρομή είναι ήδη διακομμένη' });
    }

    await db.query(`
      UPDATE user_memberships SET
        membership_status = 'cancelled',
        cancelled_at = NOW(),
        cancellation_reason = ?,
        cancelled_by_user_id = NULL
      WHERE id = ? AND business_id = ?
    `, [reason?.trim() || null, req.params.membershipId, bizId]);

    return res.json({ ok: true, message: 'Η συνδρομή διακόπηκε' });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// PATCH /api/client-admin/clients/:userId/credits/:membershipId/reactivate
router.patch('/clients/:userId/credits/:membershipId/reactivate', requireClientAdmin, async (req, res) => {
  const { valid_from, valid_until, notes } = req.body;
  const bizId = req.admin.businessId;
  try {
    const [[mem]] = await db.query(
      'SELECT id FROM user_memberships WHERE id = ? AND user_id = ? AND business_id = ?',
      [req.params.membershipId, req.params.userId, bizId],
    );
    if (!mem) return res.status(404).json({ error: 'Το πακέτο δεν βρέθηκε' });

    await db.query(`
      UPDATE user_memberships SET
        membership_status = 'active',
        cancelled_at = NULL,
        cancellation_reason = NULL,
        reactivated_at = NOW(),
        valid_from = COALESCE(?, valid_from),
        valid_until = COALESCE(?, valid_until),
        notes = COALESCE(?, notes)
      WHERE id = ? AND business_id = ?
    `, [valid_from || null, valid_until || null, notes || null, req.params.membershipId, bizId]);

    return res.json({ ok: true, message: 'Η συνδρομή επανενεργοποιήθηκε' });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// DELETE /api/client-admin/clients/:userId/credits/:membershipId
// ============================================================
router.delete('/clients/:userId/credits/:membershipId', requireClientAdmin, async (req, res) => {
  const { membershipId } = req.params;
  const bizId = req.admin.businessId;
  try {
    // Also delete the linked payment so the duplicate-check doesn't block re-adding
    await db.query(
      'DELETE FROM payments WHERE membership_id = ? AND business_id = ?',
      [membershipId, bizId],
    );
    await db.query('DELETE FROM user_memberships WHERE id = ? AND business_id = ?',
      [membershipId, bizId]);
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// POST /api/client-admin/clients/:userId/trial-program
// ============================================================
router.post('/clients/:userId/trial-program', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const userId = req.params.userId;
  const { service_id, plan_id, trial_date, trial_time, staff_id, notes } = req.body;

  if (!trial_date || !trial_time) {
    return res.status(400).json({ error: 'Απαιτούνται ημερομηνία και ώρα δοκιμαστικού' });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    if (service_id) {
      const [[existing]] = await conn.query(`
        SELECT id FROM user_memberships
        WHERE user_id = ? AND business_id = ? AND service_id = ?
          AND membership_status IN ('trial', 'active')
          AND valid_until >= CURDATE()
        LIMIT 1
      `, [userId, bizId, service_id]);
      if (existing) {
        throw new Error('Ο πελάτης έχει ήδη πακέτο ή δοκιμαστικό για αυτή την υπηρεσία');
      }
    }

    let booking;
    if (service_id) {
      booking = await createOneBooking(conn, {
        bizId,
        userId,
        service_id,
        staff_id: staff_id || null,
        date: trial_date,
        time: trial_time,
        use_credit: false,
        is_trial: true,
        source: 'admin',
      });
    } else {
      // Trial without specific service — insert minimal booking directly
      const bookingId = uuidv4();
      const startsAt = new Date(`${trial_date}T${trial_time}`);
      const endsAt = new Date(startsAt.getTime() + 60 * 60000); // 1-hour default
      await conn.query(
        `INSERT INTO bookings (id, business_id, user_id, service_id, staff_id, starts_at, ends_at, status, source, is_trial)
         VALUES (?, ?, ?, NULL, ?, ?, ?, 'confirmed', 'admin', 1)`,
        [bookingId, bizId, userId, staff_id || null, startsAt, endsAt]
      );
      booking = { id: bookingId };
    }

    let svc = null;
    if (service_id) {
      const [[row]] = await conn.query(
        'SELECT name, category FROM services WHERE id = ? AND business_id = ?',
        [service_id, bizId]
      );
      svc = row || null;
    }

    const membershipId = uuidv4();
    const noteText = notes?.trim()
      || `Δοκιμαστικό${svc ? ` — ${svc.name}` : ''} (${trial_date} ${trial_time})`;

    await conn.query(`
      INSERT INTO user_memberships
        (id, user_id, business_id, plan_id, service_id, service_category,
         total_sessions, used_sessions, valid_from, valid_until, notes,
         membership_status, trial_booking_id)
      VALUES (?, ?, ?, ?, ?, ?, 0, 0, ?, ?, ?, 'trial', ?)
    `, [
      membershipId, userId, bizId, plan_id || null, service_id || null, svc?.category || null,
      trial_date, trial_date, noteText, booking.id,
    ]);

    await conn.commit();
    return res.status(201).json({
      membership_id: membershipId,
      booking_id: booking.id,
      message: 'Το δοκιμαστικό προγραμματίστηκε',
    });
  } catch (err) {
    await conn.rollback();
    let status = 400;
    if (err.code === 'SLOT_FULL' || err.code === 'TIME_CONFLICT' || err.code === 'DUPLICATE_BOOKING') {
      status = 409;
    }
    return res.status(status).json({ error: err.message, code: err.code || null });
  } finally {
    conn.release();
  }
});

// ============================================================
// CLIENT PAYMENTS
// ============================================================
router.get('/clients/:userId/payments', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const [rows] = await db.query(`
    SELECT p.*, s.name AS service_name, s.image_url AS service_image_url,
           bp.name AS plan_name, m.valid_from AS membership_valid_from, m.valid_until AS membership_valid_until
    FROM payments p
    LEFT JOIN services s ON s.id = p.service_id
    LEFT JOIN business_plans bp ON bp.id = p.plan_id
    LEFT JOIN user_memberships m ON m.id = p.membership_id
    WHERE p.user_id = ? AND p.business_id = ?
    ORDER BY COALESCE(p.payment_date, p.due_date, p.created_at) DESC
  `, [req.params.userId, bizId]);

  const paymentIds = rows.map((r) => r.id);
  const lineItemsByPayment = {};
  if (paymentIds.length) {
    const [lineRows] = await db.query(
      `SELECT pli.*, s.name AS service_name, bp.name AS plan_name
       FROM payment_line_items pli
       LEFT JOIN services s ON s.id = pli.service_id
       LEFT JOIN business_plans bp ON bp.id = pli.plan_id
       WHERE pli.payment_id IN (?)
       ORDER BY pli.sort_order`,
      [paymentIds]
    );
    for (const line of lineRows) {
      if (!lineItemsByPayment[line.payment_id]) lineItemsByPayment[line.payment_id] = [];
      lineItemsByPayment[line.payment_id].push(line);
    }
  }

  return res.json(rows.map((row) => ({
    ...mapPaymentRow(row),
    line_items: lineItemsByPayment[row.id] || [],
  })));
});

async function resolvePaymentPayload(body, bizId) {
  const {
    description,
    amount_cents,
    subtotal_cents,
    paid_amount_cents,
    payment_date,
    due_date,
    notes,
    method,
    status,
    service_id,
    plan_id,
    payment_type,
    billing_month,
    package_months,
    period_start,
    period_end,
    discount_cents,
    registration_fee_cents,
    create_membership = true,
    membership_id,
    nutrition_plan_id,
  } = body;

  let serviceName = null;
  let linkedMembership = null;
  if (membership_id) {
    const [[mem]] = await db.query(
      `SELECT m.id, m.service_id, m.plan_id, m.valid_from, m.valid_until, s.name AS service_name
       FROM user_memberships m
       LEFT JOIN services s ON s.id = m.service_id
       WHERE m.id = ? AND m.business_id = ?`,
      [membership_id, bizId]
    );
    if (!mem) throw new Error('Το πακέτο δεν βρέθηκε');
    linkedMembership = mem;
    serviceName = mem.service_name || serviceName;
  }

  if (service_id) {
    const [[svc]] = await db.query(
      'SELECT name FROM services WHERE id = ? AND business_id = ?',
      [service_id, bizId]
    );
    if (!svc) throw new Error('Η υπηρεσία δεν βρέθηκε');
    serviceName = svc.name;
  }

  const discount = Math.max(0, Number(discount_cents) || 0);
  const regFee = Math.max(0, Number(registration_fee_cents) || 0);
  const subtotal = subtotal_cents !== undefined
    ? Number(subtotal_cents)
    : (Number(amount_cents) || 0) + discount - regFee;

  const resolvedPeriodStart = toDateString(period_start)
    || toDateString(linkedMembership?.valid_from);
  const billingMonthDate = toBillingMonthDate(billing_month);
  const computedPeriodEnd = toDateString(period_end) || computePeriodEnd(
    resolvedPeriodStart,
    payment_type,
    package_months ? Number(package_months) : null,
    billingMonthDate || billing_month
  ) || toDateString(linkedMembership?.valid_until);

  const autoDescription = buildPaymentDescription({
    serviceName,
    paymentType: payment_type,
    billingMonth: billingMonthDate,
    packageMonths: package_months ? Number(package_months) : null,
    periodStart: resolvedPeriodStart,
    periodEnd: computedPeriodEnd,
    registrationFeeCents: regFee,
  });

  const total = amount_cents !== undefined
    ? Number(amount_cents)
    : computePaymentTotal({ subtotalCents: subtotal, discountCents: discount, registrationFeeCents: regFee });

  if (!total || total < 0) {
    throw new Error('Απαιτείται έγκυρο ποσό');
  }

  return {
    description: description || autoDescription,
    amount_cents: total,
    paid_amount_cents: Number(paid_amount_cents || 0),
    payment_date: toDateString(payment_date),
    due_date: toDateString(due_date),
    notes,
    method,
    status,
    service_id: service_id || linkedMembership?.service_id || null,
    plan_id: plan_id || linkedMembership?.plan_id || null,
    payment_type: payment_type || null,
    billing_month: billingMonthDate,
    package_months: package_months ? Number(package_months) : null,
    period_start: resolvedPeriodStart,
    period_end: computedPeriodEnd,
    discount_cents: discount,
    registration_fee_cents: regFee,
    create_membership: membership_id ? false : !!create_membership,
    membership_id: membership_id || null,
    nutrition_plan_id: nutrition_plan_id || null,
    lines: Array.isArray(body.lines) ? body.lines : null,
  };
}

async function resolveBundlePaymentPayload(body, bizId) {
  const lines = (body.lines || []).map((line, index) => ({
    service_id: line.service_id || null,
    plan_id: line.plan_id || null,
    subtotal_cents: Math.max(0, Number(line.subtotal_cents) || 0),
    label: line.label || null,
    sort_order: index,
  }));

  if (!lines.length) throw new Error('Πρόσθεσε τουλάχιστον μία υπηρεσία');

  const resolvedLines = [];
  const serviceNames = [];

  for (const line of lines) {
    if (!line.service_id && !line.plan_id) {
      throw new Error('Κάθε γραμμή χρέωσης χρειάζεται υπηρεσία ή πλάνο');
    }

    let serviceName = null;
    let planName = null;

    if (line.service_id) {
      const [[svc]] = await db.query(
        'SELECT name FROM services WHERE id = ? AND business_id = ?',
        [line.service_id, bizId]
      );
      if (!svc) throw new Error('Η υπηρεσία δεν βρέθηκε');
      serviceName = svc.name;
    }

    if (line.plan_id) {
      const [[plan]] = await db.query(
        'SELECT name, service_id FROM business_plans WHERE id = ? AND business_id = ?',
        [line.plan_id, bizId]
      );
      if (!plan) throw new Error('Το πλάνο δεν βρέθηκε');
      planName = plan.name;
      if (!line.service_id && plan.service_id) line.service_id = plan.service_id;
    }

    const label = line.label || [serviceName, planName].filter(Boolean).join(' — ') || 'Πακέτο';
    serviceNames.push(label.split(' — ')[0] || label);
    resolvedLines.push({ ...line, label, serviceName, planName });
  }

  const discount = Math.max(0, Number(body.discount_cents) || 0);
  const regFee = Math.max(0, Number(body.registration_fee_cents) || 0);
  const subtotal = resolvedLines.reduce((sum, line) => sum + line.subtotal_cents, 0);
  const total = computePaymentTotal({ subtotalCents: subtotal, discountCents: discount, registrationFeeCents: regFee });
  if (!total) throw new Error('Απαιτείται έγκυρο ποσό');

  const billingMonthDate = toBillingMonthDate(body.billing_month);
  const resolvedPeriodStart = toDateString(body.period_start);
  const computedPeriodEnd = toDateString(body.period_end) || computePeriodEnd(
    resolvedPeriodStart,
    body.payment_type,
    body.package_months ? Number(body.package_months) : null,
    billingMonthDate || body.billing_month
  );

  const autoDescription = buildPaymentDescription({
    serviceNames: [...new Set(serviceNames)],
    paymentType: body.payment_type,
    billingMonth: billingMonthDate,
    packageMonths: body.package_months ? Number(body.package_months) : null,
    periodStart: resolvedPeriodStart,
    periodEnd: computedPeriodEnd,
    registrationFeeCents: regFee,
  });

  return {
    description: body.description || autoDescription,
    amount_cents: total,
    paid_amount_cents: Number(body.paid_amount_cents || 0),
    payment_date: toDateString(body.payment_date),
    due_date: toDateString(body.due_date),
    notes: body.notes,
    method: body.method || 'cash',
    status: body.status,
    payment_type: body.payment_type || null,
    billing_month: billingMonthDate,
    package_months: body.package_months ? Number(body.package_months) : null,
    period_start: resolvedPeriodStart,
    period_end: computedPeriodEnd,
    discount_cents: discount,
    registration_fee_cents: regFee,
    create_membership: body.membership_id ? false : !!body.create_membership,
    membership_id: body.membership_id || null,
    lines: resolvedLines,
    subtotal_cents: subtotal,
    service_id: resolvedLines[0]?.service_id || null,
    plan_id: resolvedLines[0]?.plan_id || null,
  };
}

router.post('/clients/:userId/payments', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const userId = req.params.userId;
  const isBundle = Array.isArray(req.body.lines) && req.body.lines.length > 0;

  let payload;
  try {
    payload = isBundle
      ? await resolveBundlePaymentPayload(req.body, bizId)
      : await resolvePaymentPayload(req.body, bizId);
    if (payload.membership_id) {
      const [[mem]] = await db.query(
        `SELECT id, membership_status FROM user_memberships
         WHERE id = ? AND user_id = ? AND business_id = ?`,
        [payload.membership_id, userId, bizId]
      );
      if (!mem) throw new Error('Το πακέτο δεν ανήκει σε αυτόν τον πελάτη');
      payload._trialMembership = mem.membership_status === 'trial';
    }
  } catch (err) {
    return res.status(400).json({ error: err.message });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    if (isBundle) {
      for (const line of payload.lines) {
        await assertNoDuplicatePayment(conn, {
          bizId,
          userId,
          serviceId: line.service_id,
          paymentType: payload.payment_type,
          billingMonth: payload.billing_month,
          periodStart: payload.period_start,
        });
      }
    } else {
      await assertNoDuplicatePayment(conn, {
        bizId,
        userId,
        serviceId: payload.service_id,
        paymentType: payload.payment_type,
        billingMonth: payload.billing_month,
        periodStart: payload.period_start,
      });
    }

    const id = uuidv4();
    const finalStatus = req.body.status != null
      ? req.body.status
      : deriveStatus(payload.amount_cents, payload.paid_amount_cents, payload.due_date);

    let membershipId = payload.membership_id || null;
    const createdMembershipIds = [];

    if (isBundle) {
      if (
        payload.create_membership
        && payload.period_start
        && payload.period_end
        && payload.payment_type
        && payload.payment_type !== 'registration_fee'
      ) {
        for (const line of payload.lines) {
          const mid = await upsertMembershipFromPayment(conn, {
            bizId,
            userId,
            service_id: line.service_id,
            plan_id: line.plan_id,
            period_start: payload.period_start,
            period_end: payload.period_end,
            paymentDescription: line.label,
          });
          line._membershipId = mid;
          createdMembershipIds.push(mid);
        }
        membershipId = createdMembershipIds[0] || null;
      }
    } else if (
      payload.create_membership
      && payload.service_id
      && payload.period_start
      && payload.period_end
      && payload.payment_type
      && payload.payment_type !== 'registration_fee'
    ) {
      membershipId = await upsertMembershipFromPayment(conn, {
        bizId,
        userId,
        service_id: payload.service_id,
        plan_id: payload.plan_id,
        period_start: payload.period_start,
        period_end: payload.period_end,
        paymentDescription: payload.description,
      });
      createdMembershipIds.push(membershipId);
    } else if (
      payload._trialMembership
      && membershipId
      && payload.service_id
      && payload.period_start
      && payload.period_end
    ) {
      let sessions = 9999;
      if (payload.plan_id) {
        const [[plan]] = await conn.query(
          'SELECT sessions FROM business_plans WHERE id = ? AND business_id = ?',
          [payload.plan_id, bizId]
        );
        sessions = planSessionsToMembershipTotal(plan?.sessions);
      }
      await conn.query(`
        UPDATE user_memberships SET
          membership_status = 'active',
          plan_id = COALESCE(?, plan_id),
          total_sessions = ?,
          used_sessions = 0,
          valid_from = ?,
          valid_until = ?,
          notes = COALESCE(?, notes)
        WHERE id = ?
      `, [
        payload.plan_id || null, sessions,
        payload.period_start, payload.period_end,
        payload.description, membershipId,
      ]);
      createdMembershipIds.push(membershipId);
    }

    if (!isBundle && payload.nutrition_plan_id && payload.period_start) {
      const [[nutritionPlan]] = await conn.query(
        `SELECT * FROM business_plans
         WHERE id = ? AND business_id = ? AND plan_type = 'nutrition' AND is_active = 1`,
        [payload.nutrition_plan_id, bizId]
      );
      if (!nutritionPlan) throw new Error('Το πακέτο διατροφής δεν βρέθηκε');

      let servicePlan = null;
      if (payload.plan_id) {
        const [[sp]] = await conn.query(
          'SELECT * FROM business_plans WHERE id = ? AND business_id = ?',
          [payload.plan_id, bizId]
        );
        servicePlan = sp || null;
      }

      const promo = evaluateNutritionPromo(nutritionPlan, {
        servicePlan,
        paymentType: payload.payment_type,
        packageMonths: payload.package_months,
        periodStart: payload.period_start,
      });

      const nutritionNotes = [
        nutritionPlan.name,
        promo.label,
        nutritionIncludesSummary(nutritionPlan).join(', '),
      ].filter(Boolean).join(' · ');

      await createNutritionMembership(conn, {
        bizId,
        userId,
        nutrition_plan_id: nutritionPlan.id,
        valid_from: payload.period_start,
        valid_until: promo.validUntil,
        notes: nutritionNotes,
      });

      if (nutritionPlan.nutrition_includes_consultations) {
        await grantConsultationCredits(conn, {
          bizId,
          userId,
          plan: nutritionPlan,
          valid_from: payload.period_start,
          valid_until: promo.validUntil,
          notes: nutritionNotes,
        });
      }
    }

    await conn.query(`
      INSERT INTO payments
        (id, business_id, user_id, amount_cents, paid_amount_cents, status,
         description, payment_date, due_date, notes, method,
         service_id, plan_id, payment_type, billing_month, package_months,
         period_start, period_end, discount_cents, registration_fee_cents, membership_id)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [
      id, bizId, userId, payload.amount_cents, payload.paid_amount_cents, finalStatus,
      payload.description, payload.payment_date || null, payload.due_date || null,
      payload.notes || null, payload.method || 'cash',
      payload.service_id, payload.plan_id, payload.payment_type, payload.billing_month,
      payload.package_months, payload.period_start, payload.period_end,
      payload.discount_cents, payload.registration_fee_cents, membershipId,
    ]);

    if (isBundle && payload.lines?.length) {
      for (const line of payload.lines) {
        await conn.query(
          `INSERT INTO payment_line_items
            (id, payment_id, membership_id, service_id, plan_id, label, amount_cents, sort_order)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            uuidv4(), id, line._membershipId || null, line.service_id, line.plan_id,
            line.label, line.subtotal_cents, line.sort_order,
          ]
        );
      }
    }

    await conn.commit();
    return res.status(201).json({
      id,
      description: payload.description,
      membership_ids: createdMembershipIds,
    });
  } catch (err) {
    await conn.rollback();
    if (err.code === 'DUPLICATE_PAYMENT') {
      return res.status(409).json({ error: err.message });
    }
    console.error(err);
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

router.patch('/payments/:id', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const [[existing]] = await db.query(
    'SELECT * FROM payments WHERE id = ? AND business_id = ?',
    [req.params.id, bizId]
  );
  if (!existing) return res.status(404).json({ error: 'Η πληρωμή δεν βρέθηκε' });

  let payload;
  try {
    payload = await resolvePaymentPayload({ ...existing, ...req.body }, bizId);
  } catch (err) {
    return res.status(400).json({ error: err.message });
  }

  const paidCents = req.body.paid_amount_cents !== undefined
    ? Math.max(0, Number(req.body.paid_amount_cents) || 0)
    : payload.paid_amount_cents;
  const finalStatus = req.body.status != null
    ? req.body.status
    : deriveStatus(payload.amount_cents, paidCents, payload.due_date);

  try {
    await assertNoDuplicatePayment(db, {
      bizId,
      userId: existing.user_id,
      serviceId: payload.service_id,
      paymentType: payload.payment_type,
      billingMonth: payload.billing_month,
      periodStart: payload.period_start,
      excludePaymentId: req.params.id,
    });
  } catch (err) {
    if (err.code === 'DUPLICATE_PAYMENT') {
      return res.status(409).json({ error: err.message });
    }
    return res.status(400).json({ error: err.message });
  }

  await db.query(`
    UPDATE payments SET
      description = ?,
      amount_cents = ?,
      paid_amount_cents = ?,
      payment_date = COALESCE(?, payment_date),
      due_date = COALESCE(?, due_date),
      notes = COALESCE(?, notes),
      method = COALESCE(?, method),
      status = ?,
      service_id = COALESCE(?, service_id),
      plan_id = COALESCE(?, plan_id),
      payment_type = COALESCE(?, payment_type),
      billing_month = COALESCE(?, billing_month),
      package_months = COALESCE(?, package_months),
      period_start = COALESCE(?, period_start),
      period_end = COALESCE(?, period_end),
      discount_cents = ?,
      registration_fee_cents = ?
    WHERE id = ? AND business_id = ?
  `, [
    payload.description, payload.amount_cents, paidCents,
    req.body.payment_date, req.body.due_date, req.body.notes, req.body.method, finalStatus,
    req.body.service_id, req.body.plan_id, req.body.payment_type, payload.billing_month,
    req.body.package_months, req.body.period_start, payload.period_end,
    payload.discount_cents, payload.registration_fee_cents,
    req.params.id, bizId,
  ]);
  return res.json({ ok: true });
});

router.delete('/payments/:id', requireClientAdmin, async (req, res) => {
  await db.query('DELETE FROM payments WHERE id = ? AND business_id = ?',
    [req.params.id, req.admin.businessId]);
  return res.json({ ok: true });
});

router.get('/payments/overview', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const month = req.query.month ? String(req.query.month).slice(0, 7) : null;
  const filter = req.query.filter || 'all';

  try {
    const [[config]] = await db.query(
      'SELECT payment_reminder_days FROM business_configs WHERE business_id = ?',
      [bizId]
    );
    const reminderDays = config?.payment_reminder_days ?? 3;

    let paymentWhere = 'p.business_id = ?';
    const params = [bizId];

    if (month) {
      paymentWhere += ` AND (
        DATE_FORMAT(COALESCE(p.due_date, p.period_end, p.payment_date), '%Y-%m') = ?
        OR DATE_FORMAT(p.billing_month, '%Y-%m') = ?
      )`;
      params.push(month, month);
    }

    const [rows] = await db.query(`
      SELECT p.*, u.full_name AS user_name, u.phone AS user_phone, u.email AS user_email,
             s.name AS service_name, s.image_url AS service_image_url,
             m.valid_until AS membership_valid_until
      FROM payments p
      LEFT JOIN users u ON u.id = p.user_id
      LEFT JOIN services s ON s.id = p.service_id
      LEFT JOIN user_memberships m ON m.id = p.membership_id
      WHERE ${paymentWhere}
      ORDER BY COALESCE(p.due_date, p.period_end, p.payment_date, p.created_at) ASC
    `, params);

    const payments = rows.map(mapPaymentRow);
    const todayStr = new Date().toISOString().slice(0, 10);
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() + reminderDays);
    const cutoffStr = cutoff.toISOString().slice(0, 10);

    const [expiringMemberships] = await db.query(`
      SELECT m.id AS membership_id, m.valid_from, m.valid_until, m.service_id,
             u.id AS user_id, u.full_name AS user_name, u.phone AS user_phone,
             s.name AS service_name, s.image_url AS service_image_url
      FROM user_memberships m
      JOIN users u ON u.id = m.user_id
      LEFT JOIN services s ON s.id = m.service_id
      WHERE m.business_id = ?
        AND m.membership_status = 'active'
        AND m.valid_until >= CURDATE()
        AND m.valid_until <= DATE_ADD(CURDATE(), INTERVAL ? DAY)
      ORDER BY m.valid_until ASC
    `, [bizId, reminderDays]);

    const summary = {
      total_amount_cents: payments.reduce((s, p) => s + (p.amount_cents || 0), 0),
      total_paid_cents: payments.reduce((s, p) => s + (p.paid_amount_cents || 0), 0),
      total_balance_cents: payments.reduce((s, p) => s + p.balance_cents, 0),
      count_pending: payments.filter(p => p.status === 'pending' || p.status === 'partial').length,
      count_overdue: payments.filter(p => p.status === 'overdue').length,
      count_paid: payments.filter(p => p.status === 'paid').length,
      count_due_soon: payments.filter(p => {
        const due = (p.due_date || p.period_end || '').toString().slice(0, 10);
        if (!due || p.status === 'paid') return false;
        return due >= todayStr && due <= cutoffStr;
      }).length,
      expiring_memberships: expiringMemberships.length,
      reminder_days: reminderDays,
    };

    let filteredPayments = payments;
    if (filter === 'overdue') {
      filteredPayments = payments.filter(p => p.status === 'overdue');
    } else if (filter === 'due_soon') {
      filteredPayments = payments.filter(p => {
        const due = (p.due_date || p.period_end || '').toString().slice(0, 10);
        if (!due || p.status === 'paid') return false;
        return due >= todayStr && due <= cutoffStr;
      });
    } else if (filter === 'pending') {
      filteredPayments = payments.filter(p => p.status === 'pending' || p.status === 'partial');
    }

    const clientMap = new Map();
    for (const p of filteredPayments) {
      if (!p.user_id) continue;
      if (!clientMap.has(p.user_id)) {
        clientMap.set(p.user_id, {
          user_id: p.user_id,
          user_name: p.user_name,
          user_phone: p.user_phone,
          user_email: p.user_email,
          payments: [],
          total_amount_cents: 0,
          total_paid_cents: 0,
          total_balance_cents: 0,
          count_paid: 0,
          count_pending: 0,
          count_overdue: 0,
        });
      }
      const c = clientMap.get(p.user_id);
      c.payments.push(p);
      c.total_amount_cents += p.amount_cents || 0;
      c.total_paid_cents += p.paid_amount_cents || 0;
      c.total_balance_cents += p.balance_cents || 0;
      if (p.status === 'paid') c.count_paid += 1;
      if (p.status === 'pending' || p.status === 'partial') c.count_pending += 1;
      if (p.status === 'overdue') c.count_overdue += 1;
    }

    const clientsGrouped = [...clientMap.values()].sort((a, b) => {
      if (b.total_balance_cents !== a.total_balance_cents) {
        return b.total_balance_cents - a.total_balance_cents;
      }
      return String(a.user_name || '').localeCompare(String(b.user_name || ''), 'el');
    });

    return res.json({
      summary,
      payments: filteredPayments,
      clients_grouped: clientsGrouped,
      expiring_memberships: expiringMemberships,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message });
  }
});

router.get('/notification-settings', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const [[row]] = await db.query(
    `SELECT booking_reminder_24h, booking_reminder_1h,
            auto_payment_reminders, payment_reminder_days
     FROM business_configs WHERE business_id = ?`,
    [bizId]
  );
  return res.json({
    booking_reminder_24h: row?.booking_reminder_24h !== 0,
    booking_reminder_1h: row?.booking_reminder_1h !== 0,
    auto_payment_reminders: !!row?.auto_payment_reminders,
    payment_reminder_days: row?.payment_reminder_days ?? 3,
    fcm_configured: !!(process.env.FIREBASE_SERVICE_ACCOUNT || process.env.FCM_SERVER_KEY),
  });
});

router.patch('/notification-settings', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const {
    booking_reminder_24h,
    booking_reminder_1h,
    auto_payment_reminders,
    payment_reminder_days,
  } = req.body;

  const updates = [];
  const params = [];

  if (booking_reminder_24h !== undefined) {
    updates.push('booking_reminder_24h = ?');
    params.push(booking_reminder_24h ? 1 : 0);
  }
  if (booking_reminder_1h !== undefined) {
    updates.push('booking_reminder_1h = ?');
    params.push(booking_reminder_1h ? 1 : 0);
  }
  if (auto_payment_reminders !== undefined) {
    updates.push('auto_payment_reminders = ?');
    params.push(auto_payment_reminders ? 1 : 0);
  }
  if (payment_reminder_days !== undefined) {
    const days = Number(payment_reminder_days);
    if (!Number.isFinite(days) || days < 0 || days > 60) {
      return res.status(400).json({ error: 'Οι ημέρες υπενθύμισης πρέπει να είναι 0–60' });
    }
    updates.push('payment_reminder_days = ?');
    params.push(days);
  }

  if (!updates.length) {
    return res.status(400).json({ error: 'Δεν υπάρχουν αλλαγές' });
  }

  params.push(bizId);
  await db.query(
    `UPDATE business_configs SET ${updates.join(', ')} WHERE business_id = ?`,
    params
  );

  const [[row]] = await db.query(
    `SELECT booking_reminder_24h, booking_reminder_1h,
            auto_payment_reminders, payment_reminder_days
     FROM business_configs WHERE business_id = ?`,
    [bizId]
  );
  return res.json({
    booking_reminder_24h: row?.booking_reminder_24h !== 0,
    booking_reminder_1h: row?.booking_reminder_1h !== 0,
    auto_payment_reminders: !!row?.auto_payment_reminders,
    payment_reminder_days: row?.payment_reminder_days ?? 3,
    fcm_configured: !!(process.env.FIREBASE_SERVICE_ACCOUNT || process.env.FCM_SERVER_KEY),
  });
});

router.post('/notifications/image', requireClientAdmin, (req, res, next) => {
  notificationImageUpload.single('image')(req, res, (err) => {
    if (err) return res.status(400).json({ error: err.message });
    next();
  });
}, async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'Δεν επιλέχθηκε εικόνα' });
    const imageUrl = req.file.publicUrl;
    return res.json({ image_url: imageUrl });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.post('/notifications/broadcast', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { title, body, audience = 'all', image_url } = req.body;

  if (!title?.trim() || !body?.trim()) {
    return res.status(400).json({ error: 'Απαιτούνται τίτλος και κείμενο' });
  }

  let imageUrl = null;
  if (image_url?.trim()) {
    imageUrl = String(image_url).trim();
  }

  let userSql = `SELECT id FROM users WHERE business_id = ? AND ${sqlActiveClients()}`;
  if (audience === 'active') {
    userSql += " AND (account_status IS NULL OR account_status = 'active')";
  }
  const [users] = await db.query(userSql, [bizId]);
  if (!users.length) {
    return res.status(400).json({ error: 'Δεν βρέθηκαν πελάτες' });
  }

  const conn = await db.getConnection();
  let sent = 0;
  try {
    await conn.beginTransaction();
    for (const u of users) {
      await createUserNotification(conn, {
        businessId: bizId,
        userId: u.id,
        type: 'announcement',
        title: title.trim(),
        body: body.trim(),
        imageUrl,
        payload: { audience },
      });
      sent += 1;
    }
    await conn.commit();
    return res.json({
      ok: true,
      sent,
      message: `Η ανακοίνωση στάλθηκε σε ${sent} πελάτες`,
      push_note: (process.env.FIREBASE_SERVICE_ACCOUNT || process.env.FCM_SERVER_KEY)
        ? 'Push εστάλη όπου υπάρχει εγγεγραμμένη συσκευή.'
        : 'FCM δεν είναι ρυθμισμένο — οι ειδοποιήσεις αποθηκεύτηκαν στην εφαρμογή.',
    });
  } catch (err) {
    await conn.rollback();
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

router.get('/payment-settings', requireClientAdmin, async (req, res) => {
  const [[row]] = await db.query(
    'SELECT payment_reminder_days, grace_period_days FROM business_configs WHERE business_id = ?',
    [req.admin.businessId]
  );
  return res.json({
    payment_reminder_days: row?.payment_reminder_days ?? 3,
    grace_period_days: row?.grace_period_days ?? 15,
  });
});

router.patch('/payment-settings', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const updates = [];
  const params = [];

  if (req.body.payment_reminder_days !== undefined) {
    const days = Number(req.body.payment_reminder_days);
    if (!Number.isFinite(days) || days < 0 || days > 60) {
      return res.status(400).json({ error: 'Οι ημέρες υπενθύμισης πρέπει να είναι 0–60' });
    }
    updates.push('payment_reminder_days = ?');
    params.push(days);
  }
  if (req.body.grace_period_days !== undefined) {
    const grace = Number(req.body.grace_period_days);
    if (!Number.isFinite(grace) || grace < 0 || grace > 90) {
      return res.status(400).json({ error: 'Η περίοδος χάριτος πρέπει να είναι 0–90 ημέρες' });
    }
    updates.push('grace_period_days = ?');
    params.push(grace);
  }
  if (!updates.length) {
    return res.status(400).json({ error: 'Δεν υπάρχουν ρυθμίσεις προς ενημέρωση' });
  }
  params.push(bizId);
  await db.query(
    `UPDATE business_configs SET ${updates.join(', ')} WHERE business_id = ?`,
    params,
  );
  const [[row]] = await db.query(
    'SELECT payment_reminder_days, grace_period_days FROM business_configs WHERE business_id = ?',
    [bizId],
  );
  return res.json({
    payment_reminder_days: row?.payment_reminder_days ?? 3,
    grace_period_days: row?.grace_period_days ?? 15,
  });
});

router.post('/payments/:id/remind', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const [[payment]] = await db.query(`
    SELECT p.*, u.full_name AS user_name
    FROM payments p
    LEFT JOIN users u ON u.id = p.user_id
    WHERE p.id = ? AND p.business_id = ?
  `, [req.params.id, bizId]);

  if (!payment) return res.status(404).json({ error: 'Η πληρωμή δεν βρέθηκε' });
  if (!payment.user_id) return res.status(400).json({ error: 'Δεν υπάρχει συνδεδεμένος πελάτης' });

  const balance = paymentBalance(payment.amount_cents, payment.paid_amount_cents || 0);
  const due = (payment.due_date || payment.period_end || '').toString().slice(0, 10);
  const title = 'Υπενθύμιση πληρωμής';
  const body = balance > 0
    ? `Οφείλετε €${(balance / 100).toFixed(2)}${due ? ` έως ${due}` : ''}. ${payment.description || ''}`.trim()
    : `Η περίοδος ${payment.description || 'συνδρομής'} λήγει${due ? ` στις ${due}` : ''}.`;

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    await createUserNotification(conn, {
      businessId: bizId,
      userId: payment.user_id,
      type: 'payment_reminder',
      title,
      body,
      payload: { payment_id: payment.id, due_date: due || null },
    });
    await conn.commit();
    return res.json({ ok: true, message: 'Η υπενθύμιση στάλθηκε' });
  } catch (err) {
    await conn.rollback();
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// ============================================================
// GET /api/client-admin/bookings/bookable-clients
// Πελάτες με πακέτο ή δοκιμαστικό (προαιρετικά για συγκεκριμένη υπηρεσία)
// ============================================================
router.get('/bookings/bookable-clients', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { service_id, q } = req.query;
  try {
    const clients = await listBookableGymClients(db, bizId, {
      serviceId: service_id || null,
      q: q || '',
    });
    return res.json(clients);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// GET /api/client-admin/clients/:userId/booking-options
router.get('/clients/:userId/booking-options', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  try {
    const options = await listClientGymBookingOptions(db, bizId, req.params.userId);
    return res.json(options);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// POST /api/client-admin/bookings
// Body: { user_id, service_id, date, time, staff_id?, use_credit?, force? }
// ============================================================
router.post('/bookings', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const {
    user_id,
    service_id,
    date,
    time,
    staff_id,
    use_credit = true,
    is_trial = false,
    force = false,
    location_id = null,
    excluded_staff_ids = [],
  } = req.body;

  if (!user_id || !service_id || !date || !time) {
    return res.status(400).json({ error: 'Απαιτούνται πελάτης, υπηρεσία, ημερομηνία και ώρα' });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const result = await createOneBooking(conn, {
      bizId,
      userId: user_id,
      service_id,
      staff_id: staff_id || null,
      date,
      time,
      use_credit: !!use_credit,
      is_trial: !!is_trial,
      force: !!force,
      source: 'admin',
      location_id: location_id || null,
      excluded_staff_ids: Array.isArray(excluded_staff_ids) ? excluded_staff_ids : [],
    });
    await conn.commit();
    return res.status(201).json(result);
  } catch (err) {
    await conn.rollback();
    let status = 400;
    if (err.code === 'SLOT_FULL' || err.code === 'TIME_CONFLICT' || err.code === 'DUPLICATE_BOOKING') {
      status = 409;
    }
    return res.status(status).json({
      error: err.message,
      code: err.code || null,
      conflicting_service: err.conflicting_service || null,
    });
  } finally {
    conn.release();
  }
});

// ============================================================
// POST /api/client-admin/bookings/drop-in
// Creates a 1-session membership + payment + booking for a single class.
// ============================================================
router.post('/bookings/drop-in', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const {
    user_id, service_id, date, time, staff_id,
    price_cents, payment_method = 'cash',
    location_id = null,
  } = req.body;

  if (!user_id || !service_id || !date || !time) {
    return res.status(400).json({ error: 'Απαιτούνται πελάτης, υπηρεσία, ημερομηνία και ώρα' });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const [[svc]] = await conn.query(
      'SELECT id, name, drop_in_price_cents FROM services WHERE id = ? AND business_id = ?',
      [service_id, bizId],
    );
    if (!svc) { await conn.rollback(); return res.status(404).json({ error: 'Υπηρεσία δεν βρέθηκε' }); }

    const finalPrice = price_cents !== undefined ? Number(price_cents) : (svc.drop_in_price_cents || 0);

    // Create a 1-session membership valid for today + 3 days
    const membershipId = uuidv4();
    const validFrom = new Date(date);
    const validUntil = new Date(date);
    validUntil.setDate(validUntil.getDate() + 3);

    await conn.query(
      `INSERT INTO user_memberships
        (id, business_id, user_id, service_id, total_sessions, used_sessions,
         valid_from, valid_until, billing_period, plan_price_cents, notes)
       VALUES (?, ?, ?, ?, 1, 0, ?, ?, 'drop_in', ?, 'Μεμονωμένη συνεδρία')`,
      [membershipId, bizId, user_id, service_id, validFrom, validUntil, finalPrice],
    );

    // Record payment
    if (finalPrice > 0) {
      await conn.query(
        `INSERT INTO payments
          (id, business_id, user_id, membership_id, amount_cents, payment_method,
           payment_type, payment_date, description)
         VALUES (?, ?, ?, ?, ?, ?, 'drop_in', CURDATE(), ?)`,
        [uuidv4(), bizId, user_id, membershipId, finalPrice, payment_method,
         `Drop-in: ${svc.name}`],
      );
    }

    // Create the booking using the new membership
    const result = await createOneBooking(conn, {
      bizId, userId: user_id, service_id,
      staff_id: staff_id || null, date, time,
      use_credit: true, is_trial: false, force: false,
      source: 'admin', location_id: location_id || null,
      excluded_staff_ids: [],
      override_membership_id: membershipId,
    });

    await conn.commit();
    return res.status(201).json({ ...result, membership_id: membershipId, price_cents: finalPrice });
  } catch (err) {
    await conn.rollback();
    let status = 400;
    if (err.code === 'SLOT_FULL' || err.code === 'TIME_CONFLICT' || err.code === 'DUPLICATE_BOOKING') status = 409;
    return res.status(status).json({ error: err.message, code: err.code || null });
  } finally {
    conn.release();
  }
});

// ============================================================
// GET /api/client-admin/bookings?date=YYYY-MM-DD
// ============================================================
// POST /client-admin/trials — create a trial booking (client optional)
router.post('/trials', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { trial_date, trial_time, service_id, staff_id, user_id, notes, new_client } = req.body;

  if (!trial_date || !trial_time) {
    return res.status(400).json({ error: 'Απαιτούνται ημερομηνία και ώρα' });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    let resolvedUserId = user_id || null;
    if (!resolvedUserId && new_client?.full_name) {
      const newUserId = uuidv4();
      await conn.query(
        'INSERT INTO users (id, business_id, full_name, phone, account_status) VALUES (?, ?, ?, ?, ?)',
        [newUserId, bizId, new_client.full_name.trim(), new_client.phone?.trim() || null, 'active']
      );
      resolvedUserId = newUserId;
    }

    let svc = null;
    if (service_id) {
      const [[row]] = await conn.query('SELECT name, category FROM services WHERE id = ? AND business_id = ?', [service_id, bizId]);
      svc = row || null;
    }

    const bookingId = uuidv4();
    const startsAt = new Date(`${trial_date}T${trial_time}`);
    const durationMins = svc ? (svc.duration_mins || 60) : 60;
    const endsAt = new Date(startsAt.getTime() + durationMins * 60000);

    await conn.query(
      `INSERT INTO bookings (id, business_id, user_id, service_id, staff_id, starts_at, ends_at, status, source, is_trial, notes)
       VALUES (?, ?, ?, ?, ?, ?, ?, 'confirmed', 'admin', 1, ?)`,
      [bookingId, bizId, resolvedUserId, service_id || null, staff_id || null, startsAt, endsAt, notes?.trim() || null]
    );

    // If user provided, also create trial membership
    if (resolvedUserId && service_id) {
      const membershipId = uuidv4();
      const noteText = notes?.trim() || `Δοκιμαστικό${svc ? ` — ${svc.name}` : ''} (${trial_date} ${trial_time})`;
      await conn.query(`
        INSERT INTO user_memberships
          (id, user_id, business_id, service_id, service_category, total_sessions, used_sessions,
           valid_from, valid_until, notes, membership_status, trial_booking_id)
        VALUES (?, ?, ?, ?, ?, 0, 0, ?, ?, ?, 'trial', ?)
      `, [membershipId, resolvedUserId, bizId, service_id, svc?.category || null,
          trial_date, trial_date, noteText, bookingId]);
    }

    await conn.commit();
    return res.status(201).json({ booking_id: bookingId, message: 'Το δοκιμαστικό καταχωρήθηκε' });
  } catch (err) {
    await conn.rollback();
    return res.status(400).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// GET /client-admin/expiring-memberships?days=3
router.get('/expiring-memberships', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const days = parseInt(req.query.days || '3', 10);
  try {
    const [rows] = await db.query(`
      SELECT
        m.id AS membership_id,
        m.valid_until,
        m.total_sessions,
        m.used_sessions,
        m.membership_status,
        m.service_category,
        u.id AS user_id,
        u.full_name,
        u.phone,
        u.email,
        p.name       AS plan_name,
        p.price_cents AS plan_price,
        sv.name AS service_name
      FROM user_memberships m
      JOIN users u ON u.id = m.user_id
      LEFT JOIN business_plans p ON p.id = m.plan_id
      LEFT JOIN services sv ON sv.id = m.service_id
      WHERE m.business_id = ?
        AND m.membership_status NOT IN ('trial', 'cancelled')
        AND m.valid_until BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL ? DAY)
        AND u.deleted_at IS NULL
      ORDER BY m.valid_until ASC, u.full_name ASC
    `, [bizId, days]);
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// GET /client-admin/trials
router.get('/trials', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  try {
    const whereClauses = ['b.business_id = ?', "b.is_trial = 1", "b.status != 'cancelled'"];
    const params = [bizId];
    if (req.query.from) { whereClauses.push('DATE(b.starts_at) >= ?'); params.push(req.query.from); }
    if (req.query.to)   { whereClauses.push('DATE(b.starts_at) <= ?'); params.push(req.query.to); }
    const [rows] = await db.query(`
      SELECT b.id, b.starts_at, b.ends_at, b.status, b.notes,
             b.user_id, b.service_id, b.staff_id,
             b.trial_became_member, b.trial_considering,
             u.full_name AS user_name, u.phone AS user_phone,
             s.name AS service_name,
             st.full_name AS staff_name, st.avatar_url AS staff_avatar, st.color_hex AS staff_color
      FROM bookings b
      LEFT JOIN users u ON u.id = b.user_id
      LEFT JOIN services s ON s.id = b.service_id
      LEFT JOIN staff st ON st.id = b.staff_id
      WHERE ${whereClauses.join(' AND ')}
      ORDER BY b.starts_at DESC
      LIMIT 500
    `, params);
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// PATCH /client-admin/trials/:id — edit date/time/service/staff/notes/user_id
router.patch('/trials/:id', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { id } = req.params;
  const { trial_date, trial_time, service_id, staff_id, notes, user_id, new_client } = req.body;
  try {
    const [[booking]] = await db.query(
      'SELECT id FROM bookings WHERE id = ? AND business_id = ? AND is_trial = 1',
      [id, bizId]
    );
    if (!booking) return res.status(404).json({ error: 'Δεν βρέθηκε' });

    const updates = [];
    const params = [];

    if (trial_date && trial_time) {
      const startsAt = new Date(`${trial_date}T${trial_time}`);
      const endsAt = new Date(startsAt.getTime() + 60 * 60000);
      updates.push('starts_at = ?', 'ends_at = ?');
      params.push(startsAt, endsAt);
    }
    if (service_id !== undefined) { updates.push('service_id = ?'); params.push(service_id || null); }
    if (staff_id !== undefined) { updates.push('staff_id = ?'); params.push(staff_id || null); }
    if (notes !== undefined) { updates.push('notes = ?'); params.push(notes?.trim() || null); }

    // Link existing client or create new
    let resolvedUserId = user_id;
    if (new_client?.full_name) {
      const { v4: uuidv4 } = require('uuid');
      const newId = uuidv4();
      await db.query(
        'INSERT INTO users (id, business_id, full_name, phone, account_status) VALUES (?, ?, ?, ?, ?)',
        [newId, bizId, new_client.full_name.trim(), new_client.phone?.trim() || null, 'active']
      );
      resolvedUserId = newId;
    }
    if (resolvedUserId !== undefined) {
      updates.push('user_id = ?');
      params.push(resolvedUserId || null);
    }

    if (updates.length) {
      params.push(id, bizId);
      await db.query(`UPDATE bookings SET ${updates.join(', ')} WHERE id = ? AND business_id = ?`, params);
    }
    return res.json({ message: 'Ενημερώθηκε', user_id: resolvedUserId || null });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// DELETE /client-admin/trials/:id
router.delete('/trials/:id', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { id } = req.params;
  try {
    const [[booking]] = await db.query(
      'SELECT id FROM bookings WHERE id = ? AND business_id = ? AND is_trial = 1',
      [id, bizId]
    );
    if (!booking) return res.status(404).json({ error: 'Δεν βρέθηκε' });
    await db.query("UPDATE bookings SET status = 'cancelled' WHERE id = ?", [id]);
    return res.json({ message: 'Διαγράφηκε' });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// PATCH /client-admin/trials/:id/refer — set referred_by_staff_id + trial_became_member + trial_considering
// Accepts optional new_client: { full_name, phone } to auto-create user when becoming member
router.patch('/trials/:id/refer', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { id } = req.params;
  const { referred_by_staff_id, trial_became_member, new_client } = req.body;
  try {
    const [[booking]] = await db.query(
      'SELECT id, user_id FROM bookings WHERE id = ? AND business_id = ? AND is_trial = 1',
      [id, bizId]
    );
    if (!booking) return res.status(404).json({ error: 'Δεν βρέθηκε' });

    const updates = [];
    const params = [];

    // Auto-create client if becoming member and no user linked
    let createdUserId = null;
    if (trial_became_member && !booking.user_id && new_client?.full_name) {
      const { v4: uuidv4 } = require('uuid');
      createdUserId = uuidv4();
      await db.query(
        'INSERT INTO users (id, business_id, full_name, phone, account_status) VALUES (?, ?, ?, ?, ?)',
        [createdUserId, bizId, new_client.full_name.trim(), new_client.phone?.trim() || null, 'active']
      );
      updates.push('user_id = ?');
      params.push(createdUserId);
    }

    if (referred_by_staff_id !== undefined) {
      updates.push('referred_by_staff_id = ?');
      params.push(referred_by_staff_id || null);
    }
    if (trial_became_member !== undefined) {
      updates.push('trial_became_member = ?');
      params.push(trial_became_member ? 1 : 0);
    }
    if (req.body.trial_considering !== undefined) {
      updates.push('trial_considering = ?');
      params.push(req.body.trial_considering ? 1 : 0);
    }
    if (!updates.length) return res.json({ message: 'Κανένα update' });
    params.push(id, bizId);
    await db.query(`UPDATE bookings SET ${updates.join(', ')} WHERE id = ? AND business_id = ?`, params);
    return res.json({ message: 'Ενημερώθηκε', created_user_id: createdUserId });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.get('/bookings', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  try {
    let q = `
      ${BOOKING_ENRICHED_SELECT}
      ${BOOKING_ENRICHED_FROM}
      WHERE b.business_id = ?
    `;
    const params = [bizId];

    if (req.query.date) { q += ' AND DATE(b.starts_at) = ?'; params.push(req.query.date); }
    if (req.query.location_id) { q += ' AND b.location_id = ?'; params.push(req.query.location_id); }
    if (req.query.id) { q += ' AND b.id = ?'; params.push(req.query.id); }
    if (req.query.user_id) { q += ' AND b.user_id = ?'; params.push(req.query.user_id); }
    if (req.query.from) { q += ' AND DATE(b.starts_at) >= ?'; params.push(req.query.from); }
    if (req.query.to) { q += ' AND DATE(b.starts_at) <= ?'; params.push(req.query.to); }
    if (req.query.q) {
      const term = `%${String(req.query.q).trim()}%`;
      q += ' AND (u.full_name LIKE ? OR u.phone LIKE ? OR COALESCE(u.email, \'\') LIKE ?)';
      params.push(term, term, term);
    }
    q += ` AND ${sqlGymServiceCategories('sv')}`;
    q += ' ORDER BY b.starts_at ASC';

    const [rows] = await db.query(q, params);
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// PATCH /api/client-admin/bookings/:id/status
// ============================================================
router.patch('/bookings/:id/status', requireClientAdmin, async (req, res) => {
  const { status } = req.body;
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const [[booking]] = await conn.query(`
      SELECT b.*, sv.name AS service_name
      FROM bookings b
      JOIN services sv ON sv.id = b.service_id
      WHERE b.id = ? AND b.business_id = ?
    `, [req.params.id, req.admin.businessId]);
    if (!booking) {
      await conn.rollback();
      return res.status(404).json({ error: 'Η κράτηση δεν βρέθηκε' });
    }

    await conn.query('UPDATE bookings SET status=? WHERE id=? AND business_id=?',
      [status, req.params.id, req.admin.businessId]);

    if (status === 'confirmed' && booking.status === 'pending' && booking.membership_id) {
      await chargeBookingMembershipOnConfirm(conn, booking);
      const { createUserNotification } = require('../lib/user_notifications');
      const when = new Date(booking.starts_at);
      const date = when.toISOString().slice(0, 10);
      const time = when.toTimeString().slice(0, 5);
      await createUserNotification(conn, {
        businessId: req.admin.businessId,
        userId: booking.user_id,
        bookingId: booking.id,
        type: 'booking_confirmed',
        title: `Κράτηση επιβεβαιώθηκε — ${booking.service_name}`,
        body: `Στις ${date} ${time}.`,
        payload: { action: 'open_booking', booking_id: booking.id },
        sendPush: true,
      });
    }

    if (['cancelled', 'no_show'].includes(status) && !['cancelled', 'no_show'].includes(booking.status)) {
      await notifyWaitlistOnCancel(
        conn, req.admin.businessId, booking.service_id, booking.starts_at, booking.service_name
      );
    }

    await conn.commit();
    return res.json({ ok: true });
  } catch (err) {
    await conn.rollback();
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// PATCH /api/client-admin/bookings/:id/attendance — επιβεβαίωση παρουσίας (χειροκίνητα από διαχειριστή)
router.patch('/bookings/:id/attendance', requireClientAdmin, async (req, res) => {
  const { attended = true } = req.body;
  const bizId = req.admin.businessId;
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const [[booking]] = await conn.query(
      'SELECT * FROM bookings WHERE id = ? AND business_id = ?',
      [req.params.id, bizId],
    );
    if (!booking) {
      await conn.rollback();
      return res.status(404).json({ error: 'Η κράτηση δεν βρέθηκε' });
    }
    if (booking.attendance_confirmed) {
      await conn.rollback();
      return res.status(409).json({ error: 'Η παρουσία έχει ήδη επιβεβαιωθεί' });
    }
    if (['cancelled'].includes(booking.status)) {
      await conn.rollback();
      return res.status(400).json({ error: 'Η κράτηση είναι ακυρωμένη' });
    }

    if (attended) {
      await conn.query(
        `UPDATE bookings SET attendance_confirmed = 1, attendance_confirmed_at = NOW(), status = 'completed'
         WHERE id = ? AND business_id = ?`,
        [req.params.id, bizId],
      );
    } else {
      await conn.query(
        `UPDATE bookings SET status = 'no_show' WHERE id = ? AND business_id = ?`,
        [req.params.id, bizId],
      );
      await refundBookingMembershipOnRemove(conn, { ...booking, status: booking.status });
    }

    await conn.commit();
    return res.json({ ok: true });
  } catch (err) {
    await conn.rollback();
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// DELETE /api/client-admin/bookings/:id — οριστική διαγραφή κράτησης
router.delete('/bookings/:id', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const deleted = await deleteBookingForBusiness(conn, bizId, req.params.id);
    if (!deleted) {
      await conn.rollback();
      return res.status(404).json({ error: 'Η κράτηση δεν βρέθηκε' });
    }
    await conn.commit();
    return res.json({ ok: true, message: 'Η κράτηση διαγράφηκε' });
  } catch (err) {
    await conn.rollback();
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

function addDaysToDateStr(dateStr, days) {
  const d = new Date(`${dateStr}T12:00:00`);
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
}

function countBookableSlots(computed, date, featureWaitlist) {
  const payload = buildSlotsPayload(computed, { featureWaitlist, date });
  return payload.slots.filter(s => s.available_staff?.length > 0 && !s.is_full).length;
}

// ============================================================
// GET /api/client-admin/booking-available-dates?service_id=&from=&days=
// Returns per-day availability for trial / booking date pickers
// ============================================================
router.get('/booking-available-dates', requireClientAdmin, async (req, res) => {
  const { service_id, from, days: daysRaw, location_id } = req.query;
  if (!service_id) {
    return res.status(400).json({ error: 'Απαιτείται υπηρεσία' });
  }
  const bizId = req.admin.businessId;
  const startDate = from || new Date().toISOString().slice(0, 10);
  const numDays = Math.min(60, Math.max(1, Number(daysRaw) || 21));

  try {
    const [[cfg]] = await db.query(
      'SELECT feature_waitlist FROM business_configs WHERE business_id = ?',
      [bizId]
    );
    const featureWaitlist = !!cfg?.feature_waitlist;
    const dates = [];
    const locId = location_id || await getDefaultLocationId(db, bizId);

    for (let i = 0; i < numDays; i++) {
      const date = addDaysToDateStr(startDate, i);
      const computed = await computeAvailableSlots(db, bizId, service_id, date, null, locId);
      if (!computed) continue;

      let status = 'available';
      let message = null;
      let slotCount = 0;
      let selectable = false;

      if (computed.closedReason) {
        status = 'closed';
        message = computed.closedReason === 'closure'
          ? 'Αποκλεισμός / κλειστό'
          : 'Κλειστό (ωράριο)';
      } else if (!computed.staffPoolNames.length && !computed.scheduleByTime?.size) {
        status = 'no_availability';
        message = 'Χωρίς διαθεσιμότητα προσωπικού';
      } else {
        slotCount = countBookableSlots(computed, date, featureWaitlist);
        if (slotCount === 0) {
          status = 'no_slots';
          message = 'Δεν υπάρχουν ελεύθερες ώρες';
        } else {
          selectable = true;
        }
      }

      dates.push({ date, status, message, slot_count: slotCount, selectable });
    }

    return res.json({ dates, from: startDate, days: numDays, service_id });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// GET /api/client-admin/booking-slots?service_id=&date=&exclude_booking_id=
// ============================================================
router.get('/booking-slots', requireClientAdmin, async (req, res) => {
  const { service_id, date, exclude_booking_id, location_id } = req.query;
  if (!service_id || !date) {
    return res.status(400).json({ error: 'Απαιτούνται υπηρεσία και ημερομηνία' });
  }
  try {
    const locId = location_id || await getDefaultLocationId(db, req.admin.businessId);
    const computed = await computeAvailableSlots(
      db, req.admin.businessId, service_id, date, exclude_booking_id, locId
    );
    if (!computed) return res.status(404).json({ error: 'Η υπηρεσία δεν βρέθηκε' });

    if (computed.closedReason) {
      return res.json({
        slots: [],
        day_status: 'closed',
        message: 'Το γυμναστήριο είναι κλειστό αυτή την ημέρα.',
        date,
        service_id,
      });
    }
    if (!computed.staffPoolNames.length && !computed.scheduleByTime?.size) {
      return res.json({
        slots: [],
        day_status: 'no_availability',
        message: 'Δεν υπάρχουν διαθέσιμες ώρες για αυτή την υπηρεσία αυτή την ημέρα.',
        date,
        service_id,
      });
    }

    const [[cfg]] = await db.query(
      'SELECT feature_waitlist FROM business_configs WHERE business_id = ?',
      [req.admin.businessId]
    );
    const payload = buildSlotsPayload(computed, {
      featureWaitlist: !!cfg?.feature_waitlist,
      date,
    });
    const [serviceStaff] = await db.query(`
      SELECT s.id, s.full_name, s.role, s.color_hex, s.avatar_url
      FROM staff s
      JOIN staff_services ss ON ss.staff_id = s.id AND ss.service_id = ?
      WHERE s.business_id = ? AND s.is_active = 1
        AND COALESCE(s.is_nutritionist, 0) = 0
      ORDER BY s.full_name
    `, [service_id, req.admin.businessId]);
    const response = {
      ...payload,
      date,
      service_id,
      feature_waitlist: !!cfg?.feature_waitlist,
      service_staff: serviceStaff,
    };
    if (!payload.slots.length) {
      response.day_status = 'no_slots';
      response.message = 'Δεν υπάρχουν διαθέσιμες ώρες για αυτή την ημέρα.';
    }
    return res.json(response);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// PATCH /api/client-admin/bookings/:id
// Επεξεργασία κράτησης: ημερομηνία, ώρα, γυμναστής, κατάσταση
// ============================================================
router.patch('/bookings/:id', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { date, time, staff_id, status } = req.body;

  if (!date || !time || !staff_id) {
    return res.status(400).json({ error: 'Απαιτούνται ημερομηνία, ώρα και γυμναστής' });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const [[booking]] = await conn.query(`
      SELECT b.*, sv.duration_mins
      FROM bookings b
      JOIN services sv ON sv.id = b.service_id
      WHERE b.id = ? AND b.business_id = ?
    `, [req.params.id, bizId]);
    if (!booking) {
      await conn.rollback();
      return res.status(404).json({ error: 'Η κράτηση δεν βρέθηκε' });
    }

    const [[staffOk]] = await conn.query(`
      SELECT s.id FROM staff s
      JOIN staff_services ss ON ss.staff_id = s.id AND ss.service_id = ?
      WHERE s.id = ? AND s.business_id = ? AND s.is_active = 1
    `, [booking.service_id, staff_id, bizId]);
    if (!staffOk) {
      await conn.rollback();
      return res.status(400).json({ error: 'Ο γυμναστής δεν είναι έγκυρος για αυτή την υπηρεσία' });
    }

    const startsAt = new Date(`${date}T${time}:00`);
    const endsAt   = new Date(startsAt.getTime() + booking.duration_mins * 60000);
    const force = !!req.body.force;

    await assertSlotCapacity(
      conn, bizId, booking.service_id, date, time, startsAt, endsAt, booking.id, force
    );
    await assertStaffAvailable(
      conn, bizId, staff_id, booking.service_id, startsAt, endsAt, booking.id
    );

    await conn.query(`
      UPDATE bookings SET
        staff_id = ?,
        starts_at = ?,
        ends_at = ?,
        status = COALESCE(?, status)
      WHERE id = ? AND business_id = ?
    `, [staff_id, startsAt, endsAt, status || null, booking.id, bizId]);

    await conn.commit();
    return res.json({ ok: true, starts_at: startsAt, ends_at: endsAt });
  } catch (err) {
    await conn.rollback();
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// ============================================================
// BUSINESS PLANS (ανεξάρτητα πλάνα επιχείρησης)
// ============================================================

router.get('/plans', requireClientAdmin, async (req, res) => {
  const type = req.query.type || 'service';
  const [rows] = await db.query(
    `SELECT bp.*, s.name AS service_name
     FROM business_plans bp
     LEFT JOIN services s ON s.id = bp.service_id
     WHERE bp.business_id = ? AND bp.plan_type = ?
     ORDER BY bp.sort_order, bp.price_cents`,
    [req.admin.businessId, type]
  );
  // Attach service_items for combo plans
  const planIds = rows.map(r => r.id);
  let itemsByPlan = {};
  if (planIds.length) {
    const placeholders = planIds.map(() => '?').join(',');
    const [items] = await db.query(
      `SELECT psi.*, s.name AS service_name
       FROM plan_service_items psi
       JOIN services s ON s.id = psi.service_id
       WHERE psi.plan_id IN (${placeholders})
       ORDER BY psi.sort_order`,
      planIds
    );
    for (const item of items) {
      if (!itemsByPlan[item.plan_id]) itemsByPlan[item.plan_id] = [];
      itemsByPlan[item.plan_id].push(item);
    }
  }
  return res.json(rows.map(r => ({ ...r, service_items: itemsByPlan[r.id] || [] })));
});

router.post('/plans', requireClientAdmin, async (req, res) => {
  const {
    service_id,
    service_items,   // array of {service_id, sessions, duration_mins} for combo plans
    name: customName,
    sessions,
    duration_mins,
    price_cents,
    billing_period = 'monthly',
    sort_order = 0,
  } = req.body;

  if (price_cents === undefined) {
    return res.status(400).json({ error: 'Απαιτείται τιμή' });
  }

  const bizId = req.admin.businessId;
  const isCombo = Array.isArray(service_items) && service_items.length > 1;

  if (isCombo) {
    // Combo plan — multiple services
    if (!customName) return res.status(400).json({ error: 'Απαιτείται όνομα για combo πακέτο' });
    const id = uuidv4();
    await db.query(
      `INSERT INTO business_plans
        (id, business_id, service_id, plan_type, name, sessions, duration_mins, price_cents, billing_period, sort_order, includes_nutrition)
       VALUES (?,?,NULL,'service',?,NULL,NULL,?,?,?,0)`,
      [id, bizId, customName, price_cents, billing_period, sort_order]
    );
    for (let i = 0; i < service_items.length; i++) {
      const item = service_items[i];
      const sessVal = normalizePlanSessions(item.sessions === '' ? null : item.sessions);
      await db.query(
        `INSERT INTO plan_service_items (id, plan_id, service_id, sessions, duration_mins, sort_order) VALUES (?,?,?,?,?,?)`,
        [uuidv4(), id, item.service_id, sessVal, item.duration_mins || null, i]
      );
      await db.query(
        'INSERT IGNORE INTO service_plan_assignments (service_id, plan_id) VALUES (?,?)',
        [item.service_id, id]
      );
    }
    return res.status(201).json({ id, name: customName });
  }

  // Single-service plan (existing behavior)
  if (!service_id) return res.status(400).json({ error: 'Απαιτούνται υπηρεσία και τιμή' });
  const [[svc]] = await db.query(
    'SELECT id, name FROM services WHERE id=? AND business_id=?',
    [service_id, bizId]
  );
  if (!svc) return res.status(404).json({ error: 'Η υπηρεσία δεν βρέθηκε' });

  const sessionsVal = normalizePlanSessions(sessions === undefined ? undefined : sessions);
  const durationVal = sessionsVal === null || duration_mins === '' || duration_mins === undefined
    ? null : Number(duration_mins);
  const name = buildServicePlanName(svc.name, { sessions: sessionsVal, duration_mins: durationVal, billing_period, price_cents });

  const id = uuidv4();
  await db.query(
    `INSERT INTO business_plans
      (id, business_id, service_id, plan_type, name, sessions, duration_mins, price_cents, billing_period, sort_order, includes_nutrition)
     VALUES (?,?,?,?,?,?,?,?,?,?,0)`,
    [id, bizId, service_id, 'service', name, sessionsVal, durationVal, price_cents, billing_period, sort_order]
  );
  await db.query(
    'INSERT IGNORE INTO service_plan_assignments (service_id, plan_id) VALUES (?,?)',
    [service_id, id]
  );
  return res.status(201).json({ id, name });
});

router.patch('/plans/:id', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { service_id, service_items, name: customName, sessions, duration_mins, price_cents, billing_period, is_active } = req.body;

  // Combo plan update
  if (Array.isArray(service_items) && service_items.length > 1) {
    const [[existing]] = await db.query('SELECT id FROM business_plans WHERE id=? AND business_id=?', [req.params.id, bizId]);
    if (!existing) return res.status(404).json({ error: 'Το πλάνο δεν βρέθηκε' });
    await db.query('UPDATE business_plans SET name=?, price_cents=COALESCE(?,price_cents), billing_period=COALESCE(?,billing_period), service_id=NULL WHERE id=?',
      [customName, price_cents, billing_period, req.params.id]);
    await db.query('DELETE FROM plan_service_items WHERE plan_id=?', [req.params.id]);
    await db.query('DELETE FROM service_plan_assignments WHERE plan_id=?', [req.params.id]);
    for (let i = 0; i < service_items.length; i++) {
      const item = service_items[i];
      const sessVal = normalizePlanSessions(item.sessions === '' ? null : item.sessions);
      await db.query('INSERT INTO plan_service_items (id, plan_id, service_id, sessions, duration_mins, sort_order) VALUES (?,?,?,?,?,?)',
        [uuidv4(), req.params.id, item.service_id, sessVal, item.duration_mins || null, i]);
      await db.query('INSERT IGNORE INTO service_plan_assignments (service_id, plan_id) VALUES (?,?)', [item.service_id, req.params.id]);
    }
    return res.json({ ok: true, name: customName });
  }

  const [[existing]] = await db.query(
    'SELECT * FROM business_plans WHERE id=? AND business_id=? AND plan_type=?',
    [req.params.id, bizId, 'service']
  );
  if (!existing) return res.status(404).json({ error: 'Το πλάνο δεν βρέθηκε' });

  const nextServiceId = service_id || existing.service_id;
  const [[svc]] = nextServiceId
    ? await db.query('SELECT id, name FROM services WHERE id=? AND business_id=?', [nextServiceId, bizId])
    : [[]];
  if (nextServiceId && !svc) return res.status(404).json({ error: 'Η υπηρεσία δεν βρέθηκε' });

  const sessionsVal = sessions === undefined
    ? normalizePlanSessions(existing.sessions)
    : normalizePlanSessions(sessions === '' ? null : sessions);
  const durationVal = sessionsVal === null || duration_mins === ''
    ? null
    : duration_mins === undefined ? existing.duration_mins : Number(duration_mins);
  const nextPrice = price_cents === undefined ? existing.price_cents : price_cents;
  const nextPeriod = billing_period || existing.billing_period;
  const name = svc
    ? buildServicePlanName(svc.name, {
      sessions: sessionsVal,
      duration_mins: durationVal,
      billing_period: nextPeriod,
      price_cents: nextPrice,
    })
    : existing.name;

  await db.query(
    `UPDATE business_plans SET
      service_id=COALESCE(?, service_id),
      name=?,
      sessions=?,
      duration_mins=?,
      price_cents=COALESCE(?, price_cents),
      billing_period=COALESCE(?, billing_period),
      is_active=COALESCE(?, is_active)
    WHERE id=? AND business_id=?`,
    [service_id || null, name, sessionsVal, durationVal, price_cents, billing_period, is_active,
     req.params.id, bizId]
  );

  if (nextServiceId) {
    await db.query('DELETE FROM service_plan_assignments WHERE plan_id=?', [req.params.id]);
    await db.query(
      'INSERT IGNORE INTO service_plan_assignments (service_id, plan_id) VALUES (?,?)',
      [nextServiceId, req.params.id]
    );
  }
  return res.json({ ok: true, name });
});

router.delete('/plans/:id', requireClientAdmin, async (req, res) => {
  await db.query('DELETE FROM plan_service_items WHERE plan_id=?', [req.params.id]);
  await db.query('DELETE FROM business_plans WHERE id=? AND business_id=?',
    [req.params.id, req.admin.businessId]);
  return res.json({ ok: true });
});

// GET package options: one row per service+linked gym plan (όχι χειροκίνητα / διατροφή)
router.get('/package-options', requireClientAdmin, async (req, res) => {
  try {
    const bizId = req.admin.businessId;
    const [[cfg]] = await db.query(
      'SELECT nutrition_consultation_service_id FROM business_configs WHERE business_id=?',
      [bizId]
    );
    const excludeServiceId = cfg?.nutrition_consultation_service_id || null;

    const params = [bizId, bizId];
    let excludeClause = '';
    if (excludeServiceId) {
      excludeClause = 'AND s.id != ?';
      params.push(excludeServiceId);
    }

    const [rows] = await db.query(
      `SELECT bp.id AS plan_id, bp.name AS plan_name, bp.sessions, bp.price_cents, bp.billing_period,
              MIN(s.id) AS service_id,
              GROUP_CONCAT(DISTINCT s.name ORDER BY s.name SEPARATOR ' + ') AS service_name,
              MIN(s.category) AS service_category,
              MIN(s.image_url) AS service_image_url
       FROM business_plans bp
       INNER JOIN service_plan_assignments spa ON spa.plan_id = bp.id
       INNER JOIN services s ON s.id = spa.service_id AND s.business_id = ? AND s.is_active = 1
         AND (s.category IS NULL OR s.category NOT IN ('nutrition', 'nutrition_consultation'))
       WHERE bp.business_id = ? AND bp.is_active = 1
         AND (bp.plan_type IS NULL OR bp.plan_type = 'service')
         ${excludeClause}
       GROUP BY bp.id, bp.name, bp.sessions, bp.price_cents, bp.billing_period
       ORDER BY bp.sort_order, bp.price_cents`,
      params
    );

    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// GET plan → service mapping (for the add-package modal)
router.get('/plans/service-mapping', requireClientAdmin, async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT bp.id AS plan_id, s.id AS service_id, s.name AS service_name
      FROM business_plans bp
      LEFT JOIN service_plan_assignments spa ON spa.plan_id = bp.id
      LEFT JOIN services s ON s.id = spa.service_id
      WHERE bp.business_id = ?
    `, [req.admin.businessId]);

    const mapping = {};
    rows.forEach(r => {
      if (!mapping[r.plan_id] && r.service_id) {
        mapping[r.plan_id] = { service_id: r.service_id, service_name: r.service_name };
      }
    });
    return res.json(mapping);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// GET plans assigned to a service
router.get('/services/:serviceId/plans', requireClientAdmin, async (req, res) => {
  const [rows] = await db.query(
    `SELECT bp.* FROM business_plans bp
     JOIN service_plan_assignments spa ON spa.plan_id=bp.id
     WHERE spa.service_id=? AND bp.business_id=? AND bp.is_active=1
     ORDER BY bp.sort_order, bp.price_cents`,
    [req.params.serviceId, req.admin.businessId]
  );
  return res.json(rows);
});

// GET assigned plan IDs for a service
router.get('/services/:serviceId/plan-ids', requireClientAdmin, async (req, res) => {
  const [rows] = await db.query(
    'SELECT plan_id FROM service_plan_assignments WHERE service_id=?',
    [req.params.serviceId]
  );
  return res.json(rows.map(r => r.plan_id));
});

// PUT assign plans to service (replace all)
router.put('/services/:serviceId/plans', requireClientAdmin, async (req, res) => {
  const { plan_ids = [] } = req.body;
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    await conn.query('DELETE FROM service_plan_assignments WHERE service_id=?', [req.params.serviceId]);
    for (const pid of plan_ids) {
      await conn.query('INSERT IGNORE INTO service_plan_assignments (service_id, plan_id) VALUES (?,?)',
        [req.params.serviceId, pid]);
    }
    await conn.commit();
    return res.json({ ok: true });
  } catch (err) {
    await conn.rollback();
    return res.status(500).json({ error: err.message });
  } finally { conn.release(); }
});

// ============================================================
// POST /api/client-admin/clients — Create client (by gym owner)
// ============================================================
router.post('/clients', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const {
    full_name, email, phone, pin,
    date_of_birth, weight_kg, fitness_goal, trainer_notes, notes, referred_by_user_id,
  } = req.body;
  if (!full_name || !phone) {
    return res.status(400).json({ error: 'Απαιτούνται: full_name, phone' });
  }

  // PIN: explicit 4-digit or auto from last 4 of phone
  const normalizedPhone = String(phone).replace(/[\s\-().]/g, '');
  const effectivePin = pin ? String(pin) : normalizedPhone.slice(-4);
  if (!/^\d{4}$/.test(effectivePin)) {
    return res.status(400).json({ error: 'Το PIN πρέπει να είναι 4 ψηφία' });
  }

  let normalizedWeight;
  let normalizedGoal;
  try {
    normalizedWeight = normalizeWeight(weight_kg);
    normalizedGoal = normalizeFitnessGoal(fitness_goal);
  } catch (err) {
    return res.status(400).json({ error: err.message });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const id   = uuidv4();
    const hash = await bcrypt.hash(effectivePin, 10);

    const effectiveEmail = email?.trim() || null;
    await conn.query(
      `INSERT INTO users
        (id, business_id, full_name, email, phone, auth_uid, account_status,
         date_of_birth, weight_kg, fitness_goal, trainer_notes, notes, referred_by_user_id)
       VALUES (?,?,?,?,?,?, 'active',?,?,?,?,?,?)`,
      [
        id, bizId, full_name.trim(), effectiveEmail, phone || null, id,
        date_of_birth || null,
        normalizedWeight ?? null,
        normalizedGoal ?? null,
        trainer_notes || null,
        notes || null,
        referred_by_user_id || null,
      ]
    );
    await conn.query(
      'INSERT INTO user_passwords (user_id, password_hash) VALUES (?,?)',
      [id, hash]
    );
    await conn.commit();
    return res.status(201).json({ id, message: 'Ο πελάτης δημιουργήθηκε' });
  } catch (err) {
    await conn.rollback();
    if (err.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: 'Το email χρησιμοποιείται ήδη' });
    return res.status(500).json({ error: err.message });
  } finally { conn.release(); }
});

// ============================================================
// SERVICES CRUD
// ============================================================
router.get('/services', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const [rows] = await db.query(
    `SELECT s.*,
      (SELECT GROUP_CONCAT(l.name ORDER BY l.sort_order, l.name SEPARATOR ', ')
       FROM service_locations sl
       JOIN locations l ON l.id = sl.location_id
       WHERE sl.service_id = s.id) AS location_names,
      (SELECT COUNT(*) FROM service_locations sl WHERE sl.service_id = s.id) AS location_count
     FROM services s
     WHERE s.business_id = ?
     ORDER BY s.category, s.name`,
    [bizId],
  );
  return res.json(rows);
});

router.post('/services', requireClientAdmin, async (req, res) => {
  const {
    name, description, duration_mins, price_cents, category,
    hide_staff_selection, slot_label_mode, location_ids,
  } = req.body;
  if (!name || !duration_mins) return res.status(400).json({ error: 'Απαιτούνται όνομα και διάρκεια' });
  const id = uuidv4();
  await db.query(
    `INSERT INTO services
      (id, business_id, name, description, duration_mins, price_cents, category, hide_staff_selection, slot_label_mode)
     VALUES (?,?,?,?,?,?,?,?,?)`,
    [id, req.admin.businessId, name, description || null, duration_mins, price_cents || 0,
     category || null, hide_staff_selection ? 1 : 0, slot_label_mode || 'time_only']
  );
  if (Array.isArray(location_ids) && location_ids.length) {
    await replaceServiceLocations(db, id, location_ids);
  }
  return res.status(201).json({ id });
});

router.patch('/services/:id', requireClientAdmin, async (req, res) => {
  const { name, description, duration_mins, price_cents, drop_in_price_cents, category, is_active,
          hide_staff_selection, slot_label_mode, icon_svg_url, image_url,
          requires_attendance_confirmation, requires_qr_scan } = req.body;
  const hideVal = hide_staff_selection === undefined ? undefined : (hide_staff_selection ? 1 : 0);
  const dropIn = drop_in_price_cents === null ? null : (drop_in_price_cents !== undefined ? Number(drop_in_price_cents) : undefined);
  const attConf = requires_attendance_confirmation === undefined ? undefined : (requires_attendance_confirmation ? 1 : 0);
  const qrScan  = requires_qr_scan === undefined ? undefined : (requires_qr_scan ? 1 : 0);
  await db.query(
    `UPDATE services SET
      name          = COALESCE(?,name),
      description   = COALESCE(?,description),
      duration_mins = COALESCE(?,duration_mins),
      price_cents   = COALESCE(?,price_cents),
      drop_in_price_cents = CASE WHEN ? IS NOT NULL THEN ? ELSE drop_in_price_cents END,
      category      = COALESCE(?,category),
      is_active     = COALESCE(?,is_active),
      hide_staff_selection = COALESCE(?, hide_staff_selection),
      slot_label_mode = COALESCE(?, slot_label_mode),
      requires_attendance_confirmation = COALESCE(?, requires_attendance_confirmation),
      requires_qr_scan = COALESCE(?, requires_qr_scan),
      icon_svg_url  = CASE WHEN ? IS NOT NULL THEN ? ELSE icon_svg_url END,
      image_url     = CASE WHEN ? IS NOT NULL THEN ? ELSE image_url END
    WHERE id=? AND business_id=?`,
    [name, description, duration_mins, price_cents, dropIn, dropIn, category, is_active, hideVal, slot_label_mode,
     attConf, qrScan,
     icon_svg_url, icon_svg_url, image_url, image_url,
     req.params.id, req.admin.businessId]
  );
  return res.json({ ok: true });
});

router.post('/services/:id/image', requireClientAdmin, (req, res, next) => {
  servicePhotoUpload.single('image')(req, res, (err) => {
    if (err) return res.status(400).json({ error: err.message });
    next();
  });
}, async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'Δεν επιλέχθηκε εικόνα' });
    const imageUrl = req.file.publicUrl;
    await db.query(
      'UPDATE services SET image_url = ? WHERE id = ? AND business_id = ?',
      [imageUrl, req.params.id, req.admin.businessId]
    );
    return res.json({ image_url: imageUrl });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.post('/services/:id/svg', requireClientAdmin, (req, res, next) => {
  serviceSvgUpload.single('svg')(req, res, (err) => {
    if (err) return res.status(400).json({ error: err.message });
    next();
  });
}, async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'Δεν επιλέχθηκε SVG' });
  const svgUrl = req.file.publicUrl;
  await db.query(
    'UPDATE services SET icon_svg_url = ? WHERE id = ? AND business_id = ?',
    [svgUrl, req.params.id, req.admin.businessId]
  );
  return res.json({ icon_svg_url: svgUrl });
});

router.delete('/services/:id/svg', requireClientAdmin, async (req, res) => {
  await db.query(
    'UPDATE services SET icon_svg_url = NULL WHERE id = ? AND business_id = ?',
    [req.params.id, req.admin.businessId]
  );
  return res.json({ ok: true });
});

router.get('/services/:id/slot-schedules', requireClientAdmin, async (req, res) => {
  const { location_id } = req.query;
  let q = `
    SELECT sss.*, st.full_name AS staff_name, st.avatar_url AS staff_avatar,
           r.name AS room_display_name, r.photo_url AS room_photo_url, r.short_info AS room_short_info
     FROM service_slot_schedules sss
     LEFT JOIN staff st ON st.id = sss.staff_id
     LEFT JOIN rooms r ON r.id = sss.room_id
     WHERE sss.service_id = ? AND sss.business_id = ?`;
  const params = [req.params.id, req.admin.businessId];
  if (location_id) {
    q += ' AND sss.location_id = ?';
    params.push(location_id);
  }
  q += ' ORDER BY sss.weekday, sss.start_time';
  const [rows] = await db.query(q, params);
  return res.json(rows);
});

router.post('/services/:id/slot-schedules', requireClientAdmin, async (req, res) => {
  const {
    weekday, weekdays, start_time, start_times, label, room_name, room_id, subtitle, icon_key,
    max_capacity, preparation_tips, post_workout_tips, staff_id, location_id,
  } = req.body;
  const days = Array.isArray(weekdays) && weekdays.length
    ? [...new Set(weekdays.map(Number))]
    : (weekday !== undefined ? [Number(weekday)] : []);

  const normalizeTime = (t) => {
    const parts = String(t).split(':');
    if (parts.length < 2) return null;
    return `${parts[0].padStart(2, '0')}:${parts[1].padStart(2, '0')}:00`;
  };

  const times = Array.isArray(start_times) && start_times.length
    ? [...new Set(start_times.map(normalizeTime).filter(Boolean))]
    : (start_time ? [normalizeTime(start_time)].filter(Boolean) : []);

  if (!days.length || !times.length) {
    return res.status(400).json({ error: 'Απαιτούνται τουλάχιστον μία ημέρα και μία ώρα' });
  }

  let locId = location_id || null;
  if (!locId) locId = await ensureDefaultLocation(db, req.admin.businessId);

  let resolvedRoomId = room_id || null;
  let resolvedRoomName = room_name || null;
  if (resolvedRoomId) {
    const synced = await syncRoomFromId(db, resolvedRoomId, req.admin.businessId);
    resolvedRoomId = synced.room_id;
    resolvedRoomName = synced.room_name;
  }

  const created = [];
  const skipped = [];

  try {
    for (const wd of days) {
      if (wd < 0 || wd > 6) continue;
      for (const time of times) {
        const id = uuidv4();
        try {
          await db.query(
            `INSERT INTO service_slot_schedules
              (id, service_id, business_id, location_id, weekday, start_time, label, room_name, room_id, subtitle, icon_key, max_capacity, preparation_tips, post_workout_tips, staff_id)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
            [id, req.params.id, req.admin.businessId, locId, wd, time,
             label || null, resolvedRoomName, resolvedRoomId, subtitle || null, icon_key || null,
             max_capacity != null && max_capacity !== '' ? Number(max_capacity) : null,
             preparation_tips || null, post_workout_tips || null, staff_id || null]
          );
          created.push({ id, weekday: wd, start_time: time });
        } catch (err) {
          if (err.code === 'ER_DUP_ENTRY') {
            skipped.push({ weekday: wd, start_time: time });
          } else {
            throw err;
          }
        }
      }
    }

    if (!created.length && skipped.length) {
      return res.status(409).json({ error: 'Υπάρχουν ήδη όλες οι επιλεγμένες ώρες για τις ημέρες που επέλεξες' });
    }

    return res.status(201).json({
      created: created.length,
      skipped: skipped.length,
      ids: created.map(c => c.id),
    });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.patch('/services/:serviceId/slot-schedules/:scheduleId', requireClientAdmin, async (req, res) => {
  const {
    weekday, start_time, label, room_name, room_id, subtitle, icon_key, is_active, max_capacity,
    preparation_tips, post_workout_tips, staff_id,
  } = req.body;
  const cap = max_capacity !== undefined
    ? (max_capacity === null || max_capacity === '' ? null : Number(max_capacity))
    : undefined;

  let roomPatchSql = '';
  const roomPatchParams = [];
  if (room_id !== undefined) {
    if (room_id) {
      const synced = await syncRoomFromId(db, room_id, req.admin.businessId);
      roomPatchSql = ', room_id = ?, room_name = ?';
      roomPatchParams.push(synced.room_id, synced.room_name);
    } else {
      roomPatchSql = ', room_id = NULL, room_name = NULL';
    }
  }

  await db.query(
    `UPDATE service_slot_schedules SET
      weekday = COALESCE(?, weekday),
      start_time = COALESCE(?, start_time),
      label = COALESCE(?, label),
      subtitle = COALESCE(?, subtitle),
      icon_key = COALESCE(?, icon_key),
      is_active = COALESCE(?, is_active),
      max_capacity = COALESCE(?, max_capacity),
      preparation_tips = COALESCE(?, preparation_tips),
      post_workout_tips = COALESCE(?, post_workout_tips),
      staff_id = CASE WHEN ? IS NOT NULL THEN ? ELSE staff_id END
      ${roomPatchSql}
     WHERE id = ? AND service_id = ? AND business_id = ?`,
    [weekday, start_time, label, subtitle, icon_key, is_active, cap,
     preparation_tips, post_workout_tips, staff_id, staff_id,
     ...roomPatchParams,
     req.params.scheduleId, req.params.serviceId, req.admin.businessId]
  );
  return res.json({ ok: true });
});

router.delete('/services/:serviceId/slot-schedules/:scheduleId', requireClientAdmin, async (req, res) => {
  await db.query(
    'DELETE FROM service_slot_schedules WHERE id = ? AND service_id = ? AND business_id = ?',
    [req.params.scheduleId, req.params.serviceId, req.admin.businessId]
  );
  return res.json({ ok: true });
});

router.delete('/services/:id', requireClientAdmin, async (req, res) => {
  await db.query('DELETE FROM services WHERE id=? AND business_id=?', [req.params.id, req.admin.businessId]);
  return res.json({ ok: true });
});

// ============================================================
// STAFF CRUD
// ============================================================
router.get('/staff', requireClientAdmin, async (req, res) => {
  const [staff] = await db.query(
    `SELECT s.*,
            (SELECT COUNT(*) FROM staff_passwords p WHERE p.staff_id = s.id) AS has_portal_password,
            (SELECT COUNT(*) FROM staff_availability_requests r
             WHERE r.staff_id = s.id AND r.status = 'pending') AS pending_availability_requests
     FROM staff s
     WHERE ${GYM_STAFF_WHERE_ALIAS}
     ORDER BY s.full_name`,
    [req.admin.businessId]
  );
  // Attach services to each staff member
  for (const s of staff) {
    const [svcs] = await db.query(
      'SELECT ss.service_id, sv.name AS service_name FROM staff_services ss JOIN services sv ON sv.id=ss.service_id WHERE ss.staff_id=?',
      [s.id]
    );
    s.services = svcs;
    s.location_ids = await getStaffLocationIds(db, s.id);
    s.portal_enabled = !!s.portal_email && s.is_active && Number(s.has_portal_password) > 0;
  }
  return res.json(staff);
});

router.post('/staff', requireClientAdmin, async (req, res) => {
  const { full_name, role, bio, color_hex, avatar_url } = req.body;
  if (!full_name || !role) return res.status(400).json({ error: 'Απαιτούνται όνομα και ρόλος' });
  const id = uuidv4();
  await db.query(
    'INSERT INTO staff (id, business_id, full_name, role, bio, color_hex, avatar_url) VALUES (?,?,?,?,?,?,?)',
    [id, req.admin.businessId, full_name, role, bio || null, color_hex || '#607D8B', avatar_url || null]
  );
  return res.status(201).json({ id });
});

router.patch('/staff/:id', requireClientAdmin, async (req, res) => {
  const { full_name, role, bio, color_hex, is_active, avatar_url } = req.body;
  await db.query(
    `UPDATE staff SET full_name=COALESCE(?,full_name), role=COALESCE(?,role),
     bio=COALESCE(?,bio), color_hex=COALESCE(?,color_hex), is_active=COALESCE(?,is_active),
     avatar_url=COALESCE(?,avatar_url)
     WHERE id=? AND business_id=?`,
    [full_name, role, bio, color_hex, is_active, avatar_url, req.params.id, req.admin.businessId]
  );
  return res.json({ ok: true });
});

router.post('/staff/:id/avatar', requireClientAdmin, (req, res, next) => {
  staffPhotoUpload.single('avatar')(req, res, (err) => {
    if (err) return res.status(400).json({ error: err.message });
    next();
  });
}, async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'Δεν επιλέχθηκε φωτογραφία' });
    const avatarUrl = req.file.publicUrl;
    await db.query(
      'UPDATE staff SET avatar_url = ? WHERE id = ? AND business_id = ?',
      [avatarUrl, req.params.id, req.admin.businessId]
    );
    return res.json({ avatar_url: avatarUrl });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.get('/staff/:id/deletion-preview', requireClientAdmin, async (req, res) => {
  const conn = await db.getConnection();
  try {
    const preview = await previewStaffDeletion(
      conn,
      req.admin.businessId,
      req.params.id,
      req.query.transfer_to || null,
    );
    if (preview.error) return res.status(400).json({ error: preview.error });
    return res.json(preview);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

router.delete('/staff/:id', requireClientAdmin, async (req, res) => {
  const { transfer_to_staff_id } = req.body || {};
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const result = await deleteStaffWithReassignment(
      conn,
      req.admin.businessId,
      req.params.id,
      { transferToStaffId: transfer_to_staff_id || null },
    );
    await conn.commit();
    return res.json({ ok: true, ...result });
  } catch (err) {
    await conn.rollback();
    if (err.message.includes('δεν βρέθηκε') || err.message.includes('γενικό προσωπικό')) {
      return res.status(400).json({ error: err.message });
    }
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// GET staff services (for assignment modal)
router.get('/staff/:id/services', requireClientAdmin, async (req, res) => {
  const [rows] = await db.query(
    'SELECT service_id FROM staff_services WHERE staff_id=?', [req.params.id]
  );
  return res.json(rows);
});

// GET staff weekly availability
// GET availability — optionally filtered by service_id
router.get('/staff/:id/availability', requireClientAdmin, async (req, res) => {
  const { service_id, location_id } = req.query;
  let q = `SELECT id, weekday, start_time, end_time, is_active, service_id, location_id
     FROM staff_availability
     WHERE staff_id=?`;
  const params = [req.params.id];
  if (service_id) {
    q += ' AND service_id=?';
    params.push(service_id);
  } else {
    q += ' AND service_id IS NULL';
  }
  if (location_id) {
    q += ' AND (location_id=? OR location_id IS NULL)';
    params.push(location_id);
  }
  q += ' ORDER BY weekday, start_time';
  const [rows] = await db.query(q, params);
  return res.json(rows);
});

// PUT staff availability — replace slots for a given scope (general or per-service)
router.put('/staff/:id/availability', requireClientAdmin, async (req, res) => {
  const { slots = [], service_id = null, location_id = null } = req.body;
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    if (service_id) {
      if (location_id) {
        await conn.query(
          'DELETE FROM staff_availability WHERE staff_id=? AND service_id=? AND (location_id=? OR location_id IS NULL)',
          [req.params.id, service_id, location_id]
        );
      } else {
        await conn.query('DELETE FROM staff_availability WHERE staff_id=? AND service_id=?', [req.params.id, service_id]);
      }
    } else if (location_id) {
      await conn.query(
        'DELETE FROM staff_availability WHERE staff_id=? AND service_id IS NULL AND (location_id=? OR location_id IS NULL)',
        [req.params.id, location_id]
      );
    } else {
      await conn.query('DELETE FROM staff_availability WHERE staff_id=? AND service_id IS NULL', [req.params.id]);
    }
    for (const slot of slots) {
      if (slot.weekday === undefined || !slot.start_time || !slot.end_time) continue;
      await conn.query(
        'INSERT INTO staff_availability (id, staff_id, location_id, service_id, weekday, start_time, end_time, is_active) VALUES (?,?,?,?,?,?,?,?)',
        [uuidv4(), req.params.id, location_id || null, service_id || null, slot.weekday, slot.start_time, slot.end_time, slot.is_active !== false ? 1 : 0]
      );
    }
    await conn.commit();
    return res.json({ ok: true });
  } catch (err) {
    await conn.rollback();
    return res.status(500).json({ error: err.message });
  } finally { conn.release(); }
});

// PUT staff services (replace all assignments)
router.put('/staff/:id/services', requireClientAdmin, async (req, res) => {
  const { service_ids = [] } = req.body;
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    await conn.query('DELETE FROM staff_services WHERE staff_id=?', [req.params.id]);
    for (const svcId of service_ids) {
      await conn.query('INSERT IGNORE INTO staff_services (staff_id, service_id) VALUES (?,?)',
        [req.params.id, svcId]);
    }
    await conn.commit();
    return res.json({ ok: true });
  } catch (err) {
    await conn.rollback();
    return res.status(500).json({ error: err.message });
  } finally { conn.release(); }
});

// ============================================================
// GET /api/client-admin/calendar?date=YYYY-MM-DD
// ============================================================
router.get('/calendar', requireClientAdmin, async (req, res) => {
  const date = req.query.date || new Date().toISOString().slice(0, 10);
  const { location_id } = req.query;
  const bizId = req.admin.businessId;
  try {
    const [[{ wd }]] = await db.query('SELECT WEEKDAY(?) AS wd', [date]);

    let bookingQ = `
      ${BOOKING_ENRICHED_SELECT}
      ${BOOKING_ENRICHED_FROM}
      WHERE b.business_id = ? AND DATE(b.starts_at) = ?
        AND b.status NOT IN ('cancelled', 'no_show')
        AND ${sqlGymServiceCategories('sv')}`;
    const bookingParams = [bizId, date];
    if (location_id) {
      bookingQ += ' AND b.location_id = ?';
      bookingParams.push(location_id);
    }
    bookingQ += ' ORDER BY b.starts_at ASC';
    const [bookings] = await db.query(bookingQ, bookingParams);

    let scheduleQ = `
      SELECT sss.*, sv.name AS service_name
      FROM service_slot_schedules sss
      JOIN services sv ON sv.id = sss.service_id
      WHERE sss.business_id = ? AND sss.weekday = ? AND sss.is_active = 1
        AND ${sqlGymServiceCategories('sv')}`;
    const scheduleParams = [bizId, wd];
    if (location_id) {
      scheduleQ += ' AND sss.location_id = ?';
      scheduleParams.push(location_id);
    }
    scheduleQ += ' ORDER BY sss.start_time';
    const [schedules] = await db.query(scheduleQ, scheduleParams);

    const [staff] = await db.query(
      `SELECT id, full_name, color_hex, avatar_url, role FROM staff WHERE ${GYM_STAFF_WHERE} ORDER BY full_name`,
      [bizId]
    );

    const [services] = await db.query(
      `SELECT id, name, image_url, duration_mins, category
       FROM services s
       WHERE s.business_id = ? AND s.is_active = 1 AND ${sqlGymServiceCategories('s')}
       ORDER BY s.name`,
      [bizId]
    );

    const [waitlist] = await db.query(`
      SELECT w.id, w.service_id, w.starts_at, w.status, w.position,
             u.full_name AS user_name, sv.name AS service_name, sv.image_url AS service_image_url
      FROM waitlist_entries w
      JOIN users u ON u.id = w.user_id
      JOIN services sv ON sv.id = w.service_id
      WHERE w.business_id = ? AND DATE(w.starts_at) = ?
        AND w.status IN ('waiting', 'offered')
        AND ${sqlGymServiceCategories('sv')}
      ORDER BY w.starts_at, w.position
    `, [bizId, date]);

    const locations = await listLocations(db, bizId, { activeOnly: true });

    return res.json({ date, location_id: location_id || null, locations, bookings, schedules, staff, services, waitlist });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ============================================================
// NOTIFICATIONS
// ============================================================
router.get('/notifications', requireClientAdmin, async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 30, 100);
  const [rows] = await db.query(`
    SELECT id, type, title, body, payload, is_read, created_at
    FROM admin_notifications
    WHERE business_id = ?
    ORDER BY created_at DESC
    LIMIT ?
  `, [req.admin.businessId, limit]);
  const [[{ unread }]] = await db.query(
    'SELECT COUNT(*) AS unread FROM admin_notifications WHERE business_id = ? AND is_read = 0',
    [req.admin.businessId]
  );
  const notifications = rows.map((row) => ({
    ...row,
    payload: row.payload
      ? (typeof row.payload === 'string' ? JSON.parse(row.payload) : row.payload)
      : null,
  }));
  return res.json({ notifications, unread_count: unread });
});

router.patch('/notifications/:id/read', requireClientAdmin, async (req, res) => {
  await db.query(
    'UPDATE admin_notifications SET is_read = 1 WHERE id = ? AND business_id = ?',
    [req.params.id, req.admin.businessId]
  );
  return res.json({ ok: true });
});

router.patch('/notifications/read-all', requireClientAdmin, async (req, res) => {
  await db.query(
    'UPDATE admin_notifications SET is_read = 1 WHERE business_id = ? AND is_read = 0',
    [req.admin.businessId]
  );
  return res.json({ ok: true });
});

// ============================================================
// WAITLIST (admin)
// ============================================================
router.get('/waitlist', requireClientAdmin, async (req, res) => {
  let q = `
    SELECT w.id, w.user_id, w.service_id, w.staff_id, w.starts_at, w.ends_at,
           w.status, w.position, w.created_at,
           u.full_name AS user_name, u.phone AS user_phone,
           sv.name AS service_name, st.full_name AS staff_name
    FROM waitlist_entries w
    JOIN users u ON u.id = w.user_id
    JOIN services sv ON sv.id = w.service_id
    LEFT JOIN staff st ON st.id = w.staff_id
    WHERE w.business_id = ?
      AND w.status IN ('waiting', 'offered')
      AND ${sqlGymServiceCategories('sv')}
  `;
  const params = [req.admin.businessId];
  if (req.query.date) {
    q += ' AND DATE(w.starts_at) = ?';
    params.push(req.query.date);
  }
  q += ' ORDER BY w.starts_at ASC, w.position ASC';
  const [rows] = await db.query(q, params);
  return res.json(rows);
});

router.post('/waitlist/:id/convert', requireClientAdmin, async (req, res) => {
  const { force = false, use_credit = true } = req.body;
  const bizId = req.admin.businessId;
  const conn = await db.getConnection();

  try {
    await conn.beginTransaction();
    const result = await convertWaitlistEntry(conn, bizId, req.params.id, { force, use_credit });
    await conn.commit();
    return res.status(201).json({
      booking_id: result.booking_id,
      message: 'Η κράτηση δημιουργήθηκε από τη λίστα αναμονής',
    });
  } catch (err) {
    await conn.rollback();
    return res.status(err.status || 400).json({ error: err.message });
  } finally {
    conn.release();
  }
});

router.delete('/waitlist/:id', requireClientAdmin, async (req, res) => {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    await cancelWaitlistEntry(conn, req.admin.businessId, req.params.id);
    await conn.commit();
    return res.json({ ok: true });
  } catch (err) {
    await conn.rollback();
    return res.status(err.status || 400).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// ── Built-in animated SVG icons ───────────────────────────────
router.get('/icons', requireClientAdmin, (req, res) => {
  const icons = [
    { key: 'dumbbell',   label: 'Βάρη',        url: '/icons/dumbbell.svg' },
    { key: 'running',    label: 'Τρέξιμο',      url: '/icons/running.svg' },
    { key: 'yoga',       label: 'Yoga',         url: '/icons/yoga.svg' },
    { key: 'cycling',    label: 'Cycling',      url: '/icons/cycling.svg' },
    { key: 'boxing',     label: 'Boxing',       url: '/icons/boxing.svg' },
    { key: 'pilates',    label: 'Pilates',      url: '/icons/pilates.svg' },
    { key: 'hiit',       label: 'HIIT',         url: '/icons/hiit.svg' },
    { key: 'swimming',   label: 'Κολύμβηση',    url: '/icons/swimming.svg' },
    { key: 'stretching', label: 'Stretching',   url: '/icons/stretching.svg' },
    { key: 'crossfit',   label: 'CrossFit',     url: '/icons/crossfit.svg' },
  ];
  return res.json(icons);
});

// ── Service Rooms ─────────────────────────────────────────────
router.get('/services/:id/rooms', requireClientAdmin, async (req, res) => {
  const [rows] = await db.query(
    `SELECT r.* FROM rooms r
     JOIN service_rooms sr ON sr.room_id = r.id
     WHERE sr.service_id = ? AND r.is_active = 1
     ORDER BY r.sort_order, r.name`,
    [req.params.id]
  );
  return res.json(rows);
});

router.put('/services/:id/rooms', requireClientAdmin, async (req, res) => {
  const { room_ids = [] } = req.body;
  await db.query('DELETE FROM service_rooms WHERE service_id = ?', [req.params.id]);
  if (room_ids.length) {
    await db.query(
      'INSERT INTO service_rooms (service_id, room_id) VALUES ' + room_ids.map(() => '(?,?)').join(','),
      room_ids.flatMap(rid => [req.params.id, rid])
    );
  }
  return res.json({ ok: true });
});

// ── Service Class Types ───────────────────────────────────────
router.get('/services/:id/class-types', requireClientAdmin, async (req, res) => {
  const [rows] = await db.query(
    'SELECT * FROM service_class_types WHERE service_id = ? AND business_id = ? ORDER BY sort_order, label',
    [req.params.id, req.admin.businessId]
  );
  return res.json(rows);
});

router.post('/services/:id/class-types', requireClientAdmin, async (req, res) => {
  const { label, subtitle, icon_key, preparation_tips, post_workout_tips, sort_order } = req.body;
  if (!label?.trim()) return res.status(400).json({ error: 'Το όνομα είναι υποχρεωτικό' });
  const id = uuidv4();
  await db.query(
    `INSERT INTO service_class_types (id, service_id, business_id, label, subtitle, icon_key, preparation_tips, post_workout_tips, sort_order)
     VALUES (?,?,?,?,?,?,?,?,?)`,
    [id, req.params.id, req.admin.businessId, label.trim(),
     subtitle || null, icon_key || null, preparation_tips || null, post_workout_tips || null, sort_order ?? 0]
  );
  const [[row]] = await db.query('SELECT * FROM service_class_types WHERE id = ?', [id]);
  return res.status(201).json(row);
});

router.patch('/services/:serviceId/class-types/:ctId', requireClientAdmin, async (req, res) => {
  const { label, subtitle, icon_key, preparation_tips, post_workout_tips, sort_order } = req.body;
  await db.query(
    `UPDATE service_class_types SET
       label = COALESCE(?, label),
       subtitle = COALESCE(?, subtitle),
       icon_key = COALESCE(?, icon_key),
       preparation_tips = COALESCE(?, preparation_tips),
       post_workout_tips = COALESCE(?, post_workout_tips),
       sort_order = COALESCE(?, sort_order)
     WHERE id = ? AND service_id = ? AND business_id = ?`,
    [label || null, subtitle ?? null, icon_key ?? null, preparation_tips ?? null,
     post_workout_tips ?? null, sort_order ?? null,
     req.params.ctId, req.params.serviceId, req.admin.businessId]
  );
  return res.json({ ok: true });
});

router.delete('/services/:serviceId/class-types/:ctId', requireClientAdmin, async (req, res) => {
  await db.query(
    'DELETE FROM service_class_types WHERE id = ? AND service_id = ? AND business_id = ?',
    [req.params.ctId, req.params.serviceId, req.admin.businessId]
  );
  return res.json({ ok: true });
});

// ── Locations (branches) ───────────────────────────────────────
router.get('/locations', requireClientAdmin, async (req, res) => {
  const rows = await listLocations(db, req.admin.businessId, { activeOnly: false });
  return res.json(rows);
});

router.post('/locations', requireClientAdmin, async (req, res) => {
  const { name, slug, address, city, phone, email, opening_hours, sort_order } = req.body;
  if (!name?.trim()) return res.status(400).json({ error: 'Το όνομα είναι υποχρεωτικό' });
  const id = uuidv4();
  const finalSlug = (slug || name).trim().toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9-]/g, '') || `loc-${Date.now()}`;
  await db.query(
    `INSERT INTO locations
      (id, business_id, name, slug, address, city, phone, email, opening_hours, sort_order)
     VALUES (?,?,?,?,?,?,?,?,?,?)`,
    [
      id, req.admin.businessId, name.trim(), finalSlug,
      address || null, city || null, phone || null, email || null,
      opening_hours ? JSON.stringify(opening_hours) : null,
      sort_order ?? 0,
    ],
  );
  const [[row]] = await db.query('SELECT * FROM locations WHERE id = ?', [id]);
  return res.status(201).json(row);
});

router.patch('/locations/:id', requireClientAdmin, async (req, res) => {
  const { name, slug, address, city, phone, email, opening_hours, is_active, sort_order } = req.body;
  await db.query(
    `UPDATE locations SET
      name = COALESCE(?, name),
      slug = COALESCE(?, slug),
      address = COALESCE(?, address),
      city = COALESCE(?, city),
      phone = COALESCE(?, phone),
      email = COALESCE(?, email),
      opening_hours = COALESCE(?, opening_hours),
      is_active = COALESCE(?, is_active),
      sort_order = COALESCE(?, sort_order)
     WHERE id = ? AND business_id = ?`,
    [
      name || null, slug || null, address ?? null, city ?? null, phone ?? null, email ?? null,
      opening_hours !== undefined ? JSON.stringify(opening_hours) : null,
      is_active ?? null, sort_order ?? null,
      req.params.id, req.admin.businessId,
    ],
  );
  return res.json({ ok: true });
});

router.delete('/locations/:id', requireClientAdmin, async (req, res) => {
  const [[loc]] = await db.query(
    'SELECT id FROM locations WHERE id = ? AND business_id = ?',
    [req.params.id, req.admin.businessId],
  );
  if (!loc) return res.status(404).json({ error: 'Δεν βρέθηκε' });
  const [[{ cnt }]] = await db.query(
    'SELECT COUNT(*) AS cnt FROM locations WHERE business_id = ? AND is_active = 1',
    [req.admin.businessId],
  );
  if (Number(cnt) <= 1) {
    return res.status(400).json({ error: 'Πρέπει να υπάρχει τουλάχιστον ένα ενεργό γυμναστήριο' });
  }
  await db.query(
    'UPDATE locations SET is_active = 0 WHERE id = ? AND business_id = ?',
    [req.params.id, req.admin.businessId],
  );
  return res.json({ ok: true });
});

router.get('/staff/:id/locations', requireClientAdmin, async (req, res) => {
  const ids = await getStaffLocationIds(db, req.params.id);
  return res.json(ids);
});

router.put('/staff/:id/locations', requireClientAdmin, async (req, res) => {
  const { location_ids = [] } = req.body;
  await replaceStaffLocations(db, req.params.id, location_ids);
  return res.json({ ok: true });
});

router.get('/clients/:userId/locations', requireClientAdmin, async (req, res) => {
  const ids = await getUserLocationIds(db, req.params.userId);
  return res.json(ids);
});

router.put('/clients/:userId/locations', requireClientAdmin, async (req, res) => {
  const { location_ids = [] } = req.body;
  await replaceUserLocations(db, req.params.userId, location_ids);
  return res.json({ ok: true });
});

router.get('/services/:id/locations', requireClientAdmin, async (req, res) => {
  const ids = await getServiceLocationIds(db, req.params.id);
  return res.json(ids);
});

router.put('/services/:id/locations', requireClientAdmin, async (req, res) => {
  const { location_ids = [] } = req.body;
  await replaceServiceLocations(db, req.params.id, location_ids);
  return res.json({ ok: true });
});

// ── Rooms ─────────────────────────────────────────────────────
router.get('/rooms', requireClientAdmin, async (req, res) => {
  const { location_id } = req.query;
  let q = 'SELECT * FROM rooms WHERE business_id = ? AND is_active = 1';
  const params = [req.admin.businessId];
  if (location_id) {
    q += ' AND location_id = ?';
    params.push(location_id);
  }
  q += ' ORDER BY sort_order, name';
  const [rows] = await db.query(q, params);
  return res.json(rows);
});

router.post('/rooms', requireClientAdmin, async (req, res) => {
  const { name, description, short_info, sort_order, location_id } = req.body;
  if (!name?.trim()) return res.status(400).json({ error: 'Το όνομα είναι υποχρεωτικό' });
  let locId = location_id || null;
  if (!locId) locId = await ensureDefaultLocation(db, req.admin.businessId);
  const id = uuidv4();
  await db.query(
    `INSERT INTO rooms (id, business_id, location_id, name, description, short_info, sort_order)
     VALUES (?,?,?,?,?,?,?)`,
    [id, req.admin.businessId, locId, name.trim(), description || null, short_info || description || null, sort_order ?? 0]
  );
  const [[row]] = await db.query('SELECT * FROM rooms WHERE id = ?', [id]);
  return res.status(201).json(row);
});

router.patch('/rooms/:id', requireClientAdmin, async (req, res) => {
  const { name, description, short_info, sort_order, is_active } = req.body;
  await db.query(
    `UPDATE rooms SET
       name = COALESCE(?, name),
       description = COALESCE(?, description),
       short_info = COALESCE(?, short_info),
       sort_order = COALESCE(?, sort_order),
       is_active = COALESCE(?, is_active)
     WHERE id = ? AND business_id = ?`,
    [name || null, description ?? null, short_info ?? null, sort_order ?? null, is_active ?? null,
     req.params.id, req.admin.businessId]
  );
  const [[row]] = await db.query('SELECT * FROM rooms WHERE id = ?', [req.params.id]);
  return res.json(row || { ok: true });
});

router.post('/rooms/:id/image', requireClientAdmin, (req, res, next) => {
  roomPhotoUpload.single('image')(req, res, (err) => {
    if (err) return res.status(400).json({ error: err.message });
    next();
  });
}, async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'Απαιτείται εικόνα' });
  const imageUrl = req.file.publicUrl;
  await db.query(
    'UPDATE rooms SET photo_url = ? WHERE id = ? AND business_id = ?',
    [imageUrl, req.params.id, req.admin.businessId],
  );
  return res.json({ photo_url: imageUrl });
});

router.delete('/rooms/:id/image', requireClientAdmin, async (req, res) => {
  await db.query(
    'UPDATE rooms SET photo_url = NULL WHERE id = ? AND business_id = ?',
    [req.params.id, req.admin.businessId],
  );
  return res.json({ ok: true });
});

router.delete('/rooms/:id', requireClientAdmin, async (req, res) => {
  await db.query(
    'UPDATE rooms SET is_active = 0 WHERE id = ? AND business_id = ?',
    [req.params.id, req.admin.businessId]
  );
  return res.json({ ok: true });
});

// ── Business Closures (blackout dates) ───────────────────────
router.get('/closures', requireClientAdmin, async (req, res) => {
  const [rows] = await db.query(
    'SELECT * FROM business_closures WHERE business_id=? ORDER BY date_from',
    [req.admin.businessId]
  );
  return res.json(rows);
});

router.post('/closures', requireClientAdmin, async (req, res) => {
  const { date_from, date_to, time_from, time_to, reason } = req.body;
  if (!date_from || !date_to) return res.status(400).json({ error: 'Απαιτούνται ημερομηνίες' });
  const id = uuidv4();
  await db.query(
    'INSERT INTO business_closures (id, business_id, date_from, date_to, time_from, time_to, reason) VALUES (?,?,?,?,?,?,?)',
    [id, req.admin.businessId, date_from, date_to, time_from || null, time_to || null, reason || null]
  );
  return res.status(201).json({ id });
});

router.delete('/closures/:id', requireClientAdmin, async (req, res) => {
  await db.query(
    'DELETE FROM business_closures WHERE id=? AND business_id=?',
    [req.params.id, req.admin.businessId]
  );
  return res.json({ ok: true });
});

// ── Drop-in Bookings (admin) ──────────────────────────────────

router.get('/dropin-bookings', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { status, from, to } = req.query;
  const params = [bizId];
  let where = 'db.business_id = ?';
  if (status) { where += ' AND db.status = ?'; params.push(status); }
  if (from)   { where += ' AND db.booking_date >= ?'; params.push(from); }
  if (to)     { where += ' AND db.booking_date <= ?'; params.push(to); }
  try {
    const [rows] = await db.query(`
      SELECT db.*, s.duration_mins
      FROM dropin_bookings db
      LEFT JOIN services s ON s.id = db.service_id
      WHERE ${where}
      ORDER BY db.booking_date DESC, db.booking_time DESC
    `, params);
    // Revenue stats
    const [[stats]] = await db.query(`
      SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN status IN ('confirmed','attended') THEN 1 ELSE 0 END) AS confirmed,
        SUM(CASE WHEN payment_status = 'paid' THEN price_cents ELSE 0 END) AS revenue_cents,
        SUM(CASE WHEN payment_method = 'venue' AND status IN ('confirmed','attended') THEN price_cents ELSE 0 END) AS pending_venue_cents
      FROM dropin_bookings WHERE business_id = ?
    `, [bizId]);
    return res.json({ bookings: rows, stats });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.patch('/dropin-bookings/:id', requireClientAdmin, async (req, res) => {
  const { status, admin_note, payment_status } = req.body;
  const allowed = ['confirmed', 'rejected', 'attended', 'cancelled'];
  if (status && !allowed.includes(status)) return res.status(400).json({ error: 'Μη έγκυρο status' });
  const sets = [];
  const params = [];
  if (status)         { sets.push('status = ?');         params.push(status); }
  if (admin_note !== undefined) { sets.push('admin_note = ?');    params.push(admin_note); }
  if (payment_status) { sets.push('payment_status = ?'); params.push(payment_status); }
  if (!sets.length) return res.status(400).json({ error: 'Τίποτα να ενημερωθεί' });
  params.push(req.params.id, req.admin.businessId);
  await db.query(`UPDATE dropin_bookings SET ${sets.join(', ')} WHERE id = ? AND business_id = ?`, params);
  return res.json({ ok: true });
});

// ── Staff Leaves ──────────────────────────────────────────────
// Ensure status column exists (migration-safe)
(async () => {
  try {
    await db.query(`ALTER TABLE staff_leaves ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'approved'`);
    await db.query(`ALTER TABLE staff_leaves ADD COLUMN IF NOT EXISTS admin_note TEXT`);
    await db.query(`ALTER TABLE staff_leaves ADD COLUMN IF NOT EXISTS reviewed_at DATETIME`);
    await db.query(`ALTER TABLE business_configs ADD COLUMN IF NOT EXISTS annual_leave_days INT NOT NULL DEFAULT 20`);
  } catch (_) {}
})();

// GET all leave requests across all staff (admin overview)
router.get('/staff-leaves', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { status } = req.query;
  const params = [bizId];
  let where = 'sl.business_id = ?';
  if (status) { where += ' AND sl.status = ?'; params.push(status); }
  const [rows] = await db.query(`
    SELECT sl.*, s.full_name AS staff_name, s.role AS staff_role,
           DATEDIFF(sl.date_to, sl.date_from) + 1 AS days_count
    FROM staff_leaves sl
    LEFT JOIN staff s ON s.id = sl.staff_id
    WHERE ${where}
    ORDER BY sl.date_from DESC
  `, params);
  const [[cfg]] = await db.query(
    'SELECT annual_leave_days FROM business_configs WHERE business_id=?', [bizId]);
  return res.json({ leaves: rows, annual_leave_days: cfg?.annual_leave_days ?? 20 });
});

router.get('/staff/:id/leaves', requireClientAdmin, async (req, res) => {
  const [rows] = await db.query(
    `SELECT *, DATEDIFF(date_to, date_from) + 1 AS days_count
     FROM staff_leaves WHERE staff_id=? AND business_id=? ORDER BY date_from DESC`,
    [req.params.id, req.admin.businessId]
  );
  const [[used]] = await db.query(
    `SELECT COALESCE(SUM(DATEDIFF(date_to, date_from) + 1), 0) AS days_used
     FROM staff_leaves WHERE staff_id=? AND business_id=? AND status='approved'
     AND YEAR(date_from)=YEAR(CURDATE())`, [req.params.id, req.admin.businessId]);
  const [[cfg]] = await db.query(
    'SELECT annual_leave_days FROM business_configs WHERE business_id=?', [req.admin.businessId]);
  return res.json({ leaves: rows, days_used: used.days_used, annual_leave_days: cfg?.annual_leave_days ?? 20 });
});

router.post('/staff/:id/leaves', requireClientAdmin, async (req, res) => {
  const { date_from, date_to, reason } = req.body;
  if (!date_from || !date_to) return res.status(400).json({ error: 'Απαιτούνται ημερομηνίες' });
  const id = uuidv4();
  await db.query(
    `INSERT INTO staff_leaves (id, staff_id, business_id, date_from, date_to, reason, status)
     VALUES (?,?,?,?,?,?,'approved')`,
    [id, req.params.id, req.admin.businessId, date_from, date_to, reason || null]
  );
  return res.status(201).json({ id });
});

// PATCH approve/reject a leave request
router.patch('/staff-leaves/:leaveId', requireClientAdmin, async (req, res) => {
  const { status, admin_note } = req.body;
  if (!['approved', 'rejected'].includes(status)) return res.status(400).json({ error: 'Invalid status' });
  await db.query(
    `UPDATE staff_leaves SET status=?, admin_note=?, reviewed_at=NOW()
     WHERE id=? AND business_id=?`,
    [status, admin_note || null, req.params.leaveId, req.admin.businessId]
  );
  return res.json({ ok: true });
});

router.delete('/staff/:staffId/leaves/:leaveId', requireClientAdmin, async (req, res) => {
  await db.query(
    'DELETE FROM staff_leaves WHERE id=? AND staff_id=? AND business_id=?',
    [req.params.leaveId, req.params.staffId, req.admin.businessId]
  );
  return res.json({ ok: true });
});

// GET annual_leave_days setting
router.get('/settings/annual-leave-days', requireClientAdmin, async (req, res) => {
  const [[cfg]] = await db.query(
    'SELECT annual_leave_days FROM business_configs WHERE business_id=?',
    [req.admin.businessId]
  );
  return res.json({ annual_leave_days: cfg?.annual_leave_days ?? 20 });
});

// PATCH annual_leave_days setting
router.patch('/settings/annual-leave-days', requireClientAdmin, async (req, res) => {
  const days = req.body.annual_leave_days ?? req.body.days;
  if (!days || days < 1) return res.status(400).json({ error: 'Invalid days' });
  await db.query(
    'UPDATE business_configs SET annual_leave_days=? WHERE business_id=?',
    [days, req.admin.businessId]
  );
  return res.json({ ok: true });
});

// ── Reviews (post-workout feedback) ──────────────────────────
router.get('/reviews', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const { page = 1, limit = 30, min_rating, service_id } = req.query;
  const offset = (Number(page) - 1) * Number(limit);
  const filters = ['b.business_id = ?', 'b.feedback_rating IS NOT NULL'];
  const params  = [bizId];
  if (min_rating) { filters.push('b.feedback_rating >= ?'); params.push(Number(min_rating)); }
  if (service_id) { filters.push('b.service_id = ?'); params.push(service_id); }
  const where = filters.join(' AND ');
  const [[{ total }]] = await db.query(
    `SELECT COUNT(*) AS total FROM bookings b WHERE ${where}`, params);
  const [rows] = await db.query(`
    SELECT b.id, b.feedback_rating, b.feedback_note, b.starts_at,
           sv.name AS service_name,
           u.full_name AS member_name, s.full_name AS staff_name
    FROM bookings b
    LEFT JOIN services sv ON sv.id = b.service_id
    LEFT JOIN users  u ON u.id = b.user_id
    LEFT JOIN staff  s ON s.id = b.staff_id
    WHERE ${where}
    ORDER BY b.starts_at DESC
    LIMIT ? OFFSET ?
  `, [...params, Number(limit), offset]);
  const [[avg]] = await db.query(
    `SELECT ROUND(AVG(feedback_rating),1) AS avg_rating, COUNT(*) AS total_reviews
     FROM bookings WHERE business_id=? AND feedback_rating IS NOT NULL`, [bizId]);
  return res.json({ reviews: rows, total, avg_rating: avg.avg_rating, total_reviews: avg.total_reviews });
});

// ── Gym Settings ──────────────────────────────────────────────
router.get('/settings', requireNutritionStaff, async (req, res) => {
  const [[cfg]] = await db.query(
    'SELECT * FROM business_configs WHERE business_id=?',
    [req.admin.businessId]
  );
  const [[biz]] = await db.query(
    'SELECT id, name, slug, owner_email FROM businesses WHERE id=?',
    [req.admin.businessId]
  );
  return res.json({ ...cfg, business_name: biz?.name, business_slug: biz?.slug, owner_email: biz?.owner_email });
});

router.patch('/settings', requireClientAdmin, async (req, res) => {
  const {
    app_name, opening_hours, owner_name, owner_phone,
    gym_address, gym_phone, gym_email, logo_url,
    feature_online_booking, feature_loyalty_points, feature_memberships, feature_waitlist, feature_nutrition,
  } = req.body;
  await db.query(
    `UPDATE business_configs SET
       app_name = COALESCE(?, app_name),
       opening_hours = COALESCE(?, opening_hours),
       owner_name = COALESCE(?, owner_name),
       owner_phone = COALESCE(?, owner_phone),
       gym_address = COALESCE(?, gym_address),
       gym_phone = COALESCE(?, gym_phone),
       gym_email = COALESCE(?, gym_email),
       logo_url = COALESCE(?, logo_url),
       feature_online_booking = COALESCE(?, feature_online_booking),
       feature_loyalty_points = COALESCE(?, feature_loyalty_points),
       feature_memberships = COALESCE(?, feature_memberships),
       feature_waitlist = COALESCE(?, feature_waitlist),
       feature_nutrition = COALESCE(?, feature_nutrition)
     WHERE business_id=?`,
    [app_name, opening_hours ? JSON.stringify(opening_hours) : null,
     owner_name, owner_phone, gym_address, gym_phone, gym_email, logo_url,
     feature_online_booking ?? null, feature_loyalty_points ?? null,
     feature_memberships ?? null, feature_waitlist ?? null, feature_nutrition ?? null,
     req.admin.businessId]
  );
  return res.json({ ok: true });
});

// Logo upload for gym settings
const gymLogoUpload = r2Multer({
  keyFn: (req, file) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.png';
    return `uploads/${req.admin.businessId}/logo/logo${ext}`;
  },
  allowedMimes: ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/svg+xml'],
  maxSizeMb: 3,
});

router.post('/settings/logo', requireClientAdmin, (req, res, next) => {
  gymLogoUpload.single('logo')(req, res, err => { if (err) return res.status(400).json({ error: err.message }); next(); });
}, async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'Δεν επιλέχθηκε αρχείο' });
  const logoUrl = req.file.publicUrl;
  await db.query('UPDATE business_configs SET logo_url=? WHERE business_id=?', [logoUrl, req.admin.businessId]);
  return res.json({ logo_url: logoUrl });
});

// ── System Backup ─────────────────────────────────────────────
router.get('/backup', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const tables = [
    ['services', 'WHERE business_id=?'],
    ['staff', 'WHERE business_id=?'],
    ['staff_availability', 'WHERE staff_id IN (SELECT id FROM staff WHERE business_id=?)'],
    ['staff_services', 'WHERE staff_id IN (SELECT id FROM staff WHERE business_id=?)'],
    ['service_slot_schedules', 'WHERE business_id=?'],
    ['service_class_types', 'WHERE business_id=?'],
    ['service_rooms', 'WHERE service_id IN (SELECT id FROM services WHERE business_id=?)'],
    ['rooms', 'WHERE business_id=?'],
    ['business_plans', 'WHERE business_id=?'],
    ['service_plan_assignments', 'WHERE service_id IN (SELECT id FROM services WHERE business_id=?)'],
    ['users', 'WHERE business_id=?'],
    ['user_memberships', 'WHERE business_id=?'],
    ['bookings', 'WHERE business_id=?'],
    ['qr_checkins', 'WHERE business_id=?'],
    ['payments', 'WHERE business_id=?'],
    ['business_configs', 'WHERE business_id=?'],
  ];

  const backup = { exported_at: new Date().toISOString(), business_id: bizId, tables: {} };

  for (const [table, where] of tables) {
    try {
      const [rows] = await db.query(`SELECT * FROM ${table} ${where}`, [bizId]);
      backup.tables[table] = rows;
    } catch (_) {
      backup.tables[table] = [];
    }
  }

  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Content-Disposition', `attachment; filename="bookup-backup-${new Date().toISOString().slice(0,10)}.json"`);
  return res.send(JSON.stringify(backup, null, 2));
});

// ============================================================
// NUTRITION — staff (owner or nutritionist)
// ============================================================

async function assertNutritionClient(bizId, userId) {
  const [[user]] = await db.query(
    `SELECT id, full_name, email, weight_kg, target_weight_kg, height_cm, body_fat_pct, target_body_fat_pct
     FROM users WHERE id=? AND business_id=?`,
    [userId, bizId]
  );
  if (!user) return null;
  const [access] = await db.query(
    `SELECT p.name AS plan_name
     FROM user_memberships m
     JOIN business_plans p ON p.id = m.plan_id AND p.plan_type = 'nutrition'
     WHERE m.user_id = ? AND m.business_id = ?
       AND (m.valid_until IS NULL OR m.valid_until >= CURDATE())
       AND COALESCE(m.membership_status, 'active') NOT IN ('trial', 'cancelled')
     ORDER BY m.valid_until DESC
     LIMIT 1`,
    [userId, bizId]
  );
  if (!access.length) return null;
  return { ...user, plan_name: access[0].plan_name };
}

router.get('/nutrition/plans', requireNutritionStaff, async (req, res) => {
  const [rows] = await db.query(
    `SELECT * FROM business_plans
     WHERE business_id = ? AND plan_type = 'nutrition'
     ORDER BY sort_order, price_cents`,
    [req.admin.businessId]
  );
  return res.json(rows.map((row) => ({
    ...row,
    promo_rules: normalizePromoRules(parsePromoRules(row.promo_rules)),
    includes_summary: nutritionIncludesSummary(row),
  })));
});

router.post('/nutrition/plans', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const {
    name,
    price_cents,
    billing_period = 'monthly',
    sort_order = 0,
    nutrition_includes_meal_plan = 1,
    nutrition_includes_measurements = 0,
    nutrition_includes_food_diary = 1,
    nutrition_includes_consultations = 0,
    nutrition_consultation_sessions = null,
    promo_rules,
  } = req.body || {};

  if (!name?.trim() || price_cents === undefined) {
    return res.status(400).json({ error: 'Απαιτούνται όνομα και τιμή' });
  }

  const id = uuidv4();
  const promoJson = JSON.stringify(normalizePromoRules(promo_rules));
  await db.query(
    `INSERT INTO business_plans
      (id, business_id, service_id, plan_type, name, sessions, duration_mins, price_cents, billing_period,
       sort_order, includes_nutrition, nutrition_includes_meal_plan, nutrition_includes_measurements,
       nutrition_includes_food_diary, nutrition_includes_consultations, nutrition_consultation_sessions, promo_rules)
     VALUES (?,?,?,?,?,?,?,?,?,?,1,?,?,?,?,?,?)`,
    [
      id, bizId, null, 'nutrition', name.trim(), null, null, price_cents, billing_period, sort_order,
      nutrition_includes_meal_plan ? 1 : 0,
      nutrition_includes_measurements ? 1 : 0,
      nutrition_includes_food_diary ? 1 : 0,
      nutrition_includes_consultations ? 1 : 0,
      nutrition_consultation_sessions ?? null,
      promoJson,
    ]
  );
  return res.status(201).json({ id });
});

router.patch('/nutrition/plans/:id', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const {
    name,
    price_cents,
    billing_period,
    is_active,
    sort_order,
    nutrition_includes_meal_plan,
    nutrition_includes_measurements,
    nutrition_includes_food_diary,
    nutrition_includes_consultations,
    nutrition_consultation_sessions,
    promo_rules,
  } = req.body || {};

  const [[existing]] = await db.query(
    `SELECT id FROM business_plans WHERE id=? AND business_id=? AND plan_type='nutrition'`,
    [req.params.id, bizId]
  );
  if (!existing) return res.status(404).json({ error: 'Το πακέτο δεν βρέθηκε' });

  const promoJson = promo_rules !== undefined
    ? JSON.stringify(normalizePromoRules(promo_rules))
    : null;

  await db.query(
    `UPDATE business_plans SET
      name=COALESCE(?, name),
      price_cents=COALESCE(?, price_cents),
      billing_period=COALESCE(?, billing_period),
      is_active=COALESCE(?, is_active),
      sort_order=COALESCE(?, sort_order),
      nutrition_includes_meal_plan=COALESCE(?, nutrition_includes_meal_plan),
      nutrition_includes_measurements=COALESCE(?, nutrition_includes_measurements),
      nutrition_includes_food_diary=COALESCE(?, nutrition_includes_food_diary),
      nutrition_includes_consultations=COALESCE(?, nutrition_includes_consultations),
      nutrition_consultation_sessions=COALESCE(?, nutrition_consultation_sessions),
      promo_rules=COALESCE(?, promo_rules)
     WHERE id=? AND business_id=?`,
    [
      name?.trim() || null,
      price_cents,
      billing_period,
      is_active,
      sort_order,
      nutrition_includes_meal_plan === undefined ? null : (nutrition_includes_meal_plan ? 1 : 0),
      nutrition_includes_measurements === undefined ? null : (nutrition_includes_measurements ? 1 : 0),
      nutrition_includes_food_diary === undefined ? null : (nutrition_includes_food_diary ? 1 : 0),
      nutrition_includes_consultations === undefined ? null : (nutrition_includes_consultations ? 1 : 0),
      nutrition_consultation_sessions === undefined ? null : (nutrition_consultation_sessions ?? null),
      promoJson,
      req.params.id,
      bizId,
    ]
  );
  return res.json({ ok: true });
});

router.delete('/nutrition/plans/:id', requireClientAdmin, async (req, res) => {
  await db.query(
    `DELETE FROM business_plans WHERE id=? AND business_id=? AND plan_type='nutrition'`,
    [req.params.id, req.admin.businessId]
  );
  return res.json({ ok: true });
});

router.post('/nutrition/plans/evaluate-promo', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const {
    nutrition_plan_id,
    service_plan_id,
    payment_type,
    package_months,
    period_start,
  } = req.body || {};

  const [[nutritionPlan]] = await db.query(
    `SELECT * FROM business_plans WHERE id=? AND business_id=? AND plan_type='nutrition'`,
    [nutrition_plan_id, bizId]
  );
  if (!nutritionPlan) return res.status(404).json({ error: 'Το πακέτο διατροφής δεν βρέθηκε' });

  let servicePlan = null;
  if (service_plan_id) {
    const [[sp]] = await db.query(
      'SELECT * FROM business_plans WHERE id=? AND business_id=?',
      [service_plan_id, bizId]
    );
    servicePlan = sp || null;
  }

  const start = formatDateOnly(period_start) || formatDateOnly(new Date());
  const promo = evaluateNutritionPromo(nutritionPlan, {
    servicePlan,
    paymentType: payment_type,
    packageMonths: package_months,
    periodStart: start,
  });

  return res.json({
    base_price_cents: nutritionPlan.price_cents,
    final_price_cents: promo.priceCents,
    bonus_months: promo.bonusMonths,
    valid_until: promo.validUntil,
    label: promo.label,
    includes: nutritionIncludesSummary(nutritionPlan),
  });
});

router.get('/nutrition/enrollable-clients', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const [rows] = await db.query(
    `SELECT u.id, u.full_name, u.email
     FROM users u
     WHERE u.business_id = ?
       AND u.deleted_at IS NULL
       AND u.id NOT IN (
         SELECT DISTINCT m.user_id
         FROM user_memberships m
         JOIN business_plans p ON p.id = m.plan_id AND p.plan_type = 'nutrition'
         WHERE m.business_id = ?
           AND (m.valid_until IS NULL OR m.valid_until >= CURDATE())
       )
     ORDER BY u.full_name`,
    [bizId, bizId]
  );
  return res.json(rows);
});

router.post('/nutrition/clients/:userId/enroll', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const userId = req.params.userId;
  const {
    valid_from,
    valid_until,
    plan_id,
    payment_type = 'package',
    package_months = 1,
    billing_month,
    subtotal_cents,
    discount_cents = 0,
    due_date,
    notes,
    method = 'cash',
    skip_payment = false,
  } = req.body || {};

  const [[user]] = await db.query(
    'SELECT id, full_name FROM users WHERE id=? AND business_id=?',
    [userId, bizId]
  );
  if (!user) return res.status(404).json({ error: 'Ο πελάτης δεν βρέθηκε' });

  const existing = await assertNutritionClient(bizId, userId);
  if (existing) return res.status(409).json({ error: 'Ο πελάτης έχει ήδη ενεργό πακέτο διατροφής' });

  if (!plan_id) return res.status(400).json({ error: 'Επίλεξε πακέτο διατροφής' });

  const [[plan]] = await db.query(
    `SELECT * FROM business_plans WHERE id=? AND business_id=? AND plan_type='nutrition' AND is_active=1`,
    [plan_id, bizId]
  );
  if (!plan) return res.status(404).json({ error: 'Το πακέτο διατροφής δεν βρέθηκε' });

  const from = formatDateOnly(valid_from) || formatDateOnly(new Date());
  const until = formatDateOnly(valid_until) || defaultValidUntil(from, plan.billing_period);
  const lineSubtotal = subtotal_cents != null
    ? Math.max(0, Number(subtotal_cents) || 0)
    : (plan.price_cents || 0);
  const discount = Math.max(0, Number(discount_cents) || 0);
  const amountCents = Math.max(0, lineSubtotal - discount);

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const nutritionNotes = [
      plan.name,
      nutritionIncludesSummary(plan).join(', '),
    ].filter(Boolean).join(' · ');

    const membershipId = await createNutritionMembership(conn, {
      bizId,
      userId,
      nutrition_plan_id: plan.id,
      valid_from: from,
      valid_until: until,
      notes: nutritionNotes,
    });

    if (plan.nutrition_includes_consultations) {
      await grantConsultationCredits(conn, {
        bizId,
        userId,
        plan,
        valid_from: from,
        valid_until: until,
        notes: `${plan.name} — επισκέψεις`,
      });
    }

    let paymentId = null;
    if (!skip_payment && amountCents > 0) {
      const billingMonthDate = toBillingMonthDate(billing_month);
      const periodEnd = until;
      const description = buildPaymentDescription({
        serviceNames: [plan.name],
        paymentType: payment_type,
        billingMonth: billingMonthDate,
        packageMonths: payment_type === 'package' ? Number(package_months) : null,
        periodStart: from,
        periodEnd,
      });

      paymentId = uuidv4();
      const finalStatus = deriveStatus(amountCents, 0, due_date);

      await conn.query(`
        INSERT INTO payments
          (id, business_id, user_id, amount_cents, paid_amount_cents, status,
           description, payment_date, due_date, notes, method,
           service_id, plan_id, payment_type, billing_month, package_months,
           period_start, period_end, discount_cents, registration_fee_cents, membership_id)
        VALUES (?, ?, ?, ?, 0, ?, ?, NULL, ?, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, 0, ?)
      `, [
        paymentId, bizId, userId, amountCents, finalStatus,
        description, toDateString(due_date), notes || null, method,
        plan.id, payment_type, billingMonthDate,
        payment_type === 'package' ? Number(package_months) : null,
        from, periodEnd, discount, membershipId,
      ]);

      await conn.query(
        `INSERT INTO payment_line_items
          (id, payment_id, membership_id, service_id, plan_id, label, amount_cents, sort_order)
         VALUES (?, ?, ?, NULL, ?, ?, ?, 0)`,
        [uuidv4(), paymentId, membershipId, plan.id, plan.name, lineSubtotal]
      );
    }

    await conn.commit();
    return res.status(201).json({
      id: membershipId,
      payment_id: paymentId,
      plan_name: plan.name,
      valid_from: from,
      valid_until: until,
      amount_cents: amountCents,
    });
  } catch (err) {
    await conn.rollback();
    return res.status(400).json({ error: err.message });
  } finally {
    conn.release();
  }
});

router.get('/nutrition/clients', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const [rows] = await db.query(
    `SELECT DISTINCT u.id, u.full_name, u.email, u.weight_kg, u.target_weight_kg, u.height_cm,
            u.body_fat_pct, u.target_body_fat_pct, p.name AS plan_name, m.valid_until
     FROM users u
     JOIN user_memberships m ON m.user_id = u.id AND m.business_id = u.business_id
     JOIN business_plans p ON p.id = m.plan_id AND p.plan_type = 'nutrition'
     WHERE u.business_id = ?
       AND (m.valid_until IS NULL OR m.valid_until >= CURDATE())
       AND COALESCE(m.membership_status, 'active') NOT IN ('trial', 'cancelled')
     ORDER BY u.full_name`,
    [bizId]
  );
  return res.json(rows);
});

router.post('/nutrition/clients/:userId/unenroll', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const userId = req.params.userId;
  const { reason } = req.body || {};

  const client = await assertNutritionClient(bizId, userId);
  if (!client) return res.status(404).json({ error: 'Ο πελάτης δεν έχει ενεργό πακέτο διατροφής' });

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const [result] = await conn.query(
      `UPDATE user_memberships SET
        membership_status = 'cancelled',
        cancelled_at = NOW(),
        cancellation_reason = ?,
        valid_until = LEAST(valid_until, CURDATE())
       WHERE user_id = ? AND business_id = ?
         AND COALESCE(membership_status, 'active') NOT IN ('trial', 'cancelled')
         AND (
           service_category IN ('nutrition', 'nutrition_consultation')
           OR plan_id IN (SELECT id FROM business_plans WHERE business_id = ? AND plan_type = 'nutrition')
         )`,
      [reason?.trim() || null, userId, bizId, bizId],
    );
    await conn.commit();
    if (!result.affectedRows) {
      return res.status(404).json({ error: 'Δεν βρέθηκε ενεργό πακέτο διατροφής' });
    }
    return res.json({ ok: true, message: 'Ο πελάτης αφαιρέθηκε από τη λίστα διατροφής' });
  } catch (err) {
    await conn.rollback();
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

router.get('/nutrition/clients/:userId/summary', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const userId = req.params.userId;
  const client = await assertNutritionClient(bizId, userId);
  if (!client) return res.status(404).json({ error: 'Ο πελάτης δεν έχει ενεργό πακέτο διατροφής' });

  const today = formatDateOnly(new Date());

  const [plan, logs, goals, progress] = await Promise.all([
    fetchMealPlanForDate(db, userId, bizId, today),
    fetchFoodLogsForDate(db, userId, bizId, today),
    fetchNutritionGoals(db, userId),
    fetchNutritionProgress(db, userId),
  ]);

  return res.json({
    client: {
      id: client.id,
      full_name: client.full_name,
      email: client.email,
      plan_name: client.plan_name,
    },
    goals,
    progress,
    today: {
      date: today,
      day_of_week: plan.day_of_week,
      effective_from: plan.effective_from,
      planned_slots: plan.planned_slots || [],
      planned_meals: plan.planned_meals || [],
      food_logs: logs,
    },
    shopping_list: plan.shopping_list,
    effective_from: plan.effective_from,
    week_start: plan.week_start,
  });
});

router.get('/nutrition/portion-units', requireNutritionStaff, (_req, res) => {
  return res.json(PORTION_UNITS.map((unit) => ({ id: unit, label: unit })));
});

router.post('/nutrition/upload', requireNutritionStaff, (req, res, next) => {
  nutritionImageUpload.single('image')(req, res, (err) => {
    if (err) return res.status(400).json({ error: err.message });
    next();
  });
}, async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'Δεν επιλέχθηκε εικόνα' });
  const imageUrl = req.file.publicUrl;
  return res.json({ image_url: imageUrl });
});

router.post('/nutrition/notify', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const { user_ids, title, body } = req.body || {};
  if (!title?.trim() || !body?.trim()) {
    return res.status(400).json({ error: 'Απαιτούνται τίτλος και κείμενο' });
  }
  if (!Array.isArray(user_ids) || !user_ids.length) {
    return res.status(400).json({ error: 'Επίλεξε τουλάχιστον έναν πελάτη' });
  }

  const conn = await db.getConnection();
  let sent = 0;
  try {
    await conn.beginTransaction();
    for (const userId of user_ids) {
      const client = await assertNutritionClient(bizId, userId);
      if (!client) continue;
      await createUserNotification(conn, {
        businessId: bizId,
        userId,
        type: 'nutrition_reminder',
        title: title.trim(),
        body: body.trim(),
        payload: { source: 'nutritionist' },
        sendPush: true,
      });
      sent += 1;
    }
    await conn.commit();
    return res.json({ ok: true, sent });
  } catch (err) {
    await conn.rollback();
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

router.get('/nutrition/clients/:userId/meal-plan', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const userId = req.params.userId;
  const client = await assertNutritionClient(bizId, userId);
  if (!client) return res.status(404).json({ error: 'Ο πελάτης δεν έχει ενεργό πακέτο διατροφής' });

  const refDate = formatDateOnly(req.query.date)
    || formatDateOnly(req.query.effective_from)
    || formatDateOnly(req.query.week_start)
    || formatDateOnly(new Date());
  const plan = await fetchMealPlanTemplate(db, userId, bizId, refDate);
  return res.json(plan);
});

router.get('/nutrition/clients/:userId/meal-plan/versions', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const userId = req.params.userId;
  const client = await assertNutritionClient(bizId, userId);
  if (!client) return res.status(404).json({ error: 'Ο πελάτης δεν έχει ενεργό πακέτο διατροφής' });

  const versions = await listMealPlanVersions(db, userId, bizId);
  return res.json({ versions });
});

router.get('/nutrition/clients/:userId/meal-plan/versions/:planId', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const userId = req.params.userId;
  const client = await assertNutritionClient(bizId, userId);
  if (!client) return res.status(404).json({ error: 'Ο πελάτης δεν έχει ενεργό πακέτο διατροφής' });

  const plan = await fetchMealPlanVersionById(db, userId, bizId, req.params.planId);
  if (!plan) return res.status(404).json({ error: 'Η έκδοση δεν βρέθηκε' });
  return res.json(plan);
});

router.post('/nutrition/clients/:userId/meal-plan/apply-template', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const userId = req.params.userId;
  const client = await assertNutritionClient(bizId, userId);
  if (!client) return res.status(404).json({ error: 'Ο πελάτης δεν έχει ενεργό πακέτο διατροφής' });

  const { template_id, effective_from } = req.body || {};
  if (!template_id) return res.status(400).json({ error: 'Απαιτείται template_id' });

  try {
    const eff = formatDateOnly(effective_from) || formatDateOnly(new Date());
    const plan = await applyProgramTemplateToClient(db, bizId, userId, template_id, eff, uuidv4);
    return res.json(plan);
  } catch (err) {
    return res.status(400).json({ error: err.message });
  }
});

router.post('/nutrition/shopping-list/smart', requireNutritionStaff, async (req, res) => {
  const { slots } = req.body || {};
  if (!Array.isArray(slots)) {
    return res.status(400).json({ error: 'Απαιτούνται slots' });
  }
  try {
    const payload = normalizeMealPlanPayload({ slots });
    return res.json({
      items: buildSmartShoppingList(payload.slots),
    });
  } catch (err) {
    return res.status(400).json({ error: err.message });
  }
});

router.get('/nutrition/templates', requireNutritionStaff, async (req, res) => {
  const templates = await listProgramTemplates(db, req.admin.businessId);
  return res.json({ templates });
});

router.post('/nutrition/templates', requireNutritionStaff, async (req, res) => {
  try {
    const tpl = await createProgramTemplate(db, req.admin.businessId, req.body, uuidv4(), uuidv4);
    return res.status(201).json(tpl);
  } catch (err) {
    return res.status(400).json({ error: err.message });
  }
});

router.get('/nutrition/templates/:templateId', requireNutritionStaff, async (req, res) => {
  const tpl = await fetchProgramTemplate(db, req.admin.businessId, req.params.templateId);
  if (!tpl) return res.status(404).json({ error: 'Το πρότυπο δεν βρέθηκε' });
  return res.json(tpl);
});

router.put('/nutrition/templates/:templateId', requireNutritionStaff, async (req, res) => {
  try {
    const tpl = await updateProgramTemplate(db, req.admin.businessId, req.params.templateId, req.body, uuidv4);
    if (!tpl) return res.status(404).json({ error: 'Το πρότυπο δεν βρέθηκε' });
    return res.json(tpl);
  } catch (err) {
    return res.status(400).json({ error: err.message });
  }
});

router.delete('/nutrition/templates/:templateId', requireNutritionStaff, async (req, res) => {
  const ok = await deleteProgramTemplate(db, req.admin.businessId, req.params.templateId);
  if (!ok) return res.status(404).json({ error: 'Το πρότυπο δεν βρέθηκε' });
  return res.json({ ok: true });
});

router.put('/nutrition/clients/:userId/meal-plan', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const userId = req.params.userId;
  const client = await assertNutritionClient(bizId, userId);
  if (!client) return res.status(404).json({ error: 'Ο πελάτης δεν έχει ενεργό πακέτο διατροφής' });

  let payload;
  try {
    payload = normalizeMealPlanPayload(req.body);
  } catch (err) {
    return res.status(400).json({ error: err.message });
  }

  const { effectiveFrom, weekStart, notes, slots } = payload;
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const [[existing]] = await conn.query(
      `SELECT id FROM meal_plans
       WHERE user_id=? AND business_id=? AND COALESCE(effective_from, week_start)=?`,
      [userId, bizId, effectiveFrom]
    );

    let planId = existing?.id;
    if (planId) {
      await conn.query(
        'UPDATE meal_plans SET notes=?, effective_from=?, week_start=? WHERE id=?',
        [notes ?? null, effectiveFrom, weekStart, planId]
      );
      await conn.query('DELETE FROM meal_plan_items WHERE meal_plan_id=?', [planId]);
    } else {
      planId = uuidv4();
      await conn.query(
        `INSERT INTO meal_plans (id, business_id, user_id, week_start, effective_from, notes)
         VALUES (?,?,?,?,?,?)`,
        [planId, bizId, userId, weekStart, effectiveFrom, notes ?? null]
      );
    }

    await insertMealPlanSlotItems(conn, planId, slots, uuidv4);

    await conn.commit();
    const plan = await fetchMealPlanTemplate(db, userId, bizId, effectiveFrom);
    return res.json(plan);
  } catch (err) {
    await conn.rollback();
    return res.status(400).json({ error: err.message });
  } finally {
    conn.release();
  }
});

router.get('/nutrition/clients/:userId/goals', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const userId = req.params.userId;
  const client = await assertNutritionClient(bizId, userId);
  if (!client) return res.status(404).json({ error: 'Ο πελάτης δεν έχει ενεργό πακέτο διατροφής' });

  const goals = await fetchNutritionGoals(db, userId);
  return res.json(goals);
});

router.put('/nutrition/clients/:userId/goals', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const userId = req.params.userId;
  const client = await assertNutritionClient(bizId, userId);
  if (!client) return res.status(404).json({ error: 'Ο πελάτης δεν έχει ενεργό πακέτο διατροφής' });

  const { target_weight_kg, target_body_fat_pct, height_cm } = req.body || {};
  const updates = [];
  const params = [];

  try {
    if (target_weight_kg !== undefined) {
      updates.push('target_weight_kg = ?');
      params.push(target_weight_kg === null || target_weight_kg === '' ? null : normalizeWeight(target_weight_kg));
    }
    if (target_body_fat_pct !== undefined) {
      updates.push('target_body_fat_pct = ?');
      params.push(target_body_fat_pct === null || target_body_fat_pct === '' ? null : normalizeBodyFat(target_body_fat_pct));
    }
    if (height_cm !== undefined) {
      updates.push('height_cm = ?');
      params.push(height_cm === null || height_cm === '' ? null : normalizeHeight(height_cm));
    }
  } catch (err) {
    return res.status(400).json({ error: err.message });
  }

  if (!updates.length) {
    return res.status(400).json({ error: 'Δεν υπάρχουν στοιχεία προς ενημέρωση' });
  }

  params.push(userId);
  await db.query(`UPDATE users SET ${updates.join(', ')} WHERE id = ?`, params);
  const goals = await fetchNutritionGoals(db, userId);
  return res.json(goals);
});

router.get('/nutrition/clients/:userId/measurements', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const userId = req.params.userId;
  const client = await assertNutritionClient(bizId, userId);
  if (!client) return res.status(404).json({ error: 'Ο πελάτης δεν έχει ενεργό πακέτο διατροφής' });

  const measurements = await fetchNutritionMeasurements(db, userId, 48);
  const progress = await fetchNutritionProgress(db, userId);
  return res.json({ measurements, progress });
});

router.post('/nutrition/clients/:userId/measurements', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const userId = req.params.userId;
  const client = await assertNutritionClient(bizId, userId);
  if (!client) return res.status(404).json({ error: 'Ο πελάτης δεν έχει ενεργό πακέτο διατροφής' });

  try {
    const measurement = await insertNutritionMeasurement(
      db, bizId, userId, { ...req.body, recorded_by: 'nutritionist', sync_profile: true }, uuidv4()
    );
    const progress = await fetchNutritionProgress(db, userId);
    return res.status(201).json({ measurement, progress });
  } catch (err) {
    return res.status(400).json({ error: err.message });
  }
});

router.get('/nutrition/clients/:userId/food-logs', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const userId = req.params.userId;
  const client = await assertNutritionClient(bizId, userId);
  if (!client) return res.status(404).json({ error: 'Ο πελάτης δεν έχει ενεργό πακέτο διατροφής' });

  const logDate = formatDateOnly(req.query.date) || formatDateOnly(new Date());
  const logs = await fetchFoodLogsForDate(db, userId, bizId, logDate);
  return res.json({ date: logDate, logs });
});

router.get('/nutrition/clients/:userId/day', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const userId = req.params.userId;
  const client = await assertNutritionClient(bizId, userId);
  if (!client) return res.status(404).json({ error: 'Ο πελάτης δεν έχει ενεργό πακέτο διατροφής' });

  const logDate = formatDateOnly(req.query.date) || formatDateOnly(new Date());

  const [plan, logs, goals] = await Promise.all([
    fetchMealPlanForDate(db, userId, bizId, logDate),
    fetchFoodLogsForDate(db, userId, bizId, logDate),
    fetchNutritionGoals(db, userId),
  ]);

  return res.json({
    date: logDate,
    day_of_week: plan.day_of_week,
    effective_from: plan.effective_from,
    week_start: plan.week_start,
    planned_slots: plan.planned_slots || [],
    food_logs: logs,
    goals,
  });
});

router.get('/nutrition/clients/:userId/food-logs/calendar', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const userId = req.params.userId;
  const client = await assertNutritionClient(bizId, userId);
  if (!client) return res.status(404).json({ error: 'Ο πελάτης δεν έχει ενεργό πακέτο διατροφής' });

  const now = new Date();
  const year = Number(req.query.year) || now.getFullYear();
  const month = Number(req.query.month) || now.getMonth() + 1;
  const from = `${year}-${String(month).padStart(2, '0')}-01`;
  const lastDay = new Date(year, month, 0).getDate();
  const to = `${year}-${String(month).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;

  const [rows] = await db.query(
    `SELECT log_date, COUNT(*) AS log_count
     FROM food_logs
     WHERE user_id = ? AND business_id = ? AND log_date BETWEEN ? AND ?
     GROUP BY log_date
     ORDER BY log_date`,
    [userId, bizId, from, to]
  );

  return res.json({
    year,
    month,
    days: rows.map((row) => ({
      date: formatDateOnly(row.log_date),
      log_count: Number(row.log_count),
    })),
  });
});

router.get('/nutrition/clients/:userId/food-logs/export', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const userId = req.params.userId;
  const client = await assertNutritionClient(bizId, userId);
  if (!client) return res.status(404).json({ error: 'Ο πελάτης δεν έχει ενεργό πακέτο διατροφής' });

  const from = formatDateOnly(req.query.from) || formatDateOnly(new Date());
  const to = formatDateOnly(req.query.to) || from;

  const [rows] = await db.query(
    `SELECT log_date, meal_type, description, photo_url, plan_option_id, logged_at
     FROM food_logs
     WHERE user_id = ? AND business_id = ? AND log_date BETWEEN ? AND ?
     ORDER BY log_date,
              FIELD(meal_type, 'breakfast', 'lunch', 'dinner', 'snack'),
              logged_at`,
    [userId, bizId, from, to]
  );

  const escape = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`;
  const lines = ['Ημερομηνία,Γεύμα,Περιγραφή,Σύνδεση προγράμματος,Φωτογραφία,Ώρα καταγραφής'];
  for (const row of rows) {
    lines.push([
      formatDateOnly(row.log_date),
      MEAL_TYPE_LABELS[row.meal_type] || row.meal_type,
      escape(row.description),
      row.plan_option_id || '',
      row.photo_url || '',
      row.logged_at ? new Date(row.logged_at).toISOString() : '',
    ].join(','));
  }

  const filename = `food-logs-${client.full_name.replace(/\s+/g, '-')}-${from}-${to}.csv`;
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
  return res.send(`\uFEFF${lines.join('\n')}`);
});

function adminNutritionistScope(req) {
  return req.admin.role === 'nutritionist' ? req.admin.nutritionistId : null;
}

// Nutrition consultation schedule & bookings (nutritionist or owner)
async function resolveConsultationContext(bizId, { nutritionistId = null } = {}) {
  let nut;
  if (nutritionistId) {
    const [[row]] = await db.query(
      'SELECT * FROM nutritionists WHERE id=? AND business_id=? AND is_active=1',
      [nutritionistId, bizId],
    );
    nut = row;
  } else {
    const [[row]] = await db.query(
      'SELECT * FROM nutritionists WHERE business_id=? AND is_active=1 ORDER BY full_name LIMIT 1',
      [bizId],
    );
    nut = row;
  }
  if (!nut) return null;
  const setup = await ensureNutritionConsultationSetup(db, bizId, nut);
  if (!setup.serviceId) return null;
  return { ...setup, nutritionist: nut };
}

router.get('/nutrition/consultation/setup', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const scopeId = adminNutritionistScope(req) || req.query.nutritionist_id || null;
  const ctx = await resolveConsultationContext(bizId, { nutritionistId: scopeId });
  if (!ctx) return res.json({ ready: false, nutritionists: [] });

  const nutritionists = await listActiveNutritionists(db, bizId);
  const [[service]] = await db.query(
    'SELECT id, name, duration_mins FROM services WHERE id=?',
    [ctx.serviceId]
  );
  return res.json({
    ready: true,
    service_id: ctx.serviceId,
    staff_id: ctx.staffId,
    service,
    nutritionist: {
      id: ctx.nutritionist.id,
      full_name: ctx.nutritionist.full_name,
      location_id: ctx.nutritionist.location_id,
    },
    nutritionists,
    selected_nutritionist_id: ctx.nutritionist.id,
  });
});

router.get('/nutrition/consultation/slot-schedules', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const scopeId = adminNutritionistScope(req) || req.query.nutritionist_id || null;
  const ctx = await resolveConsultationContext(bizId, { nutritionistId: scopeId });
  if (!ctx) return res.json([]);
  const [rows] = await db.query(
    `SELECT sss.*, st.full_name AS staff_name
     FROM service_slot_schedules sss
     LEFT JOIN staff st ON st.id = sss.staff_id
     WHERE sss.service_id = ? AND sss.business_id = ? AND sss.staff_id = ?
     ORDER BY sss.weekday, sss.start_time`,
    [ctx.serviceId, bizId, ctx.staffId]
  );
  return res.json(rows);
});

router.post('/nutrition/consultation/slot-schedules', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const scopeId = adminNutritionistScope(req) || req.body?.nutritionist_id || null;
  const ctx = await resolveConsultationContext(bizId, { nutritionistId: scopeId });
  if (!ctx) return res.status(400).json({ error: 'Ορίστε πρώτα προφίλ διατροφολόγου' });

  const { weekdays, start_times, max_capacity } = req.body || {};
  const days = Array.isArray(weekdays) ? [...new Set(weekdays.map(Number))] : [];
  const times = Array.isArray(start_times) ? start_times : [];
  if (!days.length || !times.length) {
    return res.status(400).json({ error: 'Επίλεξε ημέρες και ώρες' });
  }

  const normalizeTime = (t) => {
    const parts = String(t).split(':');
    return `${parts[0].padStart(2, '0')}:${parts[1].padStart(2, '0')}:00`;
  };

  let created = 0;
  for (const wd of days) {
    for (const rawTime of times) {
      const time = normalizeTime(rawTime);
      await db.query(
        `INSERT INTO service_slot_schedules
          (id, service_id, business_id, weekday, start_time, label, max_capacity, staff_id, is_active)
         VALUES (?,?,?,?,?,?,?,?,1)`,
        [uuidv4(), ctx.serviceId, bizId, wd, time, 'Συνεδρία', 1, ctx.staffId]
      );
      created += 1;
    }
  }
  return res.status(201).json({ created });
});

router.delete('/nutrition/consultation/slot-schedules/:scheduleId', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const scopeId = adminNutritionistScope(req) || req.query.nutritionist_id || null;
  const ctx = await resolveConsultationContext(bizId, { nutritionistId: scopeId });
  if (!ctx) return res.status(404).json({ error: 'Not found' });
  await db.query(
    'DELETE FROM service_slot_schedules WHERE id=? AND service_id=? AND business_id=?',
    [req.params.scheduleId, ctx.serviceId, req.admin.businessId]
  );
  return res.json({ ok: true });
});

router.get('/nutrition/bookings', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const serviceId = await getConsultationServiceId(db, bizId);
  if (!serviceId) return res.json([]);

  const scopeId = adminNutritionistScope(req);
  let staffFilter = '';
  const staffParams = [];
  if (scopeId) {
    const nut = await getNutritionistById(db, bizId, scopeId);
    if (nut?.staff_id) {
      staffFilter = ' AND b.staff_id = ?';
      staffParams.push(nut.staff_id);
    }
  }

  const status = req.query.status;
  let sql = `
    SELECT b.id, b.starts_at, b.ends_at, b.status, b.source, b.created_at,
           u.full_name AS client_name, u.email AS client_email, u.phone AS client_phone,
           s.name AS service_name, st.full_name AS nutritionist_name,
           l.name AS location_name
    FROM bookings b
    JOIN users u ON u.id = b.user_id
    JOIN services s ON s.id = b.service_id
    LEFT JOIN staff st ON st.id = b.staff_id
    LEFT JOIN locations l ON l.id = b.location_id
    WHERE b.business_id = ? AND b.service_id = ?
    ${staffFilter}
  `;
  const params = [bizId, serviceId, ...staffParams];
  if (status) {
    sql += ' AND b.status = ?';
    params.push(status);
  }
  sql += ' ORDER BY b.starts_at DESC LIMIT 200';
  const [rows] = await db.query(sql, params);
  return res.json(rows);
});

router.get('/nutrition/bookings/bookable-clients', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const serviceId = await resolveConsultationServiceId(db, bizId);

  const q = String(req.query.q || '').trim().toLowerCase();
  const [users] = await db.query(
    `SELECT u.id, u.full_name, u.email, u.phone, u.account_status
     FROM users u
     WHERE u.business_id = ?
       AND ${sqlActiveClients('u')}
       AND COALESCE(u.account_status, 'active') = 'active'
     ORDER BY u.full_name`,
    [bizId],
  );

  const clients = [];
  for (const user of users) {
    await ensureConsultationCreditsFromNutritionPlan(db, bizId, user.id);
    const membership = await findConsultationMembership(db, user.id, bizId);
    const credits = consultationCreditsSummary(membership);
    if (!credits.can_book) continue;

    const pending = await findPendingConsultationBooking(
      db, user.id, bizId, serviceId || membership?.service_id,
    );
    const hay = `${user.full_name} ${user.email || ''} ${user.phone || ''}`.toLowerCase();
    if (q && !hay.includes(q)) continue;

    clients.push({
      id: user.id,
      full_name: user.full_name,
      email: user.email,
      phone: user.phone,
      credits_remaining: credits.remaining,
      credits_total: credits.total,
      credits_valid_until: credits.valid_until,
      has_pending_booking: !!pending,
    });
  }
  return res.json(clients);
});

router.get('/nutrition/bookings/slots', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const { date } = req.query;
  if (!date) return res.status(400).json({ error: 'Απαιτείται ημερομηνία' });

  const scopeId = adminNutritionistScope(req) || req.query.nutritionist_id || null;
  const ctx = await resolveConsultationContext(bizId, { nutritionistId: scopeId });
  if (!ctx) return res.json({ date, slots: [], message: 'Δεν έχει οριστεί διατροφολόγος' });

  const computed = await computeAvailableSlots(
    db, bizId, ctx.serviceId, date, null, null, ctx.staffId,
  );
  if (!computed) {
    return res.json({ date, slots: [], message: 'Η υπηρεσία δεν βρέθηκε' });
  }
  if (computed.closedReason) {
    return res.json({ date, slots: [], message: 'Το γυμναστήριο είναι κλειστό αυτή την ημέρα' });
  }

  const payload = buildSlotsPayload(computed, { featureWaitlist: false, date });
  return res.json({
    date,
    slots: payload.slots,
    message: payload.message,
    nutritionist_id: ctx.nutritionist.id,
    staff_id: ctx.staffId,
  });
});

router.post('/nutrition/bookings', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const { user_id, date, time, nutritionist_id: nutritionistId } = req.body || {};
  if (!user_id || !date || !time) {
    return res.status(400).json({ error: 'Απαιτούνται πελάτης, ημερομηνία και ώρα' });
  }

  const scopeId = adminNutritionistScope(req) || nutritionistId || null;
  const ctx = await resolveConsultationContext(bizId, { nutritionistId: scopeId });
  if (!ctx?.staffId) {
    return res.status(400).json({ error: 'Δεν έχει οριστεί διατροφολόγος' });
  }

  const [[user]] = await db.query(
    'SELECT id, full_name, account_status FROM users WHERE id = ? AND business_id = ?',
    [user_id, bizId],
  );
  if (!user) return res.status(404).json({ error: 'Ο πελάτης δεν βρέθηκε' });
  if (user.account_status && user.account_status !== 'active') {
    return res.status(400).json({ error: 'Ο πελάτης δεν είναι ενεργός' });
  }

  const membership = await findConsultationMembership(db, user_id, bizId);
  const credits = consultationCreditsSummary(membership);
  if (!credits.can_book) {
    return res.status(400).json({ error: 'Ο πελάτης δεν έχει διαθέσιμες επισκέψεις με διατροφολόγο' });
  }

  const pending = await findPendingConsultationBooking(db, user_id, bizId, ctx.serviceId);
  if (pending) {
    return res.status(409).json({ error: 'Ο πελάτης έχει ήδη ενεργό αίτημα κράτησης' });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const result = await createOneBooking(conn, {
      bizId,
      userId: user_id,
      service_id: ctx.serviceId,
      staff_id: ctx.staffId,
      date,
      time,
      use_credit: true,
      status: 'confirmed',
      source: 'admin',
    });

    await conn.commit();
    return res.status(201).json(result);
  } catch (err) {
    await conn.rollback();
    let status = 400;
    if (err.code === 'SLOT_FULL' || err.code === 'TIME_CONFLICT' || err.code === 'DUPLICATE_BOOKING') {
      status = 409;
    }
    return res.status(status).json({ error: err.message, code: err.code || null });
  } finally {
    conn.release();
  }
});

router.patch('/nutrition/bookings/:id/status', requireNutritionStaff, async (req, res) => {
  const { status } = req.body || {};
  const bizId = req.admin.businessId;
  const serviceId = await getConsultationServiceId(db, bizId);
  if (!serviceId) return res.status(404).json({ error: 'Η υπηρεσία δεν βρέθηκε' });

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const [[booking]] = await conn.query(`
      SELECT b.*, sv.name AS service_name
      FROM bookings b
      JOIN services sv ON sv.id = b.service_id
      WHERE b.id = ? AND b.business_id = ? AND b.service_id = ?
    `, [req.params.id, bizId, serviceId]);
    if (!booking) {
      await conn.rollback();
      return res.status(404).json({ error: 'Η κράτηση δεν βρέθηκε' });
    }

    const scopeId = adminNutritionistScope(req);
    if (scopeId) {
      const nut = await getNutritionistById(db, bizId, scopeId);
      if (nut?.staff_id && booking.staff_id !== nut.staff_id) {
        await conn.rollback();
        return res.status(403).json({ error: 'Δεν έχεις πρόσβαση σε αυτή την κράτηση' });
      }
    }

    await conn.query('UPDATE bookings SET status=? WHERE id=?', [status, req.params.id]);

    if (status === 'confirmed' && booking.status === 'pending' && booking.membership_id) {
      await chargeBookingMembershipOnConfirm(conn, booking);
      const { createUserNotification } = require('../lib/user_notifications');
      const when = new Date(booking.starts_at);
      await createUserNotification(conn, {
        businessId: bizId,
        userId: booking.user_id,
        bookingId: booking.id,
        type: 'booking_confirmed',
        title: `Κράτηση επιβεβαιώθηκε — ${booking.service_name}`,
        body: `Στις ${when.toISOString().slice(0, 10)} ${when.toTimeString().slice(0, 5)}.`,
        payload: { action: 'open_booking', booking_id: booking.id },
        sendPush: true,
      });
    }

    await conn.commit();
    return res.json({ ok: true });
  } catch (err) {
    await conn.rollback();
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

router.delete('/nutrition/bookings/:id', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  const serviceId = await getConsultationServiceId(db, bizId);
  if (!serviceId) return res.status(404).json({ error: 'Η υπηρεσία δεν βρέθηκε' });

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const [[booking]] = await conn.query(
      'SELECT id, staff_id, service_id FROM bookings WHERE id = ? AND business_id = ? AND service_id = ?',
      [req.params.id, bizId, serviceId],
    );
    if (!booking) {
      await conn.rollback();
      return res.status(404).json({ error: 'Η κράτηση δεν βρέθηκε' });
    }

    const scopeId = adminNutritionistScope(req);
    if (scopeId) {
      const nut = await getNutritionistById(db, bizId, scopeId);
      if (nut?.staff_id && booking.staff_id !== nut.staff_id) {
        await conn.rollback();
        return res.status(403).json({ error: 'Δεν έχεις πρόσβαση σε αυτή την κράτηση' });
      }
    }

    const deleted = await deleteBookingForBusiness(conn, bizId, req.params.id);
    if (!deleted) {
      await conn.rollback();
      return res.status(404).json({ error: 'Η κράτηση δεν βρέθηκε' });
    }

    await conn.commit();
    return res.json({ ok: true, message: 'Η κράτηση διαγράφηκε' });
  } catch (err) {
    await conn.rollback();
    return res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// Nutritionist accounts (owner manages list; nutritionist reads own profile)
router.get('/nutritionists', requireClientAdmin, async (req, res) => {
  const bizId = req.admin.businessId;
  const [rows] = await db.query(
    `SELECT n.id, n.full_name, n.email, n.phone, n.bio, n.is_active, n.created_at, n.staff_id, n.location_id,
            l.name AS location_name
     FROM nutritionists n
     LEFT JOIN locations l ON l.id = n.location_id
     WHERE n.business_id = ?
     ORDER BY l.sort_order, l.name, n.full_name`,
    [bizId],
  );
  return res.json(rows);
});

router.post('/nutritionists', requireClientAdmin, async (req, res) => {
  const {
    full_name, email, password, is_active = true, phone, bio, location_id,
  } = req.body || {};
  if (!full_name || !email) {
    return res.status(400).json({ error: 'Απαιτούνται όνομα και email' });
  }

  const bizId = req.admin.businessId;
  const nutritionistId = uuidv4();
  await db.query(
    `INSERT INTO nutritionists (id, business_id, location_id, full_name, email, is_active, phone, bio)
     VALUES (?,?,?,?,?,?,?,?)`,
    [nutritionistId, bizId, location_id || null, full_name, email, is_active ? 1 : 0, phone || null, bio || null],
  );

  if (password) {
    const hash = await bcrypt.hash(password, 10);
    await db.query(
      'INSERT INTO nutritionist_passwords (nutritionist_id, password_hash) VALUES (?,?)',
      [nutritionistId, hash],
    );
  }

  const [[row]] = await db.query('SELECT * FROM nutritionists WHERE id=?', [nutritionistId]);
  await ensureNutritionConsultationSetup(db, bizId, row);
  const [[updated]] = await db.query(
    `SELECT n.id, n.full_name, n.email, n.phone, n.bio, n.is_active, n.created_at, n.staff_id, n.location_id,
            l.name AS location_name
     FROM nutritionists n
     LEFT JOIN locations l ON l.id = n.location_id
     WHERE n.id = ?`,
    [nutritionistId],
  );
  return res.status(201).json(updated);
});

router.put('/nutritionists/:id', requireClientAdmin, async (req, res) => {
  const {
    full_name, email, password, is_active = true, phone, bio, location_id,
  } = req.body || {};
  if (!full_name || !email) {
    return res.status(400).json({ error: 'Απαιτούνται όνομα και email' });
  }

  const bizId = req.admin.businessId;
  const nutritionistId = req.params.id;
  const [[existing]] = await db.query(
    'SELECT * FROM nutritionists WHERE id=? AND business_id=?',
    [nutritionistId, bizId],
  );
  if (!existing) return res.status(404).json({ error: 'Δεν βρέθηκε' });

  await db.query(
    `UPDATE nutritionists
     SET full_name=?, email=?, is_active=?, phone=?, bio=?, location_id=?
     WHERE id=? AND business_id=?`,
    [full_name, email, is_active ? 1 : 0, phone || null, bio || null, location_id || null, nutritionistId, bizId],
  );

  if (password) {
    const hash = await bcrypt.hash(password, 10);
    await db.query(
      `INSERT INTO nutritionist_passwords (nutritionist_id, password_hash) VALUES (?,?)
       ON DUPLICATE KEY UPDATE password_hash=VALUES(password_hash)`,
      [nutritionistId, hash],
    );
  }

  const [[row]] = await db.query('SELECT * FROM nutritionists WHERE id=?', [nutritionistId]);
  await ensureNutritionConsultationSetup(db, bizId, row);
  const [[updated]] = await db.query(
    `SELECT n.id, n.full_name, n.email, n.phone, n.bio, n.is_active, n.created_at, n.staff_id, n.location_id,
            l.name AS location_name
     FROM nutritionists n
     LEFT JOIN locations l ON l.id = n.location_id
     WHERE n.id = ?`,
    [nutritionistId],
  );
  return res.json(updated);
});

router.get('/nutritionist', requireNutritionStaff, async (req, res) => {
  const bizId = req.admin.businessId;
  if (req.admin.role === 'nutritionist') {
    const [[row]] = await db.query(
      `SELECT n.id, n.full_name, n.email, n.phone, n.bio, n.is_active, n.created_at, n.staff_id, n.location_id,
              l.name AS location_name
       FROM nutritionists n
       LEFT JOIN locations l ON l.id = n.location_id
       WHERE n.id = ? AND n.business_id = ?`,
      [req.admin.nutritionistId, bizId],
    );
    return res.json(row || null);
  }
  const [[row]] = await db.query(
    `SELECT n.id, n.full_name, n.email, n.phone, n.bio, n.is_active, n.created_at, n.staff_id, n.location_id,
            l.name AS location_name
     FROM nutritionists n
     LEFT JOIN locations l ON l.id = n.location_id
     WHERE n.business_id = ?
     ORDER BY n.full_name LIMIT 1`,
    [bizId],
  );
  return res.json(row || null);
});

mountTrainerPortal(router, {
  db,
  jwt,
  requireClientAdmin,
  enrichClientProfile,
  normalizeFitnessGoal,
  FITNESS_GOAL_LABELS,
  getUserStats,
});

router.use('/messages', messagesStaffRoutes);

// ============================================================
// WORKOUT PROGRAMS
// ============================================================

// --- Exercises ---
router.get('/exercises', requireClientAdmin, async (req, res) => {
  const [rows] = await db.query(
    'SELECT * FROM exercises WHERE business_id=? AND is_active=1 ORDER BY sort_order, name',
    [req.admin.businessId]
  );
  res.json(rows);
});

router.post('/exercises', requireClientAdmin, async (req, res) => {
  const { name, description, muscle_group, animation_url, thumbnail_url } = req.body;
  if (!name) return res.status(400).json({ error: 'Το όνομα είναι υποχρεωτικό' });
  const id = uuidv4();
  await db.query(
    'INSERT INTO exercises (id,business_id,name,description,muscle_group,animation_url,thumbnail_url) VALUES (?,?,?,?,?,?,?)',
    [id, req.admin.businessId, name, description||null, muscle_group||null, animation_url||null, thumbnail_url||null]
  );
  res.status(201).json({ id });
});

router.patch('/exercises/:id', requireClientAdmin, async (req, res) => {
  const { name, description, muscle_group, animation_url, thumbnail_url, is_active } = req.body;
  const fields = [];
  const vals = [];
  if (name !== undefined) { fields.push('name=?'); vals.push(name); }
  if (description !== undefined) { fields.push('description=?'); vals.push(description||null); }
  if (muscle_group !== undefined) { fields.push('muscle_group=?'); vals.push(muscle_group||null); }
  if (animation_url !== undefined) { fields.push('animation_url=?'); vals.push(animation_url||null); }
  if (thumbnail_url !== undefined) { fields.push('thumbnail_url=?'); vals.push(thumbnail_url||null); }
  if (is_active !== undefined) { fields.push('is_active=?'); vals.push(is_active ? 1 : 0); }
  if (!fields.length) return res.status(400).json({ error: 'Δεν δόθηκαν πεδία' });
  vals.push(req.params.id, req.admin.businessId);
  await db.query(`UPDATE exercises SET ${fields.join(',')} WHERE id=? AND business_id=?`, vals);
  res.json({ ok: true });
});

router.delete('/exercises/:id', requireClientAdmin, async (req, res) => {
  await db.query('UPDATE exercises SET is_active=0 WHERE id=? AND business_id=?', [req.params.id, req.admin.businessId]);
  res.json({ ok: true });
});

// Upload media (image/gif/video) for an exercise
router.post('/exercises/:id/media', requireClientAdmin, (req, res, next) => {
  const upload = r2Multer({
    keyFn: (req2, file) => {
      const ext = path.extname(file.originalname).toLowerCase();
      return `uploads/${req2.admin.businessId}/exercises/${req2.params.id}-${Date.now()}${ext}`;
    },
    maxSizeMb: 100,
  });
  upload.single('media')(req, res, next);
}, async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'Δεν ανέβηκε αρχείο' });
  const url = req.file.publicUrl;
  await db.query('UPDATE exercises SET animation_url=? WHERE id=? AND business_id=?',
    [url, req.params.id, req.admin.businessId]);
  res.json({ url });
});

// --- Programs ---
router.get('/programs', requireClientAdmin, async (req, res) => {
  const [rows] = await db.query(
    'SELECT * FROM workout_programs WHERE business_id=? ORDER BY created_at DESC',
    [req.admin.businessId]
  );
  res.json(rows);
});

router.get('/programs/:id', requireClientAdmin, async (req, res) => {
  const [[prog]] = await db.query('SELECT * FROM workout_programs WHERE id=? AND business_id=?', [req.params.id, req.admin.businessId]);
  if (!prog) return res.status(404).json({ error: 'Δεν βρέθηκε' });
  const [items] = await db.query(
    `SELECT pe.*, e.name AS exercise_name, e.muscle_group, e.animation_url, e.thumbnail_url
     FROM program_exercises pe
     JOIN exercises e ON e.id = pe.exercise_id
     WHERE pe.program_id=? ORDER BY pe.sort_order`,
    [req.params.id]
  );
  res.json({ ...prog, exercises: items });
});

router.post('/programs', requireClientAdmin, async (req, res) => {
  const { name, description, exercises = [] } = req.body;
  if (!name) return res.status(400).json({ error: 'Το όνομα είναι υποχρεωτικό' });
  const id = uuidv4();
  await db.query(
    'INSERT INTO workout_programs (id,business_id,name,description) VALUES (?,?,?,?)',
    [id, req.admin.businessId, name, description||null]
  );
  for (let i = 0; i < exercises.length; i++) {
    const ex = exercises[i];
    await db.query(
      'INSERT INTO program_exercises (id,program_id,exercise_id,exercise_sets,exercise_reps,duration_secs,rest_secs,notes,sort_order) VALUES (?,?,?,?,?,?,?,?,?)',
      [uuidv4(), id, ex.exercise_id, ex.sets||null, ex.reps||null, ex.duration_secs||null, ex.rest_secs||null, ex.notes||null, i]
    );
  }
  res.status(201).json({ id });
});

router.patch('/programs/:id', requireClientAdmin, async (req, res) => {
  const { name, description, is_active, exercises } = req.body;
  const fields = [];
  const vals = [];
  if (name !== undefined) { fields.push('name=?'); vals.push(name); }
  if (description !== undefined) { fields.push('description=?'); vals.push(description||null); }
  if (is_active !== undefined) { fields.push('is_active=?'); vals.push(is_active ? 1 : 0); }
  if (fields.length) {
    vals.push(req.params.id, req.admin.businessId);
    await db.query(`UPDATE workout_programs SET ${fields.join(',')} WHERE id=? AND business_id=?`, vals);
  }
  if (exercises !== undefined) {
    await db.query('DELETE FROM program_exercises WHERE program_id=?', [req.params.id]);
    for (let i = 0; i < exercises.length; i++) {
      const ex = exercises[i];
      await db.query(
        'INSERT INTO program_exercises (id,program_id,exercise_id,exercise_sets,exercise_reps,duration_secs,rest_secs,notes,sort_order) VALUES (?,?,?,?,?,?,?,?,?)',
        [uuidv4(), req.params.id, ex.exercise_id, ex.sets||null, ex.reps||null, ex.duration_secs||null, ex.rest_secs||null, ex.notes||null, i]
      );
    }
  }
  res.json({ ok: true });
});

router.delete('/programs/:id', requireClientAdmin, async (req, res) => {
  await db.query('UPDATE workout_programs SET is_active=0 WHERE id=? AND business_id=?', [req.params.id, req.admin.businessId]);
  res.json({ ok: true });
});

// --- Client program assignments ---
router.get('/clients/:userId/programs', requireClientAdmin, async (req, res) => {
  const [rows] = await db.query(
    `SELECT cp.*, wp.name AS program_name, wp.description AS program_description
     FROM client_programs cp
     JOIN workout_programs wp ON wp.id = cp.program_id
     WHERE cp.user_id=? AND cp.business_id=?
     ORDER BY cp.assigned_at DESC`,
    [req.params.userId, req.admin.businessId]
  );
  res.json(rows);
});

router.post('/clients/:userId/programs', requireClientAdmin, async (req, res) => {
  const { program_id, assigned_at, notes } = req.body;
  if (!program_id) return res.status(400).json({ error: 'program_id required' });
  const id = uuidv4();
  const date = assigned_at || new Date().toISOString().slice(0, 10);
  await db.query(
    'INSERT INTO client_programs (id,user_id,business_id,program_id,assigned_at,notes) VALUES (?,?,?,?,?,?)',
    [id, req.params.userId, req.admin.businessId, program_id, date, notes||null]
  );
  res.status(201).json({ id });
});

router.delete('/clients/:userId/programs/:cpId', requireClientAdmin, async (req, res) => {
  await db.query('DELETE FROM client_programs WHERE id=? AND business_id=?', [req.params.cpId, req.admin.businessId]);
  res.json({ ok: true });
});

// Mobile API: client sees their own programs (used by app)
router.get('/my-programs', async (req, res) => {
  const bizId = req.headers['x-business-id'];
  const userId = req.headers['x-user-id'];
  if (!bizId || !userId) return res.status(400).json({ error: 'Missing headers' });
  const [assignments] = await db.query(
    `SELECT cp.id as assignment_id, cp.assigned_at, cp.notes as assignment_notes,
            wp.id as program_id, wp.name as program_name, wp.description as program_description
     FROM client_programs cp
     JOIN workout_programs wp ON wp.id=cp.program_id AND wp.is_active=1
     WHERE cp.user_id=? AND cp.business_id=? AND cp.is_active=1
     ORDER BY cp.assigned_at DESC`,
    [userId, bizId]
  );
  const result = [];
  for (const a of assignments) {
    const [exs] = await db.query(
      `SELECT pe.*, e.name AS exercise_name, e.muscle_group, e.animation_url, e.thumbnail_url, e.description AS exercise_description
       FROM program_exercises pe
       JOIN exercises e ON e.id=pe.exercise_id AND e.is_active=1
       WHERE pe.program_id=? ORDER BY pe.sort_order`,
      [a.program_id]
    );
    result.push({ ...a, exercises: exs });
  }
  res.json(result);
});

// ============================================================
// GET /api/client-admin/discovery-profile  — get discovery settings
// PATCH /api/client-admin/discovery-profile — set city, lat, lng, description, is_discoverable
// ============================================================
router.get('/discovery-profile', requireClientAdmin, async (req, res) => {
  try {
    const [[biz]] = await db.query(
      'SELECT city, country, latitude, longitude, description, is_discoverable FROM businesses WHERE id = ?',
      [req.admin.businessId],
    );
    return res.json(biz || {});
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.patch('/discovery-profile', requireClientAdmin, async (req, res) => {
  const { city, country, latitude, longitude, description, is_discoverable } = req.body;
  try {
    await db.query(
      `UPDATE businesses SET
         city = COALESCE(?, city),
         country = COALESCE(?, country),
         latitude = COALESCE(?, latitude),
         longitude = COALESCE(?, longitude),
         description = COALESCE(?, description),
         is_discoverable = COALESCE(?, is_discoverable)
       WHERE id = ?`,
      [city ?? null, country ?? null, latitude ?? null, longitude ?? null,
       description ?? null, is_discoverable ?? null, req.admin.businessId],
    );
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

module.exports = router;
