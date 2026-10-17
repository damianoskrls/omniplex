'use client'

import { TESTIMONIALS } from '@/lib/constants'
import { FadeUp, StaggerContainer, StaggerItem } from '@/components/ui/motion-wrapper'

function Stars() {
  return (
    <div className="flex gap-0.5 mb-4">
      {[...Array(5)].map((_, i) => (
        <svg key={i} width="14" height="14" viewBox="0 0 24 24" fill="#C52473" xmlns="http://www.w3.org/2000/svg">
          <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
        </svg>
      ))}
    </div>
  )
}

export default function Testimonials() {
  return (
    <section className="py-24 md:py-32">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">

        <FadeUp className="text-center mb-14">
          <p className="text-sm font-semibold text-[#9A9DFF] uppercase tracking-widest mb-3">Κριτικές πελατών</p>
          <h2 className="text-4xl md:text-5xl font-black text-[#F5F5FA] tracking-tight mb-4">
            Τι λένε όσοι<br />
            <span style={{ background: 'linear-gradient(135deg, #4452D8, #C52473)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent', backgroundClip: 'text' }}>
              το χρησιμοποιούν ήδη
            </span>
          </h2>
          <p className="text-[#A7ABBE] text-lg max-w-md mx-auto">
            Πάνω από 500 επαγγελματίες του fitness εμπιστεύονται το OmniPlex κάθε μέρα.
          </p>
        </FadeUp>

        <StaggerContainer className="grid grid-cols-1 md:grid-cols-3 gap-6" staggerDelay={0.12}>
          {TESTIMONIALS.map((t) => (
            <StaggerItem key={t.author}>
              <div className="relative p-6 rounded-2xl bg-[#14161F] border border-[#2B2E3D] h-full flex flex-col hover:border-[#4452D8]/30 transition-colors duration-300 group">
                {/* Gradient border on hover */}
                <div className="absolute inset-0 rounded-2xl opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none" style={{ background: 'linear-gradient(135deg, #4452D8, #7B3EAD, #C52473)', padding: '1px', WebkitMask: 'linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0)', WebkitMaskComposite: 'xor' }} />

                <Stars />

                <blockquote className="text-[#F5F5FA] text-sm leading-relaxed flex-1 mb-6">
                  &ldquo;{t.quote}&rdquo;
                </blockquote>

                <div className="flex items-center gap-3 pt-4 border-t border-[#1E2130]">
                  <div
                    className="w-10 h-10 rounded-full flex items-center justify-center text-xs font-bold text-white flex-shrink-0"
                    style={{ background: 'linear-gradient(135deg, #4452D8, #C52473)' }}
                  >
                    {t.initials}
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-[#F5F5FA]">{t.author}</p>
                    <p className="text-xs text-[#A7ABBE]">{t.role} · {t.location}</p>
                  </div>
                </div>
              </div>
            </StaggerItem>
          ))}
        </StaggerContainer>

        {/* Social proof bar */}
        <FadeUp delay={0.2} className="mt-12 flex flex-wrap justify-center items-center gap-8 text-sm text-[#6B7280]">
          <div className="flex items-center gap-2">
            <div className="flex -space-x-2">
              {['ΜΠ', 'ΣΚ', 'ΝΔ', 'ΕΜ'].map((initials) => (
                <div key={initials} className="w-7 h-7 rounded-full border-2 border-[#090A0F] flex items-center justify-center text-[9px] font-bold text-white" style={{ background: 'linear-gradient(135deg, #4452D8, #C52473)' }}>
                  {initials}
                </div>
              ))}
            </div>
            <span>500+ ενεργά γυμναστήρια</span>
          </div>
          <div className="flex items-center gap-2">
            <span className="text-[#C52473] font-bold">★ 4.9/5</span>
            <span>μέση βαθμολογία</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-1.5 h-1.5 rounded-full bg-[#8DE2BB]" />
            <span>Χωρίς καταγγελίες υποστήριξης &gt;3 ωρών</span>
          </div>
        </FadeUp>
      </div>
    </section>
  )
}
