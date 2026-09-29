async function count(db, sql, params) {
  try {
    const [[row]] = await db.query(sql, params);
    return Number(row?.cnt || 0);
  } catch {
    return 0;
  }
}

function parseProgress(raw) {
  if (!raw) return { last_step: 'details', skipped: [], finished: false, dismissed: false };
  try {
    const value = typeof raw === 'string' ? JSON.parse(raw) : raw;
    return {
      last_step: value.last_step || 'details',
      skipped: Array.isArray(value.skipped) ? value.skipped : [],
      finished: !!value.finished,
      dismissed: !!value.dismissed,
    };
  } catch {
    return { last_step: 'details', skipped: [], finished: false, dismissed: false };
  }
}

async function getSetupWizard(db, bizId) {
  const [[cfg]] = await db.query(
    `SELECT app_name, logo_url, gym_phone, gym_email, owner_name, feature_nutrition,
            annual_leave_days, setup_wizard
     FROM business_configs WHERE business_id = ?`,
    [bizId],
  );
  const [[biz]] = await db.query(
    'SELECT name, description FROM businesses WHERE id = ?',
    [bizId],
  );

  const [
    photos, locations, locationsWithHours, dropInLocations,
    services, plans, rooms, staff, staffWithHours, nutritionists, leaves, programs,
  ] = await Promise.all([
    count(db, 'SELECT COUNT(*) AS cnt FROM gym_photos WHERE business_id = ?', [bizId]),
    count(db, 'SELECT COUNT(*) AS cnt FROM locations WHERE business_id = ? AND is_active = 1', [bizId]),
    count(db, 'SELECT COUNT(*) AS cnt FROM locations WHERE business_id = ? AND is_active = 1 AND opening_hours IS NOT NULL', [bizId]),
    count(db, 'SELECT COUNT(*) AS cnt FROM locations WHERE business_id = ? AND is_active = 1 AND accepts_drop_in = 1', [bizId]),
    count(db, 'SELECT COUNT(*) AS cnt FROM services WHERE business_id = ? AND is_active = 1', [bizId]),
    count(db, 'SELECT COUNT(*) AS cnt FROM business_plans WHERE business_id = ? AND is_active = 1', [bizId]),
    count(db, 'SELECT COUNT(*) AS cnt FROM rooms WHERE business_id = ? AND is_active = 1', [bizId]),
    count(db, `SELECT COUNT(*) AS cnt FROM staff WHERE business_id = ? AND is_active = 1 AND COALESCE(is_general_pool,0)=0 AND COALESCE(is_nutritionist,0)=0`, [bizId]),
    count(db, `SELECT COUNT(DISTINCT sa.staff_id) AS cnt
               FROM staff_availability sa
               JOIN staff s ON s.id = sa.staff_id
               WHERE s.business_id = ? AND sa.is_active = 1`, [bizId]),
    count(db, 'SELECT COUNT(*) AS cnt FROM nutritionists WHERE business_id = ? AND is_active = 1', [bizId]),
    count(db, 'SELECT COUNT(*) AS cnt FROM staff_leaves WHERE business_id = ?', [bizId]),
    count(db, 'SELECT COUNT(*) AS cnt FROM workout_programs WHERE business_id = ?', [bizId]),
  ]);

  return {
    progress: parseProgress(cfg?.setup_wizard),
    checks: {
      has_name: !!(cfg?.app_name || biz?.name),
      has_logo: !!cfg?.logo_url,
      has_contact: !!(cfg?.gym_phone || cfg?.gym_email),
      has_owner: !!cfg?.owner_name,
      photos,
      has_description: !!(biz?.description && String(biz.description).trim()),
      locations,
      locations_with_hours: locationsWithHours,
      drop_in_locations: dropInLocations,
      services,
      plans,
      rooms,
      staff,
      staff_with_hours: staffWithHours,
      nutrition_enabled: !!cfg?.feature_nutrition,
      nutritionists,
      leaves,
      programs,
      annual_leave_days: cfg?.annual_leave_days ?? 20,
    },
  };
}

async function saveSetupWizard(db, bizId, patch = {}) {
  const current = await getSetupWizard(db, bizId);
  const next = {
    ...current.progress,
    ...patch,
    skipped: patch.skipped || current.progress.skipped,
  };
  await db.query(
    'UPDATE business_configs SET setup_wizard = ? WHERE business_id = ?',
    [JSON.stringify(next), bizId],
  );
  return next;
}

module.exports = { getSetupWizard, saveSetupWizard };
