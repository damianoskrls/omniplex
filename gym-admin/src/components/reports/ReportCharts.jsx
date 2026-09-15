import { AnimatedCounter } from '../dashboard/DashboardCharts';

const CHART_COLORS = ['#76C043', '#4A8D2C', '#65a838', '#22c55e', '#86efac', '#a3e635', '#14b8a6', '#f59e0b'];

export function HorizontalBarChart({ data, nameKey, valueKey, suffix = '' }) {
  const max = Math.max(1, ...data.map((d) => d[valueKey] || 0));
  if (!data.length) {
    return <div className="text-muted reports-empty">Δεν υπάρχουν δεδομένα</div>;
  }
  return (
    <div className="reports-hbar-list">
      {data.map((d, i) => {
        const val = d[valueKey] || 0;
        const pct = (val / max) * 100;
        return (
          <div key={`${d[nameKey]}-${i}`} className="reports-hbar-row">
            <div className="reports-hbar-label" title={d[nameKey]}>{d[nameKey]}</div>
            <div className="reports-hbar-track">
              <div
                className="reports-hbar-fill"
                style={{
                  width: `${Math.max(val ? 6 : 0, pct)}%`,
                  background: CHART_COLORS[i % CHART_COLORS.length],
                  animationDelay: `${i * 60}ms`,
                }}
              />
            </div>
            <div className="reports-hbar-value">{val}{suffix}</div>
          </div>
        );
      })}
    </div>
  );
}

export function TimeOfDayChart({ data }) {
  const icons = { morning: '🌅', afternoon: '☀️', evening: '🌙' };
  const max = Math.max(1, ...data.map((d) => d.bookings || 0));
  if (!data.length) {
    return <div className="text-muted reports-empty">Δεν υπάρχουν δεδομένα</div>;
  }
  return (
    <div className="reports-time-grid">
      {data.map((d, i) => {
        const pct = ((d.bookings || 0) / max) * 100;
        return (
          <div key={d.bucket} className="reports-time-card">
            <div className="reports-time-icon">{icons[d.bucket] || '📊'}</div>
            <div className="reports-time-label">{d.label}</div>
            <div className="reports-time-bar-track">
              <div
                className="reports-time-bar-fill"
                style={{ height: `${Math.max(8, pct)}%`, animationDelay: `${i * 100}ms` }}
              />
            </div>
            <div className="reports-time-count"><AnimatedCounter value={d.bookings} /></div>
            <div className="reports-time-sub">{d.unique_clients} αθλητές</div>
          </div>
        );
      })}
    </div>
  );
}

export { AnimatedCounter };
