// ============================================================
// FILE: src/db/index.js
// MySQL connection pool — used by all routes
// ============================================================

const mysql = require('mysql2/promise');
require('dotenv').config();

const pool = mysql.createPool({
  host:            process.env.DB_HOST     || 'localhost',
  port:            process.env.DB_PORT     || 3306,
  user:            process.env.DB_USER     || 'root',
  password:        process.env.DB_PASSWORD || '',
  database:        process.env.DB_NAME     || 'bookup',
  charset:         'utf8mb4',
  waitForConnections: true,
  connectionLimit:    10,
  queueLimit:         0,
});

// Match schema.sql / app tables (utf8mb4_unicode_ci). A 0900 connection collation
// makes JOINs fail when bootstrap tables (global_users, gym_join_requests) were
// created as utf8mb4_0900_ai_ci and businesses/users are utf8mb4_unicode_ci.
pool.on('connection', (connection) => {
  connection.query("SET NAMES 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'");
});

// Keep retrying. A DNS failure (EAI_AGAIN on mysql.railway.internal) used to
// call process.exit, so Railway restarted the container in a loop and the
// browser showed a CORS error. The process now stays up until MySQL answers.
async function waitForDatabase() {
  let attempt = 0;
  for (;;) {
    try {
      const conn = await pool.getConnection();
      console.log('✓ Database connected');
      conn.release();
      return;
    } catch (err) {
      attempt += 1;
      const delay = Math.min(15000, 1000 * attempt);
      console.error(`✗ Database connection failed (attempt ${attempt}):`, err.message || String(err));
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }
}

waitForDatabase();

module.exports = pool;
