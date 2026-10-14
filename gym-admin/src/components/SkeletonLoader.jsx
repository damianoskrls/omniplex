// Shimmer skeleton placeholders for content loading states

export function SkeletonRow({ cols = [120, 180, 100, 80] }) {
  return (
    <div className="skeleton-row">
      <span className="skeleton skeleton-avatar" />
      <div style={{ flex: 1, display: 'flex', gap: 16, alignItems: 'center' }}>
        {cols.map((w, i) => (
          <span key={i} className="skeleton skeleton-line" style={{ width: w, flex: i === 0 ? '1 1 auto' : '0 0 auto', maxWidth: w }} />
        ))}
      </div>
    </div>
  );
}

export function SkeletonCard({ lines = 3 }) {
  return (
    <div className="card" style={{ padding: 16 }}>
      <div style={{ display: 'flex', gap: 12, alignItems: 'center', marginBottom: 12 }}>
        <span className="skeleton skeleton-avatar" />
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 6 }}>
          <span className="skeleton skeleton-line" style={{ width: '60%' }} />
          <span className="skeleton skeleton-line skeleton-line-sm" style={{ width: '40%' }} />
        </div>
      </div>
      {Array.from({ length: lines - 1 }).map((_, i) => (
        <span key={i} className="skeleton skeleton-line" style={{ width: `${70 - i * 15}%`, marginBottom: 8, display: 'block' }} />
      ))}
    </div>
  );
}

export function SkeletonTable({ rows = 5, cols = [1, 160, 120, 80] }) {
  return (
    <div style={{ padding: '0 4px' }}>
      {Array.from({ length: rows }).map((_, i) => (
        <SkeletonRow key={i} cols={cols} />
      ))}
    </div>
  );
}

export function SkeletonCards({ count = 6 }) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: 16 }}>
      {Array.from({ length: count }).map((_, i) => (
        <SkeletonCard key={i} lines={3} />
      ))}
    </div>
  );
}
