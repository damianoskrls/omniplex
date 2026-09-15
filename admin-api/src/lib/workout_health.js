function parseOptionalDate(value) {
  if (!value) return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d;
}

function normalizeWorkoutHealthPayload(body) {
  const raw = body?.health_workout ?? body?.health ?? null;
  if (!raw || typeof raw !== 'object') return null;

  const calories = raw.calories_kcal != null && raw.calories_kcal !== ''
    ? Math.round(Number(raw.calories_kcal)) : null;
  const duration = raw.duration_mins != null && raw.duration_mins !== ''
    ? Math.round(Number(raw.duration_mins)) : null;
  const hr = raw.avg_heart_rate != null && raw.avg_heart_rate !== ''
    ? Math.round(Number(raw.avg_heart_rate)) : null;
  const distance = raw.distance_m != null && raw.distance_m !== ''
    ? Math.round(Number(raw.distance_m) * 100) / 100 : null;

  const started = parseOptionalDate(raw.started_at);
  const ended = parseOptionalDate(raw.ended_at);

  if (calories == null && duration == null && !started) return null;

  return {
    external_id: raw.external_id ? String(raw.external_id).slice(0, 120) : null,
    activity_type: raw.activity_type ? String(raw.activity_type).slice(0, 80) : null,
    activity_label: raw.activity_label ? String(raw.activity_label).slice(0, 120) : null,
    workout_started_at: started,
    workout_ended_at: ended,
    duration_mins: duration != null && duration >= 0 && duration <= 600 ? duration : null,
    calories_kcal: calories != null && calories >= 0 && calories <= 5000 ? calories : null,
    avg_heart_rate: hr != null && hr >= 40 && hr <= 220 ? hr : null,
    distance_m: distance != null && distance >= 0 && distance <= 500 ? distance : null,
    source: raw.source ? String(raw.source).slice(0, 40) : 'health',
  };
}

function mapBookingHealthFields(row) {
  if (!row) return null;
  if (row.health_calories_kcal == null && row.health_duration_mins == null && !row.health_workout_started_at) {
    return null;
  }
  return {
    external_id: row.health_external_id,
    activity_type: row.health_activity_type,
    activity_label: row.health_activity_label,
    started_at: row.health_workout_started_at,
    ended_at: row.health_workout_ended_at,
    duration_mins: row.health_duration_mins != null ? Number(row.health_duration_mins) : null,
    calories_kcal: row.health_calories_kcal != null ? Number(row.health_calories_kcal) : null,
    avg_heart_rate: row.health_avg_heart_rate != null ? Number(row.health_avg_heart_rate) : null,
    distance_m: row.health_distance_m != null ? Number(row.health_distance_m) : null,
    source: row.health_source,
    synced_at: row.health_synced_at,
  };
}

async function saveBookingWorkoutHealth(executor, bookingId, health) {
  if (!health) return;
  await executor.query(
    `UPDATE bookings SET
      health_external_id = ?,
      health_activity_type = ?,
      health_activity_label = ?,
      health_workout_started_at = ?,
      health_workout_ended_at = ?,
      health_duration_mins = ?,
      health_calories_kcal = ?,
      health_avg_heart_rate = ?,
      health_distance_m = ?,
      health_source = ?,
      health_synced_at = NOW()
     WHERE id = ?`,
    [
      health.external_id,
      health.activity_type,
      health.activity_label,
      health.workout_started_at,
      health.workout_ended_at,
      health.duration_mins,
      health.calories_kcal,
      health.avg_heart_rate,
      health.distance_m,
      health.source,
      bookingId,
    ]
  );
}

module.exports = {
  normalizeWorkoutHealthPayload,
  mapBookingHealthFields,
  saveBookingWorkoutHealth,
};
