const express = require('express');
const jwt = require('jsonwebtoken');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const { v4: uuidv4 } = require('uuid');
const db = require('../db');
const { getCustomerStatus, STATUS_MESSAGES } = require('../lib/customer_auth');
const { normalizeWeight } = require('../lib/client_profile');
const {
  MEAL_TYPES,
  MEAL_TYPE_LABELS,
  PORTION_UNITS,
  normalizeMealType,
  normalizeHeight,
  normalizeBodyFat,
  mondayOfWeek,
  formatDateOnly,
  userHasNutritionAccess,
  fetchMealPlanForDate,
  fetchFoodLogsForDate,
  fetchNutritionGoals,
  fetchNutritionProgress,
  fetchNutritionMeasurements,
  insertNutritionMeasurement,
  buildSmartShoppingList,
} = require('../lib/nutrition');
const { computeAvailableSlots, buildSlotsPayload } = require('../lib/slots');
const { createOneBooking } = require('../lib/create_booking');
const {
  findConsultationMembership,
  consultationCreditsSummary,
  getConsultationServiceId,
  ensureDefaultConsultationSchedules,
  findPendingConsultationBooking,
  findUpcomingConfirmedConsultationBooking,
  hasActiveConsultationBooking,
  listActiveNutritionists,
  getNutritionistById,
  resolveNutritionistStaffId,
  ensureNutritionConsultationSetup,
} = require('../lib/nutrition_consultation');

const router = express.Router();

const foodPhotoStorage = multer.diskStorage({
  destination: (req, _file, cb) => {
    const dir = path.join(process.env.UPLOAD_DIR || './uploads', req.user.businessId, 'food-logs', req.user.userId);
    fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    cb(null, `${uuidv4()}${ext}`);
  },
});
const foodPhotoUpload = multer({
  storage: foodPhotoStorage,
  limits: { fileSize: 8 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (/^image\/(jpeg|jpg|png|webp|gif)$/.test(file.mimetype)) cb(null, true);
    else cb(new Error('Μόνο εικόνες επιτρέπονται'));
  },
});

async function requireCustomer(req, res, next) {
  const header = req.headers.authorization;
  if (!header) return res.status(401).json({ error: 'Δεν είστε συνδεδεμένος' });
  const token = header.startsWith('Bearer ') ? header.slice(7) : header;
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if (decoded.role && decoded.role !== 'customer') {
      return res.status(403).json({ error: 'Μη εξουσιοδοτημένη πρόσβαση' });
    }
    const status = await getCustomerStatus(decoded.userId);
    if (status !== 'active') {
      return res.status(403).json({
        error: STATUS_MESSAGES[status] || 'Ο λογαριασμός δεν είναι ενεργός',
        account_status: status,
      });
    }
    req.user = decoded;
    next();
  } catch {
    return res.status(401).json({ error: 'Μη έγκυρο token' });
  }
}

async function requireNutritionAccess(req, res, next) {
  const hasAccess = await userHasNutritionAccess(db, req.user.userId, req.user.businessId);
  if (!hasAccess) {
    return res.status(403).json({ error: 'Δεν έχετε ενεργό πακέτο διατροφής' });
  }
  next();
}

router.get('/meal-types', (_req, res) => {
  return res.json(MEAL_TYPES.map((id) => ({ id, label: MEAL_TYPE_LABELS[id] })));
});

router.get('/portion-units', (_req, res) => {
  return res.json(PORTION_UNITS.map((unit) => ({ id: unit, label: unit })));
});

router.get('/time-of-day', (_req, res) => {
  const { TIME_OF_DAY_VALUES, TIME_OF_DAY_LABELS } = require('../lib/nutrition');
  return res.json(TIME_OF_DAY_VALUES.map((id) => ({ id, label: TIME_OF_DAY_LABELS[id] })));
});

router.get('/access', requireCustomer, async (req, res) => {
  const hasAccess = await userHasNutritionAccess(db, req.user.userId, req.user.businessId);
  return res.json({ has_access: hasAccess });
});

router.get('/goals', requireCustomer, requireNutritionAccess, async (req, res) => {
  const goals = await fetchNutritionGoals(db, req.user.userId);
  return res.json(goals);
});

