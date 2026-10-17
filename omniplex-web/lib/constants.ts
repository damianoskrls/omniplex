export const ROLES = [
  {
    id: 'owner',
    label: 'Ιδιοκτήτης',
    icon: 'Building2',
    headline: 'Διαχειριστείτε. Αναλύστε. Κλιμακωθείτε.',
    description: 'Πλήρης εικόνα του γυμναστηρίου σας σε πραγματικό χρόνο.',
    bullets: [
      'Κρατήσεις και ακυρώσεις σε πραγματικό χρόνο',
      'AI analytics: προβλέψεις εσόδων και πρότυπα επισκεψιμότητας',
      'Marketplace: προβάλλετε υπηρεσίες και αυξήστε τα έσοδά σας',
      'Multi-branch χωρίς extra κόστος — μοναδικό στην Ελλάδα',
    ],
    color: '#4452D8',
  },
  {
    id: 'member',
    label: 'Μέλος',
    icon: 'User',
    headline: 'Βρες χώρο. Κλείσε θέση. Προπονήσου.',
    description: 'Κατέβασε το app, βρες γυμναστήριο κοντά σου και ξεκίνα — μέλος ή drop-in, αμέσως.',
    bullets: [
      'Βρες γυμναστήριο κοντά σου — γίνε μέλος ή κάνε drop-in αμέσως',
      'Ανήκεις σε πολλά γυμναστήρια ταυτόχρονα — ένα app για όλα',
      'AI agent: κλείνει θέση βάσει του προγράμματός σου αυτόματα',
      'Social feed, Marketplace & επικοινωνία με προπονητή',
    ],
    color: '#7B3EAD',
  },
  {
    id: 'trainer',
    label: 'Προπονητής',
    icon: 'Dumbbell',
    headline: 'Δούλεψε παντού. Διαχειρίσου τα πάντα.',
    description: 'Εργάζεσαι σε πολλά γυμναστήρια; Βλέπεις όλες τις κρατήσεις σου σε ένα μέρος.',
    bullets: [
      'Δουλεύεις σε πολλά γυμναστήρια — όλες οι κρατήσεις σε μία εικόνα',
      'Ταυτόχρονα προπονητής ΚΑΙ ασκούμενος — χωρίς δεύτερο app',
      'Marketplace προφίλ: νέοι πελάτες σε βρίσκουν εύκολα',
      'Ψηφιακά πρωτόκολλα άσκησης ανά αθλητή',
    ],
    color: '#A4308D',
  },
  {
    id: 'nutritionist',
    label: 'Διατροφολόγος',
    icon: 'Apple',
    headline: 'Η διατροφή των πελατών σας, σε μία πλατφόρμα.',
    description: 'Επαγγελματική διαχείριση συνεδριών και διατροφικών προγραμμάτων.',
    bullets: [
      'Ψηφιακά προγράμματα διατροφής ανά πελάτη',
      'Ιστορικό μετρήσεων, βάρους και προόδου',
      'Online ραντεβού και follow-up μηνυμάτων',
      'Marketplace listing: αναπτύξτε την πελατεία σας εντός του οικοσυστήματος',
    ],
    color: '#C52473',
  },
  {
    id: 'request',
    label: 'Ο ρόλος σας;',
    icon: 'Plus',
    headline: 'Ο επόμενος ρόλος είναι δικός σας.',
    description: 'Δουλεύετε σε γυμναστήριο με ρόλο που δεν βλέπετε εδώ; Ζητήστε ενσωμάτωση.',
    bullets: [],
    color: '#6B7280',
    isRequest: true,
  },
]

export const STATS = [
  { value: 40, suffix: '%', label: 'αύξηση κρατήσεων', prefix: '+' },
  { value: 3, suffix: 'ώρ/εβδ.', label: 'λιγότερη διαχείριση', prefix: '-' },
  { value: 500, suffix: '+', label: 'γυμναστήρια εμπιστεύονται', prefix: '' },
  { value: 98, suffix: '%', label: 'ικανοποίηση πελατών', prefix: '' },
]

