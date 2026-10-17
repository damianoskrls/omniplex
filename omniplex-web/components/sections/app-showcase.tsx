'use client'

import { useState } from 'react'
import { motion } from 'framer-motion'
import { Play } from 'lucide-react'
import { FadeUp, StaggerContainer, StaggerItem } from '@/components/ui/motion-wrapper'

const APP_STORE_LINKS = {
  apple: '#',
  google: '#',
}

function AppStoreButton({ store }: { store: 'apple' | 'google' }) {
  const isApple = store === 'apple'
  return (
    <a
      href={isApple ? APP_STORE_LINKS.apple : APP_STORE_LINKS.google}
      className="inline-flex items-center gap-3 px-5 py-3 rounded-xl border border-[#2B2E3D] bg-[#14161F] hover:border-[#4452D8]/50 hover:bg-[#1E2130] transition-all duration-200 group"
    >
      {isApple ? (
        <svg width="20" height="24" viewBox="0 0 814 1000" fill="#F5F5FA">
          <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76 0-103.7 40.8-165.9 40.8s-105-48.8-155.5-127.4C46.7 790.7 0 663 0 541.8c0-207.5 135.4-317.3 269-317.3 71 0 130.5 46.4 175 46.4 42.5 0 109.2-49.7 188.5-49.7 23.4 0 117.4 2.1 186.2 91.2zm-248-192.4c31.7-37.5 54.3-89.7 54.3-141.9 0-7.1-.6-14.3-1.9-20.1-51.6 2-112.3 34.4-149.2 75.8-28.5 32.4-55.1 84.7-55.1 137.5 0 7.7 1.3 15.5 1.9 18 3.2.6 8.4 1.3 13.6 1.3 46.5 0 102.5-29.9 136.4-70.6z" />
        </svg>
      ) : (
        <svg width="20" height="22" viewBox="0 0 512 512" fill="#F5F5FA">
          <path d="M325.3 234.3L104.6 13l280.8 161.2-60.1 60.1zM47 0C34 6.8 25.3 19.2 25.3 35.3v441.3c0 16.1 8.7 28.5 21.7 35.3l232.6-233L47 0zm412.6 235.7l-60.2-34.4-67.4 64.6 67.4 64.6 60.5-34.4c17.4-10 17.4-35.4-.3-45.4zM104.6 499l280.8-161.2-60.1-60.1L104.6 499z" />
        </svg>
      )}
      <div>
        <p className="text-[10px] text-[#A7ABBE] leading-none mb-0.5">Κατεβάστε από</p>
        <p className="text-sm font-bold text-[#F5F5FA] leading-none">{isApple ? 'App Store' : 'Google Play'}</p>
      </div>
    </a>
  )
}

