/** SQL fragments for gym-facing staff (excludes nutritionist shadow records & general pool). */
const GYM_STAFF_WHERE = 'business_id = ? AND is_active = 1 AND COALESCE(is_general_pool, 0) = 0 AND COALESCE(is_nutritionist, 0) = 0';

const GYM_STAFF_WHERE_ALIAS = 's.business_id = ? AND s.is_active = 1 AND COALESCE(s.is_general_pool, 0) = 0 AND COALESCE(s.is_nutritionist, 0) = 0';

module.exports = {
  GYM_STAFF_WHERE,
  GYM_STAFF_WHERE_ALIAS,
};
