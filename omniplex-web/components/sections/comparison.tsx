'use client'

import { Check, X } from 'lucide-react'
import { FadeUp } from '@/components/ui/motion-wrapper'

const FEATURES = [
  {
    label: 'Εφαρμογές για κάθε ρόλο (ιδιοκτήτης, μέλος, προπονητής, διατροφολόγος)',
    us: true,
    them: false,
  },
  {
    label: 'AI agent για αυτόματη διαχείριση κρατήσεων',
    us: true,
    them: false,
  },
  {
    label: 'Social network & κοινωνικό feed εντός της εφαρμογής',
    us: true,
    them: false,
  },
  {
    label: 'Marketplace υπηρεσιών fitness',
    us: true,
    them: false,
  },
  {
    label: 'iOS & Android app από την 1η μέρα — χωρίς ετήσιο συμβόλαιο',
    us: true,
    them: false,
  },
  {
    label: 'Multi-branch υποστήριξη χωρίς extra κόστος',
    us: true,
    them: false,
  },
  {
    label: 'Ελληνική γλώσσα & υποστήριξη',
    us: true,
    them: true,
  },
]

export default function Comparison() {
  return (
    <section className="py-24 md:py-32 relative overflow-hidden">
      {/* Subtle gradient tint */}
      <div
        className="absolute inset-0 pointer-events-none opacity-[0.03]"
        style={{ background: 'linear-gradient(135deg, #4452D8, #C52473)' }}
      />

      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">

        <FadeUp className="text-center mb-14">
          <p className="text-sm font-semibold text-[#9A9DFF] uppercase tracking-widest mb-3">Γιατί OmniPlex</p>
          <h2 className="text-4xl md:text-5xl font-black text-[#F5F5FA] tracking-tight mb-4">
            Ένα ecosystem,<br />
            <span style={{ background: 'linear-gradient(135deg, #4452D8, #C52473)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent', backgroundClip: 'text' }}>
              όχι απλώς ένα εργαλείο.
            </span>
          </h2>
          <p className="text-[#A7ABBE] text-lg max-w-md mx-auto">
            Συγκρίνετε μόνοι σας.
          </p>
        </FadeUp>

        <FadeUp>
          <div className="rounded-2xl border border-[#2B2E3D] overflow-hidden">

            {/* Table header */}
            <div className="grid grid-cols-[1fr_120px_120px] px-6 py-4 bg-[#14161F] border-b border-[#2B2E3D]">
              <div />
              <div className="text-center">
                <span
                  className="text-sm font-bold"
                  style={{
                    background: 'linear-gradient(135deg, #4452D8, #C52473)',
                    WebkitBackgroundClip: 'text',
                    WebkitTextFillColor: 'transparent',
                    backgroundClip: 'text',
                  }}
                >
                  OmniPlex
                </span>
              </div>
              <div className="text-center text-sm text-[#6B7280] font-medium">Οι υπόλοιποι</div>
            </div>

            {/* Feature rows */}
            {FEATURES.map((f, i) => (
              <div
                key={i}
                className="grid grid-cols-[1fr_120px_120px] px-6 py-4 border-b border-[#1E2130] last:border-0 hover:bg-[#14161F]/60 transition-colors duration-200"
              >
                <span className="text-sm text-[#F5F5FA] pr-6 leading-snug self-center">{f.label}</span>
                <div className="flex justify-center items-center">
                  {f.us
                    ? <div className="w-6 h-6 rounded-full flex items-center justify-center" style={{ background: '#8DE2BB20' }}>
                        <Check size={14} className="text-[#8DE2BB]" />
                      </div>
                    : <X size={16} className="text-[#6B7280]" />
                  }
                </div>
                <div className="flex justify-center items-center">
                  {f.them
                    ? <div className="w-6 h-6 rounded-full flex items-center justify-center" style={{ background: '#6B728020' }}>
                        <Check size={14} className="text-[#6B7280]" />
                      </div>
                    : <X size={16} className="text-[#C52473]/60" />
                  }
                </div>
              </div>
            ))}
          </div>
        </FadeUp>

        {/* Footnote */}
        <FadeUp delay={0.15} className="mt-6 text-center">
          <p className="text-xs text-[#6B7280]">
            Βάσει δημόσιων πληροφοριών ανταγωνιστών · Οκτ. 2026 ·{' '}
            Τιμή ανταγωνιστών: €25–150+/μήνα ·{' '}
            <a href="#pricing" className="text-[#9A9DFF] hover:underline transition-colors">
              Δείτε τα πακέτα OmniPlex
            </a>
          </p>
        </FadeUp>
      </div>
    </section>
  )
}
