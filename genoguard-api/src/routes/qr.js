const router = require('express').Router();
const crypto = require('crypto');
const rateLimit = require('express-rate-limit');
const { z } = require('zod');
const db = require('../db');
const { requireAuth, requireRole } = require('../auth');

// Match by QR. Person A creates a code (QR or typed). Person B claims it. A must approve every
// share before either side sees a genotype.
router.use(requireAuth, requireRole('patient', 'explorer'));

const CODE_TTL_MINUTES = 5; // how long a code lives
const RESULT_TTL_MINUTES = 10; // how long both sides can fetch the result after approval
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const sha = (s) => crypto.createHash('sha256').update(s).digest('hex');
const makeCode = () => Array.from({ length: 8 }, () => ALPHABET[crypto.randomInt(ALPHABET.length)]).join('');
const normalize = (s) => String(s || '').toUpperCase().replace(/^GENOGUARD:/, '').replace(/[^A-Z0-9]/g, '');
const firstName = (n) => String(n || '').trim().split(/\s+/)[0] || 'Someone';

const needGenotype = (req, res) => {
  if (!req.user.genotype) {
    res.status(400).json({ error: 'Add your genotype in Profile first' });
    return false;
  }
  return true;
};

// A: create a code. Any earlier unfinished code of theirs is cancelled.
router.post('/shares', async (req, res) => {
  if (!needGenotype(req, res)) return;
  await db.query(`UPDATE qr_shares SET status = 'expired' WHERE owner_id = $1 AND status IN ('open', 'requested')`, [
    req.user.id,
  ]);
  const code = makeCode();
  const { rows } = await db.query(
    `INSERT INTO qr_shares (owner_id, code_hash, expires_at)
     VALUES ($1, $2, now() + ($3 || ' minutes')::interval) RETURNING id`,
    [req.user.id, sha(code), String(CODE_TTL_MINUTES)]
  );
  res.status(201).json({ id: rows[0].id, code, expires_in: CODE_TTL_MINUTES * 60 });
});

// B: claim a code (scanned or typed). Throttled so codes cannot be guessed.
const claimLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 10,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many tries. Wait a minute and try again.' },
});

router.post('/claim', claimLimiter, async (req, res) => {
  const p = z.object({ code: z.string().min(4).max(40) }).safeParse(req.body);
  const code = p.success ? normalize(p.data.code) : '';
  if (code.length !== 8) return res.status(400).json({ error: 'Enter the 8-character code' });
  if (!needGenotype(req, res)) return;

  const hash = sha(code);
  const { rows } = await db.query(
    `UPDATE qr_shares SET status = 'requested', requester_id = $2, requested_at = now()
      WHERE code_hash = $1 AND status = 'open' AND expires_at > now() AND owner_id <> $2
      RETURNING id, owner_id`,
    [hash, req.user.id]
  );
  if (!rows[0]) {
    const own = await db.query('SELECT 1 FROM qr_shares WHERE code_hash = $1 AND owner_id = $2', [hash, req.user.id]);
    if (own.rows.length) return res.status(400).json({ error: 'That is your own code' });
    return res.status(404).json({ error: 'That code is invalid or has expired' });
  }
  const owner = await db.query('SELECT full_name FROM users WHERE id = $1', [rows[0].owner_id]);
  res.json({ id: rows[0].id, other_name: firstName(owner.rows[0]?.full_name) });
});

// Both sides poll this. Genotypes are only included once the owner approved.
router.get('/shares/:id', async (req, res) => {
  if (!UUID.test(req.params.id)) return res.status(400).json({ error: 'Invalid id' });
  const { rows } = await db.query(
    `SELECT s.status, s.owner_id, s.requester_id, s.expires_at, s.decided_at,
            o.full_name AS owner_name, o.genotype AS owner_genotype,
            r.full_name AS requester_name, r.genotype AS requester_genotype
       FROM qr_shares s
       JOIN users o ON o.id = s.owner_id
       LEFT JOIN users r ON r.id = s.requester_id
      WHERE s.id = $1 AND (s.owner_id = $2 OR s.requester_id = $2)`,
    [req.params.id, req.user.id]
  );
  const s = rows[0];
  if (!s) return res.status(404).json({ error: 'Not found' });

  const now = Date.now();
  let status = s.status;
  if ((status === 'open' || status === 'requested') && new Date(s.expires_at).getTime() < now) status = 'expired';
  if (status === 'approved' && new Date(s.decided_at).getTime() + RESULT_TTL_MINUTES * 60 * 1000 < now) status = 'expired';

  const isOwner = s.owner_id === req.user.id;
  const out = { status, other_name: firstName(isOwner ? s.requester_name : s.owner_name) };
  if (status === 'open' && isOwner) out.other_name = null;
  if (status === 'approved') {
    out.you = isOwner ? s.owner_genotype : s.requester_genotype;
    out.partner = isOwner ? s.requester_genotype : s.owner_genotype;
  }
  res.json(out);
});

// A: allow or decline.
router.post('/shares/:id/decision', async (req, res) => {
  if (!UUID.test(req.params.id)) return res.status(400).json({ error: 'Invalid id' });
  const p = z.object({ allow: z.boolean() }).safeParse(req.body);
  if (!p.success) return res.status(400).json({ error: 'allow must be true or false' });
  const { rows } = await db.query(
    `UPDATE qr_shares SET status = $3, decided_at = now()
      WHERE id = $1 AND owner_id = $2 AND status = 'requested' AND expires_at > now()
      RETURNING id`,
    [req.params.id, req.user.id, p.data.allow ? 'approved' : 'declined']
  );
  if (!rows[0]) return res.status(409).json({ error: 'This request is no longer open' });
  res.json({ status: p.data.allow ? 'approved' : 'declined' });
});

module.exports = router;