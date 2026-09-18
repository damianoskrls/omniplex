import { useMemo } from 'react';

/** Convert "HH:MM" (24h) → { h12, minute, period } */
function from24(val) {
  if (!val) return { h12: 9, minute: 0, period: 'ΠΜ' };
  const [hStr, mStr] = val.split(':');
  let h = parseInt(hStr, 10);
  const m = parseInt(mStr, 10) || 0;
  const period = h < 12 ? 'ΠΜ' : 'ΜΜ';
  if (h === 0) h = 12;
  else if (h > 12) h -= 12;
  return { h12: h, minute: m, period };
}

/** Convert { h12, minute, period } → "HH:MM" */
function to24({ h12, minute, period }) {
  let h = h12 % 12;
  if (period === 'ΜΜ') h += 12;
  return `${String(h).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
}

const MINUTES = Array.from({ length: 60 }, (_, i) => i);

export default function TimeInput({ value, onChange, style, disabled }) {
  const { h12, minute, period } = useMemo(() => from24(value), [value]);

  function update(field, val) {
    const next = { h12, minute, period, [field]: val };
    onChange(to24(next));
  }

  const baseSelect = {
    border: '1px solid var(--border)',
    borderRadius: 8,
    padding: '4px 6px',
    fontSize: '0.855rem',
    background: 'var(--surface)',
    color: 'var(--text)',
    cursor: disabled ? 'not-allowed' : 'pointer',
    outline: 'none',
    appearance: 'none',
    WebkitAppearance: 'none',
    textAlign: 'center',
    fontFamily: 'inherit',
    opacity: disabled ? 0.5 : 1,
  };

  return (
    <div style={{ display: 'inline-flex', alignItems: 'center', gap: 2, ...style }}>
      <select
        disabled={disabled}
        value={h12}
        onChange={e => update('h12', parseInt(e.target.value, 10))}
        style={{ ...baseSelect, width: 44 }}
      >
        {[12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11].map(h => (
          <option key={h} value={h}>{String(h).padStart(2, '0')}</option>
        ))}
      </select>
      <span style={{ color: 'var(--text-3)', fontWeight: 600, fontSize: '0.85rem', lineHeight: 1 }}>:</span>
      <select
        disabled={disabled}
        value={minute}
        onChange={e => update('minute', parseInt(e.target.value, 10))}
        style={{ ...baseSelect, width: 44 }}
      >
        {MINUTES.map(m => (
          <option key={m} value={m}>{String(m).padStart(2, '0')}</option>
        ))}
      </select>
      <button
        type="button"
        disabled={disabled}
        onClick={() => update('period', period === 'ΠΜ' ? 'ΜΜ' : 'ΠΜ')}
        style={{
          ...baseSelect,
          width: 38,
          padding: '4px 4px',
          fontWeight: 700,
          fontSize: '0.72rem',
          color: period === 'ΠΜ' ? '#2563eb' : '#dc2626',
          border: `1px solid ${period === 'ΠΜ' ? '#bfdbfe' : '#fecaca'}`,
          background: period === 'ΠΜ' ? '#eff6ff' : '#fff1f2',
          letterSpacing: '0.02em',
          cursor: disabled ? 'not-allowed' : 'pointer',
        }}
      >
        {period}
      </button>
    </div>
  );
}
