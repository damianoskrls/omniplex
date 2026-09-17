export default function BrandLogo({ variant = 'sidebar' }) {
  return (
    <div className={`brand-logo brand-logo--${variant}`}>
      <div className="brand-logo__row">
        <img src="/omniplex-logo.png" alt="OmniPlex" className="brand-logo__icon" />
        <span className="brand-logo__wordmark">OmniPlex</span>
      </div>
    </div>
  );
}
