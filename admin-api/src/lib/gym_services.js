const NUTRITION_CATEGORIES = ['nutrition', 'nutrition_consultation'];

function isGymServiceCategory(category) {
  return !category || !NUTRITION_CATEGORIES.includes(category);
}

/** SQL fragment: alias.category NOT nutrition* */
function sqlGymServiceCategories(alias = 'sv') {
  const col = alias ? `${alias}.category` : 'category';
  return `(${col} IS NULL OR ${col} NOT IN ('nutrition', 'nutrition_consultation'))`;
}

module.exports = {
  NUTRITION_CATEGORIES,
  isGymServiceCategory,
  sqlGymServiceCategories,
};
