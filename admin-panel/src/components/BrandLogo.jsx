const LOGO_SRC = '/handstand-logo.png';

export default function BrandLogo({ variant = 'sidebar' }) {
  const bannerClass = variant === 'login'
    ? 'brand-logo__banner brand-logo__banner--login'
    : 'brand-logo__banner brand-logo__banner--sidebar';

  return (
    <div className={`brand-logo brand-logo--${variant}`}>
      <img src={LOGO_SRC} alt="Handstand Fitness hall" className={bannerClass} />
    </div>
  );
}
