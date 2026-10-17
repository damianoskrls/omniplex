'use client'

import { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Building2, User, Dumbbell, Apple, Check, Plus, ArrowRight } from 'lucide-react'
import { ROLES } from '@/lib/constants'
import { FadeUp } from '@/components/ui/motion-wrapper'
import { cn } from '@/lib/utils'

const ICONS = { Building2, User, Dumbbell, Apple, Plus }

const UPCOMING_ROLES = [
  'Φυσιοθεραπευτής',
  'Χορογράφος',
  'Pilates Instructor',
  'Yoga Teacher',
  'Massage Therapist',
  'Dietitian',
]

const ROLE_VISUALS = [
  // Owner — analytics card
  <div key="owner" className="rounded-2xl bg-[#14161F] border border-[#2B2E3D] p-5 w-full max-w-[340px]">
    <p className="text-xs text-[#A7ABBE] uppercase tracking-wider mb-4">Έσοδα αυτής της εβδομάδας</p>
    <p className="text-3xl font-black text-[#F5F5FA] mb-1">€4,820</p>
    <div className="flex items-center gap-2 mb-5">
      <span className="text-xs font-medium text-[#8DE2BB] bg-[#8DE2BB]/10 px-2 py-0.5 rounded-full">+18% vs προηγ.</span>
    </div>
    <div className="space-y-2">
      {[['CrossFit', 62], ['Yoga', 41], ['Pilates', 29]].map(([name, pct]) => (
        <div key={name} className="flex items-center gap-3">
          <span className="text-xs text-[#A7ABBE] w-16">{name}</span>
          <div className="flex-1 h-1.5 rounded-full bg-[#1E2130] overflow-hidden">
            <motion.div
              initial={{ width: 0 }}
              animate={{ width: `${pct}%` }}
              transition={{ duration: 1, ease: [0.16, 1, 0.3, 1], delay: 0.3 }}
              className="h-full rounded-full"
              style={{ background: 'linear-gradient(90deg, #4452D8, #C52473)' }}
            />
          </div>
          <span className="text-xs text-[#A7ABBE] w-8 text-right">{pct}%</span>
        </div>
      ))}
    </div>
  </div>,

  // Member — schedule card
  <div key="member" className="rounded-2xl bg-[#14161F] border border-[#2B2E3D] p-5 w-full max-w-[340px]">
    <p className="text-xs text-[#A7ABBE] uppercase tracking-wider mb-4">Πρόγραμμά σου · Παρασκευή</p>
    {[
      { time: '09:00', name: 'Yoga Flow', trainer: 'Μαρία Κ.', status: 'confirmed' },
      { time: '17:30', name: 'HIIT Circuit', trainer: 'Κώστας Π.', status: 'open' },
    ].map((cls) => (
      <div key={cls.time} className={cn('rounded-xl p-3 mb-2 border', cls.status === 'confirmed' ? 'border-[#4452D8]/40 bg-[#4452D8]/10' : 'border-[#2B2E3D] bg-[#1E2130]')}>
        <div className="flex justify-between items-start">
          <div>
            <p className="text-sm font-semibold text-[#F5F5FA]">{cls.name}</p>
            <p className="text-xs text-[#A7ABBE]">{cls.time} · {cls.trainer}</p>
          </div>
          {cls.status === 'confirmed'
            ? <span className="text-[10px] text-[#8DE2BB] font-medium">✓ Επιβεβαιωμένο</span>
            : <button className="text-[10px] font-semibold text-white px-2 py-1 rounded-lg" style={{ background: 'linear-gradient(135deg, #4452D8, #C52473)' }}>Κράτηση</button>
          }
        </div>
      </div>
    ))}
    <div className="mt-3 rounded-xl p-3 bg-[#7B3EAD]/10 border border-[#7B3EAD]/30 flex items-start gap-2">
      <span className="text-[#9A9DFF] text-xs">🤖</span>
      <p className="text-xs text-[#9A9DFF]">AI agent: «Να κλείσω θέση για HIIT αύριο στις 17:30;»</p>
    </div>
  </div>,

  // Trainer — client list
  <div key="trainer" className="rounded-2xl bg-[#14161F] border border-[#2B2E3D] p-5 w-full max-w-[340px]">
    <p className="text-xs text-[#A7ABBE] uppercase tracking-wider mb-4">Σήμερα · 4 συνεδρίες</p>
    {[
      { name: 'Αλέξης Μ.', time: '10:00', type: 'Strength' },
      { name: 'Ελένη Π.', time: '12:00', type: 'Cardio' },
      { name: 'Γιώργης Κ.', time: '17:00', type: 'HIIT' },
    ].map((c) => (
      <div key={c.name} className="flex items-center gap-3 py-2.5 border-b border-[#1E2130] last:border-0">
        <div className="w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold text-white flex-shrink-0" style={{ background: 'linear-gradient(135deg, #4452D8, #C52473)' }}>
          {c.name.charAt(0)}
        </div>
        <div className="flex-1 min-w-0">
          <p className="text-sm font-medium text-[#F5F5FA] truncate">{c.name}</p>
          <p className="text-xs text-[#A7ABBE]">{c.time} · {c.type}</p>
        </div>
        <div className="w-2 h-2 rounded-full bg-[#8DE2BB]" />
      </div>
    ))}
    <div className="mt-3 rounded-xl p-2.5 bg-[#A4308D]/10 border border-[#A4308D]/30">
      <p className="text-[10px] text-[#C52473] font-medium">Marketplace · 3 νέα αιτήματα</p>
    </div>
  </div>,

  // Nutritionist — nutrition plan
  <div key="nutritionist" className="rounded-2xl bg-[#14161F] border border-[#2B2E3D] p-5 w-full max-w-[340px]">
    <p className="text-xs text-[#A7ABBE] uppercase tracking-wider mb-4">Διατροφολόγιο · Νίκος Δ.</p>
    <div className="grid grid-cols-3 gap-2 mb-4">
      {[['Πρωτεΐνη', '165g', '#8DE2BB'], ['Υδατ/κες', '280g', '#9A9DFF'], ['Λιπαρά', '68g', '#C52473']].map(([label, val, color]) => (
        <div key={label as string} className="rounded-xl bg-[#1E2130] p-2.5 text-center">
          <p className="text-base font-bold" style={{ color: color as string }}>{val as string}</p>
          <p className="text-[9px] text-[#A7ABBE] mt-0.5">{label as string}</p>
        </div>
      ))}
    </div>
    <div className="rounded-xl bg-[#1E2130] p-3 mb-2">
      <p className="text-xs font-semibold text-[#F5F5FA] mb-1">Επόμενο follow-up</p>
      <p className="text-xs text-[#A7ABBE]">Δευτέρα, 13 Οκτ · 11:00</p>
    </div>
    <div className="rounded-xl p-2.5 bg-[#C52473]/10 border border-[#C52473]/30">
      <p className="text-[10px] text-[#C52473] font-medium">Marketplace · 2 νέες κρατήσεις</p>
    </div>
  </div>,

  // Request role — special visual
  <div key="request" className="rounded-2xl border border-dashed border-[#2B2E3D] bg-[#14161F]/50 p-8 w-full max-w-[340px] flex flex-col items-center justify-center text-center gap-5">
    <div
      className="w-20 h-20 rounded-full flex items-center justify-center"
      style={{ background: 'linear-gradient(135deg, #4452D820, #C5247320)', border: '1px solid #4452D840' }}
    >
      <Plus size={32} className="text-[#9A9DFF]" />
    </div>
    <div>
      <p className="text-sm font-bold text-[#F5F5FA] mb-1">Νέος ρόλος</p>
      <p className="text-xs text-[#A7ABBE] leading-relaxed">Πείτε μας τον ρόλο σας και τις ανάγκες σας.</p>
    </div>
    <div className="flex flex-wrap justify-center gap-1.5">
      {UPCOMING_ROLES.slice(0, 4).map((r) => (
        <span key={r} className="text-[10px] px-2.5 py-1 rounded-full border border-[#2B2E3D] bg-[#14161F] text-[#6B7280]">
          {r}
        </span>
      ))}
    </div>
  </div>,
]

