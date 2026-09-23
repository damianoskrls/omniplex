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

// Test connection on startup
pool.getConnection()
  .then(conn => {
    console.log('✓ Database connected');
    conn.release();
  })
  .catch(err => {
    const msg = err.message || String(err);
    console.error('✗ Database connection failed:', msg || '(no details)');
    console.error('  → Έλεγξε ότι τρέχει MySQL: brew services start mysql');
    console.error('  → Μετά τρέξε: mysql -u root < schema.sql');
    process.exit(1);
  });

module.exports = pool;
