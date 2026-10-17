'use client'

import Nav from '@/components/nav'
import Footer from '@/components/sections/footer'
import DemoModal from '@/components/ui/demo-modal'
import { motion } from 'framer-motion'
import { ArrowRight, Mail, MessageCircle, Calendar } from 'lucide-react'

const EASE = [0.16, 1, 0.3, 1]

const CONTACT_OPTIONS = [
  {
    icon: Calendar,
    title: 'Demo 20 λεπτών',
    description: 'Δείτε το OmniPlex σε live επίδειξη — στη γλώσσα σας, με τα δικά σας δεδομένα. Χωρίς δεσμεύσεις.',
    cta: 'Κλείστε demo',
    action: 'modal' as const,
    color: '#4452D8',
  },
  {
    icon: Mail,
    title: 'Email',
    description: 'Στείλτε μας ό,τι χρειάζεστε — ερωτήσεις, συνεργασίες, τεχνική υποστήριξη.',
    cta: 'hello@omniplex.gr',
    action: 'email' as const,
    href: 'mailto:hello@omniplex.gr',
    color: '#7B3EAD',
  },
  {
    icon: MessageCircle,
    title: 'WhatsApp / Viber',
    description: 'Προτιμάτε γρήγορη επικοινωνία; Είμαστε διαθέσιμοι για γρήγορες ερωτήσεις.',
    cta: '+30 210 000 0000',
    action: 'phone' as const,
    href: 'tel:+302100000000',
    color: '#A4308D',
  },
]

export default function ContactPage() {
  return (
    <main className="min-h-screen bg-bg">
      <Nav />

      <section className="relative pt-32 pb-24 overflow-hidden">
        <div className="absolute inset-0 dot-bg opacity-20 pointer-events-none" />
        <div
          className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[400px] opacity-[0.07] pointer-events-none"
          style={{ background: 'radial-gradient(ellipse at top, #4452D8 0%, transparent 65%)' }}
        />

        <div className="relative max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
          {/* Header */}
          <div className="text-center mb-16">
            <motion.div
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, ease: EASE }}
              className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full border border-[#2B2E3D] bg-[#14161F] text-xs font-medium text-[#9A9DFF] mb-6"
            >
              Επικοινωνία
            </motion.div>

            <motion.h1
              initial={{ opacity: 0, y: 24 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.8, ease: EASE, delay: 0.1 }}
              className="text-5xl md:text-6xl font-black tracking-tight text-[#F5F5FA] mb-4"
            >
              Πώς μπορούμε να{' '}
              <span
                style={{
                  background: 'linear-gradient(135deg, #4452D8 0%, #7B3EAD 55%, #C52473 100%)',
                  WebkitBackgroundClip: 'text',
                  WebkitTextFillColor: 'transparent',
                  backgroundClip: 'text',
                }}
              >
                βοηθήσουμε;
              </span>
            </motion.h1>

            <motion.p
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.7, ease: EASE, delay: 0.22 }}
              className="text-lg text-[#A7ABBE] max-w-xl mx-auto"
            >
              Επιλέξτε τον τρόπο που σας βολεύει — θα απαντήσουμε εντός 24 ωρών.
            </motion.p>
          </div>

          {/* Contact options */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
            {CONTACT_OPTIONS.map((opt, i) => {
              const Icon = opt.icon
              return (
                <motion.div
                  key={opt.title}
                  initial={{ opacity: 0, y: 32 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ duration: 0.7, ease: EASE, delay: 0.3 + i * 0.1 }}
                  className="flex flex-col p-6 rounded-2xl border border-[#2B2E3D] bg-[#14161F] hover:border-[#4452D8]/40 transition-all duration-300"
                >
                  <div
                    className="w-11 h-11 rounded-xl flex items-center justify-center mb-5"
                    style={{ background: `${opt.color}18`, border: `1px solid ${opt.color}40` }}
                  >
                    <Icon size={20} style={{ color: opt.color }} />
                  </div>

                  <h2 className="text-lg font-bold text-[#F5F5FA] mb-2">{opt.title}</h2>
                  <p className="text-sm text-[#A7ABBE] leading-relaxed flex-1 mb-6">
                    {opt.description}
                  </p>

                  {opt.action === 'modal' ? (
                    <button
                      type="button"
                      onClick={() => window.dispatchEvent(new CustomEvent('open-demo-modal'))}
                      className="group inline-flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-semibold text-white transition-all duration-200 hover:opacity-90 self-start"
                      style={{ background: `linear-gradient(135deg, ${opt.color}, #C52473)` }}
                    >
                      {opt.cta}
                      <ArrowRight size={14} className="group-hover:translate-x-0.5 transition-transform" />
                    </button>
                  ) : (
                    <a
                      href={opt.href}
                      className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-semibold text-[#F5F5FA] border transition-all duration-200 hover:bg-[#1E2130] self-start"
                      style={{ borderColor: `${opt.color}40`, color: opt.color }}
                    >
                      {opt.cta}
                    </a>
                  )}
                </motion.div>
              )
            })}
          </div>

          {/* Bottom note */}
          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.7, duration: 0.6 }}
            className="text-center text-xs text-[#4B5563] mt-12"
          >
            Κανένα spam. Απαντάμε σε όλα τα μηνύματα εντός 24 ωρών.
          </motion.p>
        </div>
      </section>

      <Footer />
      <DemoModal />
    </main>
  )
}
