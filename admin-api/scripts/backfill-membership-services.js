require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const db = require('../src/db');

(async () => {
  const [result] = await db.query(`
    UPDATE user_memberships um
    JOIN service_plan_assignments spa ON spa.plan_id = um.plan_id
    JOIN services s ON s.id = spa.service_id
    SET
        um.service_id       = spa.service_id,
        um.service_category = s.category
    WHERE um.plan_id IS NOT NULL
      AND um.service_id IS NULL
  `);
  console.log('Backfill OK, rows affected:', result.affectedRows);
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
