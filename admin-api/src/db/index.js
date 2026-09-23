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
  charset:         'UTF8MB4_UNICODE_CI',
  waitForConnections: true,
  connectionLimit:    10,
  queueLimit:         0,
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
