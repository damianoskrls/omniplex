const KEYWORDS = [
  ['yoga', 'yoga'],
  ['pilates', 'pilates'],
  ['cross', 'cross_training'],
  ['hiit', 'hiit'],
  ['cycle', 'cycling'],
  ['rpm', 'cycling'],
  ['spin', 'cycling'],
  ['stretch', 'stretching'],
  ['trx', 'trx'],
  ['strength', 'strength'],
  ['weights', 'strength'],
  ['fitness', 'fitness'],
  ['group', 'fitness'],
];

export function guessServiceIconKey(service) {
  if (service?.icon_key) return service.icon_key;
  const hay = `${service?.name || ''} ${service?.category || ''}`.toLowerCase();
  for (const [word, key] of KEYWORDS) {
    if (hay.includes(word)) return key;
  }
  return 'fitness';
}

export default function ServiceIcon({ service, iconKey, size = 40, className = '' }) {
  const key = iconKey || guessServiceIconKey(service);
  const src = `/icons/${key}.svg`;

  return (
    <img
      src={src}
      alt=""
      className={className}
      style={{ width: size, height: size, objectFit: 'contain' }}
      onError={(e) => { e.currentTarget.src = '/icons/fitness.svg'; }}
    />
  );
}