router.patch('/goals', requireCustomer, requireNutritionAccess, async (req, res) => {
  const { weight_kg, target_weight_kg, height_cm, body_fat_pct } = req.body || {};
  const updates = [];
  const params = [];

  try {
    if (weight_kg !== undefined) {
      updates.push('weight_kg = ?');
      params.push(normalizeWeight(weight_kg));
    }
    if (target_weight_kg !== undefined) {
      updates.push('target_weight_kg = ?');
      params.push(normalizeWeight(target_weight_kg));
    }
    if (height_cm !== undefined) {
      updates.push('height_cm = ?');
      params.push(normalizeHeight(height_cm));
    }
    if (body_fat_pct !== undefined) {
      updates.push('body_fat_pct = ?');
      params.push(normalizeBodyFat(body_fat_pct));
    }
  } catch (err) {
    return res.status(400).json({ error: err.message });
  }

  if (!updates.length) {
    return res.status(400).json({ error: 'Δεν υπάρχουν στοιχεία προς ενημέρωση' });
  }

  params.push(req.user.userId);
  await db.query(`UPDATE users SET ${updates.join(', ')} WHERE id = ?`, params);
  const goals = await fetchNutritionGoals(db, req.user.userId);
  return res.json(goals);
});

router.get('/meal-plan', requireCustomer, requireNutritionAccess, async (req, res) => {
  const date = formatDateOnly(req.query.date)
    || formatDateOnly(req.query.week_start)
    || formatDateOnly(new Date());
  const plan = await fetchMealPlanForDate(db, req.user.userId, req.user.businessId, date);
  return res.json(plan);
});

router.get('/shopping-list', requireCustomer, requireNutritionAccess, async (req, res) => {
  const date = formatDateOnly(req.query.date)
    || formatDateOnly(req.query.week_start)
    || formatDateOnly(new Date());
  const plan = await fetchMealPlanForDate(db, req.user.userId, req.user.businessId, date);
  const smart = req.query.smart === '1' || req.query.smart === 'true';
  return res.json({
    effective_from: plan.effective_from,
    week_start: plan.week_start,
    items: smart ? (plan.smart_shopping_list || buildSmartShoppingList(plan.slots)) : plan.shopping_list,
    smart,
  });
});

router.get('/progress', requireCustomer, requireNutritionAccess, async (req, res) => {
  const progress = await fetchNutritionProgress(db, req.user.userId);
  return res.json(progress);
});

router.get('/measurements', requireCustomer, requireNutritionAccess, async (req, res) => {
  const measurements = await fetchNutritionMeasurements(db, req.user.userId, 48);
  const progress = await fetchNutritionProgress(db, req.user.userId);
  return res.json({ measurements, progress });
});

router.post('/measurements', requireCustomer, requireNutritionAccess, async (req, res) => {
  try {
    const measurement = await insertNutritionMeasurement(
      db,
      req.user.businessId,
      req.user.userId,
      { ...req.body, recorded_by: 'athlete', sync_profile: true },
      uuidv4()
    );
    const progress = await fetchNutritionProgress(db, req.user.userId);
    return res.status(201).json({ measurement, progress });
  } catch (err) {
    return res.status(400).json({ error: err.message });
  }
});

router.get('/food-logs', requireCustomer, requireNutritionAccess, async (req, res) => {
  const logDate = formatDateOnly(req.query.date) || formatDateOnly(new Date());
  const logs = await fetchFoodLogsForDate(db, req.user.userId, req.user.businessId, logDate);
  return res.json({ date: logDate, logs });
});

