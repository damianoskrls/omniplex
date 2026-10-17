import Nav from '@/components/nav'
import DemoModal from '@/components/ui/demo-modal'
import Hero from '@/components/sections/hero'
import HowItWorks from '@/components/sections/how-it-works'
import Features from '@/components/sections/features'
import Comparison from '@/components/sections/comparison'
import AppShowcase from '@/components/sections/app-showcase'
import Stats from '@/components/sections/stats'
import Testimonials from '@/components/sections/testimonials'
import Pricing from '@/components/sections/pricing'
import DemoCta from '@/components/sections/demo-cta'
import Footer from '@/components/sections/footer'

export default function Home() {
  return (
    <main className="min-h-screen bg-bg">
      <Nav />
      <Hero />
      <HowItWorks />
      <Features />
      <Comparison />
      <AppShowcase />
      <Stats />
      <Testimonials />
      <Pricing />
      <DemoCta />
      <Footer />
      <DemoModal />
    </main>
  )
}
