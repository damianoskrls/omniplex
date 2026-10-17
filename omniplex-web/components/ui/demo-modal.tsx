'use client'

import { useState, useEffect, useCallback } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { X, ArrowRight, Check } from 'lucide-react'
import { cn } from '@/lib/utils'

const BUSINESS_TYPES = [
  'Γυμναστήριο',
  'Pilates Studio',
  'CrossFit Box',
  'Yoga Studio',
  'Personal Training',
  'Άλλο',
]

const MEMBER_COUNTS = ['Μέχρι 50', '50 – 150', '150 – 300', '300+']

const EASE = [0.16, 1, 0.3, 1]

const EMPTY = { businessType: '', memberCount: '', area: '', name: '', phone: '', email: '' }

export default function DemoModal() {
  const [open, setOpen] = useState(false)
  const [submitted, setSubmitted] = useState(false)
  const [form, setForm] = useState(EMPTY)

  const handleOpen = useCallback(() => {
    setOpen(true)
    setSubmitted(false)
    setForm(EMPTY)
  }, [])

  const handleClose = useCallback(() => setOpen(false), [])

  useEffect(() => {
    window.addEventListener('open-demo-modal', handleOpen)
    return () => window.removeEventListener('open-demo-modal', handleOpen)
  }, [handleOpen])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') handleClose() }
    if (open) document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [open, handleClose])

  useEffect(() => {
    document.body.style.overflow = open ? 'hidden' : ''
    return () => { document.body.style.overflow = '' }
  }, [open])

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (form.name && form.email && form.businessType) setSubmitted(true)
  }

  const set = (key: keyof typeof EMPTY) => (val: string) =>
    setForm((prev) => ({ ...prev, [key]: val }))

  return (
    <AnimatePresence>
      {open && (
        <>
          {/* Backdrop */}
          <motion.div
            key="backdrop"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.25 }}
            className="fixed inset-0 bg-[#090A0F]/80 backdrop-blur-sm z-50"
            onClick={handleClose}
          />

          {/* Panel */}
          <motion.div
            key="panel"
            initial={{ opacity: 0, scale: 0.95, y: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: 16 }}
            transition={{ duration: 0.35, ease: EASE }}
            className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-4 sm:p-6 pointer-events-none"
          >
            <div
              className="relative w-full max-w-lg rounded-2xl border border-[#2B2E3D] bg-[#14161F] shadow-2xl pointer-events-auto max-h-[92vh] overflow-y-auto"
              onClick={(e) => e.stopPropagation()}
            >
              {/* Gradient top accent */}
              <div
                className="absolute inset-x-0 top-0 h-[2px] rounded-t-2xl"
                style={{ background: 'linear-gradient(90deg, #4452D8, #7B3EAD, #C52473)' }}
              />

              {/* Close */}
              <button
                onClick={handleClose}
                className="absolute top-4 right-4 w-8 h-8 rounded-xl bg-[#1E2130] flex items-center justify-center text-[#A7ABBE] hover:text-[#F5F5FA] hover:bg-[#2B2E3D] transition-colors z-10"
              >
                <X size={15} />
              </button>

              <div className="p-6 pt-7">
                {submitted ? (
                  <motion.div
                    initial={{ opacity: 0, scale: 0.96 }}
                    animate={{ opacity: 1, scale: 1 }}
                    className="flex flex-col items-center text-center py-8 gap-4"
                  >
                    <div
                      className="w-16 h-16 rounded-full flex items-center justify-center"
                      style={{ background: '#8DE2BB20', border: '1px solid #8DE2BB40' }}
                    >
                      <Check size={28} className="text-[#8DE2BB]" />
                    </div>
                    <div>
                      <h3 className="text-xl font-black text-[#F5F5FA] mb-2">Λάβαμε το αίτημά σας!</h3>
                      <p className="text-[#A7ABBE] text-sm leading-relaxed max-w-xs mx-auto">
                        Θα επικοινωνήσουμε μαζί σας εντός 24 ωρών για να κλείσουμε τη δωρεάν επίδειξη.
                      </p>
                    </div>
                    <button
                      onClick={handleClose}
                      className="mt-2 px-5 py-2.5 rounded-xl text-sm font-semibold text-[#F5F5FA] border border-[#2B2E3D] hover:border-[#4452D8]/60 transition-colors"
                    >
                      Κλείσιμο
                    </button>
                  </motion.div>
                ) : (
                  <form onSubmit={handleSubmit} className="space-y-5">
                    <div>
                      <h3 className="text-xl font-black text-[#F5F5FA] mb-0.5">Ζητήστε demo</h3>
                      <p className="text-sm text-[#A7ABBE]">20 λεπτά, χωρίς δεσμεύσεις — στη γλώσσα σας.</p>
                    </div>

                    {/* Business type */}
                    <div>
                      <label className="block text-xs font-semibold text-[#F5F5FA] uppercase tracking-wider mb-2.5">
                        Τύπος επιχείρησης <span className="text-[#C52473]">*</span>
                      </label>
                      <div className="flex flex-wrap gap-2">
                        {BUSINESS_TYPES.map((type) => (
                          <button
                            key={type}
                            type="button"
                            onClick={() => set('businessType')(type)}
                            className={cn(
                              'px-3 py-1.5 rounded-xl text-sm font-medium border transition-all duration-200',
                              form.businessType === type
                                ? 'text-white border-transparent'
                                : 'text-[#A7ABBE] border-[#2B2E3D] bg-[#1E2130] hover:border-[#4452D8]/50 hover:text-[#F5F5FA]'
                            )}
                            style={form.businessType === type
                              ? { background: 'linear-gradient(135deg, #4452D8, #7B3EAD, #C52473)' }
                              : {}}
                          >
                            {type}
                          </button>
                        ))}
                      </div>
                    </div>

                    {/* Member count */}
                    <div>
                      <label className="block text-xs font-semibold text-[#F5F5FA] uppercase tracking-wider mb-2.5">
                        Περίπου πόσα μέλη έχετε;
                      </label>
                      <div className="flex flex-wrap gap-2">
                        {MEMBER_COUNTS.map((count) => (
                          <button
                            key={count}
                            type="button"
                            onClick={() => set('memberCount')(count)}
                            className={cn(
                              'px-3 py-1.5 rounded-xl text-sm font-medium border transition-all duration-200',
                              form.memberCount === count
                                ? 'text-white border-transparent'
                                : 'text-[#A7ABBE] border-[#2B2E3D] bg-[#1E2130] hover:border-[#4452D8]/50 hover:text-[#F5F5FA]'
                            )}
                            style={form.memberCount === count
                              ? { background: 'linear-gradient(135deg, #4452D8, #C52473)' }
                              : {}}
                          >
                            {count}
                          </button>
                        ))}
                      </div>
                    </div>

                    {/* Area */}
                    <div>
                      <label className="block text-xs font-semibold text-[#F5F5FA] uppercase tracking-wider mb-2">
                        Περιοχή
                      </label>
                      <input
                        type="text"
                        value={form.area}
                        onChange={(e) => set('area')(e.target.value)}
                        placeholder="π.χ. Αθήνα, Θεσσαλονίκη…"
                        className="w-full px-4 py-3 rounded-xl bg-[#1E2130] border border-[#2B2E3D] text-[#F5F5FA] placeholder-[#6B7280] text-sm focus:outline-none focus:border-[#4452D8] transition-colors"
                      />
                    </div>

                    {/* Name + Phone */}
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                      <div>
                        <label className="block text-xs font-semibold text-[#F5F5FA] uppercase tracking-wider mb-2">
                          Ονοματεπώνυμο <span className="text-[#C52473]">*</span>
                        </label>
                        <input
                          type="text"
                          value={form.name}
                          onChange={(e) => set('name')(e.target.value)}
                          placeholder="Γιώργης Παπαδόπουλος"
                          required
                          className="w-full px-4 py-3 rounded-xl bg-[#1E2130] border border-[#2B2E3D] text-[#F5F5FA] placeholder-[#6B7280] text-sm focus:outline-none focus:border-[#4452D8] transition-colors"
                        />
                      </div>
                      <div>
                        <label className="block text-xs font-semibold text-[#F5F5FA] uppercase tracking-wider mb-2">
                          Τηλέφωνο
                        </label>
                        <input
                          type="tel"
                          value={form.phone}
                          onChange={(e) => set('phone')(e.target.value)}
                          placeholder="69X XXX XXXX"
                          className="w-full px-4 py-3 rounded-xl bg-[#1E2130] border border-[#2B2E3D] text-[#F5F5FA] placeholder-[#6B7280] text-sm focus:outline-none focus:border-[#4452D8] transition-colors"
                        />
                      </div>
                    </div>

                    {/* Email */}
                    <div>
                      <label className="block text-xs font-semibold text-[#F5F5FA] uppercase tracking-wider mb-2">
                        Email <span className="text-[#C52473]">*</span>
                      </label>
                      <input
                        type="email"
                        value={form.email}
                        onChange={(e) => set('email')(e.target.value)}
                        placeholder="email@gymnastirio.gr"
                        required
                        className="w-full px-4 py-3 rounded-xl bg-[#1E2130] border border-[#2B2E3D] text-[#F5F5FA] placeholder-[#6B7280] text-sm focus:outline-none focus:border-[#4452D8] transition-colors"
                      />
                    </div>

                    <button
                      type="submit"
                      disabled={!form.name || !form.email || !form.businessType}
                      className="group w-full inline-flex items-center justify-center gap-2 px-6 py-3.5 rounded-xl text-sm font-semibold text-white transition-all duration-200 hover:opacity-90 hover:scale-[1.01] active:scale-[0.99] disabled:opacity-40 disabled:cursor-not-allowed disabled:hover:scale-100"
                      style={{ background: 'linear-gradient(135deg, #4452D8, #7B3EAD, #C52473)' }}
                    >
                      Αποστολή αιτήματος
                      <ArrowRight size={16} className="group-hover:translate-x-0.5 transition-transform" />
                    </button>

                    <p className="text-xs text-[#6B7280] text-center">
                      Κανένα spam · Απάντηση εντός 24 ωρών
                    </p>
                  </form>
                )}
              </div>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  )
}
