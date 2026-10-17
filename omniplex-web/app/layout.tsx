import type { Metadata } from 'next'
import './globals.css'
import CinemaProvider from '@/components/providers/cinema-provider'

export const metadata: Metadata = {
  title: 'OmniPlex — Ένα σύστημα για κάθε ρόλο στο γυμναστήριο',
  description: 'Διαχείριση γυμναστηρίου, κρατήσεις και προπόνηση — συγχρονισμένα σε μία εφαρμογή. Για ιδιοκτήτες, μέλη, προπονητές και διατροφολόγους.',
  keywords: 'γυμναστήριο, κρατήσεις, fitness, διαχείριση, personal training, OmniPlex',
  openGraph: {
    title: 'OmniPlex — Ένα σύστημα για κάθε ρόλο στο γυμναστήριο',
    description: 'Διαχείριση γυμναστηρίου, κρατήσεις και προπόνηση — συγχρονισμένα σε μία εφαρμογή.',
    locale: 'el_GR',
    type: 'website',
  },
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="el" className="dark">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
      </head>
      <body className="bg-bg text-text antialiased">
        <CinemaProvider>
          {children}
        </CinemaProvider>
      </body>
    </html>
  )
}
