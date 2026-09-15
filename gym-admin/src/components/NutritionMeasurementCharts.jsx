function clamp(n, min, max) {
  return Math.min(max, Math.max(min, n));
}

function buildPath(points, width, height, target, padding = 12) {
  if (!points?.length) return { line: '', area: '', min: 0, max: 0, targetY: null };
  const values = points.map(p => Number(p.value));
  let min = Math.min(...values);
  let max = Math.max(...values);
  if (target != null) {
    min = Math.min(min, target);
    max = Math.max(max, target);
  }
  const range = Math.abs(max - min) < 0.01 ? 1 : max - min;
  const w = width - padding * 2;
  const h = height - padding * 2;

  const coords = points.map((p, i) => {
    const x = padding + (points.length === 1 ? w / 2 : (i / (points.length - 1)) * w);
    const y = padding + h - ((Number(p.value) - min) / range) * h;
    return { x, y, ...p };
  });

  let line = '';
  coords.forEach((c, i) => {
    if (i === 0) line += `M ${c.x} ${c.y}`;
    else {
      const prev = coords[i - 1];
      const cx = (prev.x + c.x) / 2;
      line += ` C ${cx} ${prev.y}, ${cx} ${c.y}, ${c.x} ${c.y}`;
    }
  });

  const area = `${line} L ${coords[coords.length - 1].x} ${height - padding} L ${coords[0].x} ${height - padding} Z`;
  const targetY = target != null ? padding + h - ((target - min) / range) * h : null;
  return { line, area, min, max, targetY, coords };
}

export function GoalRing({ label, value, target, percent, color = '#76C043' }) {
  const p = clamp(percent ?? 0, 0, 100);
  const r = 42;
  const c = 2 * Math.PI * r;
  const offset = c * (1 - p / 100);

  return (
    <div style={{ textAlign: 'center', flex: 1, minWidth: 120 }}>
      <svg width="100" height="100" viewBox="0 0 100 100">
        <circle cx="50" cy="50" r={r} fill="none" stroke="#e2e8f0" strokeWidth="8" />
        <circle
          cx="50"
          cy="50"
          r={r}
          fill="none"
          stroke={color}
          strokeWidth="8"
          strokeLinecap="round"
          strokeDasharray={c}
          strokeDashoffset={offset}
          transform="rotate(-90 50 50)"
          style={{ transition: 'stroke-dashoffset 0.9s ease' }}
        />
        <text x="50" y="54" textAnchor="middle" fontSize="16" fontWeight="700" fill={color}>{p}%</text>
      </svg>
      <div style={{ fontWeight: 600, fontSize: '0.85rem' }}>{label}</div>
      <div style={{ fontSize: '1rem', fontWeight: 700 }}>{value ?? '—'}</div>
      {target != null && <div style={{ fontSize: '0.75rem', color: '#64748b' }}>Στόχος: {target}</div>}
    </div>
  );
}