const SCREENS = [
  {
    label: 'Ιδιοκτήτης',
    color: '#4452D8',
    content: (
      <div className="p-4 space-y-3">
        <p className="text-[10px] text-[#A7ABBE] uppercase tracking-wider">Dashboard</p>
        <p className="text-xl font-black text-[#F5F5FA]">€4,820</p>
        <div className="space-y-2">
          {[['CrossFit', 62, '#4452D8'], ['Yoga', 41, '#7B3EAD'], ['Pilates', 29, '#C52473']].map(([n, p, c]) => (
            <div key={n as string} className="flex items-center gap-2">
              <span className="text-[10px] text-[#A7ABBE] w-12">{n as string}</span>
              <div className="flex-1 h-1 rounded-full bg-[#1E2130] overflow-hidden">
                <div className="h-full rounded-full" style={{ width: `${p}%`, background: c as string }} />
              </div>
            </div>
          ))}
        </div>
        <div className="rounded-lg bg-[#4452D8]/20 border border-[#4452D8]/30 p-2.5">
          <p className="text-[9px] text-[#9A9DFF]">AI: Πρόβλεψη +22% επόμενη εβδομάδα</p>
        </div>
      </div>
    ),
  },
  {
    label: 'Μέλος',
    color: '#7B3EAD',
    content: (
      <div className="p-4 space-y-2.5">
        <p className="text-[10px] text-[#A7ABBE] uppercase tracking-wider">Πρόγραμμά σου</p>
        {[
          { name: 'Yoga Flow', time: '09:00', ok: true },
          { name: 'HIIT', time: '17:30', ok: false },
        ].map((c) => (
          <div key={c.name} className={`rounded-lg p-2.5 border ${c.ok ? 'border-[#7B3EAD]/40 bg-[#7B3EAD]/10' : 'border-[#2B2E3D] bg-[#1E2130]'}`}>
            <p className="text-xs font-semibold text-[#F5F5FA]">{c.name}</p>
            <p className="text-[9px] text-[#A7ABBE]">{c.time}</p>
          </div>
        ))}
        <div className="rounded-lg bg-[#7B3EAD]/20 border border-[#7B3EAD]/30 p-2.5">
          <p className="text-[9px] text-[#9A9DFF]">🤖 AI: Να κλείσω θέση αύριο;</p>
        </div>
      </div>
    ),
  },
  {
    label: 'Προπονητής',
    color: '#A4308D',
    content: (
      <div className="p-4 space-y-2.5">
        <p className="text-[10px] text-[#A7ABBE] uppercase tracking-wider">Σήμερα · 4 συνεδρίες</p>
        {['Αλέξης Μ.', 'Ελένη Π.', 'Γιώργης Κ.'].map((name) => (
          <div key={name} className="flex items-center gap-2 py-1.5 border-b border-[#1E2130] last:border-0">
            <div className="w-6 h-6 rounded-full flex items-center justify-center text-[9px] font-bold text-white flex-shrink-0" style={{ background: 'linear-gradient(135deg, #4452D8, #C52473)' }}>
              {name.charAt(0)}
            </div>
            <p className="text-xs text-[#F5F5FA] truncate">{name}</p>
            <div className="w-1.5 h-1.5 rounded-full bg-[#8DE2BB] ml-auto flex-shrink-0" />
          </div>
        ))}
        <div className="rounded-lg bg-[#A4308D]/20 border border-[#A4308D]/30 p-2 mt-1">
          <p className="text-[9px] text-[#C52473]">Marketplace · 3 νέα αιτήματα</p>
        </div>
      </div>
    ),
  },
]

