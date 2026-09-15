/** SQL φίλτρο: ενεργοί πελάτες (όχι στον κάδο). Χωρίς alias: deleted_at IS NULL */
function sqlActiveClients(alias = '') {
  const col = alias ? `${alias}.deleted_at` : 'deleted_at';
  return `${col} IS NULL`;
}

/** SQL φίλτρο: πελάτες στον κάδο */
function sqlTrashClients(alias = '') {
  const col = alias ? `${alias}.deleted_at` : 'deleted_at';
  return `${col} IS NOT NULL`;
}

module.exports = {
  sqlActiveClients,
  sqlTrashClients,
};
