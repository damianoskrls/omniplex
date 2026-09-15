const MEAL_TYPES = ['breakfast', 'lunch', 'dinner', 'snack'];

const MEAL_TYPE_LABELS = {
  breakfast: 'Πρωινό',
  lunch: 'Μεσημεριανό',
  dinner: 'Βραδινό',
  snack: 'Σνακ',
};

const PORTION_UNITS = ['g', 'kg', 'ml', 'l', 'cup', 'κ.σ.', 'κ.γ.', 'τεμ', 'φέτες', 'scoops'];

const TIME_OF_DAY_VALUES = ['morning', 'noon', 'afternoon', 'evening'];

const TIME_OF_DAY_LABELS = {
  morning: 'Πρωί',
  noon: 'Μεσημέρι',
  afternoon: 'Απόγευμα',
  evening: 'Βράδυ',
};

function normalizeTimeOfDay(value) {
  if (value == null || value === '') return null;
  const v = String(value).trim().toLowerCase();
  if (!TIME_OF_DAY_VALUES.includes(v)) {
    throw new Error('Μη έγκυρη στιγμή ημέρας');
  }
  return v;
}

function normalizeMeasuredTime(value) {
  if (value == null || value === '') return null;
  const s = String(value).trim();
  const m = s.match(/^(\d{1,2}):(\d{2})(?::\d{2})?$/);
  if (!m) throw new Error('Μη έγκυρη ώρα (π.χ. 08:30)');
  const h = Number(m[1]);
  const min = Number(m[2]);
  if (h < 0 || h > 23 || min < 0 || min > 59) throw new Error('Μη έγκυρη ώρα');
  return `${String(h).padStart(2, '0')}:${String(min).padStart(2, '0')}:00`;
}

function formatMeasuredTimeDisplay(value) {
  if (!value) return null;
  const parts = String(value).split(':');
  return `${parts[0]}:${parts[1]}`;
}

function formatMeasuredWhenLabel(measuredOn, timeOfDay, measuredTime) {
  const date = formatDateOnly(measuredOn);
  if (!date) return null;
  const [y, mo, d] = date.split('-');
  const dateLabel = `${Number(d)}/${Number(mo)}/${y}`;
  if (measuredTime) {
    return `${dateLabel} ${formatMeasuredTimeDisplay(measuredTime)}`;
  }
  if (timeOfDay && TIME_OF_DAY_LABELS[timeOfDay]) {
    return `${dateLabel} ${TIME_OF_DAY_LABELS[timeOfDay]}`;
  }
  return dateLabel;
}

function normalizeMealType(value) {
  const v = String(value || '').trim().toLowerCase();
  if (!MEAL_TYPES.includes(v)) {
    throw new Error('Μη έγκυρος τύπος γεύματος');
  }
  return v;
}

function normalizeDayOfWeek(value) {
  const n = Number(value);
  if (!Number.isInteger(n) || n < 1 || n > 7) {
    throw new Error('Η ημέρα πρέπει να είναι 1-7 (Δευτέρα-Κυριακή)');
  }
  return n;
}

function normalizeHeight(value) {
  if (value === null || value === undefined || value === '') return null;
  const n = Number(value);
  if (!Number.isFinite(n) || n < 50 || n > 250) {
    throw new Error('Μη έγκυρο ύψος (cm)');
  }
  return Math.round(n * 10) / 10;
}

function normalizeBodyFat(value) {
  if (value === null || value === undefined || value === '') return null;
  const n = Number(value);
  if (!Number.isFinite(n) || n < 1 || n > 70) {
    throw new Error('Μη έγκυρο ποσοστό λίπους');
  }
  return Math.round(n * 10) / 10;
}

function normalizePortions(portions) {
  if (!portions) return [];
  if (!Array.isArray(portions)) return [];
  return portions
    .map((p) => ({
      ingredient: String(p?.ingredient || '').trim(),
      amount: p?.amount === '' || p?.amount == null ? null : Number(p.amount),
      unit: String(p?.unit || 'g').trim(),
    }))
    .filter((p) => p.ingredient);
}

function parsePortionsJson(raw) {
  if (!raw) return [];
  if (Array.isArray(raw)) return raw;
  if (typeof raw === 'string') {
    try { return JSON.parse(raw); } catch { return []; }
  }
  return [];
}

function mapMealOptionRow(row) {
  const portions = parsePortionsJson(row.portions_json);
  const title = row.title || row.description || '';
  return {
    id: row.id,
    day_of_week: row.day_of_week,
    meal_type: row.meal_type,
    meal_type_label: MEAL_TYPE_LABELS[row.meal_type],
    title,
    description: row.description || title,
    notes: row.notes || null,
    portions: portions.map((p) => ({
      ingredient: p.ingredient,
      amount: p.amount != null ? Number(p.amount) : null,
      unit: p.unit || 'g',
    })),
    image_url: row.image_url || null,
    recipe_text: row.recipe_text || null,
    sort_order: row.sort_order ?? 0,
  };
}

