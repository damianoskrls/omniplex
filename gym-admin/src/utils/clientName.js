export function displayClientName(name) {
  const raw = String(name || '').replace(/[—–-]/g, ' ').replace(/\s+/g, ' ').trim();
  if (!raw || /χωρίς πελάτη/i.test(raw)) return 'Ανώνυμος πελάτης';
  return raw;
}
