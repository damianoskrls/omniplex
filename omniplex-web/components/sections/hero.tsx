'use client'

import { useState, useEffect, useRef, Fragment } from 'react'
import Image from 'next/image'
import { motion, AnimatePresence } from 'framer-motion'
import { ArrowRight, Zap } from 'lucide-react'
import { useGSAP } from '@gsap/react'
import gsap from 'gsap'

gsap.registerPlugin(useGSAP)

const EASE = [0.16, 1, 0.3, 1]

const APP_STORE_LINKS = {
  apple: '#',
  google: '#',
}

const SLIDES = [
  { type: 'video' as const, src: '/videos/hero-bg.mp4', label: 'OmniPlex', sublabel: 'Το fitness super-app' },
  { type: 'image' as const, src: '/images/persona-member.webp', label: 'Ασκούμενοι', sublabel: 'Βρες χώρο, κλείσε θέση' },
  { type: 'image' as const, src: '/images/persona-trainer.webp', label: 'Προπονητές', sublabel: 'Δούλεψε παντού' },
  { type: 'image' as const, src: '/images/persona-owner.webp', label: 'Ιδιοκτήτες', sublabel: 'Αναπτύξτε τον χώρο σας' },
]

const INTERVAL = 4500

function AppStoreButton({ store }: { store: 'apple' | 'google' }) {
  const isApple = store === 'apple'
  return (
    <a
      href={isApple ? APP_STORE_LINKS.apple : APP_STORE_LINKS.google}
      className="inline-flex items-center gap-3 px-4 py-2.5 rounded-xl border border-[#2B2E3D] bg-[#14161F] hover:border-[#4452D8]/50 hover:bg-[#1E2130] transition-all duration-200 group"
    >
      {isApple ? (
        <svg width="18" height="22" viewBox="0 0 814 1000" fill="#F5F5FA">
          <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76 0-103.7 40.8-165.9 40.8s-105-48.8-155.5-127.4C46.7 790.7 0 663 0 541.8c0-207.5 135.4-317.3 269-317.3 71 0 130.5 46.4 175 46.4 42.5 0 109.2-49.7 188.5-49.7 23.4 0 117.4 2.1 186.2 91.2zm-248-192.4c31.7-37.5 54.3-89.7 54.3-141.9 0-7.1-.6-14.3-1.9-20.1-51.6 2-112.3 34.4-149.2 75.8-28.5 32.4-55.1 84.7-55.1 137.5 0 7.7 1.3 15.5 1.9 18 3.2.6 8.4 1.3 13.6 1.3 46.5 0 102.5-29.9 136.4-70.6z" />
        </svg>
      ) : (
        <svg width="18" height="20" viewBox="0 0 512 512" fill="#F5F5FA">
          <path d="M325.3 234.3L104.6 13l280.8 161.2-60.1 60.1zM47 0C34 6.8 25.3 19.2 25.3 35.3v441.3c0 16.1 8.7 28.5 21.7 35.3l232.6-233L47 0zm412.6 235.7l-60.2-34.4-67.4 64.6 67.4 64.6 60.5-34.4c17.4-10 17.4-35.4-.3-45.4zM104.6 499l280.8-161.2-60.1-60.1L104.6 499z" />
        </svg>
      )}
      <div>
        <p className="text-[9px] text-[#A7ABBE] leading-none mb-0.5">Κατεβάστε από</p>
        <p className="text-xs font-bold text-[#F5F5FA] leading-none">{isApple ? 'App Store' : 'Google Play'}</p>
      </div>
    </a>
  )
}

