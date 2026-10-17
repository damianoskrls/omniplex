'use client'

import { useState } from 'react'
import { motion } from 'framer-motion'
import { Check } from 'lucide-react'
import { PRICING_TIERS } from '@/lib/constants'
import { FadeUp, StaggerContainer, StaggerItem } from '@/components/ui/motion-wrapper'
import { cn } from '@/lib/utils'

export default function Pricing() {
  const [annual, setAnnual] = useState(false)

  return (
    <section id="pricing" className="py-24 md:py-32">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">

        <FadeUp className="text-center mb-12">
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full border border-[#4452D8]/40 bg-[#4452D8]/10 text-sm font-semibold text-[#9A9DFF] mb-4">
            Για γυμναστήρια &amp; studios
          </div>
          <h2 className="text-4xl md:text-5xl font-black text-[#F5F5FA] tracking-tight mb-4">
            Ξεκινήστε σήμερα,<br />
            <span style={{ background: 'linear-gradient(135deg, #4452D8, #C52473)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent', backgroundClip: 'text' }}>
              κλιμακωθείτε αύριο
            </span>
          </h2>
          <p className="text-[#A7ABBE] text-lg max-w-md mx-auto mb-3">
            14 ημέρες δωρεάν δοκιμή. Χωρίς πιστωτική κάρτα. Ακύρωση οποτεδήποτε.
          </p>
          <p className="text-sm text-[#8DE2BB] mb-8">
            ✓ Η εφαρμογή για ασκούμενους είναι δωρεάν — τα πακέτα αφορούν τους χώρους
          </p>

          {/* Monthly / Annual toggle */}
          <div className="inline-flex items-center gap-3 p-1 rounded-xl bg-[#14161F] border border-[#2B2E3D]">
            <button
              onClick={() => setAnnual(false)}
              className={cn('px-4 py-2 rounded-lg text-sm font-medium transition-all duration-200', !annual ? 'bg-[#1E2130] text-[#F5F5FA]' : 'text-[#A7ABBE]')}
            >
              Μηνιαία
            </button>
            <button
              onClick={() => setAnnual(true)}
              className={cn('px-4 py-2 rounded-lg text-sm font-medium transition-all duration-200 flex items-center gap-2', annual ? 'bg-[#1E2130] text-[#F5F5FA]' : 'text-[#A7ABBE]')}
            >
              Ετήσια
              <span className="text-[10px] font-bold text-[#8DE2BB] bg-[#8DE2BB]/10 px-1.5 py-0.5 rounded-full">-20%</span>
            </button>
          </div>
        </FadeUp>

        <StaggerContainer className="grid grid-cols-1 md:grid-cols-3 gap-6 items-stretch" staggerDelay={0.1}>
          {PRICING_TIERS.map((tier) => (
            <StaggerItem key={tier.name}>
              <div
                className={cn(
                  'relative flex flex-col h-full rounded-2xl p-6 border transition-all duration-300',
                  tier.highlighted
                    ? 'border-transparent scale-[1.02] shadow-brand-lg'
                    : 'border-[#2B2E3D] bg-[#14161F] hover:border-[#4452D8]/30'
                )}
                style={tier.highlighted ? { background: 'linear-gradient(#14161F, #14161F) padding-box, linear-gradient(135deg, #4452D8, #7B3EAD, #C52473) border-box' } : {}}
              >
                {tier.badge && (
                  <div className="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 rounded-full text-xs font-bold text-white" style={{ background: 'linear-gradient(135deg, #4452D8, #C52473)' }}>
                    {tier.badge}
                  </div>
                )}

                <div className="mb-6">
                  <h3 className="text-lg font-bold text-[#F5F5FA] mb-1">{tier.name}</h3>
                  <p className="text-sm text-[#A7ABBE] mb-4">{tier.description}</p>

                  {tier.monthlyPrice !== null ? (
                    <div className="flex items-end gap-1">
                      <motion.span
                        key={annual ? 'annual' : 'monthly'}
                        initial={{ opacity: 0, y: 8 }}
                        animate={{ opacity: 1, y: 0 }}
                        className="text-4xl font-black text-[#F5F5FA] tabular-nums"
                      >
                        €{annual ? tier.annualPrice : tier.monthlyPrice}
                      </motion.span>
                      <span className="text-[#A7ABBE] text-sm mb-1.5">/μήνα</span>
                    </div>
                  ) : (
                    <div className="text-4xl font-black text-[#F5F5FA]">Επικοινωνήστε</div>
                  )}

                  {annual && tier.monthlyPrice !== null && (
                    <p className="text-xs text-[#8DE2BB] mt-1">Εξοικονόμηση €{(tier.monthlyPrice - tier.annualPrice!) * 12}/χρόνο</p>
                  )}
                </div>

                <ul className="space-y-3 flex-1 mb-8">
                  {tier.features.map((feature) => (
                    <li key={feature} className="flex items-start gap-2.5 text-sm">
                      <div className="flex-shrink-0 w-4 h-4 rounded-full flex items-center justify-center mt-0.5" style={{ background: tier.highlighted ? 'linear-gradient(135deg, #4452D8, #C52473)' : '#1E2130' }}>
                        <Check size={10} className={tier.highlighted ? 'text-white' : 'text-[#A7ABBE]'} />
                      </div>
                      <span className={tier.highlighted ? 'text-[#F5F5FA]' : 'text-[#A7ABBE]'}>{feature}</span>
                    </li>
                  ))}
                </ul>

                <button
                  className={cn(
                    'w-full py-3 rounded-xl text-sm font-semibold transition-all duration-200 hover:scale-[1.02] active:scale-[0.98]',
                    tier.highlighted
                      ? 'text-white hover:opacity-90'
                      : 'text-[#F5F5FA] border border-[#2B2E3D] hover:border-[#4452D8]/60 hover:bg-[#1E2130]'
                  )}
                  style={tier.highlighted ? { background: 'linear-gradient(135deg, #4452D8, #7B3EAD, #C52473)' } : {}}
                >
                  {tier.cta}
                </button>
              </div>
            </StaggerItem>
          ))}
        </StaggerContainer>

        <FadeUp delay={0.2} className="mt-10 text-center text-sm text-[#6B7280]">
          Όλα τα πακέτα περιλαμβάνουν δωρεάν onboarding · Διαθέσιμο και σε ετήσια τιμολόγηση ·{' '}
          <a href="#contact" className="text-[#9A9DFF] hover:underline">Επικοινωνήστε</a> για custom τιμολόγηση
        </FadeUp>
      </div>
    </section>
  )
}
