require('dotenv').config();
const fs = require('fs');
const path = require('path');
const db = require('./db');

(async () => {
  await db.query(fs.readFileSync(path.join(__dirname, '..', 'schema.sql'), 'utf8'));
  console.log('Schema applied');
  await db.pool.end();
})().catch((e) => {
  console.error(e);
  process.exit(1);
});