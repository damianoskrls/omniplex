const ACCOUNT_STATUS_LABELS = {
  pending: 'Εκκρεμεί έγκριση',
  active: 'Ενεργός',
  suspended: 'Απενεργοποιημένος',
  deleted: 'Στον κάδο',
};

const FITNESS_GOAL_LABELS = {
  weight_loss: 'Απώλεια βάρους',
  strength: 'Ενδυνάμωση',
  endurance: 'Αντοχή',
  flexibility: 'Ευλυγισία',
  rehabilitation: 'Αποκατάσταση',
  general: 'Γενική φυσική κατάσταση',
};

function computeAge(dateOfBirth) {
  if (!dateOfBirth) return null;
  const dob = new Date(`${String(dateOfBirth).slice(0, 10)}T12:00:00`);
  if (Number.isNaN(dob.getTime())) return null;
  const today = new Date();
  let age = today.getFullYear() - dob.getFullYear();
  const m = today.getMonth() - dob.getMonth();
  if (m < 0 || (m === 0 && today.getDate() < dob.getDate())) age -= 1;
  return age;
}

function isBirthdayToday(dateOfBirth) {
  if (!dateOfBirth) return false;
  const dob = new Date(`${String(dateOfBirth).slice(0, 10)}T12:00:00`);
  const today = new Date();
  return dob.getMonth() === today.getMonth() && dob.getDate() === today.getDate();
}

function daysUntilBirthday(dateOfBirth) {
  if (!dateOfBirth) return null;
  if (isBirthdayToday(dateOfBirth)) return 0;
  const dob = new Date(`${String(dateOfBirth).slice(0, 10)}T12:00:00`);
  const today = new Date();
  today.setHours(12, 0, 0, 0);
  const next = new Date(today.getFullYear(), dob.getMonth(), dob.getDate(), 12);
  if (next <= today) next.setFullYear(today.getFullYear() + 1);
  return Math.ceil((next - today) / 86400000);
}

function enrichClientProfile(row) {
  if (!row) return row;
  const goalKey = row.fitness_goal;
  const isDeleted = !!row.deleted_at;
  const status = isDeleted ? 'deleted' : (row.account_status || 'active');
  return {
    ...row,
    is_deleted: isDeleted,
    account_status: status,
    account_status_label: ACCOUNT_STATUS_LABELS[status] || status,
    age: computeAge(row.date_of_birth),
    birthday_today: isBirthdayToday(row.date_of_birth),
    days_until_birthday: daysUntilBirthday(row.date_of_birth),
    fitness_goal_label: goalKey
      ? (FITNESS_GOAL_LABELS[goalKey] || goalKey)
      : null,
  };
}

function normalizeFitnessGoal(value) {
  if (value === undefined) return undefined;
  if (!value) return null;
  const key = String(value).trim();
  if (FITNESS_GOAL_LABELS[key] || key.length <= 100) return key;
  throw new Error('Μη έγκυρος στόχος');
}

function normalizeWeight(value) {
  if (value === undefined) return undefined;
  if (value === null || value === '') return null;
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0 || n > 500) {
    throw new Error('Το βάρος πρέπει να είναι μεταξύ 0 και 500 kg');
  }
  return Math.round(n * 10) / 10;
}

module.exports = {
  ACCOUNT_STATUS_LABELS,
  FITNESS_GOAL_LABELS,
  computeAge,
  isBirthdayToday,
  daysUntilBirthday,
  enrichClientProfile,
  normalizeFitnessGoal,
  normalizeWeight,
};
