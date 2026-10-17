'use client'

import { motion } from 'framer-motion'
import { Check, ArrowRight } from 'lucide-react'
import Link from 'next/link'
import RoleMockup from '@/components/ui/role-mockup'

type Role = {
  id: string
  label: string
  headline: string
  description: string
  bullets: string[]
  color: string
  isRequest?: boolean
}

const EASE = [0.16, 1, 0.3, 1]
const VALID_ROLE_IDS = ['owner', 'member', 'trainer', 'nutritionist'] as const
type RoleId = typeof VALID_ROLE_IDS[number]

export default function RoleSection({ role, index }: { role: Role; index: number }) {
  const isEven = index % 2 === 0
  const roleId = (VALID_ROLE_IDS.includes(role.id as RoleId) ? role.id : 'owner') as RoleId

  const TextContent = (
    <motion.div
      initial={{ opacity: 0, x: isEven ? -40 : 40 }}
      whileInView={{ opacity: 1, x: 0 }}
      viewport={{ once: true, margin: '-80px' }}
      transition={{ duration: 0.8, ease: EASE }}
      className="flex flex-col justify-center"
    >
      {/* Role badge */}
      <div className="inline-flex items-center gap-2.5 mb-6 w-fit">
        <div
          className="w-8 h-8 rounded-xl flex items-center justify-center text-xs font-bold"
          style={{ background: `${role.color}18`, border: `1px solid ${role.color}40`, color: role.color }}
        >
          {String(index + 1).padStart(2, '0')}
        </div>
        <span className="text-sm font-semibold tracking-wide" style={{ color: role.color }}>
          {role.label}
        </span>
      </div>

      {/* Headline */}
      <h2 className="text-4xl lg:text-5xl xl:text-6xl font-black text-[#F5F5FA] leading-[1.05] tracking-tight mb-5">
        {role.headline}
      </h2>

      {/* Description */}
      <p className="text-lg text-[#A7ABBE] leading-relaxed mb-8 max-w-md">
        {role.description}
      </p>

      {/* Bullets */}
      <ul className="space-y-3.5 mb-10">
        {role.bullets.map((bullet) => (
          <li key={bullet} className="flex items-start gap-3">
            <div
              className="mt-0.5 w-5 h-5 rounded-full flex items-center justify-center flex-shrink-0"
              style={{ background: `${role.color}18`, border: `1px solid ${role.color}40` }}
            >
              <Check size={11} style={{ color: role.color }} strokeWidth={2.5} />
            </div>
            <span className="text-[#A7ABBE] text-sm leading-relaxed">{bullet}</span>
          </li>
        ))}
      </ul>

      {/* CTAs */}
      <div className="flex flex-wrap gap-3">
        <button
          type="button"
          onClick={() => window.dispatchEvent(new CustomEvent('open-demo-modal'))}
          className="group inline-flex items-center gap-2 px-6 py-3.5 rounded-xl text-sm font-semibold text-white transition-all duration-200 hover:opacity-90 hover:scale-[1.02] active:scale-[0.98]"
          style={{ background: `linear-gradient(135deg, ${role.color}, #C52473)` }}
        >
          Ζητήστε demo
          <ArrowRight size={15} className="group-hover:translate-x-0.5 transition-transform" />
        </button>
        <Link
          href="/#pricing"
          className="inline-flex items-center gap-2 px-6 py-3.5 rounded-xl text-sm font-semibold text-[#F5F5FA] border border-[#2B2E3D] hover:border-[#4452D8]/60 hover:bg-[#14161F] transition-all duration-200"
        >
          Δείτε τιμές →
        </Link>
      </div>
    </motion.div>
  )

  const MockupContent = (
    <motion.div
      initial={{ opacity: 0, scale: 0.9 }}
      whileInView={{ opacity: 1, scale: 1 }}
      viewport={{ once: true, margin: '-80px' }}
      transition={{ duration: 0.9, ease: EASE, delay: 0.15 }}
      className="flex justify-center"
    >
      <RoleMockup roleId={roleId} color={role.color} />
    </motion.div>
  )

  return (
    <section id={role.id} className="relative py-24 lg:py-32 overflow-hidden scroll-mt-16">
      {/* Ambient glow */}
      <div
        className="absolute pointer-events-none"
        style={{
          width: 700,
          height: 700,
          borderRadius: '50%',
          background: role.color,
          opacity: 0.035,
          filter: 'blur(130px)',
          top: '50%',
          [isEven ? 'left' : 'right']: '-15%',
          transform: 'translateY(-50%)',
        }}
      />

      <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 lg:gap-20 items-center">
          {isEven ? (
            <>
              {TextContent}
              {MockupContent}
            </>
          ) : (
            <>
              {MockupContent}
              {TextContent}
            </>
          )}
        </div>
      </div>

      {/* Bottom divider */}
      <div
        className="absolute bottom-0 left-1/2 -translate-x-1/2 w-px h-20 pointer-events-none"
        style={{ background: `linear-gradient(to bottom, ${role.color}30, transparent)` }}
      />
    </section>
  )
}
