'use client'

import { useState, useEffect } from 'react'
import Image from 'next/image'
import Link from 'next/link'
import { motion, AnimatePresence } from 'framer-motion'
import { Menu, X } from 'lucide-react'
import { NAV_LINKS } from '@/lib/constants'
import { cn } from '@/lib/utils'

export default function Nav() {
  const [scrolled, setScrolled] = useState(false)
  const [menuOpen, setMenuOpen] = useState(false)

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20)
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  return (
    <>
      <motion.header
        initial={{ y: -80, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
        className={cn(
          'fixed top-0 left-0 right-0 z-50 transition-all duration-300',
          scrolled
            ? 'bg-[rgba(9,10,15,0.85)] backdrop-blur-2xl border-b border-[#1E2130]'
            : 'bg-transparent'
        )}
      >
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">

            {/* Logo */}
            <Link href="/" className="flex items-center gap-2.5 flex-shrink-0">
              <div className="w-8 h-8 relative">
                <Image src="/omniplex-icon.svg" alt="OmniPlex" fill className="object-contain" />
              </div>
              <span
                className="text-xl font-bold tracking-tight"
                style={{
                  background: 'linear-gradient(90deg, #4452D8, #C52473)',
                  WebkitBackgroundClip: 'text',
                  WebkitTextFillColor: 'transparent',
                  backgroundClip: 'text',
                }}
              >
                omniplex
              </span>
            </Link>

            {/* Desktop nav */}
            <nav className="hidden md:flex items-center gap-8">
              {NAV_LINKS.map((link) => (
                <Link
                  key={link.href}
                  href={link.href}
                  className="text-sm text-[#A7ABBE] hover:text-[#F5F5FA] transition-colors duration-200 font-medium"
                >
                  {link.label}
                </Link>
              ))}
            </nav>

            {/* Desktop CTAs */}
            <div className="hidden md:flex items-center gap-3">
              <Link
                href="#pricing"
                className="text-sm font-medium text-[#A7ABBE] hover:text-[#F5F5FA] transition-colors duration-200 px-4 py-2 rounded-xl border border-[#2B2E3D] hover:border-[#4452D8]/50"
              >
                Πακέτα & εγγραφή
              </Link>
              <button
                type="button"
                onClick={() => window.dispatchEvent(new CustomEvent('open-demo-modal'))}
                className="text-sm font-semibold text-white px-4 py-2 rounded-xl transition-all duration-200 hover:opacity-90 hover:scale-[1.02] active:scale-[0.98]"
                style={{ background: 'linear-gradient(135deg, #4452D8, #7B3EAD, #C52473)' }}
              >
                Ζητήστε demo
              </button>
            </div>

            {/* Mobile hamburger */}
            <button
              onClick={() => setMenuOpen((v) => !v)}
              className="md:hidden p-2 text-[#A7ABBE] hover:text-[#F5F5FA] transition-colors"
              aria-label={menuOpen ? 'Κλείσιμο μενού' : 'Άνοιγμα μενού'}
            >
              {menuOpen ? <X size={22} /> : <Menu size={22} />}
            </button>
          </div>
        </div>
      </motion.header>

      {/* Mobile menu */}
      <AnimatePresence>
        {menuOpen && (
          <motion.div
            initial={{ opacity: 0, y: -16 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -16 }}
            transition={{ duration: 0.25, ease: [0.16, 1, 0.3, 1] }}
            className="fixed top-16 left-0 right-0 z-40 bg-[rgba(9,10,15,0.97)] backdrop-blur-2xl border-b border-[#1E2130] px-4 py-6"
          >
            <nav className="flex flex-col gap-4 mb-6">
              {NAV_LINKS.map((link) => (
                <Link
                  key={link.href}
                  href={link.href}
                  onClick={() => setMenuOpen(false)}
                  className="text-base font-medium text-[#A7ABBE] hover:text-[#F5F5FA] transition-colors py-1"
                >
                  {link.label}
                </Link>
              ))}
            </nav>
            <div className="flex flex-col gap-3">
              <Link
                href="#pricing"
                onClick={() => setMenuOpen(false)}
                className="text-sm font-medium text-center py-3 rounded-xl border border-[#2B2E3D] text-[#A7ABBE] hover:text-[#F5F5FA] transition-colors"
              >
                Πακέτα & εγγραφή
              </Link>
              <button
                type="button"
                onClick={() => { setMenuOpen(false); window.dispatchEvent(new CustomEvent('open-demo-modal')) }}
                className="text-sm font-semibold text-center text-white py-3 rounded-xl"
                style={{ background: 'linear-gradient(135deg, #4452D8, #7B3EAD, #C52473)' }}
              >
                Ζητήστε demo
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  )
}
