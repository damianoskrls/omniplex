'use client'

import { STATS } from '@/lib/constants'
import { CountUp, FadeUp, StaggerContainer, StaggerItem } from '@/components/ui/motion-wrapper'

export default function Stats() {
  return (
    <section id="why" className="py-20 relative border-y border-[#1E2130]">
      {/* Subtle gradient band */}
      <div
        className="absolute inset-0 opacity-5 pointer-events-none"
        style={{ background: 'linear-gradient(90deg, #4452D8, #7B3EAD, #C52473)' }}
      />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <FadeUp className="text-center mb-12">
          <p className="text-sm font-semibold text-[#9A9DFF] uppercase tracking-widest mb-3">Γιατί OmniPlex</p>
          <h2 className="text-4xl md:text-5xl font-black text-[#F5F5FA] tracking-tight mb-4">
            Αριθμοί που μιλούν<br />
            <span style={{ background: 'linear-gradient(135deg, #4452D8, #C52473)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent', backgroundClip: 'text' }}>
              από μόνοι τους
            </span>
          </h2>
          <p className="text-[#A7ABBE] text-lg max-w-md mx-auto">
            Πάνω από 500 γυμναστήρια έχουν ήδη επιλέξει το OmniPlex ως την κεντρική τους πλατφόρμα.
          </p>
        </FadeUp>

        <StaggerContainer className="grid grid-cols-2 md:grid-cols-4 gap-6 md:gap-8">
          {STATS.map((stat) => (
            <StaggerItem key={stat.label}>
              <div className="text-center p-6 rounded-2xl bg-[#14161F] border border-[#2B2E3D] hover:border-[#4452D8]/40 transition-colors duration-300">
                <div className="text-4xl md:text-5xl font-black mb-2 tabular-nums" style={{ background: 'linear-gradient(135deg, #4452D8, #C52473)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent', backgroundClip: 'text' }}>
                  <span>{stat.prefix}</span>
                  <CountUp target={stat.value} duration={2} />
                  <span>{stat.suffix}</span>
                </div>
                <p className="text-sm text-[#A7ABBE] font-medium leading-snug">{stat.label}</p>
              </div>
            </StaggerItem>
          ))}
        </StaggerContainer>

        {/* Three USPs below the counters */}
        <StaggerContainer className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-12" staggerDelay={0.12}>
          {[
            {
              icon: '🤖',
              title: 'AI agent κρατήσεων',
              desc: 'Κανένας Ελληνικός ανταγωνιστής δεν διαθέτει AI assistant. Το OmniPlex κλείνει θέσεις για τους πελάτες σας αυτόματα.',
            },
            {
              icon: '📱',
              title: 'iOS & Android από την 1η μέρα',
              desc: 'Native apps για κάθε ρόλο — ιδιοκτήτης, μέλος, προπονητής, διατροφολόγος. Χωρίς ετήσιο συμβόλαιο.',
            },
            {
              icon: '🌐',
              title: 'Social · Marketplace · Ecosystem',
              desc: 'Κοινωνικό δίκτυο και marketplace μέσα στην εφαρμογή — μοναδικό χαρακτηριστικό στην Ελληνική αγορά fitness.',
            },
          ].map((usp) => (
            <StaggerItem key={usp.title}>
              <div className="p-6 rounded-2xl bg-[#14161F] border border-[#2B2E3D] hover:border-[#2B2E3D]/80 transition-colors duration-300">
                <div className="text-2xl mb-3">{usp.icon}</div>
                <h3 className="text-base font-bold text-[#F5F5FA] mb-2">{usp.title}</h3>
                <p className="text-sm text-[#A7ABBE] leading-relaxed">{usp.desc}</p>
              </div>
            </StaggerItem>
          ))}
        </StaggerContainer>
      </div>
    </section>
  )
}
