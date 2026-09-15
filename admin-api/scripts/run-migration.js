#!/usr/bin/env node
/**
 * Run a SQL migration using credentials from admin-api/.env
 * Usage: node scripts/run-migration.js migrations/042_locations_index_fix.sql
 */
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const file = process.argv[2];
if (!file) {
  console.error('Usage: node scripts/run-migration.js <path-to.sql>');
  process.exit(1);
}

const sqlPath = path.isAbsolute(file) ? file : path.join(__dirname, '..', file);
if (!fs.existsSync(sqlPath)) {
  console.error('File not found:', sqlPath);
  process.exit(1);
}

async function main() {
  const sql = fs.readFileSync(sqlPath, 'utf8');
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT) || 3306,
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'bookup',
    multipleStatements: true,
  });

  console.log(`Running ${path.basename(sqlPath)} as ${process.env.DB_USER}@${process.env.DB_HOST}/${process.env.DB_NAME}...`);
  await conn.query(sql);
  await conn.end();
  console.log('Done.');
}

main().catch((err) => {
  console.error('Migration failed:', err.message);
  process.exit(1);
});
