const router = require('express').Router();
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { z } = require('zod');
const db = require('../db');
const { sendResetCode } = require('../mail');

const CONSENT_VERSION = '1.0';
const GENOTYPES = ['AA', 'AS', 'AC', 'SS', 'SC', 'CC'];
const REFRESH_DAYS = Number(process.env.REFRESH_TTL_DAYS || 30);

const sha = (s) => crypto.createHash('sha256').update(s).digest('hex');
const roleFor = (hasScd) => (hasScd ? 'patient' : 'explorer');

const email = z.string().trim().toLowerCase().email().max(254);
const password = z.string().min(8, 'Password must be at least 8 characters').max(72);

const registerSchema = z
  .object({
    email,
    password,
    has_scd: z.boolean(),
    genotype: z.enum(GENOTYPES).optional(),
    location: z.string().trim().max(120).optional(),
    consent: z.literal(true, { errorMap: () => ({ message: 'Consent is required' }) }),
    consent_version: z.string(),
  })
  .refine((d) => !d.has_scd || ['SS', 'SC'].includes(d.genotype), {
    message: 'The patient side is for people living with SS or SC',
    path: ['genotype'],
  })
  .refine((d) => d.consent_version === CONSENT_VERSION, {
    message: 'Please review the latest consent text',
    path: ['consent_version'],
  });

function parse(schema, body, res) {
  const r = schema.safeParse(body);
  if (!r.success) {
    res.status(400).json({ error: r.error.issues[0].message });
    return null;
  }
  return r.data;
}

const publicUser = (u) => ({
  id: u.id,
  email: u.email,
  role: u.role,
  has_scd: u.has_scd,
  genotype: u.genotype,
  location: u.location,
});

async function issueTokens(user) {
  const access_token = jwt.sign({ sub: user.id, role: user.role }, process.env.JWT_SECRET, {
    algorithm: 'HS256',
    expiresIn: process.env.ACCESS_TTL || '15m',
  });
  const refresh_token = crypto.randomBytes(48).toString('hex');
  await db.query(
    `INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
     VALUES ($1, $2, now() + ($3 || ' days')::interval)`,
    [user.id, sha(refresh_token), String(REFRESH_DAYS)]
  );
  return { access_token, refresh_token, user: publicUser(user) };
}

router.post('/register', async (req, res) => {
  const d = parse(registerSchema, req.body, res);
  if (!d) return;
  const exists = await db.query('SELECT 1 FROM users WHERE email = $1', [d.email]);
  if (exists.rowCount) return res.status(409).json({ error: 'An account with this email already exists' });
  const hash = await bcrypt.hash(d.password, 12);
  const { rows } = await db.query(
    `INSERT INTO users (email, password_hash, role, has_scd, genotype, location, consent_version, consented_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7, now()) RETURNING *`,
    [d.email, hash, roleFor(d.has_scd), d.has_scd, d.genotype ?? null, d.location ?? null, d.consent_version]
  );
  res.status(201).json(await issueTokens(rows[0]));
});

router.post('/login', async (req, res) => {
  const d = parse(z.object({ email, password: z.string().min(1).max(72) }), req.body, res);
  if (!d) return;
  const { rows } = await db.query('SELECT * FROM users WHERE email = $1', [d.email]);
  const ok = rows[0] && (await bcrypt.compare(d.password, rows[0].password_hash));
  if (!ok) return res.status(401).json({ error: 'Incorrect email or password' });
  res.json(await issueTokens(rows[0]));
});

// Rotating refresh tokens. Re-using an already-rotated token revokes every session for that user.
router.post('/refresh', async (req, res) => {
  const d = parse(z.object({ refresh_token: z.string().min(10) }), req.body, res);
  if (!d) return;
  const { rows } = await db.query('SELECT * FROM refresh_tokens WHERE token_hash = $1', [sha(d.refresh_token)]);
  const t = rows[0];
  if (!t || new Date(t.expires_at) < new Date()) return res.status(401).json({ error: 'Session expired' });
  if (t.revoked_at) {
    await db.query('UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL', [t.user_id]);
    return res.status(401).json({ error: 'Session expired' });
  }
  await db.query('UPDATE refresh_tokens SET revoked_at = now() WHERE id = $1', [t.id]);
  const u = await db.query('SELECT * FROM users WHERE id = $1', [t.user_id]);
  if (!u.rows[0]) return res.status(401).json({ error: 'Session expired' });
  res.json(await issueTokens(u.rows[0]));
});

router.post('/logout', async (req, res) => {
  const rt = req.body && req.body.refresh_token;
  if (typeof rt === 'string') {
    await db.query('UPDATE refresh_tokens SET revoked_at = now() WHERE token_hash = $1 AND revoked_at IS NULL', [sha(rt)]);
  }
  res.status(204).end();
});

// Always answers 200 so the endpoint can't be used to find out which emails are registered.
router.post('/forgot-password', async (req, res) => {
  const d = parse(z.object({ email }), req.body, res);
  if (!d) return;
  const { rows } = await db.query('SELECT id FROM users WHERE email = $1', [d.email]);
  if (rows[0]) {
    const code = String(crypto.randomInt(100000, 1000000));
    await db.query('UPDATE password_resets SET used_at = now() WHERE user_id = $1 AND used_at IS NULL', [rows[0].id]);
    await db.query(
      `INSERT INTO password_resets (user_id, code_hash, expires_at) VALUES ($1, $2, now() + interval '15 minutes')`,
      [rows[0].id, sha(code)]
    );
    try {
      await sendResetCode(d.email, code);
    } catch (e) {
      console.error('reset email failed', e.message);
    }
  }
  res.json({ ok: true });
});

router.post('/reset-password', async (req, res) => {
  const d = parse(
    z.object({ email, code: z.string().regex(/^\d{6}$/, 'Enter the 6-digit code'), new_password: password }),
    req.body,
    res
  );
  if (!d) return;
  const bad = () => res.status(400).json({ error: 'Invalid or expired code' });
  const u = await db.query('SELECT id FROM users WHERE email = $1', [d.email]);
  if (!u.rows[0]) return bad();
  const { rows } = await db.query(
    `SELECT * FROM password_resets
     WHERE user_id = $1 AND used_at IS NULL AND expires_at > now()
     ORDER BY created_at DESC LIMIT 1`,
    [u.rows[0].id]
  );
  const r = rows[0];
  if (!r || r.attempts >= 5) return bad();
  const match = crypto.timingSafeEqual(Buffer.from(sha(d.code)), Buffer.from(r.code_hash));
  if (!match) {
    await db.query('UPDATE password_resets SET attempts = attempts + 1 WHERE id = $1', [r.id]);
    return bad();
  }
  const hash = await bcrypt.hash(d.new_password, 12);
  await db.query('UPDATE users SET password_hash = $1, updated_at = now() WHERE id = $2', [hash, u.rows[0].id]);
  await db.query('UPDATE password_resets SET used_at = now() WHERE id = $1', [r.id]);
  await db.query('UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL', [u.rows[0].id]);
  res.json({ ok: true });
});

module.exports = router;
module.exports.publicUser = publicUser;
module.exports.roleFor = roleFor;
module.exports.GENOTYPES = GENOTYPES;