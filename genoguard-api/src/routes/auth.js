const router = require('express').Router();
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { z } = require('zod');
const { OAuth2Client } = require('google-auth-library');
const db = require('../db');
const { sendResetCode, sendWelcome } = require('../mail');

const CONSENT_VERSION = '1.0';
const GENOTYPES = ['AA', 'AS', 'AC', 'SS', 'SC'];
const REFRESH_DAYS = Number(process.env.REFRESH_TTL_DAYS || 30);

const DISABLED = 'This account has been disabled';
const sha = (s) => crypto.createHash('sha256').update(s).digest('hex');
const roleFor = (hasScd) => (hasScd ? 'patient' : 'explorer');

const email = z.string().trim().toLowerCase().email().max(254);
const password = z.string().min(8, 'Password must be at least 8 characters').max(72);
const fullName = z.string().trim().min(1, 'Enter your name').max(120);

const registerSchema = z
  .object({
    full_name: fullName,
    email,
    password,
    has_scd: z.boolean(),
    genotype: z.enum(GENOTYPES).optional(),
    location: z.string().trim().max(120).optional(),
    consent: z.literal(true, { errorMap: () => ({ message: 'Consent is required' }) }),
    consent_version: z.string(),
    usage_logs: z.boolean().optional(),
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
  full_name: u.full_name,
  role: u.role,
  has_scd: u.has_scd,
  genotype: u.genotype,
  location: u.location,
  has_password: !!u.password_hash,
  consent_version: u.consent_version, consented_at: u.consented_at, usage_logs_consent: !!u.usage_logs_consent,
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
    `INSERT INTO users (email, full_name, password_hash, role, has_scd, genotype, location,
                        consent_version, consented_at, usage_logs_consent)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8, now(), $9) RETURNING *`,
    [d.email, d.full_name, hash, roleFor(d.has_scd), d.has_scd, d.genotype ?? null, d.location ?? null,
     d.consent_version, d.usage_logs === true]
  );
  sendWelcome(rows[0]).catch((e) => console.error('welcome email failed', e.message));
  res.status(201).json(await issueTokens(rows[0]));
});

router.post('/login', async (req, res) => {
  const d = parse(z.object({ email, password: z.string().min(1).max(72) }), req.body, res);
  if (!d) return;
  const { rows } = await db.query('SELECT * FROM users WHERE email = $1', [d.email]);
  const u = rows[0];
  if (u && !u.password_hash) {
    return res.status(401).json({ error: 'This account uses Google sign-in. Tap Continue with Google.' });
  }
  const ok = u && (await bcrypt.compare(d.password, u.password_hash));
  if (!ok) return res.status(401).json({ error: 'Incorrect email or password' });
  if (u.disabled_at) return res.status(403).json({ error: DISABLED });
  res.json(await issueTokens(u));
});

// ---- Google sign-in -------------------------------------------------------
const googleClient = new OAuth2Client();
const googleAudiences = () =>
  (process.env.GOOGLE_CLIENT_IDS || '').split(',').map((s) => s.trim()).filter(Boolean);

const googleSchema = z.object({
  id_token: z.string().min(20),
  full_name: z.string().trim().max(120).optional(),
  has_scd: z.boolean().optional(),
  genotype: z.enum(GENOTYPES).optional(),
  location: z.string().trim().max(120).optional(),
  consent: z.boolean().optional(),
  consent_version: z.string().optional(),
  usage_logs: z.boolean().optional(),
});

router.post('/google', async (req, res) => {
  const d = parse(googleSchema, req.body, res);
  if (!d) return;

  const audience = googleAudiences();
  if (!audience.length) return res.status(503).json({ error: 'Google sign-in is not set up on the server yet' });

  let p;
  try {
    const ticket = await googleClient.verifyIdToken({ idToken: d.id_token, audience });
    p = ticket.getPayload();
  } catch {
    return res.status(401).json({ error: 'Google sign-in failed. Try again.' });
  }
  if (!p || !p.email || !p.email_verified) {
    return res.status(401).json({ error: 'Your Google email is not verified' });
  }
  const mail = p.email.toLowerCase();

  let found = await db.query('SELECT * FROM users WHERE google_id = $1', [p.sub]);
  if (found.rows[0]) {
    if (found.rows[0].disabled_at) return res.status(403).json({ error: DISABLED });
    return res.json(await issueTokens(found.rows[0]));
  }

  found = await db.query('SELECT * FROM users WHERE email = $1', [mail]);
  if (found.rows[0]) {
    if (found.rows[0].disabled_at) return res.status(403).json({ error: DISABLED });
    const linked = await db.query(
      'UPDATE users SET google_id = $1, full_name = COALESCE(full_name, $2), updated_at = now() WHERE id = $3 RETURNING *',
      [p.sub, p.name || null, found.rows[0].id]
    );
    return res.json(await issueTokens(linked.rows[0]));
  }

  if (d.has_scd === undefined) return res.json({ status: 'needs_profile', email: mail, name: p.name || '' });

  const name = (d.full_name || p.name || '').trim();
  if (!name) return res.status(400).json({ error: 'Enter your name' });
  if (d.consent !== true) return res.status(400).json({ error: 'Consent is required' });
  if (d.consent_version !== CONSENT_VERSION) {
    return res.status(400).json({ error: 'Please review the latest consent text' });
  }
  if (d.has_scd && !['SS', 'SC'].includes(d.genotype)) {
    return res.status(400).json({ error: 'The patient side is for people living with SS or SC' });
  }
  const { rows } = await db.query(
    `INSERT INTO users (email, full_name, google_id, role, has_scd, genotype, location,
                        consent_version, consented_at, usage_logs_consent)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8, now(), $9) RETURNING *`,
    [mail, name, p.sub, roleFor(d.has_scd), d.has_scd, d.genotype ?? null, d.location ?? null,
     d.consent_version, d.usage_logs === true]
  );
  sendWelcome(rows[0]).catch((e) => console.error('welcome email failed', e.message));
  res.status(201).json(await issueTokens(rows[0]));
});

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
  if (u.rows[0].disabled_at) return res.status(403).json({ error: DISABLED });
  res.json(await issueTokens(u.rows[0]));
});

router.post('/logout', async (req, res) => {
  const rt = req.body && req.body.refresh_token;
  if (typeof rt === 'string') {
    await db.query('UPDATE refresh_tokens SET revoked_at = now() WHERE token_hash = $1 AND revoked_at IS NULL', [sha(rt)]);
  }
  res.status(204).end();
});


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