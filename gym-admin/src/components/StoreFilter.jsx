import { useEffect } from 'react';
import { useAuth } from '../context/AuthContext';

export default function StoreFilter({ locations = [], value = '', onChange }) {
  const { business } = useAuth();
  const locked = business?.location_id ? String(business.location_id) : '';
  const stores = locations.filter((l) => l && l.is_active !== 0 && l.is_active !== false);

  useEffect(() => {
    if (locked && String(value || '') !== locked) onChange(locked);
  }, [locked, value, onChange]);

  if (locked) {
    const store = stores.find((l) => String(l.id) === locked);
    return (
      <div className="store-filter" role="tablist" aria-label="Κατάστημα">
        <span className="store-filter-label">Κατάστημα</span>
        <div className="store-filter-chips">
          <button type="button" className="store-filter-chip is-on" disabled>
            {store?.name || business?.location_name || 'Κατάστημα'}
          </button>
        </div>
      </div>
    );
  }

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
