/** @returns {{ date: string, time: string }} ISO date (yyyy-MM-dd) and HH:mm in local time */
function parseDateTimeParts(value) {
  if (!value) throw new Error('Μη έγκυρη ημερομηνία');

  const raw = String(value);
  if (/^\d{4}-\d{2}-\d{2}/.test(raw)) {
    const date = raw.slice(0, 10);
    const time = raw.includes('T') ? raw.slice(11, 16) : '00:00';
    return { date, time };
  }

  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) {
    throw new Error('Μη έγκυρη ημερομηνία');
  }

  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  const hours = String(d.getHours()).padStart(2, '0');
  const mins = String(d.getMinutes()).padStart(2, '0');
  return { date: `${year}-${month}-${day}`, time: `${hours}:${mins}` };
}

module.exports = { parseDateTimeParts };
