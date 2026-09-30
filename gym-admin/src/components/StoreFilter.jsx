export default function StoreFilter({ locations = [], value = '', onChange }) {
  const stores = locations.filter((l) => l && l.is_active !== 0 && l.is_active !== false);
  if (stores.length < 2) return null;
  const current = value ? String(value) : '';

  return (
    <div className="store-filter" role="tablist" aria-label="Κατάστημα">
      <span className="store-filter-label">Κατάστημα</span>
      <div className="store-filter-chips">
        <button
          type="button"
          role="tab"
          aria-selected={current === ''}
          className={`store-filter-chip ${current === '' ? 'is-on' : ''}`}
          onClick={() => onChange('')}
        >
          Συνολικά
        </button>
        {stores.map((loc) => {
          const id = String(loc.id);
          return (
            <button
              key={id}
              type="button"
              role="tab"
              aria-selected={current === id}
              className={`store-filter-chip ${current === id ? 'is-on' : ''}`}
              onClick={() => onChange(id)}
            >
              {loc.name}
            </button>
          );
        })}
      </div>
    </div>
  );
}
