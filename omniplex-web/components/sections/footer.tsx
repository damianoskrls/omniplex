import Image from 'next/image'
import Link from 'next/link'

const FOOTER_LINKS = [
  {
    heading: 'Πλατφόρμα',
    links: [
      { label: 'Δυνατότητες', href: '#features' },
      { label: 'Πακέτα', href: '#pricing' },
      { label: 'Γιατί OmniPlex', href: '#why' },
      { label: 'Demo', href: '#contact' },
    ],
  },
  {
    heading: 'Ρόλοι',
    links: [
      { label: 'Ιδιοκτήτες γυμναστηρίων', href: '#features' },
      { label: 'Μέλη', href: '#features' },
      { label: 'Προπονητές', href: '#features' },
      { label: 'Διατροφολόγοι', href: '#features' },
    ],
  },
  {
    heading: 'Εταιρεία',
    links: [
      { label: 'Σχετικά με εμάς', href: '#' },
      { label: 'Blog', href: '#' },
      { label: 'Καριέρα', href: '#' },
      { label: 'Επικοινωνία', href: '#contact' },
    ],
  },
  {
    heading: 'Νομικά',
    links: [
      { label: 'Όροι χρήσης', href: '#' },
      { label: 'Πολιτική απορρήτου', href: '#' },
      { label: 'Cookies', href: '#' },
      { label: 'GDPR', href: '#' },
    ],
  },
]

export default function Footer() {
  return (
    <footer className="border-t border-[#1E2130] bg-[#090A0F]">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">

        {/* Main footer content */}
        <div className="py-14 grid grid-cols-2 md:grid-cols-6 gap-8 lg:gap-12">

          {/* Brand column */}
          <div className="col-span-2">
            <Link href="/" className="flex items-center gap-2.5 mb-4">
              <div className="w-8 h-8 relative flex-shrink-0">
                <Image src="/omniplex-icon.svg" alt="OmniPlex" fill className="object-contain" />
              </div>
              <span
                className="text-xl font-bold tracking-tight"
                style={{
                  background: 'linear-gradient(90deg, #4452D8, #C52473)',
                  WebkitBackgroundClip: 'text',
                  WebkitTextFillColor: 'transparent',
                  backgroundClip: 'text',
                }}
              >
                omniplex
              </span>
            </Link>
            <p className="text-sm text-[#A7ABBE] leading-relaxed max-w-[220px] mb-6">
              Η πλατφόρμα fitness που ενώνει γυμναστήρια, μέλη, προπονητές και διατροφολόγους.
            </p>
            <div className="flex gap-3">
              {/* Social icons */}
              {[
                { label: 'Instagram', path: 'M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z' },
                { label: 'LinkedIn', path: 'M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433a2.062 2.062 0 01-2.063-2.065 2.064 2.064 0 112.063 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z' },
              ].map((social) => (
                <a
                  key={social.label}
                  href="#"
                  aria-label={social.label}
                  className="w-9 h-9 rounded-xl border border-[#2B2E3D] bg-[#14161F] flex items-center justify-center text-[#A7ABBE] hover:text-[#F5F5FA] hover:border-[#4452D8]/50 transition-all duration-200"
                >
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                    <path d={social.path} />
                  </svg>
                </a>
              ))}
            </div>
          </div>

          {/* Link columns */}
          {FOOTER_LINKS.map((col) => (
            <div key={col.heading}>
              <h4 className="text-xs font-semibold text-[#F5F5FA] uppercase tracking-widest mb-4">
                {col.heading}
              </h4>
              <ul className="space-y-2.5">
                {col.links.map((link) => (
                  <li key={link.label}>
                    <Link
                      href={link.href}
                      className="text-sm text-[#A7ABBE] hover:text-[#F5F5FA] transition-colors duration-200"
                    >
                      {link.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        {/* Bottom bar */}
        <div className="py-6 border-t border-[#1E2130] flex flex-col sm:flex-row justify-between items-center gap-3 text-xs text-[#6B7280]">
          <p>© {new Date().getFullYear()} OmniPlex. Με επιφύλαξη παντός δικαιώματος.</p>
          <p className="flex items-center gap-1">
            Φτιαγμένο με{' '}
            <span
              style={{
                background: 'linear-gradient(90deg, #4452D8, #C52473)',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
                backgroundClip: 'text',
                fontWeight: 700,
              }}
            >
              ❤
            </span>
            {' '}στην Ελλάδα
          </p>
        </div>
      </div>
    </footer>
  )
}