export default function AppShowcase() {
  const [videoPlaying, setVideoPlaying] = useState(false)

  return (
    <section className="py-24 md:py-32 relative overflow-hidden">

      {/* Subtle ambient glow */}
      <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[400px] opacity-[0.06] pointer-events-none rounded-full blur-3xl"
        style={{ background: 'linear-gradient(135deg, #4452D8, #C52473)' }}
      />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">

        <FadeUp className="text-center mb-14">
          <p className="text-sm font-semibold text-[#9A9DFF] uppercase tracking-widest mb-3">Δείτε το OmniPlex</p>
          <h2 className="text-4xl md:text-5xl font-black text-[#F5F5FA] tracking-tight mb-4">
            Σε δράση,<br />
            <span style={{ background: 'linear-gradient(135deg, #4452D8, #C52473)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent', backgroundClip: 'text' }}>
              σε κάθε οθόνη.
            </span>
          </h2>
          <p className="text-[#A7ABBE] text-lg max-w-md mx-auto">
            Μια σύντομη επίδειξη αξίζει όσο χίλιες λέξεις.
          </p>
        </FadeUp>

        {/* Video embed */}
        <FadeUp className="mb-20">
          <div className="relative max-w-4xl mx-auto">
            {/* Glow */}
            <div className="absolute -inset-[1px] rounded-2xl opacity-40 blur-xl pointer-events-none"
              style={{ background: 'linear-gradient(135deg, #4452D8, #C52473)' }}
            />

            <div className="relative rounded-2xl overflow-hidden border border-[#2B2E3D] bg-[#14161F] aspect-video">
              {videoPlaying ? (
                /* Replace YOUTUBE_VIDEO_ID with your actual video ID */
                <iframe
                  className="w-full h-full"
                  src="https://www.youtube.com/embed/YOUTUBE_VIDEO_ID?autoplay=1&rel=0"
                  title="OmniPlex App Demo"
                  allow="autoplay; fullscreen; picture-in-picture"
                  allowFullScreen
                />
              ) : (
                /* Placeholder — shown until user presses play */
                <div className="absolute inset-0 flex flex-col items-center justify-center gap-5">
                  {/* Background pattern */}
                  <div className="absolute inset-0 dot-bg opacity-20" />
                  <div className="absolute inset-0" style={{ background: 'linear-gradient(135deg, #4452D820 0%, #C5247315 100%)' }} />

                  {/* Play button */}
                  <motion.button
                    onClick={() => setVideoPlaying(true)}
                    whileHover={{ scale: 1.08 }}
                    whileTap={{ scale: 0.96 }}
                    className="relative z-10 w-20 h-20 rounded-full flex items-center justify-center shadow-2xl"
                    style={{ background: 'linear-gradient(135deg, #4452D8, #7B3EAD, #C52473)' }}
                  >
                    <Play size={28} className="text-white ml-1" fill="white" />
                  </motion.button>

                  <div className="relative z-10 text-center">
                    <p className="text-[#F5F5FA] font-semibold text-lg mb-1">Demo OmniPlex</p>
                    <p className="text-sm text-[#A7ABBE]">Δείτε πώς λειτουργεί το οικοσύστημα σε 3 λεπτά</p>
                  </div>

                  <div className="relative z-10 flex flex-wrap justify-center gap-2">
                    {['AI agent', 'Social feed', 'Marketplace', 'Multi-role'].map((tag) => (
                      <span key={tag} className="text-xs px-2.5 py-1 rounded-full border border-[#2B2E3D] bg-[#14161F]/80 text-[#9A9DFF]">
                        {tag}
                      </span>
                    ))}
                  </div>
                </div>
              )}
            </div>
          </div>
        </FadeUp>

        {/* App screenshots */}
        <FadeUp className="mb-14">
          <p className="text-center text-sm font-semibold text-[#6B7280] uppercase tracking-widest mb-10">
            Screenshots από την εφαρμογή
          </p>
          <StaggerContainer className="grid grid-cols-1 sm:grid-cols-3 gap-6 max-w-3xl mx-auto" staggerDelay={0.1}>
            {SCREENS.map((screen) => (
              <StaggerItem key={screen.label}>
                <div className="flex flex-col items-center gap-3">
                  {/* Phone frame */}
                  <div
                    className="relative w-[180px] rounded-[28px] overflow-hidden border-2 shadow-xl"
                    style={{
                      borderColor: `${screen.color}60`,
                      background: '#090A0F',
                      boxShadow: `0 20px 60px ${screen.color}25`,
                    }}
                  >
                    {/* Status bar */}
                    <div className="flex items-center justify-between px-4 pt-3 pb-1">
                      <span className="text-[9px] text-[#A7ABBE] font-medium">9:41</span>
                      <div className="flex items-center gap-1">
                        {[3, 3, 3].map((_, i) => <div key={i} className="w-0.5 h-2 rounded-full bg-[#A7ABBE]" style={{ height: `${6 + i * 2}px` }} />)}
                        <div className="w-3 h-1.5 rounded-sm border border-[#A7ABBE] ml-1">
                          <div className="w-2/3 h-full bg-[#8DE2BB] rounded-sm" />
                        </div>
                      </div>
                    </div>

                    {/* App content */}
                    {screen.content}

                    {/* Bottom bar */}
                    <div className="flex justify-around py-3 px-2 border-t border-[#1E2130]">
                      {['⊞', '📅', '💬', '👤'].map((icon) => (
                        <span key={icon} className="text-sm">{icon}</span>
                      ))}
                    </div>
                  </div>

                  <span className="text-xs font-medium text-[#A7ABBE]">{screen.label}</span>
                </div>
              </StaggerItem>
            ))}
          </StaggerContainer>
        </FadeUp>

        {/* App store buttons */}
        <FadeUp className="flex flex-col sm:flex-row gap-4 justify-center items-center">
          <p className="text-sm text-[#A7ABBE] sm:mr-2">Κατεβάστε τώρα:</p>
          <AppStoreButton store="apple" />
          <AppStoreButton store="google" />
        </FadeUp>

      </div>
    </section>
  )
}
