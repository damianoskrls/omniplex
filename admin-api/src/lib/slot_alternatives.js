const { assertSlotCapacity } = require('./slots');

/**
 * Find the next bookable slot on the same day, preferring +60 minutes.
 */
async function findAlternativeSlot(dbConn, bizId, serviceId, date, requestedTime, staffId = null) {
  const [[service]] = await dbConn.query(
    'SELECT duration_mins FROM services WHERE id = ? AND business_id = ?',
    [serviceId, bizId]
  );
  if (!service) return null;

  const [h, m] = requestedTime.split(':').map(Number);
  const baseMins = h * 60 + m;
  const offsets = [60, 30, 90, 120];

  for (const offset of offsets) {
    const total = baseMins + offset;
    if (total >= 24 * 60) continue;

    const newTime = `${String(Math.floor(total / 60)).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`;
    const startsAt = new Date(`${date}T${newTime}:00`);
    const endsAt = new Date(startsAt.getTime() + service.duration_mins * 60000);

    try {
      const { computed } = await assertSlotCapacity(
        dbConn, bizId, serviceId, date, newTime, startsAt, endsAt, null, false
      );
      const pool = computed.slotMap[newTime] || [];
      if (!pool.length) continue;
      if (staffId && !pool.some(s => s.id === staffId)) continue;

      return { date, time: newTime, offset_mins: offset };
    } catch (_) {
      continue;
    }
  }

  return null;
}

module.exports = { findAlternativeSlot };
