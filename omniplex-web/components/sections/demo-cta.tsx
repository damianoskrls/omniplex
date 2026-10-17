'use client'

import { useRef } from 'react'
import { ArrowRight } from 'lucide-react'
import { motion, useScroll, useTransform } from 'framer-motion'
import { FadeUp } from '@/components/ui/motion-wrapper'

export default function DemoCta() {
  const sectionRef = useRef<HTMLElement>(null)

  const { scrollYProgress } = useScroll({
    target: sectionRef,
    offset: ['start end', 'end start'],
  })

  // Video moves at ~30% the speed of the page — classic parallax
  const videoY = useTransform(scrollYProgress, [0, 1], ['-15%', '15%'])

  return (
    <section id="contact" ref={sectionRef} className="py-24 md:py-32 relative overflow-hidden">

      {/* Parallax video */}
      <motion.div
        style={{ y: videoY }}
        className="absolute inset-0 pointer-events-none"
      >
        <video
          autoPlay
          muted
          loop
          playsInline
          className="absolute inset-0 w-full h-full object-cover"
          style={{ transform: 'scale(1.35)' }}
        >
          <source src="/videos/hero-bg.mp4" type="video/mp4" />
        </video>
      </motion.div>

      {/* Overlays */}
      <div className="absolute inset-0 bg-[#090A0F]/72 pointer-events-none" />
      <div
        className="absolute inset-0 opacity-[0.10] pointer-events-none"
        style={{ background: 'linear-gradient(135deg, #4452D8 0%, #7B3EAD 50%, #C52473 100%)' }}
      />
      <div className="absolute inset-0 dot-bg opacity-15 pointer-events-none" />

      {/* Ambient glows */}
      <div className="absolute -left-32 top-1/2 -translate-y-1/2 w-[400px] h-[400px] rounded-full opacity-12 blur-3xl pointer-events-none" style={{ background: '#4452D8' }} />
      <div className="absolute -right-32 top-1/2 -translate-y-1/2 w-[400px] h-[400px] rounded-full opacity-12 blur-3xl pointer-events-none" style={{ background: '#C52473' }} />

      <div className="relative max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <FadeUp>
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full border border-[#2B2E3D] bg-[#14161F]/80 text-xs font-medium text-[#9A9DFF] mb-6 backdrop-blur-sm">
            🚀 Ξεκινήστε σε λιγότερο από 10 λεπτά
          </div>

          <h2 className="text-4xl md:text-5xl lg:text-6xl font-black text-[#F5F5FA] tracking-tight mb-4 leading-tight">
            Δείτε το OmniPlex{' '}
            <span style={{ background: 'linear-gradient(135deg, #4452D8, #C52473)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent', backgroundClip: 'text' }}>
              ζωντανά
            </span>
          </h2>

          <p className="text-lg text-[#A7ABBE] mb-10 max-w-xl mx-auto leading-relaxed">
            Μια προσωπική επίδειξη 20 λεπτών — χωρίς δεσμεύσεις, στη γλώσσα σας, με τα δικά σας δεδομένα.
          </p>

          <div className="mb-6">
            <button
              type="button"
              onClick={() => window.dispatchEvent(new CustomEvent('open-demo-modal'))}
              className="group inline-flex items-center justify-center gap-2 px-8 py-4 rounded-xl text-base font-semibold text-white transition-all duration-200 hover:opacity-90 hover:scale-[1.02] active:scale-[0.98]"
              style={{ background: 'linear-gradient(135deg, #4452D8, #7B3EAD, #C52473)' }}
            >
              Ζητήστε demo τώρα
              <ArrowRight size={18} className="group-hover:translate-x-0.5 transition-transform" />
            </button>
          </div>

          <p className="text-xs text-[#6B7280]">
            Κανένα spam. Μόνο μία κλήση — όποτε σας βολεύει.
          </p>
        </FadeUp>
      </div>
    </section>
  )
}
