// In-memory Postgres loaded with the project's real schema SQL (any schema*.sql file found).
const { newDb, DataType } = require('pg-mem');
const fs = require('fs');
const path = require('path');

const mem = newDb();
mem.public.registerFunction({
  name: 'gen_random_uuid', returns: DataType.uuid, impure: true,
  implementation: () => require('crypto').randomUUID(),
});
mem.public.registerFunction({
  name: 'char_length', args: [DataType.text], returns: DataType.integer,
  implementation: (s) => s.length,
});

// A trimmed users table: only the columns the tested routes read. The project's own
// CREATE TABLE users is skipped (it already exists here); later ALTERs still apply.
mem.public.none(`
  CREATE TABLE users (
    id uuid PRIMARY KEY, email text, full_name text, genotype text, role text,
    created_at timestamptz DEFAULT now(), usage_logs_consent boolean DEFAULT false
  );
  CREATE TABLE refresh_tokens (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid, revoked_at timestamptz
  );`);

const apiRoot = path.join(__dirname, '..', '..');

function findSchemaFiles(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.name === 'node_modules' || e.name.startsWith('.')) continue;
    const full = path.join(dir, e.name);
    if (e.isDirectory()) findSchemaFiles(full, out);
    else if (/^schema.*\.sql$/.test(e.name)) out.push(full);
  }
  return out;
}

// Split into statements and run each one; skip ones pg-mem cannot run (extensions, users/refresh
// table definitions, unsupported index types). The check below proves the tables we need exist.
const SKIP = /^\s*(CREATE\s+EXTENSION|CREATE\s+TABLE\s+(IF\s+NOT\s+EXISTS\s+)?(users|refresh_tokens)\b)/i;
for (const file of findSchemaFiles(apiRoot).sort()) {
  const sql = fs.readFileSync(file, 'utf8').replace(/--.*$/gm, '');
  for (const stmt of sql.split(';').map((s) => s.trim()).filter(Boolean)) {
    if (SKIP.test(stmt)) continue;
    try { mem.public.none(stmt); } catch (_) { /* unsupported by pg-mem; not needed for tests */ }
  }
}

const REQUIRED = ['posts', 'comments', 'post_reports', 'comment_reports', 'quiz_responses',
                  'usage_events', 'qr_shares', 'admin_audit'];
const missing = REQUIRED.filter((t) => {
  try { mem.public.many(`SELECT 1 FROM ${t} LIMIT 1`); return false; } catch (_) { return true; }
});
if (missing.length) {
  throw new Error(`Schema is missing tables the tests need: ${missing.join(', ')}. ` +
                  'Add their CREATE TABLE statements to schema.sql.');
}

const { Pool } = mem.adapters.createPg();
module.exports = new Pool();