function groupOptionsIntoSlots(options) {
  const slotMap = new Map();
  for (const opt of options) {
    const key = `${opt.day_of_week}:${opt.meal_type}`;
    if (!slotMap.has(key)) {
      slotMap.set(key, {
        day_of_week: opt.day_of_week,
        meal_type: opt.meal_type,
        meal_type_label: opt.meal_type_label,
        options: [],
      });
    }
    slotMap.get(key).options.push(opt);
  }
  return Array.from(slotMap.values()).sort((a, b) => {
    if (a.day_of_week !== b.day_of_week) return a.day_of_week - b.day_of_week;
    return MEAL_TYPES.indexOf(a.meal_type) - MEAL_TYPES.indexOf(b.meal_type);
  });
}

function formatLocalDate(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function mondayOfWeek(date = new Date()) {
  const d = new Date(date);
  const day = d.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  d.setDate(d.getDate() + diff);
  d.setHours(0, 0, 0, 0);
  return formatLocalDate(d);
}

function formatDateOnly(value) {
  if (!value) return null;
  if (value instanceof Date) return formatLocalDate(value);
  return String(value).slice(0, 10);
}

function parseLocalDate(iso) {
  const [y, m, d] = String(iso).slice(0, 10).split('-').map(Number);
  return new Date(y, m - 1, d);
}

function dayOfWeekFromDate(date) {
  const js = date.getDay();
  return js === 0 ? 7 : js;
}

function buildShoppingList(slotsOrOptions) {
  const options = Array.isArray(slotsOrOptions) && slotsOrOptions[0]?.options
    ? slotsOrOptions.flatMap((s) => s.options)
    : slotsOrOptions;

  const map = new Map();
  for (const opt of options) {
    for (const p of opt.portions || []) {
      const key = `${p.ingredient.toLowerCase()}::${p.unit}`;
      const existing = map.get(key);
      if (existing) {
        if (existing.amount != null && p.amount != null) {
          existing.amount = Math.round((existing.amount + p.amount) * 100) / 100;
        }
        existing.sources += 1;
      } else {
        map.set(key, {
          ingredient: p.ingredient,
          amount: p.amount,
          unit: p.unit,
          sources: 1,
        });
      }
    }
  }
  return Array.from(map.values()).sort((a, b) => a.ingredient.localeCompare(b.ingredient, 'el'));
}

function toBaseAmount(amount, unit) {
  if (amount == null || !Number.isFinite(Number(amount))) return null;
  const n = Number(amount);
  const u = String(unit || '').toLowerCase().trim();
  if (u === 'kg') return { value: n * 1000, base: 'g' };
  if (u === 'g') return { value: n, base: 'g' };
  if (u === 'l') return { value: n * 1000, base: 'ml' };
  if (u === 'ml') return { value: n, base: 'ml' };
  if (u === 'cup') return { value: n * 240, base: 'ml' };
  return { value: n, base: u || unit };
}

function formatQty(n) {
  if (n == null) return null;
  const rounded = Math.round(n * 100) / 100;
  return rounded % 1 === 0 ? String(Math.round(rounded)) : String(rounded);
}

function suggestPurchaseAmount(amount, unit, ingredient = '') {
  const base = toBaseAmount(amount, unit);
  if (!base || base.value == null) {
    return { buy_amount: amount, buy_unit: unit, suggestion: null };
  }

  const name = String(ingredient).toLowerCase();

  if (base.base === 'ml') {
    const ml = base.value;
    let buyMl;
    let suggestion;
    if (ml <= 500) {
      buyMl = 1000;
      suggestion = `Χρειάζεσαι ${formatQty(ml)} ml — προτείνουμε 1 λίτρο`;
    } else if (ml <= 1000) {
      buyMl = 1000;
      suggestion = `Χρειάζεσαι ${formatQty(ml)} ml — προτείνουμε 1 λίτρο`;
    } else {
      buyMl = Math.ceil(ml / 500) * 500;
      const liters = buyMl / 1000;
      suggestion = `Χρειάζεσαι ${formatQty(ml)} ml — προτείνουμε ${formatQty(liters)} λίτρο`;
    }
    if (buyMl >= 1000 && buyMl % 1000 === 0) {
      return { buy_amount: buyMl / 1000, buy_unit: 'l', suggestion };
    }
    return { buy_amount: buyMl, buy_unit: 'ml', suggestion };
  }

  if (base.base === 'g') {
    const g = base.value;
    let buyG;
    let suggestion;
    if (g <= 250) {
      buyG = 250;
      suggestion = `Χρειάζεσαι ${formatQty(g)} g — προτείνουμε 250 g`;
    } else if (g <= 500) {
      buyG = 500;
      suggestion = `Χρειάζεσαι ${formatQty(g)} g — προτείνουμε 500 g`;
    } else if (g <= 1000) {
      buyG = 1000;
      suggestion = `Χρειάζεσαι ${formatQty(g)} g — προτείνουμε 1 kg`;
    } else {
      buyG = Math.ceil(g / 500) * 500;
      const kg = buyG / 1000;
      suggestion = `Χρειάζεσαι ${formatQty(g)} g — προτείνουμε ${formatQty(kg)} kg`;
    }
    if (buyG >= 1000 && buyG % 1000 === 0) {
      return { buy_amount: buyG / 1000, buy_unit: 'kg', suggestion };
    }
    return { buy_amount: buyG, buy_unit: 'g', suggestion };
  }

  if (['τεμ', 'φέτες', 'scoops'].includes(base.base)) {
    const n = Math.ceil(base.value);
    const isEgg = /αυγ|egg/i.test(name);
    if (isEgg && n <= 6) {
      return { buy_amount: 6, buy_unit: 'τεμ', suggestion: `Χρειάζεσαι ${n} αυγά — προτείνουμε συσκευασία 6 τεμ.` };
    }
    if (isEgg && n <= 12) {
      return { buy_amount: 12, buy_unit: 'τεμ', suggestion: `Χρειάζεσαι ${n} αυγά — προτείνουμε συσκευασία 12 τεμ.` };
    }
    if (isEgg) {
      const dozen = Math.ceil(n / 12) * 12;
      return { buy_amount: dozen, buy_unit: 'τεμ', suggestion: `Χρειάζεσαι ${n} αυγά — προτείνουμε ${dozen} τεμ.` };
    }
    return {
      buy_amount: n,
      buy_unit: base.base,
      suggestion: n > base.value ? `Χρειάζεσαι ${formatQty(base.value)} — προτείνουμε ${n} ${base.base}` : null,
    };
  }

  return { buy_amount: base.value, buy_unit: base.base, suggestion: null };
}

function buildSmartShoppingList(slotsOrOptions) {
  const raw = buildShoppingList(slotsOrOptions);
  return raw.map((item) => {
    const smart = suggestPurchaseAmount(item.amount, item.unit, item.ingredient);
    return {
      ingredient: item.ingredient,
      needed_amount: item.amount,
      needed_unit: item.unit,
      buy_amount: smart.buy_amount,
      buy_unit: smart.buy_unit,
      suggestion: smart.suggestion,
      sources: item.sources,
    };
  });
}

async function insertMealPlanSlotItems(conn, planId, slots, uuidFn) {
  for (const slot of slots) {
    for (const option of slot.options) {
      const portionsJson = option.portions?.length ? JSON.stringify(option.portions) : null;
      await conn.query(
        `INSERT INTO meal_plan_items
          (id, meal_plan_id, day_of_week, meal_type, title, description, notes, portions_json, image_url, recipe_text, sort_order)
         VALUES (?,?,?,?,?,?,?,?,?,?,?)`,
        [
          uuidFn(), planId, slot.day_of_week, slot.meal_type,
          option.title, option.description || option.title,
          option.notes, portionsJson, option.image_url, option.recipe_text,
          option.sort_order ?? 0,
        ]
      );
    }
  }
}

async function fetchMealPlanVersionById(db, userId, businessId, planId) {
  const [[plan]] = await db.query(
    `SELECT id, effective_from, week_start, notes, created_at, updated_at
     FROM meal_plans
     WHERE id = ? AND user_id = ? AND business_id = ?`,
    [planId, userId, businessId]
  );
  if (!plan) return null;
  const options = await loadMealPlanItems(db, plan.id);
  return buildMealPlanResponse(plan, options);
}

async function listProgramTemplates(db, businessId) {
  const [rows] = await db.query(
    `SELECT t.id, t.name, t.notes, t.created_at, t.updated_at,
            (SELECT COUNT(*) FROM nutrition_program_template_items i WHERE i.template_id = t.id) AS item_count
     FROM nutrition_program_templates t
     WHERE t.business_id = ?
     ORDER BY t.name`,
    [businessId]
  );
  return rows.map((row) => ({
    id: row.id,
    name: row.name,
    notes: row.notes,
    item_count: Number(row.item_count),
    created_at: row.created_at,
    updated_at: row.updated_at,
  }));
}

async function loadTemplateItems(db, templateId) {
  const [items] = await db.query(
    `SELECT id, day_of_week, meal_type, title, description, notes, portions_json,
            image_url, recipe_text, sort_order
     FROM nutrition_program_template_items
     WHERE template_id = ?
     ORDER BY day_of_week, FIELD(meal_type, 'breakfast','lunch','dinner','snack'), sort_order`,
    [templateId]
  );
  return items.map(mapMealOptionRow);
}

async function fetchProgramTemplate(db, businessId, templateId) {
  const [[tpl]] = await db.query(
    `SELECT id, name, notes, created_at, updated_at
     FROM nutrition_program_templates
     WHERE id = ? AND business_id = ?`,
    [templateId, businessId]
  );
  if (!tpl) return null;
  const options = await loadTemplateItems(db, templateId);
  const slots = groupOptionsIntoSlots(options);
  return {
    id: tpl.id,
    name: tpl.name,
    notes: tpl.notes,
    slots,
    meals: options,
    shopping_list: buildShoppingList(slots),
    smart_shopping_list: buildSmartShoppingList(slots),
    created_at: tpl.created_at,
    updated_at: tpl.updated_at,
  };
}

async function saveProgramTemplateItems(conn, templateId, slots, uuidFn) {
  await conn.query('DELETE FROM nutrition_program_template_items WHERE template_id=?', [templateId]);
  for (const slot of slots) {
    for (const option of slot.options) {
      const portionsJson = option.portions?.length ? JSON.stringify(option.portions) : null;
      await conn.query(
        `INSERT INTO nutrition_program_template_items
          (id, template_id, day_of_week, meal_type, title, description, notes, portions_json, image_url, recipe_text, sort_order)
         VALUES (?,?,?,?,?,?,?,?,?,?,?)`,
        [
          uuidFn(), templateId, slot.day_of_week, slot.meal_type,
          option.title, option.description || option.title,
          option.notes, portionsJson, option.image_url, option.recipe_text,
          option.sort_order ?? 0,
        ]
      );
    }
  }
}

async function createProgramTemplate(db, businessId, body, templateId, uuidFn) {
  const name = String(body?.name || '').trim();
  if (!name) throw new Error('Απαιτείται όνομα προτύπου');
  const payload = normalizeMealPlanPayload({ slots: body?.slots, meals: body?.meals, notes: body?.notes });
  const id = templateId;
  await db.query(
    'INSERT INTO nutrition_program_templates (id, business_id, name, notes) VALUES (?,?,?,?)',
    [id, businessId, name, payload.notes ?? null]
  );
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    await saveProgramTemplateItems(conn, id, payload.slots, uuidFn);
    await conn.commit();
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
  return fetchProgramTemplate(db, businessId, id);
}

async function updateProgramTemplate(db, businessId, templateId, body, uuidFn) {
  const [[existing]] = await db.query(
    'SELECT id FROM nutrition_program_templates WHERE id=? AND business_id=?',
    [templateId, businessId]
  );
  if (!existing) return null;
  const name = body?.name != null ? String(body.name).trim() : null;
  if (body?.name != null && !name) throw new Error('Απαιτείται όνομα προτύπου');
  const payload = body?.slots ? normalizeMealPlanPayload({ slots: body.slots, notes: body.notes }) : null;
  const updates = [];
  const params = [];
  if (name) { updates.push('name=?'); params.push(name); }
  if (body?.notes !== undefined) { updates.push('notes=?'); params.push(body.notes ?? null); }
  if (updates.length) {
    params.push(templateId);
    await db.query(`UPDATE nutrition_program_templates SET ${updates.join(', ')} WHERE id=?`, params);
  }
  if (payload?.slots) {
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();
      await saveProgramTemplateItems(conn, templateId, payload.slots, uuidFn);
      await conn.commit();
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  }
  return fetchProgramTemplate(db, businessId, templateId);
}

async function deleteProgramTemplate(db, businessId, templateId) {
  const [result] = await db.query(
    'DELETE FROM nutrition_program_templates WHERE id=? AND business_id=?',
    [templateId, businessId]
  );
  return result.affectedRows > 0;
}

async function applyProgramTemplateToClient(db, businessId, userId, templateId, effectiveFrom, uuidFn) {
  const tpl = await fetchProgramTemplate(db, businessId, templateId);
  if (!tpl) throw new Error('Το πρότυπο δεν βρέθηκε');
  const payload = normalizeMealPlanPayload({
    effective_from: effectiveFrom,
    notes: tpl.notes,
    slots: tpl.slots,
  });
  const { effectiveFrom: eff, weekStart, notes, slots } = payload;
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const [[existing]] = await conn.query(
      `SELECT id FROM meal_plans
       WHERE user_id=? AND business_id=? AND COALESCE(effective_from, week_start)=?`,
      [userId, businessId, eff]
    );
    let planId = existing?.id;
    if (planId) {
      await conn.query(
        'UPDATE meal_plans SET notes=?, effective_from=?, week_start=? WHERE id=?',
        [notes ?? null, eff, weekStart, planId]
      );
      await conn.query('DELETE FROM meal_plan_items WHERE meal_plan_id=?', [planId]);
    } else {
      planId = uuidFn();
      await conn.query(
        `INSERT INTO meal_plans (id, business_id, user_id, week_start, effective_from, notes)
         VALUES (?,?,?,?,?,?)`,
        [planId, businessId, userId, weekStart, eff, notes ?? null]
      );
    }
    await insertMealPlanSlotItems(conn, planId, slots, uuidFn);
    await conn.commit();
    return fetchMealPlanTemplate(db, userId, businessId, eff);
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
}

async function isNutritionFeatureEnabled(db, businessId) {
  const [[row]] = await db.query(
    'SELECT feature_nutrition FROM business_configs WHERE business_id = ?',
    [businessId]
  );
  return !!row?.feature_nutrition;
}

async function userHasNutritionAccess(db, userId, businessId) {
  if (!(await isNutritionFeatureEnabled(db, businessId))) return false;
  const [rows] = await db.query(
    `SELECT 1
     FROM user_memberships m
     LEFT JOIN business_plans p ON p.id = m.plan_id
     WHERE m.user_id = ? AND m.business_id = ?
       AND (m.valid_until IS NULL OR m.valid_until >= CURDATE())
       AND (
         (p.plan_type = 'nutrition')
         OR (m.service_category = 'nutrition' AND m.service_id IS NULL)
       )
     LIMIT 1`,
    [userId, businessId]
  );
  return rows.length > 0;
}

async function fetchActiveMealPlanRow(db, userId, businessId, dateIso) {
  const date = formatDateOnly(dateIso) || formatDateOnly(new Date());
  const [[plan]] = await db.query(
    `SELECT id, effective_from, week_start, notes, created_at, updated_at
     FROM meal_plans
     WHERE user_id = ? AND business_id = ?
       AND COALESCE(effective_from, week_start) <= ?
     ORDER BY COALESCE(effective_from, week_start) DESC
     LIMIT 1`,
    [userId, businessId, date]
  );
  return plan || null;
}

async function loadMealPlanItems(db, planId) {
  const [items] = await db.query(
    `SELECT id, day_of_week, meal_type, title, description, notes, portions_json,
            image_url, recipe_text, sort_order
     FROM meal_plan_items
     WHERE meal_plan_id = ?
     ORDER BY day_of_week, FIELD(meal_type, 'breakfast','lunch','dinner','snack'), sort_order`,
    [planId]
  );
  return items.map(mapMealOptionRow);
}

function buildMealPlanResponse(plan, options, { date, dayOfWeek } = {}) {
  const allSlots = groupOptionsIntoSlots(options);
  const payload = {
    id: plan?.id || null,
    effective_from: plan ? formatDateOnly(plan.effective_from || plan.week_start) : null,
    week_start: plan ? formatDateOnly(plan.week_start) : null,
    notes: plan?.notes || null,
    slots: allSlots,
    week_slots: allSlots,
    meals: options,
    shopping_list: buildShoppingList(allSlots),
    smart_shopping_list: buildSmartShoppingList(allSlots),
  };
  if (date) {
    payload.date = date;
    payload.day_of_week = dayOfWeek;
    payload.planned_slots = allSlots.filter((s) => s.day_of_week === dayOfWeek);
    payload.planned_meals = options.filter((o) => o.day_of_week === dayOfWeek);
  }
  return payload;
}

async function fetchMealPlanForDate(db, userId, businessId, dateIso) {
  const date = formatDateOnly(dateIso) || formatDateOnly(new Date());
  const localDate = parseLocalDate(date);
  const dayOfWeek = dayOfWeekFromDate(localDate);
  const plan = await fetchActiveMealPlanRow(db, userId, businessId, date);
  if (!plan) {
    return buildMealPlanResponse(null, [], { date, dayOfWeek });
  }
  const options = await loadMealPlanItems(db, plan.id);
  return buildMealPlanResponse(plan, options, { date, dayOfWeek });
}

/** Full weekly template (no day filter) — for admin editor */
async function fetchMealPlanTemplate(db, userId, businessId, dateIso) {
  const date = formatDateOnly(dateIso) || formatDateOnly(new Date());
  const plan = await fetchActiveMealPlanRow(db, userId, businessId, date);
  if (!plan) return buildMealPlanResponse(null, []);
  const options = await loadMealPlanItems(db, plan.id);
  return buildMealPlanResponse(plan, options);
}

/** @deprecated Use fetchMealPlanForDate — kept for callers passing week Monday as proxy date */
async function fetchMealPlanForWeek(db, userId, businessId, weekStart) {
  return fetchMealPlanForDate(db, userId, businessId, weekStart);
}

async function listMealPlanVersions(db, userId, businessId) {
  const today = formatDateOnly(new Date());
  const active = await fetchActiveMealPlanRow(db, userId, businessId, today);
  const [rows] = await db.query(
    `SELECT id, effective_from, week_start, notes, created_at, updated_at
     FROM meal_plans
     WHERE user_id = ? AND business_id = ?
     ORDER BY COALESCE(effective_from, week_start) DESC`,
    [userId, businessId]
  );
  return rows.map((row) => ({
    id: row.id,
    effective_from: formatDateOnly(row.effective_from || row.week_start),
    notes: row.notes,
    created_at: row.created_at,
    updated_at: row.updated_at,
    is_current: active?.id === row.id,
  }));
}

function goalProgressPct(start, current, target) {
  if (start == null || current == null || target == null) return null;
  const total = Math.abs(start - target);
  if (total < 0.01) return Math.abs(current - target) < 0.01 ? 100 : 0;
  const traveled = Math.abs(start - current);
  const towardTarget = (start > target && current <= start) || (start < target && current >= start);
  if (!towardTarget) return Math.min(100, Math.max(0, Math.round((traveled / total) * 50)));
  return Math.min(100, Math.max(0, Math.round((traveled / total) * 100)));
}

function buildMeasurementChartSeries(measurements, field) {
  const chronological = [...measurements].reverse();
  return chronological
    .filter((m) => m[field] != null)
    .map((m) => ({
      date: m.measured_on,
      value: m[field],
      recorded_by: m.recorded_by || 'nutritionist',
    }));
}

function mapMeasurementRow(row) {
  const num = (v) => (v != null ? Number(v) : null);
  const timeOfDay = row.time_of_day || null;
  const measuredTime = row.measured_time || null;
  return {
    id: row.id,
    measured_on: formatDateOnly(row.measured_on),
    time_of_day: timeOfDay,
    time_of_day_label: timeOfDay ? TIME_OF_DAY_LABELS[timeOfDay] : null,
    measured_time: measuredTime ? formatMeasuredTimeDisplay(measuredTime) : null,
    measured_when: formatMeasuredWhenLabel(row.measured_on, timeOfDay, measuredTime),
    recorded_by: row.recorded_by || 'nutritionist',
    weight_kg: num(row.weight_kg),
    height_cm: num(row.height_cm),
    body_fat_pct: num(row.body_fat_pct),
    muscle_mass_kg: num(row.muscle_mass_kg),
    fat_mass_kg: num(row.fat_mass_kg),
    bone_mass_kg: num(row.bone_mass_kg),
    bmi: num(row.bmi),
    visceral_fat_level: row.visceral_fat_level != null ? Number(row.visceral_fat_level) : null,
    bmr_kcal: row.bmr_kcal != null ? Number(row.bmr_kcal) : null,
    metabolic_age: row.metabolic_age != null ? Number(row.metabolic_age) : null,
    notes: row.notes || null,
    created_at: row.created_at,
  };
}

async function fetchNutritionMeasurements(db, userId, limit = 24) {
  const [rows] = await db.query(
    `SELECT id, measured_on, time_of_day, measured_time, recorded_by, weight_kg, height_cm, body_fat_pct,
            muscle_mass_kg, fat_mass_kg, bone_mass_kg, bmi, visceral_fat_level, bmr_kcal, metabolic_age, notes, created_at
     FROM nutrition_measurements
     WHERE user_id = ?
     ORDER BY measured_on DESC,
              COALESCE(measured_time,
                CASE time_of_day
                  WHEN 'morning' THEN '08:00:00'
                  WHEN 'noon' THEN '12:00:00'
                  WHEN 'afternoon' THEN '17:00:00'
                  WHEN 'evening' THEN '21:00:00'
                  ELSE '12:00:00'
                END) DESC,
              created_at DESC
     LIMIT ?`,
    [userId, limit]
  );
  return rows.map(mapMeasurementRow);
}

async function fetchNutritionProgress(db, userId, limit = 24) {
  const goals = await fetchNutritionGoals(db, userId);
  const measurements = await fetchNutritionMeasurements(db, userId, limit);
  const latest = measurements[0] || null;
  const first = measurements.length ? measurements[measurements.length - 1] : null;

  const delta = (current, start) => {
    if (current == null || start == null) return null;
    return Math.round((current - start) * 10) / 10;
  };

  const startWeight = first?.weight_kg ?? goals.weight_kg;
  const startBodyFat = first?.body_fat_pct ?? goals.body_fat_pct;

  return {
    goals,
    latest_measurement: latest,
    first_measurement: first,
    measurements,
    chart: {
      weight: buildMeasurementChartSeries(measurements, 'weight_kg'),
      body_fat_pct: buildMeasurementChartSeries(measurements, 'body_fat_pct'),
      muscle_mass_kg: buildMeasurementChartSeries(measurements, 'muscle_mass_kg'),
    },
    visits: measurements.map((m) => ({
      id: m.id,
      date: m.measured_on,
      measured_when: m.measured_when,
      time_of_day: m.time_of_day,
      time_of_day_label: m.time_of_day_label,
      measured_time: m.measured_time,
      recorded_by: m.recorded_by,
      weight_kg: m.weight_kg,
      body_fat_pct: m.body_fat_pct,
      muscle_mass_kg: m.muscle_mass_kg,
      bmi: m.bmi,
      notes: m.notes,
    })),
    progress: {
      weight_kg_delta: delta(latest?.weight_kg, first?.weight_kg),
      body_fat_pct_delta: delta(latest?.body_fat_pct, first?.body_fat_pct),
      muscle_mass_kg_delta: delta(latest?.muscle_mass_kg, first?.muscle_mass_kg),
      toward_target_weight_kg:
        goals.target_weight_kg != null && latest?.weight_kg != null
          ? Math.round((latest.weight_kg - goals.target_weight_kg) * 10) / 10
          : null,
      toward_target_body_fat_pct:
        goals.target_body_fat_pct != null && latest?.body_fat_pct != null
          ? Math.round((latest.body_fat_pct - goals.target_body_fat_pct) * 10) / 10
          : null,
      weight_goal_pct: goalProgressPct(startWeight, latest?.weight_kg, goals.target_weight_kg),
      body_fat_goal_pct: goalProgressPct(startBodyFat, latest?.body_fat_pct, goals.target_body_fat_pct),
    },
  };
}

function normalizeMeasurementPayload(body) {
  const measuredOn = formatDateOnly(body?.measured_on) || formatDateOnly(new Date());
  let measuredTime = null;
  let timeOfDay = null;
  try {
    measuredTime = normalizeMeasuredTime(body?.measured_time);
    timeOfDay = measuredTime ? null : normalizeTimeOfDay(body?.time_of_day);
  } catch (err) {
    throw err;
  }
  const numField = (key, min, max) => {
    const v = body?.[key];
    if (v === null || v === undefined || v === '') return null;
    const n = Number(v);
    if (!Number.isFinite(n)) throw new Error(`Μη έγκυρο ${key}`);
    if (min != null && n < min) throw new Error(`Μη έγκυρο ${key}`);
    if (max != null && n > max) throw new Error(`Μη έγκυρο ${key}`);
    return Math.round(n * 10) / 10;
  };
  return {
    measuredOn,
    timeOfDay,
    measuredTime,
    weight_kg: numField('weight_kg', 20, 300),
    height_cm: body?.height_cm != null && body?.height_cm !== '' ? normalizeHeight(body.height_cm) : null,
    body_fat_pct: body?.body_fat_pct != null && body?.body_fat_pct !== '' ? normalizeBodyFat(body.body_fat_pct) : null,
    muscle_mass_kg: numField('muscle_mass_kg', 1, 200),
    fat_mass_kg: numField('fat_mass_kg', 1, 200),
    bone_mass_kg: numField('bone_mass_kg', 0.5, 20),
    bmi: numField('bmi', 10, 60),
    visceral_fat_level: body?.visceral_fat_level != null && body?.visceral_fat_level !== ''
      ? Math.round(Number(body.visceral_fat_level)) : null,
    bmr_kcal: body?.bmr_kcal != null && body?.bmr_kcal !== '' ? Math.round(Number(body.bmr_kcal)) : null,
    metabolic_age: body?.metabolic_age != null && body?.metabolic_age !== ''
      ? Math.round(Number(body.metabolic_age)) : null,
    notes: body?.notes ? String(body.notes).trim() : null,
    syncProfile: body?.sync_profile !== false,
    recordedBy: body?.recorded_by === 'athlete' ? 'athlete' : 'nutritionist',
  };
}

function normalizeAthleteMeasurementPayload(body) {
  const payload = normalizeMeasurementPayload({ ...body, recorded_by: 'athlete', sync_profile: true });
  if (payload.weight_kg == null) throw new Error('Το βάρος απαιτείται');
  if (!payload.measuredTime && !payload.timeOfDay) {
    throw new Error('Επίλεξε στιγμή ημέρας ή ακριβή ώρα');
  }
  return payload;
}

async function insertNutritionMeasurement(db, businessId, userId, body, measurementId) {
  const payload = body?.recorded_by === 'athlete'
    ? normalizeAthleteMeasurementPayload(body)
    : normalizeMeasurementPayload({ ...body, recorded_by: body?.recorded_by || 'nutritionist' });
  const id = measurementId;
  await db.query(
    `INSERT INTO nutrition_measurements
      (id, business_id, user_id, recorded_by, measured_on, time_of_day, measured_time, weight_kg, height_cm, body_fat_pct,
       muscle_mass_kg, fat_mass_kg, bone_mass_kg, bmi, visceral_fat_level, bmr_kcal, metabolic_age, notes)
     VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
    [
      id, businessId, userId, payload.recordedBy, payload.measuredOn,
      payload.timeOfDay, payload.measuredTime,
      payload.weight_kg, payload.height_cm, payload.body_fat_pct,
      payload.muscle_mass_kg, payload.fat_mass_kg, payload.bone_mass_kg,
      payload.bmi, payload.visceral_fat_level, payload.bmr_kcal, payload.metabolic_age,
      payload.notes,
    ]
  );

  if (payload.syncProfile) {
    const updates = [];
    const params = [];
    if (payload.weight_kg != null) { updates.push('weight_kg = ?'); params.push(payload.weight_kg); }
    if (payload.height_cm != null) { updates.push('height_cm = ?'); params.push(payload.height_cm); }
    if (payload.body_fat_pct != null) { updates.push('body_fat_pct = ?'); params.push(payload.body_fat_pct); }
    if (updates.length) {
      params.push(userId);
      await db.query(`UPDATE users SET ${updates.join(', ')} WHERE id = ?`, params);
    }
  }

  const [rows] = await db.query(
    `SELECT id, measured_on, time_of_day, measured_time, recorded_by, weight_kg, height_cm, body_fat_pct, muscle_mass_kg, fat_mass_kg,
            bone_mass_kg, bmi, visceral_fat_level, bmr_kcal, metabolic_age, notes, created_at
     FROM nutrition_measurements WHERE id = ?`,
    [id]
  );
  return mapMeasurementRow(rows[0]);
}

async function fetchFoodLogsForDate(db, userId, businessId, logDate) {
  const [rows] = await db.query(
    `SELECT id, log_date, meal_type, description, photo_url, plan_option_id, logged_at
     FROM food_logs
     WHERE user_id = ? AND business_id = ? AND log_date = ?
     ORDER BY FIELD(meal_type, 'breakfast','lunch','dinner','snack'), logged_at`,
    [userId, businessId, logDate]
  );
  return rows.map((row) => ({
    id: row.id,
    log_date: formatDateOnly(row.log_date),
    meal_type: row.meal_type,
    meal_type_label: MEAL_TYPE_LABELS[row.meal_type],
    description: row.description,
    photo_url: row.photo_url || null,
    plan_option_id: row.plan_option_id || null,
    logged_at: row.logged_at,
  }));
}

async function fetchNutritionGoals(db, userId) {
  const [[row]] = await db.query(
    `SELECT weight_kg, target_weight_kg, height_cm, body_fat_pct, target_body_fat_pct
     FROM users WHERE id = ?`,
    [userId]
  );
  return {
    weight_kg: row?.weight_kg != null ? Number(row.weight_kg) : null,
    target_weight_kg: row?.target_weight_kg != null ? Number(row.target_weight_kg) : null,
    height_cm: row?.height_cm != null ? Number(row.height_cm) : null,
    body_fat_pct: row?.body_fat_pct != null ? Number(row.body_fat_pct) : null,
    target_body_fat_pct: row?.target_body_fat_pct != null ? Number(row.target_body_fat_pct) : null,
  };
}

function slotsFromLegacyMeals(meals) {
  const slotMap = new Map();
  for (const meal of meals || []) {
    if (!meal?.description && !meal?.title) continue;
    const day = normalizeDayOfWeek(meal.day_of_week);
    const mealType = normalizeMealType(meal.meal_type);
    const key = `${day}:${mealType}`;
    if (!slotMap.has(key)) {
      slotMap.set(key, { day_of_week: day, meal_type: mealType, options: [] });
    }
    slotMap.get(key).options.push({
      title: meal.title || meal.description,
      description: meal.description || meal.title,
      notes: meal.notes || null,
      portions: normalizePortions(meal.portions),
      image_url: meal.image_url || null,
      recipe_text: meal.recipe_text || null,
      sort_order: meal.sort_order ?? slotMap.get(key).options.length,
    });
  }
  return Array.from(slotMap.values());
}

function normalizeMealPlanPayload(body) {
  const { week_start, effective_from, notes, slots, meals } = body || {};
  let normalizedSlots = [];
  if (Array.isArray(slots) && slots.length) {
    normalizedSlots = slots.map((slot) => ({
      day_of_week: normalizeDayOfWeek(slot.day_of_week),
      meal_type: normalizeMealType(slot.meal_type),
      options: (slot.options || [])
        .filter((o) => o?.title?.trim() || o?.description?.trim())
        .map((o, idx) => ({
          title: String(o.title || o.description).trim(),
          description: String(o.description || o.title || '').trim(),
          notes: o.notes ? String(o.notes).trim() : null,
          portions: normalizePortions(o.portions),
          image_url: o.image_url || null,
          recipe_text: o.recipe_text ? String(o.recipe_text).trim() : null,
          sort_order: o.sort_order ?? idx,
        })),
    })).filter((s) => s.options.length);
  } else if (Array.isArray(meals)) {
    normalizedSlots = slotsFromLegacyMeals(meals);
  }
  const effectiveFrom = formatDateOnly(effective_from)
    || formatDateOnly(week_start)
    || formatDateOnly(new Date());
  const weekStart = mondayOfWeek(parseLocalDate(effectiveFrom));
  return {
    effectiveFrom,
    weekStart,
    notes: notes ?? null,
    slots: normalizedSlots,
  };
}

module.exports = {
  MEAL_TYPES,
  MEAL_TYPE_LABELS,
  PORTION_UNITS,
  TIME_OF_DAY_VALUES,
  TIME_OF_DAY_LABELS,
  normalizeMealType,
  normalizeDayOfWeek,
  normalizeHeight,
  normalizeBodyFat,
  normalizePortions,
  mapMealOptionRow,
  groupOptionsIntoSlots,
  buildShoppingList,
  buildSmartShoppingList,
  suggestPurchaseAmount,
  insertMealPlanSlotItems,
  fetchMealPlanVersionById,
  listProgramTemplates,
  fetchProgramTemplate,
  createProgramTemplate,
  updateProgramTemplate,
  deleteProgramTemplate,
  applyProgramTemplateToClient,
  mondayOfWeek,
  formatDateOnly,
  parseLocalDate,
  dayOfWeekFromDate,
  isNutritionFeatureEnabled,
  userHasNutritionAccess,
  fetchMealPlanForDate,
  fetchMealPlanForWeek,
  fetchMealPlanTemplate,
  listMealPlanVersions,
  fetchFoodLogsForDate,
  fetchNutritionGoals,
  fetchNutritionMeasurements,
  fetchNutritionProgress,
  insertNutritionMeasurement,
  normalizeAthleteMeasurementPayload,
  normalizeMealPlanPayload,
};