function HeroSlider() {
  const [index, setIndex] = useState(0)
  const videoRef = useRef<HTMLVideoElement>(null)
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null)

  const startTimer = () => {
    if (timerRef.current) clearInterval(timerRef.current)
    timerRef.current = setInterval(() => {
      setIndex((i) => (i + 1) % SLIDES.length)
    }, INTERVAL)
  }

  useEffect(() => {
    startTimer()
    return () => { if (timerRef.current) clearInterval(timerRef.current) }
  }, [])

  useEffect(() => {
    if (SLIDES[index].type === 'video' && videoRef.current) {
      videoRef.current.currentTime = 0
      videoRef.current.play().catch(() => {})
    }
  }, [index])

  const goTo = (i: number) => {
    setIndex(i)
    startTimer()
  }

  const slide = SLIDES[index]

  return (
    <div className="relative w-full rounded-2xl overflow-hidden" style={{ aspectRatio: '4/5', maxWidth: 480 }}>
      <AnimatePresence mode="wait">
        <motion.div
          key={index}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.7, ease: EASE }}
          className="absolute inset-0"
        >
          {slide.type === 'video' ? (
            <video
              ref={videoRef}
              src={slide.src}
              autoPlay
              muted
              loop
              playsInline
              className="w-full h-full object-cover"
            />
          ) : (
            <Image
              src={slide.src}
              alt={slide.label}
              fill
              className="object-cover"
              sizes="(max-width: 768px) 100vw, 480px"
              priority={index === 0}
            />
          )}

          {/* Gradient overlay */}
          <div className="absolute inset-0 bg-gradient-to-t from-[#090A0F]/80 via-transparent to-transparent" />

          {/* Label */}
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, ease: EASE, delay: 0.15 }}
            className="absolute bottom-14 left-5"
          >
            <p className="text-white text-xl font-black leading-tight">{slide.label}</p>
            <p className="text-white/60 text-sm">{slide.sublabel}</p>
          </motion.div>
        </motion.div>
      </AnimatePresence>

      {/* Dot nav */}
      <div className="absolute bottom-5 left-0 right-0 flex justify-center gap-2 z-10">
        {SLIDES.map((_, i) => (
          <button
            key={i}
            type="button"
            onClick={() => goTo(i)}
            aria-label={`Slide ${i + 1}`}
            className="transition-all duration-300"
            style={{
              width: i === index ? 24 : 6,
              height: 6,
              borderRadius: 3,
              background: i === index
                ? 'linear-gradient(90deg, #4452D8, #C52473)'
                : 'rgba(255,255,255,0.3)',
            }}
          />
        ))}
      </div>

      {/* Progress bar */}
      <div className="absolute top-0 left-0 right-0 h-0.5 bg-white/10 z-10">
        <motion.div
          key={index}
          initial={{ width: '0%' }}
          animate={{ width: '100%' }}
          transition={{ duration: INTERVAL / 1000, ease: 'linear' }}
          className="h-full"
          style={{ background: 'linear-gradient(90deg, #4452D8, #C52473)' }}
        />
      </div>
    </div>
  )
}

function wordSplit(text: string) {
  return text.split(' ').map((word, i, arr) => (
    <Fragment key={i}>
      <span style={{ display: 'inline-block', overflow: 'hidden', verticalAlign: 'bottom' }}>
        <span className="word-inner" style={{ display: 'inline-block' }}>{word}</span>
      </span>
      {i < arr.length - 1 && ' '}
    </Fragment>
  ))
}

function HeroHeadline() {
  const ref = useRef<HTMLHeadingElement>(null)

  useGSAP(
    () => {
      if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return
      const wordInners = ref.current?.querySelectorAll<HTMLElement>('.word-inner')
      const gradientWrap = ref.current?.querySelector<HTMLElement>('.gradient-wrap')
      if (!wordInners?.length) return

      const tl = gsap.timeline({ delay: 0.2 })

      tl.from(wordInners, {
        yPercent: 120,
        duration: 0.9,
        stagger: 0.08,
        ease: 'power4.out',
      })

      if (gradientWrap) {
        tl.from(
          gradientWrap,
          { yPercent: 110, duration: 0.9, ease: 'power4.out' },
          '-=0.65'
        )
      }
    },
    { scope: ref }
  )

  return (
    <h1
      ref={ref}
      aria-label="Βρες χώρο. Ξεκίνα σήμερα."
      className="text-5xl sm:text-6xl lg:text-7xl font-black tracking-tight leading-[1.05] mb-6"
    >
      <span className="block text-[#F5F5FA]" aria-hidden="true">
        {wordSplit('Βρες χώρο.')}
      </span>
      <span className="block" aria-hidden="true" style={{ overflow: 'hidden' }}>
        <span
          className="gradient-wrap block"
          style={{
            background: 'linear-gradient(135deg, #4452D8 0%, #7B3EAD 55%, #C52473 100%)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
            backgroundClip: 'text',
          }}
        >
          Ξεκίνα σήμερα.
        </span>
      </span>
    </h1>
  )
}

