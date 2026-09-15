import { useEffect, useState } from 'react';
import api from '../api/client';

export default function LocationCheckboxes({ value = [], onChange, label = 'Τοποθεσίες' }) {
  const [locations, setLocations] = useState([]);

  useEffect(() => {
    api.get('/client-admin/locations').then((r) => {
      setLocations((r.data || []).filter((l) => l.is_active));
    }).catch(() => {});
  }, []);

  if (locations.length === 0) return null;

  const allSelected = value.length === 0;

  const toggle = (id) => {
    const set = new Set(value);
    if (set.has(id)) set.delete(id);
    else set.add(id);
    onChange([...set]);
  };

  return (
    <div className="form-group">
      <label className="form-label">{label}</label>
      <p className="text-muted" style={{ fontSize: '0.8rem', marginBottom: 8 }}>
        Επίλεξε συγκεκριμένα γυμναστήρια ή «Όλα» για διαθεσιμότητα σε όλα τα καταστήματα.
      </p>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
        <button
          type="button"
          onClick={() => onChange([])}
          style={{
            padding: '6px 14px', borderRadius: 8,
            border: `1px solid ${allSelected ? '#86efac' : '#e2e8f0'}`,
            background: allSelected ? '#f0fdf4' : '#fff',
            fontWeight: allSelected ? 700 : 400,
            fontSize: '0.85rem', cursor: 'pointer',
          }}
        >
          Όλα τα γυμναστήρια
        </button>
        {locations.map((loc) => {
          const checked = value.includes(loc.id);
          return (
            <label
              key={loc.id}
              style={{
                display: 'flex', alignItems: 'center', gap: 6, padding: '6px 12px',
                border: `1px solid ${checked ? '#86efac' : '#e2e8f0'}`,
                borderRadius: 8, cursor: 'pointer',
                background: checked ? '#f0fdf4' : '#fff',
              }}
            >
              <input type="checkbox" checked={checked} onChange={() => toggle(loc.id)} />
              {loc.name}
            </label>
          );
        })}
      </div>
    </div>
  );
}
