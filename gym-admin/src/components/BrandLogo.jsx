import { mediaUrl } from '../utils/media';

// OmniPlex wordmark shown when no gym logo is set
function OmniplexMark({ size = 'sidebar' }) {
  const isLogin = size === 'login';
  const logoSize = isLogin ? 72 : 36;

  return (
    <div style={{
      display: 'flex',
      alignItems: 'center',
      gap: isLogin ? 12 : 8,
      justifyContent: isLogin ? 'center' : 'flex-start',
    }}>
      <img
        src="/omniplex-logo.png"
        alt="OmniPlex"
        style={{ width: logoSize, height: logoSize, objectFit: 'contain', borderRadius: 10 }}
      />
      {isLogin && (
        <div style={{ textAlign: 'left' }}>
          <div style={{
            fontWeight: 800,
            fontSize: 22,
            letterSpacing: '-0.02em',
            lineHeight: 1,
          }}>
            <span style={{ color: '#fff' }}>Omni</span>
            <span style={{ color: '#B8F55E' }}>Plex</span>
          </div>
          <div style={{ color: 'rgba(255,255,255,0.35)', fontSize: 10, letterSpacing: 2, marginTop: 3, textTransform: 'uppercase' }}>
            flow for all
          </div>
        </div>
      )}
      {!isLogin && (
        <span style={{ fontWeight: 800, fontSize: 15, letterSpacing: '-0.01em', color: '#fff' }}>
          Omni<span style={{ color: '#B8F55E' }}>Plex</span>
        </span>
      )}
    </div>
  );
}

export default function BrandLogo({ variant = 'sidebar', logoUrl, gymName, className = '' }) {
  const isLogin  = variant === 'login';
  const isKiosk  = variant === 'kiosk';
  const isSidebar = variant === 'sidebar';

  // No gym context yet (login page) → always OmniPlex
  if (isLogin) {
    return (
      <div className={`brand-logo brand-logo--${variant} ${className}`.trim()}
           style={{ display: 'flex', justifyContent: 'center', marginBottom: 8 }}>
        <OmniplexMark size="login" />
      </div>
    );
  }

  // Gym has its own logo → show it
  if (logoUrl) {
    const src = mediaUrl(logoUrl);
    const bannerClass = isKiosk
      ? 'brand-logo__banner brand-logo__banner--kiosk'
      : 'brand-logo__banner brand-logo__banner--sidebar';

    return (
      <div className={`brand-logo brand-logo--${variant} ${className}`.trim()}>
        <img src={src} alt={gymName || 'Gym logo'} className={bannerClass} />
      </div>
    );
  }

  // No gym logo → OmniPlex wordmark in sidebar
  return (
    <div className={`brand-logo brand-logo--${variant} ${className}`.trim()}
         style={{ padding: '4px 0' }}>
      <OmniplexMark size="sidebar" />
    </div>
  );
}
