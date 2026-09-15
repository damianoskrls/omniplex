const DAYS_SHORT = ['Δευ', 'Τρί', 'Τετ', 'Πέμ', 'Παρ', 'Σαβ', 'Κυρ'];

export default function AvailabilityEditor({ slots, onChange, gymHours, readOnly = false }) {
  const gymOpen = (wd) => gymHours?.[wd]?.closed ? null : (gymHours?.[wd]?.open || '09:00');
  const gymClose = (wd) => gymHours?.[wd]?.closed ? null : (gymHours?.[wd]?.close || '21:00');

  const addSlot = (wd) => {
    if (readOnly) return;
    const open = gymOpen(wd) || '09:00';
    const close = gymClose(wd) || '21:00';
    onChange([...slots, { weekday: wd, start_time: open, end_time: close }]);
  };

  const update = (i, key, val) => {
    if (readOnly) return;
    onChange(slots.map((s, idx) => idx === i ? { ...s, [key]: val } : s));
  };
  const remove = (i) => {
    if (readOnly) return;
    onChange(slots.filter((_, idx) => idx !== i));
  };

  const fillAllDays = () => {
    if (readOnly) return;
    const all = [0, 1, 2, 3, 4, 5, 6]
      .filter(d => !gymHours?.[d]?.closed)
      .map(d => ({ weekday: d, start_time: gymOpen(d), end_time: gymClose(d) }));
    onChange(all);
  };

  const byDay = {};
  slots.forEach((s, i) => {
    if (!byDay[s.weekday]) byDay[s.weekday] = [];
    byDay[s.weekday].push({ ...s, _idx: i });
  });

  return (
    <div>
      {!readOnly && (
        <div style={{ display: 'flex', gap: 8, marginBottom: 14, flexWrap: 'wrap' }}>
          <button type="button" className="btn btn-secondary btn-sm" onClick={fillAllDays}>
            Γέμισε από ωράριο γυμν.
          </button>
          <button type="button" className="btn btn-secondary btn-sm" onClick={() => onChange([])}>
            Καθαρισμός
          </button>
        </div>
      )}

      <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
        {[0, 1, 2, 3, 4, 5, 6].map(wd => {
          const daySlots = byDay[wd] || [];
          const gymClosed = gymHours?.[wd]?.closed;
          const minTime = gymOpen(wd);
          const maxTime = gymClose(wd);

          return (
            <div key={wd} style={{ background: gymClosed ? '#f9fafb' : '#f8fafc', borderRadius: 8, padding: '8px 12px', border: '1px solid #e2e8f0', opacity: gymClosed ? 0.5 : 1 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: daySlots.length ? 8 : 0 }}>
                <div style={{ width: 40, fontWeight: 600, fontSize: '0.85rem', color: '#374151' }}>{DAYS_SHORT[wd]}</div>
                {gymClosed ? (
                  <span style={{ fontSize: '0.78rem', color: '#94a3b8' }}>Κλειστό γυμν.</span>
                ) : (
                  <>
                    {gymHours && <span style={{ fontSize: '0.72rem', color: '#94a3b8' }}>{minTime}–{maxTime}</span>}
                    {!readOnly && (
                      <button
                        type="button"
                        onClick={() => addSlot(wd)}
                        style={{ border: '1px dashed #76C043', borderRadius: 6, padding: '2px 8px', fontSize: '0.75rem', color: '#76C043', background: 'none', cursor: 'pointer' }}
                      >
                        + Slot
                      </button>
                    )}
                  </>
                )}
              </div>

              {daySlots.map(s => (
                <div key={s._idx} style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 4, paddingLeft: 50 }}>
                  <input
                    type="time"
                    className="form-input"
                    style={{ width: 100, padding: '4px 8px' }}
                    value={s.start_time}
                    min={minTime || undefined}
                    max={maxTime || undefined}
                    disabled={readOnly}
                    onChange={e => update(s._idx, 'start_time', e.target.value)}
                  />
                  <span style={{ color: '#94a3b8' }}>—</span>
                  <input
                    type="time"
                    className="form-input"
                    style={{ width: 100, padding: '4px 8px' }}
                    value={s.end_time}
                    min={minTime || undefined}
                    max={maxTime || undefined}
                    disabled={readOnly}
                    onChange={e => update(s._idx, 'end_time', e.target.value)}
                  />
                  {!readOnly && (
                    <button type="button" onClick={() => remove(s._idx)} style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#ef4444' }}>
                      ×
                    </button>
                  )}
                </div>
              ))}
            </div>
          );
        })}
      </div>
    </div>
  );
}
