import { useEffect, useState, useRef } from 'react';

export function AnimatedCounter({ value, duration = 700 }) {
  const target = Number(value) || 0;
  const [display, setDisplay] = useState(0);
  const fromRef = useRef(0);

  useEffect(() => {
    const from = fromRef.current;
    if (from === target) return undefined;
    const start = performance.now();
    let frame;
    const tick = (now) => {
      const t = Math.min(1, (now - start) / duration);
      const eased = 1 - (1 - t) ** 3;
      const next = Math.round(from + (target - from) * eased);
      setDisplay(next);
      if (t < 1) {
        frame = requestAnimationFrame(tick);
      } else {
        fromRef.current = target;
      }
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [target, duration]);

  return <>{display}</>;
}

const CHART_COLORS = ['#76C043', '#4A8D2C', '#65a838', '#22c55e', '#86efac', '#a3e635'];

export function WeekBarChart({ data }) {
  const max = Math.max(1, ...data.map((d) => d.count));

  return (
    <div className="dash-bar-chart">
      {data.map((d, i) => {
        const pct = (d.count / max) * 100;
        const label = new Date(`${d.day}T12:00:00`).toLocaleDateString('el-GR', {
          weekday: 'short',
          day: 'numeric',
        });
        const isToday = i === data.length - 1;
        return (
          <div key={d.day} className="dash-bar-chart__col">
            <div className="dash-bar-chart__value">{d.count || ''}</div>
            <div className="dash-bar-chart__track">
              <div
                className={`dash-bar-chart__bar ${isToday ? 'dash-bar-chart__bar--today' : ''}`}
                style={{
                  height: `${Math.max(d.count ? 8 : 0, pct)}%`,
                  animationDelay: `${i * 60}ms`,
                }}
              />
            </div>
            <div className={`dash-bar-chart__label ${isToday ? 'dash-bar-chart__label--today' : ''}`}>
              {label}
            </div>
          </div>
        );
      })}
    </div>
  );
}

export function DonutChart({ data, size = 140 }) {
  const total = data.reduce((s, d) => s + d.count, 0) || 1;
  const r = 52;
  const c = 2 * Math.PI * r;
  let offset = 0;

  const slices = data.map((d, i) => {
    const pct = d.count / total;
    const dash = c * pct;
    const slice = {
      ...d,
      color: CHART_COLORS[i % CHART_COLORS.length],
      dash,
      offset: -offset,
      pct: Math.round(pct * 100),
    };
    offset += dash;
    return slice;
  });

  if (!data.length) {
    return <div className="text-muted" style={{ padding: 24, textAlign: 'center' }}>Δεν υπάρχουν δεδομένα</div>;
  }

  return (
    <div className="dash-donut">
      <svg width={size} height={size} viewBox="0 0 140 140" className="dash-donut__svg">
        <circle cx="70" cy="70" r={r} fill="none" stroke="#f1f5f9" strokeWidth="18" />
        {slices.map((s, i) => (
          <circle
            key={s.service_name}
            cx="70"
            cy="70"
            r={r}
            fill="none"
            stroke={s.color}
            strokeWidth="18"
            strokeDasharray={`${s.dash} ${c - s.dash}`}
            strokeDashoffset={s.offset}
            transform="rotate(-90 70 70)"
            className="dash-donut__slice"
            style={{ animationDelay: `${i * 80}ms` }}
          />
        ))}
        <text x="70" y="66" textAnchor="middle" fontSize="22" fontWeight="800" fill="#0f172a">{total}</text>
        <text x="70" y="82" textAnchor="middle" fontSize="10" fill="#64748b">σήμερα</text>
      </svg>
      <div className="dash-donut__legend">
        {slices.map(s => (
          <div key={s.service_name} className="dash-donut__legend-item">
            <span className="dash-donut__dot" style={{ background: s.color }} />
            <span className="dash-donut__name">{s.service_name}</span>
            <span className="dash-donut__pct">{s.count} ({s.pct}%)</span>
          </div>
        ))}
      </div>
    </div>
  );
}