router.post('/food-logs', requireCustomer, requireNutritionAccess, (req, res, next) => {
  foodPhotoUpload.single('photo')(req, res, (err) => {
    if (err) return res.status(400).json({ error: err.message });
    next();
  });
}, async (req, res) => {
  const body = req.body || {};
  const description = body.description;
  if (!description || !String(description).trim()) {
    return res.status(400).json({ error: 'Περιγραφή γεύματος απαιτείται' });
  }

  let mealType;
  try {
    mealType = normalizeMealType(body.meal_type);
  } catch (err) {
    return res.status(400).json({ error: err.message });
  }

  const logDate = formatDateOnly(body.date) || formatDateOnly(new Date());
  const photoUrl = req.file
    ? `/uploads/${req.user.businessId}/food-logs/${req.user.userId}/${req.file.filename}`
    : (body.photo_url?.trim() || null);
  const planOptionId = body.plan_option_id?.trim() || null;
  const id = uuidv4();

  await db.query(
    `INSERT INTO food_logs (id, business_id, user_id, log_date, meal_type, description, photo_url, plan_option_id)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [id, req.user.businessId, req.user.userId, logDate, mealType, String(description).trim(), photoUrl, planOptionId]
  );

  const [rows] = await db.query(
    `SELECT id, log_date, meal_type, description, photo_url, plan_option_id, logged_at
     FROM food_logs WHERE id = ?`,
    [id]
  );
  const row = rows[0];
  return res.status(201).json({
    id: row.id,
    log_date: formatDateOnly(row.log_date),
    meal_type: row.meal_type,
    meal_type_label: MEAL_TYPE_LABELS[row.meal_type],
    description: row.description,
    photo_url: row.photo_url,
    plan_option_id: row.plan_option_id,
    logged_at: row.logged_at,
  });
});

router.get('/today', requireCustomer, requireNutritionAccess, async (req, res) => {
  const today = formatDateOnly(new Date());

  const [goals, plan, logs] = await Promise.all([
    fetchNutritionGoals(db, req.user.userId),
    fetchMealPlanForDate(db, req.user.userId, req.user.businessId, today),
    fetchFoodLogsForDate(db, req.user.userId, req.user.businessId, today),
  ]);

  return res.json({
    date: today,
    day_of_week: plan.day_of_week,
    effective_from: plan.effective_from,
    week_start: plan.week_start,
    goals,
    planned_slots: plan.planned_slots || [],
    planned_meals: plan.planned_meals || [],
    food_logs: logs,
    shopping_list: plan.shopping_list,
  });
});

router.get('/consultation', requireCustomer, requireNutritionAccess, async (req, res) => {
  const bizId = req.user.businessId;
  const userId = req.user.userId;
  const membership = await findConsultationMembership(db, userId, bizId);
  const credits = consultationCreditsSummary(membership);
  let serviceId = await getConsultationServiceId(db, bizId);
  let nutritionists = await listActiveNutritionists(db, bizId);

  if (!serviceId && nutritionists.length > 0) {
    await ensureNutritionConsultationSetup(db, bizId, nutritionists[0]);
    serviceId = await getConsultationServiceId(db, bizId);
    nutritionists = await listActiveNutritionists(db, bizId);
  }

  if (!serviceId) {
    return res.json({ can_book: false, credits, service: null, pending_booking: null, nutritionists: [] });
  }
  const [[service]] = await db.query(
    'SELECT id, name, description, duration_mins, price_cents, category, hide_staff_selection, slot_label_mode, image_url FROM services WHERE id=?',
    [serviceId]
  );
  if (!service) return res.json({ can_book: false, credits, service: null, pending_booking: null, nutritionists: [] });

  for (const nut of nutritionists) {
    if (nut.staff_id) {
      await ensureDefaultConsultationSchedules(db, bizId, serviceId, nut.staff_id, nut.location_id);
    }
  }

  const pendingBooking = await findPendingConsultationBooking(db, userId, bizId, serviceId);
  const upcomingBooking = await findUpcomingConfirmedConsultationBooking(db, userId, bizId, serviceId);
  const hasActiveBooking = await hasActiveConsultationBooking(db, userId, bizId, serviceId);
  const needsNutritionistChoice = nutritionists.length > 1;

  return res.json({
    can_book: credits.can_book && !hasActiveBooking && nutritionists.length > 0,
    credits,
    pending_booking: pendingBooking,
    upcoming_booking: upcomingBooking,
    nutritionists: nutritionists.map((n) => ({
      id: n.id,
      full_name: n.full_name,
      location_id: n.location_id,
      location_name: n.location_name,
      label: n.location_name ? `${n.full_name} — ${n.location_name}` : n.full_name,
    })),
    needs_nutritionist_choice: needsNutritionistChoice,
    service: {
      ...service,
      hide_staff_selection: !!service.hide_staff_selection,
      credits_remaining: credits.remaining,
      credits_valid_until: credits.valid_until,
      can_book: credits.can_book,
      has_membership: credits.has_access,
      is_unlimited: credits.is_unlimited,
    },
  });
});

router.get('/consultation/slots', requireCustomer, requireNutritionAccess, async (req, res) => {
  const bizId = req.user.businessId;
  const userId = req.user.userId;
  const membership = await findConsultationMembership(db, userId, bizId);
  const credits = consultationCreditsSummary(membership);
  if (!credits.can_book) {
    return res.status(403).json({ error: 'Δεν έχεις διαθέσιμες επισκέψεις' });
  }

  const serviceId = await getConsultationServiceId(db, bizId);
  const date = formatDateOnly(req.query.date) || formatDateOnly(new Date());
  const { nutritionist_id: nutritionistId } = req.query;

  const nutritionists = await listActiveNutritionists(db, bizId);
  for (const nut of nutritionists) {
    if (nut.staff_id) {
      await ensureDefaultConsultationSchedules(db, bizId, serviceId, nut.staff_id, nut.location_id);
    }
  }

  const staffId = await resolveNutritionistStaffId(db, bizId, { nutritionist_id: nutritionistId });
  if (!staffId && nutritionists.length > 1) {
    return res.status(400).json({ error: 'Επίλεξε διατροφολόγο' });
  }
  if (!staffId && !nutritionists.length) {
    return res.json({ date, slots: [], message: 'Δεν υπάρχει διαθέσιμος διατροφολόγος' });
  }

  const computed = await computeAvailableSlots(db, bizId, serviceId, date, null, null, staffId);
  if (!computed) {
    return res.json({ date, slots: [], message: 'Το γυμναστήριο είναι κλειστό αυτή την ημέρα' });
  }

  const [[cfg]] = await db.query(
    'SELECT feature_waitlist FROM business_configs WHERE business_id=?',
    [bizId]
  );
  const payload = buildSlotsPayload(computed, {
    featureWaitlist: !!cfg?.feature_waitlist,
    date,
  });
  return res.json({ date, slots: payload.slots, message: payload.message });
});

router.post('/consultation/book', requireCustomer, requireNutritionAccess, async (req, res) => {
  const bizId = req.user.businessId;
  const userId = req.user.userId;
  const { date, time, nutritionist_id: nutritionistId } = req.body || {};
  if (!date || !time) return res.status(400).json({ error: 'Απαιτούνται ημερομηνία και ώρα' });

  const membership = await findConsultationMembership(db, userId, bizId);
  const credits = consultationCreditsSummary(membership);
  if (!credits.can_book) {
    return res.status(403).json({ error: 'Δεν έχεις διαθέσιμες επισκέψεις' });
  }

  const serviceId = await getConsultationServiceId(db, bizId);
  const hasActive = await hasActiveConsultationBooking(db, userId, bizId, serviceId);
  if (hasActive) {
    return res.status(409).json({ error: 'Έχεις ήδη ενεργή κράτηση με τον διατροφολόγο' });
  }

  if (!serviceId) return res.status(400).json({ error: 'Η υπηρεσία δεν είναι διαθέσιμη' });

  const nutritionists = await listActiveNutritionists(db, bizId);
  const staffId = await resolveNutritionistStaffId(db, bizId, { nutritionist_id: nutritionistId });
  if (!staffId) {
    const msg = nutritionists.length > 1
      ? 'Επίλεξε διατροφολόγο'
      : 'Δεν υπάρχει διαθέσιμος διατροφολόγος';
    return res.status(400).json({ error: msg });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const result = await createOneBooking(conn, {
      bizId,
      userId,
      service_id: serviceId,
      staff_id: staffId,
      date: formatDateOnly(date),
      time,
      use_credit: true,
      status: 'pending',
      defer_credit_charge: true,
      source: 'app',
    });
    await conn.commit();
    return res.status(201).json({
      ...result,
      message: 'Το αίτημα καταχωρήθηκε. Θα επιβεβαιωθεί από τον διατροφολόγο.',
    });
  } catch (err) {
    await conn.rollback();
    return res.status(400).json({ error: err.message });
  } finally {
    conn.release();
  }
});

module.exports = router;
