import { mediaUrl } from '../utils/media';

const LOGO_FALLBACK = '/handstand-logo.png';

export default function BrandLogo({ variant = 'sidebar', logoUrl, className = '' }) {
  const src = logoUrl ? mediaUrl(logoUrl) : LOGO_FALLBACK;
  const bannerClass = variant === 'login'
    ? 'brand-logo__banner brand-logo__banner--login'
    : variant === 'kiosk'
      ? 'brand-logo__banner brand-logo__banner--kiosk'
      : 'brand-logo__banner brand-logo__banner--sidebar';

  return (
    <div className={`brand-logo brand-logo--${variant} ${className}`.trim()}>
      <img
        src={src}
        alt="Handstand Fitness hall"
        className={bannerClass}
      />
    </div>
  );
}
