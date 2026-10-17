'use client'

import { useEffect } from 'react'
import gsap from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'

gsap.registerPlugin(ScrollTrigger)

export default function CinemaProvider({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    if (reduced) return

    // Hide [data-reveal] elements before first paint
    gsap.set('[data-reveal]', { opacity: 0, y: 48 })

    // Batch staggered reveal for all [data-reveal] elements
    ScrollTrigger.batch('[data-reveal]', {
      onEnter: (els) =>
        gsap.to(els, {
          opacity: 1,
          y: 0,
          duration: 0.9,
          stagger: 0.08,
          ease: 'power3.out',
        }),
      start: 'top 88%',
      once: true,
    })

    // Parallax depth for [data-parallax="<depth>"] (default 20)
    document.querySelectorAll<HTMLElement>('[data-parallax]').forEach((el) => {
      const depth = parseFloat(el.dataset.parallax ?? '20')
      gsap.fromTo(
        el,
        { yPercent: -depth },
        {
          yPercent: depth,
          ease: 'none',
          scrollTrigger: {
            trigger: el,
            start: 'top bottom',
            end: 'bottom top',
            scrub: true,
          },
        }
      )
    })

    // Magnetic hover for [data-magnetic="<strength>"] (default 0.35)
    const magnetics = Array.from(document.querySelectorAll<HTMLElement>('[data-magnetic]'))
    const magneticOff: Array<() => void> = []
    magnetics.forEach((el) => {
      const str = parseFloat(el.dataset.magnetic ?? '0.35')
      const onMove = (e: MouseEvent) => {
        const r = el.getBoundingClientRect()
        gsap.to(el, {
          x: (e.clientX - (r.left + r.width / 2)) * str,
          y: (e.clientY - (r.top + r.height / 2)) * str,
          duration: 0.4,
          ease: 'power2.out',
        })
      }
      const onOut = () =>
        gsap.to(el, { x: 0, y: 0, duration: 0.7, ease: 'elastic.out(1, 0.5)' })
      el.addEventListener('mousemove', onMove)
      el.addEventListener('mouseleave', onOut)
      magneticOff.push(() => {
        el.removeEventListener('mousemove', onMove)
        el.removeEventListener('mouseleave', onOut)
      })
    })

    // Lenis smooth scroll — async import keeps SSR clean
    let mounted = true
    let lenis: { on: Function; raf: Function; destroy: Function } | null = null
    let ticker: (time: number) => void

    import('lenis').then(({ default: Lenis }) => {
      if (!mounted) return
      lenis = new (Lenis as any)()
      lenis!.on('scroll', ScrollTrigger.update)
      ticker = (time: number) => lenis!.raf(time * 1000)
      gsap.ticker.add(ticker)
      gsap.ticker.lagSmoothing(0)
    })

    return () => {
      mounted = false
      if (ticker) gsap.ticker.remove(ticker)
      lenis?.destroy()
      ScrollTrigger.getAll().forEach((t) => t.kill())
      magneticOff.forEach((fn) => fn())
    }
  }, [])

  return <>{children}</>
}
