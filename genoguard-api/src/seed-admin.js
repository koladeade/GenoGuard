require('dotenv').config();
const bcrypt = require('bcryptjs');
const db = require('./db');

(async () => {
  const email = (process.env.ADMIN_EMAIL || '').trim().toLowerCase();
  const pw = process.env.ADMIN_PASSWORD || '';
  if (!email || pw.length < 8) throw new Error('Set ADMIN_EMAIL and an ADMIN_PASSWORD of 8+ characters');
  const hash = await bcrypt.hash(pw, 12);
  await db.query(
    `INSERT INTO users (email, password_hash, role, has_scd, consent_version, consented_at)
     VALUES ($1,$2,'admin',false,'1.0', now())
     ON CONFLICT (email) DO UPDATE SET role='admin', password_hash=EXCLUDED.password_hash`,
    [email, hash]
  );
  console.log('Admin ready:', email);
  await db.pool.end();
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});