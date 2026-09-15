const PREP_BY_ICON = {
  cross_training: [
    'Φέρε πετσέτα και μπουκάλι νερό',
    'Φάε ελαφρύ γεύμα 1–2 ώρες πριν',
    'Αποφυγε βαριά γεύματα αμέσως πριν την προπόνηση',
  ],
  strength: [
    'Φέρε πετσέτα και μπουκάλι νερό',
    'Φάε ελαφρύ γεύμα 1–2 ώρες πριν',
    'Άφησε 30 λεπτά μετά το φαγητό πριν την προπόνηση',
  ],
  trx: [
    'Φέρε πετσέτα και μπουκάλι νερό',
    'Φάε ελαφρά 60–90 λεπτά πριν',
  ],
  pilates: [
    'Φέρε πετσέτα (υποχρεωτική)',
    'Μπουκάλι νερό',
    'Φάε ελαφρά 1 ώρα πριν — όχι γεμάτο στομάχι',
  ],
  yoga: [
    'Φέρε πετσέτα και μπουκάλι νερό',
    'Φάε ελαφρό γεύμα 1–2 ώρες πριν',
    'Αποφυγε βαριά γεύματα 2 ώρες πριν',
  ],
  cycling: [
    'Φέρε πετσέτα και μπουκάλι νερό',
    'Φάε ελαφρό σνακ 45–60 λεπτά πριν',
    'Έλεγξε ότι έχεις φαγωθεί αρκετά — το cardio απαιτεί ενέργεια',
  ],
  hiit: [
    'Φέρε πετσέτα και μπουκάλι νερό',
    'Φάε ελαφρά 1–2 ώρες πριν',
    'Αν δεν έχεις φάει, πάρε μισή μπανάνα 30 λεπτά πριν',
  ],
  stretching: [
    'Φέρε πετσέτα και μπουκάλι νερό',
    'Καλύτερα με άδειο ή ελαφρώς γεμάτο στομάχι',
  ],
};

const POST_BY_ICON = {
  cross_training: [
    'Πιες νερό μέσα στα επόμενα 15 λεπτά',
    'Φάε πρωτεΐνη εντός 30–60 λεπτών (γιαούρτι, αυγό ή shake)',
    '5 λεπτά διατάσεις για αποκατάσταση',
    'Καλή ξεκούραση — το σώμα χτίζεται στην ανάκαμψη!',
  ],
  strength: [
    'Πρωτεΐνη + υδατάνθρακες εντός 1 ώρας (κοτόπουλο, ρύζι, γιαούρτι)',
    'Πιες αρκετά νερά',
    'Διατάσεις στις μυικές ομάδες που δούλεψες',
    'Κοιμήσου καλά απόψε — η μυϊκή ανάπτυξη γίνεται στον ύπνο',
  ],
  pilates: [
    'Πιες νερό αργά-αργά',
    'Ελαφρό σνακ με πρωτεΐνη αν πείνασες',
    '3–5 λεπτά διατάσεις core',
    'Απόφυγε έντονη καταπίεση αμέσως μετά',
  ],
  yoga: [
    'Πιες νερό ή ρόφημα χωρίς ζάχαρη',
    'Φάε ελαφρά 30–45 λεπτά μετά αν χρειάζεται',
    'Κράτησε την ηρεμία — αποφυγε έντονη άσκηση 1–2 ώρες',
  ],
  cycling: [
    'Αναπλήρωσε υγρά και ηλεκτρολύτες',
    'Φάε υδατάνθρακες + πρωτεΐνη (π.χ. σάντουιτς με γαλοπούλα)',
    'Διατάσεις ποδιών και γοφών',
  ],
  hiit: [
    'Πιες νερό σταδιακά — όχι όλο μαζί',
    'Πρωτεΐνη εντός 45 λεπτών για αποκατάσταση',
    'Καλή ξεκούραση — το HIIT καταπονεί το νευρικό σύστημα',
  ],
  stretching: [
    'Πιες νερό',
    'Κράτησε χαλαρή στάση 10–15 λεπτά',
    'Ιδανικό μετά: βόλτα ή ελαφρό γεύμα',
  ],
};

const GENERIC_PREP = [
  'Φέρε πετσέτα και μπουκάλι νερό',
  'Φάε ελαφρύ γεύμα 1–2 ώρες πριν',
  'Άφησε 30 λεπτά μετά το φαγητό πριν την προπόνηση',
];

const GENERIC_POST = [
  'Πιες νερό μέσα στα επόμενα 15 λεπτά',
  'Φάε πρωτεΐνη εντός 30–60 λεπτών',
  'Κάνε 5 λεπτά διατάσεις',
  'Ξεκούραση — η πρόοδος έρχεται με συνέπεια!',
];

const NUTRITION_PREP = [
  'Φέρε πρόσφατες μετρήσεις ή φωτογραφίες πρόοδου αν έχεις',
  'Σημείωσε τι έφαγες τις τελευταίες 24 ώρες',
  'Έλα 5 λεπτά νωρίτερα',
];

const NUTRITION_POST = [
  'Ακολούθησε τις οδηγίες του διατροφολόγου',
  'Καταχώρησε τα γεύματα της ημέρας στην εφαρμογή',
  'Πιες αρκετά νερά',
];

function parseTipsText(text) {
  if (!text || !String(text).trim()) return [];
  return String(text)
    .split('\n')
    .map(s => s.trim())
    .filter(Boolean);
}

/** Αφαιρεί οδηγίες για ρούχα/παπούτσια — κρατά βασικά (πετσέτα, νερό, φαγητό) */
const CLOTHING_PREP_PATTERN = /φόρα|κολλάν|κάλτσ|παπούτσ|ρούχ|ματ\b|μαγιό/i;

function filterBasicPrepTips(tips) {
  const list = Array.isArray(tips) ? tips : [];
  const filtered = list.filter((t) => !CLOTHING_PREP_PATTERN.test(t));
  if (filtered.length >= 2) return filtered;
  return [
    'Φέρε πετσέτα και μπουκάλι νερό',
    'Φάε ελαφρύ γεύμα 1–2 ώρες πριν',
  ];
}

function firstNameFromFull(fullName) {
  const name = String(fullName || '').trim().split(/\s+/)[0];
  return name || 'Φίλε';
}

function resolveTips(schedule, iconKey, { serviceCategory = null } = {}) {
  const prepRaw = parseTipsText(schedule?.preparation_tips);
  const post = parseTipsText(schedule?.post_workout_tips);
  const key = iconKey || schedule?.icon_key;
  const isNutrition = serviceCategory === 'nutrition_consultation';

  const prepBase = prepRaw.length
    ? prepRaw
    : (isNutrition ? NUTRITION_PREP : (PREP_BY_ICON[key] || GENERIC_PREP));

  return {
    preparation_tips: isNutrition ? prepBase : filterBasicPrepTips(prepBase),
    post_workout_tips: post.length
      ? post
      : (isNutrition ? NUTRITION_POST : (POST_BY_ICON[key] || GENERIC_POST)),
    label: schedule?.label || null,
    room_name: schedule?.room_name || null,
    icon_key: key || null,
  };
}

module.exports = {
  PREP_BY_ICON,
  POST_BY_ICON,
  NUTRITION_PREP,
  NUTRITION_POST,
  parseTipsText,
  filterBasicPrepTips,
  firstNameFromFull,
  resolveTips,
};
