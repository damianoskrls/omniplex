import type { Metadata } from 'next'
import Nav from '@/components/nav'
import DemoModal from '@/components/ui/demo-modal'
import RoleHero from '@/components/sections/role-hero'
import RoleSection from '@/components/sections/role-section'
import DemoCta from '@/components/sections/demo-cta'
import Footer from '@/components/sections/footer'
import { ROLES } from '@/lib/constants'

export const metadata: Metadata = {
  title: 'Ρόλοι | OmniPlex — Εφαρμογή για κάθε ρόλο στο γυμναστήριο',
  description:
    'Ιδιοκτήτης, μέλος, προπονητής, διατροφολόγος — το OmniPlex έχει native iOS & Android app για κάθε ρόλο. Δείτε τι κερδίζει ο καθένας.',
  openGraph: {
    title: 'Οι Ρόλοι του OmniPlex',
    description: 'Κάθε ρόλος έχει το δικό του app — σχεδιασμένο ακριβώς για εκείνον.',
  },
}

const DISPLAY_ROLES = ROLES.filter((r) => !r.isRequest)

export default function RolesPage() {
  return (
    <main className="min-h-screen bg-[#090A0F]">
      <Nav />
      <RoleHero />
      {DISPLAY_ROLES.map((role, i) => (
        <RoleSection key={role.id} role={role} index={i} />
      ))}
      <DemoCta />
      <Footer />
      <DemoModal />
    </main>
  )
}