export default function Features() {
  const [activeIndex, setActiveIndex] = useState(0)

  const activeRole = ROLES[activeIndex]
  const isRequest = Boolean((activeRole as { isRequest?: boolean }).isRequest)
  const Icon = ICONS[activeRole.icon as keyof typeof ICONS]

  return (
    <section id="features" className="py-24 md:py-32 relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">

        {/* Section header */}
        <FadeUp className="text-center mb-14">
          <p className="text-sm font-semibold text-[#9A9DFF] uppercase tracking-widest mb-3">Δυνατότητες</p>
          <h2 className="text-4xl md:text-5xl font-black text-[#F5F5FA] tracking-tight mb-4">
            Για κάθε ρόλο,<br />
            <span style={{ background: 'linear-gradient(135deg, #4452D8, #C52473)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent', backgroundClip: 'text' }}>
              μια τέλεια εμπειρία
            </span>
          </h2>
          <p className="text-[#A7ABBE] text-lg max-w-xl mx-auto">
            Ένα app που αναγνωρίζει ποιος είσαι — ασκούμενος, προπονητής ή ιδιοκτήτης — και σου δίνει ακριβώς αυτό που χρειάζεσαι.
          </p>
        </FadeUp>

        {/* Role tabs */}
        <FadeUp delay={0.1} className="flex justify-center mb-12">
          <div className="inline-flex p-1 rounded-2xl bg-[#14161F] border border-[#2B2E3D] gap-1 flex-wrap justify-center">
            {ROLES.map((role, i) => {
              const RoleIcon = ICONS[role.icon as keyof typeof ICONS]
              const isReqTab = Boolean((role as { isRequest?: boolean }).isRequest)
              const isActive = activeIndex === i
              return (
                <button
                  key={role.id}
                  onClick={() => setActiveIndex(i)}
                  className={cn(
                    'relative flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-medium transition-all duration-200',
                    isActive ? 'text-white' : 'text-[#A7ABBE] hover:text-[#F5F5FA]',
                    isReqTab && !isActive && 'border border-dashed border-[#2B2E3D]',
                  )}
                >
                  {isActive && !isReqTab && (
                    <motion.div
                      layoutId="tab-bg"
                      className="absolute inset-0 rounded-xl"
                      style={{ background: 'linear-gradient(135deg, #4452D8, #7B3EAD, #C52473)' }}
                      transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
                    />
                  )}
                  {isActive && isReqTab && (
                    <motion.div
                      className="absolute inset-0 rounded-xl"
                      style={{ background: 'linear-gradient(135deg, #4452D820, #C5247320)', border: '1px solid #4452D840' }}
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      transition={{ duration: 0.25 }}
                    />
                  )}
                  <span className="relative z-10 flex items-center gap-2">
                    <RoleIcon size={15} />
                    <span className="hidden sm:inline">{role.label}</span>
                  </span>
                </button>
              )
            })}
          </div>
        </FadeUp>

        {/* Role content */}
        <AnimatePresence mode="wait">
          <motion.div
            key={activeIndex}
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            transition={{ duration: 0.35, ease: [0.16, 1, 0.3, 1] }}
            className="grid grid-cols-1 lg:grid-cols-2 gap-10 lg:gap-16 items-center"
          >
            {/* Left: text */}
            <div>
              {isRequest ? (
                /* Request role — special layout */
                <>
                  <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full border border-dashed border-[#4452D8]/40 bg-[#4452D8]/10 text-xs font-medium text-[#9A9DFF] mb-6">
                    ✦ Έρχεται σύντομα
                  </div>
                  <h3 className="text-2xl md:text-3xl font-black text-[#F5F5FA] tracking-tight mb-3 leading-tight">
                    {activeRole.headline}
                  </h3>
                  <p className="text-[#A7ABBE] mb-6">{activeRole.description}</p>
                  <div className="flex flex-wrap gap-2 mb-8">
                    {UPCOMING_ROLES.map((r) => (
                      <span key={r} className="px-3 py-1.5 rounded-full bg-[#14161F] border border-[#2B2E3D] text-xs text-[#A7ABBE] hover:border-[#4452D8]/40 hover:text-[#F5F5FA] transition-colors cursor-default">
                        {r}
                      </span>
                    ))}
                    <span className="px-3 py-1.5 rounded-full bg-[#14161F] border border-dashed border-[#2B2E3D] text-xs text-[#6B7280]">
                      + ο δικός σας;
                    </span>
                  </div>
                  <a
                    href="#contact"
                    className="group inline-flex items-center gap-2 px-5 py-3 rounded-xl text-sm font-semibold text-white transition-all duration-200 hover:opacity-90 hover:scale-[1.02] active:scale-[0.98]"
                    style={{ background: 'linear-gradient(135deg, #4452D8, #7B3EAD, #C52473)' }}
                  >
                    Αιτήθητε τον ρόλο σας
                    <ArrowRight size={15} className="group-hover:translate-x-0.5 transition-transform" />
                  </a>
                </>
              ) : (
                /* Normal role layout */
                <>
                  <div
                    className="inline-flex items-center justify-center w-12 h-12 rounded-2xl mb-6"
                    style={{ background: `${activeRole.color}20`, border: `1px solid ${activeRole.color}40` }}
                  >
                    <Icon size={22} style={{ color: activeRole.color }} />
                  </div>
                  <h3 className="text-2xl md:text-3xl font-black text-[#F5F5FA] tracking-tight mb-3 leading-tight">
                    {activeRole.headline}
                  </h3>
                  <p className="text-[#A7ABBE] mb-7">{activeRole.description}</p>
                  <ul className="space-y-3">
                    {activeRole.bullets.map((bullet, i) => (
                      <motion.li
                        key={bullet}
                        initial={{ opacity: 0, x: -12 }}
                        animate={{ opacity: 1, x: 0 }}
                        transition={{ delay: i * 0.07, duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
                        className="flex items-start gap-3"
                      >
                        <div className="flex-shrink-0 w-5 h-5 rounded-full flex items-center justify-center mt-0.5" style={{ background: `${activeRole.color}20` }}>
                          <Check size={11} style={{ color: activeRole.color }} />
                        </div>
                        <span className="text-[#F5F5FA] text-sm leading-relaxed">{bullet}</span>
                      </motion.li>
                    ))}
                  </ul>
                </>
              )}
            </div>

            {/* Right: visual */}
            <div className="flex justify-center lg:justify-end">
              {ROLE_VISUALS[activeIndex]}
            </div>
          </motion.div>
        </AnimatePresence>
      </div>
    </section>
  )
}
