USE bookup;

INSERT IGNORE INTO business_plans (id, business_id, name, sessions, price_cents, billing_period, sort_order, is_active)
VALUES ('demo-plan-fitness', 'demo-business-id', 'Fitness Unlimited', NULL, 5000, 'monthly', 4, 1);

DELETE FROM service_plan_assignments
WHERE service_id = 'demo-svc-fitness' AND plan_id = 'demo-plan-yoga-unl';

INSERT IGNORE INTO service_plan_assignments (service_id, plan_id)
VALUES ('demo-svc-fitness', 'demo-plan-fitness');