export function TrendChart({ title, points, target, unit, color = '#76C043', height = 140 }) {
  const width = 320;
  const { line, area, targetY, coords } = buildPath(points, width, height, target);

  if (!points?.length) {
    return (
      <div style={{ marginBottom: 16 }}>
        <div style={{ fontWeight: 600, marginBottom: 8 }}>{title}</div>
        <div className="text-muted" style={{ fontSize: '0.85rem' }}>Χρειάζονται τουλάχιστον 2 μετρήσεις.</div>
      </div>
    );
  }

  return (
    <div style={{ marginBottom: 16 }}>
      <div style={{ fontWeight: 600, marginBottom: 8 }}>{title}</div>
      <svg width="100%" viewBox={`0 0 ${width} ${height}`} style={{ maxWidth: 480, display: 'block' }}>
        <defs>
          <linearGradient id={`grad-${title}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity="0.25" />
            <stop offset="100%" stopColor={color} stopOpacity="0.02" />
          </linearGradient>
        </defs>
        {[1, 2, 3].map(i => (
          <line key={i} x1="12" x2={width - 12} y1={(height / 4) * i} y2={(height / 4) * i} stroke="#f1f5f9" />
        ))}
        {targetY != null && (
          <line x1="12" x2={width - 12} y1={targetY} y2={targetY} stroke="#f97316" strokeDasharray="5 4" strokeWidth="1.5" />
        )}
        {area && <path d={area} fill={`url(#grad-${title})`} />}
        {line && <path d={line} fill="none" stroke={color} strokeWidth="2.5" strokeLinecap="round" />}
        {coords?.map((c, i) => (
          <g key={i}>
            <circle cx={c.x} cy={c.y} r="4.5" fill={c.recorded_by === 'athlete' ? '#22c55e' : color} />
            <title>{c.date}: {c.value} {unit}</title>
          </g>
        ))}
      </svg>
      <div style={{ display: 'flex', gap: 12, fontSize: '0.7rem', color: '#64748b', marginTop: 4 }}>
        <span><span style={{ color: color }}>●</span> Διατροφολόγος</span>
        <span><span style={{ color: '#22c55e' }}>●</span> Ασκούμενος</span>
        {target != null && <span><span style={{ color: '#f97316' }}>—</span> Στόχος</span>}
      </div>
    </div>
  );
}

export function VisitTimeline({ visits }) {
  if (!visits?.length) return null;

  return (
    <div style={{ marginTop: 8 }}>
      <div style={{ fontWeight: 600, marginBottom: 10 }}>Ιστορικό επισκέψεων / μετρήσεων</div>
      <div style={{ position: 'relative', paddingLeft: 20 }}>
        <div style={{ position: 'absolute', left: 7, top: 4, bottom: 4, width: 2, background: '#e2e8f0' }} />
        {visits.map((v, i) => {
          const isAthlete = v.recorded_by === 'athlete';
          return (
            <div key={v.id || i} style={{ position: 'relative', marginBottom: 14, paddingLeft: 12 }}>
              <div style={{
                position: 'absolute',
                left: -17,
                top: 6,
                width: 12,
                height: 12,
                borderRadius: '50%',
                background: isAthlete ? '#22c55e' : '#76C043',
                border: '2px solid #fff',
                boxShadow: '0 0 0 1px #e2e8f0',
              }} />
              <div style={{ background: '#f8fafc', borderRadius: 10, padding: '10px 12px', border: '1px solid #e2e8f0' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, flexWrap: 'wrap' }}>
                  <div>
                    <strong>{v.measured_when || v.date || v.measured_on}</strong>
                    <div style={{ fontSize: '0.75rem', color: '#64748b' }}>
                      {isAthlete ? 'Καταγραφή ασκουμένου' : 'Μέτρηση διατροφολόγου (επίσκεψη)'}
                    </div>
                  </div>
                  <div style={{ textAlign: 'right', fontSize: '0.85rem' }}>
                    {v.weight_kg != null && <div><strong>{v.weight_kg} kg</strong></div>}
                    {v.body_fat_pct != null && <div>{v.body_fat_pct}% λίπος</div>}
                    {v.muscle_mass_kg != null && <div>{v.muscle_mass_kg} kg μύες</div>}
                  </div>
                </div>
                {v.notes && <div style={{ fontSize: '0.8rem', color: '#64748b', marginTop: 6 }}>{v.notes}</div>}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

export function BodyMeasurementsHero({
  latest,
  goals,
  progress,
  height = 220,
}) {
  const weight = latest?.weight_kg;
  const bodyFat = latest?.body_fat_pct;
  const heightCm = latest?.height_cm;

  return (
    <div className="body-measurements-hero">
      <div className="body-measurements-hero__head">
        <div>
          <div className="body-measurements-hero__title">Μετρήσεις σώματος</div>
          <div className="body-measurements-hero__sub">
            {latest?.measured_when || latest?.measured_on
              ? `Τελευταία μέτρηση: ${latest.measured_when || latest.measured_on}`
              : 'Καταχώρησε μετρήσεις μετά από επίσκεψη (InBody κ.λπ.)'}
          </div>
        </div>
        {heightCm != null && (
          <span className="body-measurements-badge">Ύψος {heightCm} cm</span>
        )}
      </div>

      <div className="body-measurements-hero__body">
        <div className="body-measurements-stats">
          <div className="body-measurements-stat">
            <div className="body-measurements-stat__label">Βάρος</div>
            <div className="body-measurements-stat__value">
              {weight != null ? `${weight} kg` : '—'}
            </div>
            {goals?.target_weight_kg != null && (
              <div className="body-measurements-stat__target">Στόχος {goals.target_weight_kg} kg</div>
            )}
          </div>
          <div className="body-measurements-stat">
            <div className="body-measurements-stat__label">Λίπος</div>
            <div className="body-measurements-stat__value">
              {bodyFat != null ? `${bodyFat}%` : '—'}
            </div>
            {goals?.target_body_fat_pct != null && (
              <div className="body-measurements-stat__target">Στόχος {goals.target_body_fat_pct}%</div>
            )}
          </div>
          <div className="body-measurements-stat">
            <div className="body-measurements-stat__label">Πρόοδος βάρους</div>
            <div className="body-measurements-stat__value accent">{progress?.weight_goal_pct ?? 0}%</div>
          </div>
          <div className="body-measurements-stat">
            <div className="body-measurements-stat__label">Πρόοδος λίπους</div>
            <div className="body-measurements-stat__value teal">{progress?.body_fat_goal_pct ?? 0}%</div>
          </div>
        </div>

        <div className="body-measurements-figure">
          <img
            src="/icons/body_measurements.png"
            alt=""
            height={height}
            className="body-measurements-figure__img"
          />
        </div>
      </div>
    </div>
  );
}

/** @deprecated use BodyMeasurementsHero */
export function BodySilhouetteImage({ height = 100 }) {
  return (
    <img
      src="/icons/body_measurements.png"
      alt=""
      height={height}
      className="body-measurements-figure__img"
    />
  );
}