export const TESTIMONIALS = [
  {
    quote: 'Από τη στιγμή που εφαρμόσαμε το OmniPlex, οι online κρατήσεις αυξήθηκαν 40% μέσα σε έναν μήνα. Δεν φανταζόμουν ότι η διαχείριση μπορούσε να είναι τόσο απλή.',
    author: 'Μανώλης Π.',
    role: 'Ιδιοκτήτης CrossFit Box',
    location: 'Αθήνα',
    initials: 'ΜΠ',
  },
  {
    quote: 'Διαχειρίζομαι 35 πελάτες χωρίς να χάνω τον ύπνο μου. Το ημερολόγιο, τα πρωτόκολλα, οι αποδοχές — όλα σε ένα μέρος. Τέλος στο chaos.',
    author: 'Σοφία Κ.',
    role: 'Personal Trainer',
    location: 'Θεσσαλονίκη',
    initials: 'ΣΚ',
  },
  {
    quote: 'Κλείνω θέση σε μάθημα σε 10 δευτερόλεπτα. Βλέπω το πρόγραμμά μου, επικοινωνώ με τον προπονητή μου. Δεν χρειάζομαι τίποτα άλλο.',
    author: 'Νίκος Δ.',
    role: 'Μέλος γυμναστηρίου',
    location: 'Αθήνα',
    initials: 'ΝΔ',
  },
]

export const PRICING_TIERS = [
  {
    name: 'Starter',
    monthlyPrice: 49,
    annualPrice: 39,
    description: 'Ιδανικό για μικρά γυμναστήρια που ξεκινούν.',
    features: [
      '1 κατάστημα · έως 150 μέλη',
      'Κρατήσεις, QR check-in & λίστα αναμονής',
      'Εβδομαδιαίο πρόγραμμα & χώροι',
      'App μελών (iOS & Android)',
      'Προπονητές & προγράμματα άσκησης',
      'Μηνύματα, ειδοποιήσεις & αξιολογήσεις',
      'Βασικά analytics & αναφορές',
    ],
    cta: 'Ξεκινήστε δωρεάν',
    highlighted: false,
  },
  {
    name: 'Pro',
    monthlyPrice: 89,
    annualPrice: 71,
    description: 'Το πλήρες οικοσύστημα — για γυμναστήρια που θέλουν τα πάντα.',
    features: [
      'Έως 5 καταστήματα · απεριόριστα μέλη',
      'Όλα του Starter',
      'Marketplace (προϊόντα, παραγγελίες, αποστολή)',
      'Εξτρά ρόλοι: διατροφολόγοι & ειδικοί',
      'App διατροφολόγου: μετρήσεις, διατροφολόγιο & άσκηση',
      'AI agent κρατήσεων · Κοινότητα & επιβράβευση',
      'Advanced analytics, Excel export & priority support',
    ],
    cta: 'Ξεκινήστε δωρεάν',
    highlighted: true,
    badge: 'Δημοφιλές',
  },
  {
    name: 'Enterprise',
    monthlyPrice: null,
    annualPrice: null,
    description: 'Για αλυσίδες γυμναστηρίων και franchise.',
    features: [
      'Απεριόριστα καταστήματα & μέλη',
      'Όλα του Pro',
      'White-label εφαρμογή',
      'Custom integrations & API access',
      'Dedicated account manager',
      'SLA 99.9% uptime',
    ],
    cta: 'Επικοινωνήστε μαζί μας',
    highlighted: false,
  },
]

export const NAV_LINKS = [
  { label: 'Δυνατότητες', href: '/#features' },
  { label: 'Ρόλοι', href: '/roles' },
  { label: 'Πακέτα', href: '/#pricing' },
  { label: 'Γιατί OmniPlex', href: '/#why' },
  { label: 'Επικοινωνία', href: '/contact' },
]
