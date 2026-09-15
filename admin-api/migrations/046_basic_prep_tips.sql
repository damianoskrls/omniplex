-- Απλοποίηση οδηγιών προετοιμασίας: πετσέτα, νερό, ελαφρό φαγητό (χωρίς ρούχα/παπούτσια)

UPDATE service_slot_schedules
SET preparation_tips = 'Φέρε πετσέτα (υποχρεωτική)
Μπουκάλι νερό
Φάε ελαφρά 1 ώρα πριν — όχι γεμάτο στομάχι'
WHERE preparation_tips LIKE '%κολλάν%'
   OR preparation_tips LIKE '%κάλτσ%';

UPDATE service_slot_schedules
SET preparation_tips = 'Φέρε πετσέτα και μπουκάλι νερό
Φάε ελαφρύ γεύμα 1–2 ώρες πριν
Αποφυγε βαριά γεύματα αμέσως πριν'
WHERE preparation_tips LIKE '%παπούτσ%'
   OR preparation_tips LIKE '%Φόρα%';
