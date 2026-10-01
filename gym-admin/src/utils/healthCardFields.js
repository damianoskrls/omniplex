export const CONDITION_OPTIONS = [
  ['cardiac', 'Καρδιολογικά προβλήματα'],
  ['hypertension', 'Υπέρταση'],
  ['diabetes', 'Διαβήτης'],
  ['asthma', 'Άσθμα / αναπνευστικά'],
  ['orthopedic', 'Ορθοπεδικά προβλήματα'],
  ['injury', 'Τραυματισμοί'],
  ['other', 'Άλλο'],
  ['none', 'Κανένα'],
];

export const STATUS_OPTIONS = [
  ['fit', 'Κατάλληλος για άσκηση', '#166534', '#dcfce7'],
  ['restricted', 'Άσκηση με περιορισμούς', '#92400e', '#fef3c7'],
  ['clearance', 'Χρειάζεται ιατρική έγκριση', '#991b1b', '#fee2e2'],
];

export const GENDER_OPTIONS = [
  ['male', 'Άνδρας'],
  ['female', 'Γυναίκα'],
  ['other', 'Άλλο'],
];

export const BLOOD_OPTIONS = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

export function conditionLabel(key) {
  return CONDITION_OPTIONS.find(([id]) => id === key)?.[1] || key;
}

export function statusMeta(key) {
  return STATUS_OPTIONS.find(([id]) => id === key) || null;
}

export function genderLabel(key) {
  return GENDER_OPTIONS.find(([id]) => id === key)?.[1] || '';
}

export function ageFromDob(value) {
  const text = String(value || '').slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) return null;
  const dob = new Date(`${text}T12:00:00`);
  if (Number.isNaN(dob.getTime())) return null;
  const today = new Date();
  let age = today.getFullYear() - dob.getFullYear();
  const m = today.getMonth() - dob.getMonth();
  if (m < 0 || (m === 0 && today.getDate() < dob.getDate())) age -= 1;
  return age >= 0 && age < 130 ? age : null;
}

export function conditionKeys(health) {
  if (Array.isArray(health?.condition_keys)) return health.condition_keys;
  return [];
}
