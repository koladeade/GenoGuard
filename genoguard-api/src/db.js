const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  // Render's managed Postgres requires SSL for external connections
  ssl: process.env.DATABASE_URL && !/localhost|127\.0\.0\.1/.test(process.env.DATABASE_URL)
    ? { rejectUnauthorized: false }
    : false,
});

module.exports = { query: (text, params) => pool.query(text, params), pool };