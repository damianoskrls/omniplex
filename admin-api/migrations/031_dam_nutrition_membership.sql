USE bookup;

-- dam@test.com needs an active nutrition plan membership for the mobile Διατροφή tab.
SET @dam_user_id = (
  SELECT id FROM users WHERE email = 'dam@test.com' AND business_id = 'demo-business-id' LIMIT 1
);

SET @nutrition_plan_id = (
  SELECT id FROM business_plans
  WHERE business_id = 'demo-business-id' AND plan_type = 'nutrition' AND is_active = 1
  ORDER BY sort_order, price_cents
  LIMIT 1
);

INSERT INTO user_memberships (
  id, user_id, business_id, plan_id, service_id, service_category,
  total_sessions, used_sessions, valid_from, valid_until, notes, membership_status
)
SELECT
  'dam-membership-nutrition',
  @dam_user_id,
  'demo-business-id',
  @nutrition_plan_id,
  NULL,
  'nutrition',
  9999,
  0,
  CURDATE(),
  DATE_ADD(CURDATE(), INTERVAL 6 MONTH),
  'Πακέτο διατροφής (demo)',
  'active'
FROM DUAL
WHERE @dam_user_id IS NOT NULL
  AND @nutrition_plan_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM user_memberships m
    JOIN business_plans p ON p.id = m.plan_id AND p.plan_type = 'nutrition'
    WHERE m.user_id = @dam_user_id
      AND m.business_id = 'demo-business-id'
      AND (m.valid_until IS NULL OR m.valid_until >= CURDATE())
  );

SELECT IF(
  @dam_user_id IS NULL,
  'dam@test.com not found — skipped',
  IF(
    @nutrition_plan_id IS NULL,
    'No active nutrition plan — create one in gym-admin first',
    'dam@test.com nutrition membership ensured'
  )
) AS info;
