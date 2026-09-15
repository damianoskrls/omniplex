USE bookup;

-- Restore correct demo plan names & service links (were swapped in admin edits)
UPDATE business_plans SET
  name = 'PT 8 συνεδρίες/μήνα',
  sessions = 8,
  price_cents = 8000
WHERE id = 'demo-plan-pt-8' AND business_id = 'demo-business-id';

UPDATE business_plans SET
  name = 'Yoga Unlimited',
  sessions = NULL,
  price_cents = 4500
WHERE id = 'demo-plan-yoga-unl' AND business_id = 'demo-business-id';

UPDATE business_plans SET
  name = 'Pilates 6/μήνα',
  sessions = 6,
  price_cents = 5500
WHERE id = 'demo-plan-pilates' AND business_id = 'demo-business-id';

UPDATE business_plans SET
  name = 'Fitness Unlimited',
  sessions = NULL,
  price_cents = 5000
WHERE id = 'demo-plan-fitness' AND business_id = 'demo-business-id';

DELETE FROM service_plan_assignments
WHERE service_id IN ('demo-svc-pt', 'demo-svc-yoga', 'demo-svc-pilates', 'demo-svc-fitness');

INSERT IGNORE INTO service_plan_assignments (service_id, plan_id) VALUES
  ('demo-svc-pt',      'demo-plan-pt-8'),
  ('demo-svc-yoga',    'demo-plan-yoga-unl'),
  ('demo-svc-pilates', 'demo-plan-pilates'),
  ('demo-svc-fitness', 'demo-plan-fitness');

-- Unlimited plans → 9999 sessions in memberships
UPDATE user_memberships m
JOIN business_plans bp ON bp.id = m.plan_id
SET m.total_sessions = 9999
WHERE m.business_id = 'demo-business-id'
  AND bp.sessions IS NULL
  AND m.total_sessions < 9999;
