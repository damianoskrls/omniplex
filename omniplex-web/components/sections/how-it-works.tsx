'use client'

import Image from 'next/image'
import Link from 'next/link'
import { Check, ArrowRight } from 'lucide-react'
import { FadeUp } from '@/components/ui/motion-wrapper'

const PERSONAS = [
  {
    id: 'member',
    photo: '/images/persona-member.webp',
    badge: 'Ασκούμενοι',
    color: '#7B3EAD',
    headline: 'Βρες, κλείσε, προπονήσου.',
    bullets: [
      'Αναζήτηση γυμναστηρίων κοντά σου',
      'Πακέτο ή drop-in — πληρώνεις μόνο ό,τι κάνεις',
      'Μέλος σε πολλούς χώρους ταυτόχρονα',
    ],
    ctaLabel: 'Κατεβάστε το app',
    ctaHref: '#',
    ctaType: 'link' as const,
  },
  {
    id: 'trainer',
    photo: '/images/persona-trainer.webp',
    badge: 'Προπονητές',
    color: '#A4308D',
    headline: 'Δούλεψε παντού. Διαχειρίσου τα πάντα.',
    bullets: [
      'Όλα τα γυμναστήρια, μία ενιαία εικόνα',
      'Ταυτόχρονα προπονητής ΚΑΙ ασκούμενος',
      'Marketplace προφίλ για νέους πελάτες',
    ],
    ctaLabel: 'Δείτε τον ρόλο',
    ctaHref: '/roles#trainer',
    ctaType: 'link' as const,
  },
  {
    id: 'owner',
    photo: '/images/persona-owner.webp',
    badge: 'Ιδιοκτήτες χώρων',
    color: '#4452D8',
    headline: 'Αναπτύξτε τον χώρο σας.',
    bullets: [
      'AI analytics & προβλέψεις εσόδων',
      'Marketplace, multi-branch & κοινότητα',
      'App για κάθε ρόλο στον χώρο σας',
    ],
    ctaLabel: 'Ζητήστε demo',
    ctaHref: '',
    ctaType: 'modal' as const,
  },
]

export default function HowItWorks() {
  return (
    <section className="py-24 md:py-32 relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <FadeUp className="text-center mb-16">
          <p className="text-sm font-semibold text-[#9A9DFF] uppercase tracking-widest mb-3">Για ποιον</p>
          <h2 className="text-4xl md:text-5xl font-black text-[#F5F5FA] tracking-tight mb-4">
            Ένα app.{' '}
            <span style={{ background: 'linear-gradient(135deg, #4452D8, #C52473)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent', backgroundClip: 'text' }}>
              Για όλους.
            </span>
          </h2>
          <p className="text-[#A7ABBE] text-lg max-w-xl mx-auto">
            Ασκούμενος, προπονητής, ιδιοκτήτης χώρου — το OmniPlex προσαρμόζεται στον ρόλο σου.
          </p>
        </FadeUp>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
          {PERSONAS.map((persona) => (
            <PersonaCard key={persona.id} persona={persona} />
          ))}
        </div>
      </div>
    </section>
  )
}

function PersonaCard({ persona }: { persona: typeof PERSONAS[0] }) {
  return (
    <div
      data-reveal
      className="group relative overflow-hidden rounded-2xl cursor-pointer"
      style={{ height: 520 }}
    >
      <Image
        src={persona.photo}
        alt={persona.badge}
        fill
        className="object-cover transition-transform duration-700 group-hover:scale-105"
        sizes="(max-width: 768px) 100vw, 33vw"
      />

      <div className="absolute inset-0 bg-gradient-to-t from-[#090A0F] via-[#090A0F]/55 to-transparent" />
      <div
        className="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-300"
        style={{ background: `linear-gradient(to top, ${persona.color}28, transparent)` }}
      />

      <div className="absolute top-5 left-5">
        <span
          className="px-3 py-1.5 rounded-full text-xs font-semibold text-white backdrop-blur-sm"
          style={{ background: `${persona.color}CC`, border: `1px solid ${persona.color}` }}
        >
          {persona.badge}
        </span>
      </div>

      <div className="absolute bottom-0 left-0 right-0 p-6">
        <h3 className="text-2xl font-black text-white leading-tight mb-3">
          {persona.headline}
        </h3>

        <ul className="space-y-1.5 mb-5">
          {persona.bullets.map((b) => (
            <li key={b} className="flex items-start gap-2">
              <Check size={13} className="mt-0.5 flex-shrink-0" style={{ color: persona.color }} />
              <span className="text-sm text-white/80 leading-tight">{b}</span>
            </li>
          ))}
        </ul>

        {persona.ctaType === 'modal' ? (
          <button
            type="button"
            onClick={() => window.dispatchEvent(new CustomEvent('open-demo-modal'))}
            className="group/btn inline-flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-semibold text-white transition-all duration-200 hover:opacity-90"
            style={{ background: `linear-gradient(135deg, ${persona.color}, #C52473)` }}
          >
            {persona.ctaLabel}
            <ArrowRight size={14} className="group-hover/btn:translate-x-0.5 transition-transform" />
          </button>
        ) : (
          <Link
            href={persona.ctaHref}
            className="group/btn inline-flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-semibold text-white transition-all duration-200 hover:opacity-90"
            style={{ background: `${persona.color}CC`, border: `1px solid ${persona.color}80` }}
          >
            {persona.ctaLabel}
            <ArrowRight size={14} className="group-hover/btn:translate-x-0.5 transition-transform" />
          </Link>
        )}
      </div>
    </div>
  )
}
