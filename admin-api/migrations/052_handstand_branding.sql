-- Rename demo gym branding to Handstand and set logo
UPDATE businesses
SET name = 'Handstand', slug = 'handstand'
WHERE id = 'demo-business-id' AND (name = 'Demo Gym' OR slug = 'demo-gym');

UPDATE business_configs
SET
  app_name = 'Handstand',
  logo_url = '/uploads/demo-business-id/logo/handstand.png',
  bundle_id = COALESCE(NULLIF(bundle_id, ''), 'com.handstand.app'),
  android_package = COALESCE(NULLIF(android_package, ''), 'com.handstand.app')
WHERE business_id = 'demo-business-id'
  AND (app_name IN ('BookUp Demo', 'Demo Gym') OR logo_url IS NULL);
