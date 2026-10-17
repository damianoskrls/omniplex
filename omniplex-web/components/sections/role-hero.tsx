'use client'

import { useState, useEffect, useRef } from 'react'
import { motion } from 'framer-motion'
import { ROLES } from '@/lib/constants'

const EASE = [0.16, 1, 0.3, 1]
const DISPLAY_ROLES = ROLES.filter((r) => !r.isRequest)

export default function RoleHero() {
  const [activeId, setActiveId] = useState<string | null>(null)
  const [sticky, setSticky] = useState(false)
  const sentinelRef = useRef<HTMLDivElement>(null)

  // Detect when the hero scrolls past so the pill bar sticks
  useEffect(() => {
    const sentinel = sentinelRef.current
    if (!sentinel) return
    const obs = new IntersectionObserver(
      ([entry]) => setSticky(!entry.isIntersecting),
      { threshold: 0 }
    )
    obs.observe(sentinel)
    return () => obs.disconnect()
  }, [])

  // Track which role section is visible
  useEffect(() => {
    const observers: IntersectionObserver[] = []
    DISPLAY_ROLES.forEach((role) => {
      const el = document.getElementById(role.id)
      if (!el) return
      const obs = new IntersectionObserver(
        ([entry]) => { if (entry.isIntersecting) setActiveId(role.id) },
        { threshold: 0.35 }
      )
      obs.observe(el)
      observers.push(obs)
    })
    return () => observers.forEach((o) => o.disconnect())
  }, [])

  const scrollTo = (id: string) => {
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }

  return (
    <>
      {/* Page hero */}
      <section className="relative pt-32 pb-16 overflow-hidden">
        <div className="absolute inset-0 dot-bg opacity-20 pointer-events-none" />
        <div
          className="absolute top-0 left-1/2 -translate-x-1/2 w-[900px] h-[500px] opacity-[0.06] pointer-events-none"
          style={{ background: 'radial-gradient(ellipse at top, #4452D8 0%, transparent 65%)' }}
        />

        <div className="relative max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, ease: EASE }}
            className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full border border-[#2B2E3D] bg-[#14161F] text-xs font-medium text-[#9A9DFF] mb-6"
          >
            ✦ Ένα app, άπειροι χώροι.
          </motion.div>

          <motion.h1
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, ease: EASE, delay: 0.1 }}
            className="text-5xl sm:text-6xl lg:text-7xl font-black tracking-tight leading-[1.05] text-[#F5F5FA] mb-6"
          >
            Οι ρόλοι του{' '}
            <span
              style={{
                background: 'linear-gradient(135deg, #4452D8 0%, #7B3EAD 55%, #C52473 100%)',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
                backgroundClip: 'text',
              }}
            >
              OmniPlex
            </span>
          </motion.h1>

          <motion.p
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, ease: EASE, delay: 0.22 }}
            className="text-xl text-[#A7ABBE] leading-relaxed max-w-2xl mx-auto mb-10"
          >
            Κατεβάζεις ένα app και ανοίγει ο κόσμος του fitness. Μέλος σε πολλά γυμναστήρια,
            προπονητής που βλέπει όλες τις κρατήσεις του, ιδιοκτήτης που αναπτύσσει τον χώρο του.
          </motion.p>

          {/* Role overview chips */}
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, ease: EASE, delay: 0.36 }}
            className="flex flex-wrap justify-center gap-3"
          >
            {DISPLAY_ROLES.map((role) => (
              <button
                key={role.id}
                onClick={() => scrollTo(role.id)}
                className="px-4 py-2 rounded-xl text-sm font-medium border transition-all duration-200 hover:scale-[1.03]"
                style={{ background: `${role.color}12`, borderColor: `${role.color}40`, color: role.color }}
              >
                {role.label}
              </button>
            ))}
          </motion.div>
        </div>
      </section>

      {/* Sentinel — triggers sticky state when scrolled past */}
      <div ref={sentinelRef} className="h-px" />

      {/* Sticky role pill nav */}
      <div
        className={`z-40 transition-all duration-300 ${
          sticky
            ? 'sticky top-16 bg-[rgba(9,10,15,0.92)] backdrop-blur-xl border-b border-[#1E2130]'
            : 'invisible pointer-events-none h-0 overflow-hidden'
        }`}
      >
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-center gap-2 py-3 overflow-x-auto">
            {DISPLAY_ROLES.map((role) => (
              <button
                key={role.id}
                onClick={() => scrollTo(role.id)}
                className="flex-shrink-0 px-4 py-2 rounded-xl text-sm font-medium border transition-all duration-200"
                style={
                  activeId === role.id
                    ? { background: `${role.color}18`, borderColor: `${role.color}60`, color: role.color }
                    : { background: 'transparent', borderColor: '#2B2E3D', color: '#6B7280' }
                }
              >
                {role.label}
              </button>
            ))}
          </div>
        </div>
      </div>
    </>
  )
}