export default function Hero() {
  return (
    <section className="relative min-h-screen flex items-center overflow-hidden pt-16">

      {/* Dot grid background */}
      <div className="absolute inset-0 dot-bg opacity-30 pointer-events-none" />

      {/* Ambient light top */}
      <div
        className="absolute top-0 left-1/2 -translate-x-1/2 w-[900px] h-[500px] opacity-10 pointer-events-none"
        style={{ background: 'radial-gradient(ellipse at center top, #4452D8 0%, transparent 70%)' }}
      />

      <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20 md:py-28">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 lg:gap-16 items-center">

          {/* Left: Text */}
          <div className="text-center lg:text-left">

            {/* Badge */}
            <motion.div
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, ease: EASE, delay: 0.1 }}
              className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full border border-[#2B2E3D] bg-[#14161F] text-xs font-medium text-[#9A9DFF] mb-6"
            >
              <Zap size={12} className="fill-[#9A9DFF]" />
              iOS &amp; Android · Δωρεάν λήψη · Marketplace
            </motion.div>

            {/* Headline — GSAP masked word reveal */}
            <HeroHeadline />

            {/* Subline */}
            <motion.p
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.7, ease: EASE, delay: 0.35 }}
              className="text-lg text-[#A7ABBE] leading-relaxed max-w-lg mx-auto lg:mx-0 mb-8"
            >
              Κατέβασε το app, βρες γυμναστήριο κοντά σου και κλείσε θέση —
              μέλος ή drop-in, αμέσως.
            </motion.p>

            {/* CTAs */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.7, ease: EASE, delay: 0.48 }}
              className="flex flex-col sm:flex-row items-center justify-center lg:justify-start gap-3 mb-6"
            >
              <a
                href={APP_STORE_LINKS.apple}
                data-magnetic="0.3"
                className="group w-full sm:w-auto inline-flex items-center justify-center gap-2 px-6 py-3.5 rounded-xl text-sm font-semibold text-white transition-all duration-200 hover:opacity-90 active:scale-[0.98]"
                style={{ background: 'linear-gradient(135deg, #4452D8, #7B3EAD, #C52473)' }}
              >
                Κατεβάστε το app
                <ArrowRight size={16} className="group-hover:translate-x-0.5 transition-transform" />
              </a>
              <button
                type="button"
                data-magnetic="0.25"
                onClick={() => window.dispatchEvent(new CustomEvent('open-demo-modal'))}
                className="w-full sm:w-auto inline-flex items-center justify-center px-6 py-3.5 rounded-xl text-sm font-semibold text-[#F5F5FA] border border-[#2B2E3D] hover:border-[#4452D8]/60 hover:bg-[#14161F] transition-all duration-200"
              >
                Για γυμναστήρια →
              </button>
            </motion.div>

            {/* App store buttons */}
            <motion.div
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, ease: EASE, delay: 0.58 }}
              className="flex flex-wrap items-center justify-center lg:justify-start gap-3 mb-8"
            >
              <AppStoreButton store="apple" />
              <AppStoreButton store="google" />
            </motion.div>

            {/* Trust indicators */}
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.6, delay: 0.7 }}
              className="flex flex-wrap items-center justify-center lg:justify-start gap-4 text-xs text-[#6B7280]"
            >
              {['Δωρεάν λήψη', 'iOS & Android', 'Χωρίς δέσμευση'].map((t) => (
                <div key={t} className="flex items-center gap-1.5">
                  <div className="w-1.5 h-1.5 rounded-full bg-[#8DE2BB]" />
                  {t}
                </div>
              ))}
            </motion.div>
          </div>

          {/* Right: Slider */}
          <motion.div
            initial={{ opacity: 0, x: 40, scale: 0.95 }}
            animate={{ opacity: 1, x: 0, scale: 1 }}
            transition={{ duration: 0.9, ease: EASE, delay: 0.3 }}
            className="flex justify-center lg:justify-end"
          >
            <HeroSlider />
          </motion.div>
        </div>

        {/* Scroll indicator */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 1.2, duration: 0.6 }}
          className="absolute bottom-8 left-1/2 -translate-x-1/2 hidden md:flex flex-col items-center gap-2"
        >
          <span className="text-xs text-[#6B7280] tracking-widest uppercase">Κυλήστε</span>
          <motion.div
            animate={{ y: [0, 6, 0] }}
            transition={{ duration: 1.4, repeat: Infinity, ease: 'easeInOut' }}
            className="w-[1px] h-8 bg-gradient-to-b from-[#4452D8] to-transparent"
          />
        </motion.div>
      </div>
    </section>
  )
}
