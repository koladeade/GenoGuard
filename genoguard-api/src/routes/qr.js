const router = require('express').Router();
const crypto = require('crypto');
const rateLimit = require('express-rate-limit');
const { z } = require('zod');
const db = require('../db');
const { requireAuth, requireRole } = require('../auth');
const { sendMatchInvite } = require('../mail');

// Match by QR, and by email invite for someone who is not next to you. Person A creates a code (QR or
// typed) or invites an email address. Person B claims it. A must approve every share before either side
// sees a genotype.
router.use(requireAuth, requireRole('patient', 'explorer'));

const CODE_TTL_MINUTES = 5; // how long a code lives
const RESULT_TTL_MINUTES = 10; // how long both sides can fetch the result after approval
const INVITE_TTL_DAYS = 7; // an emailed invite stays usable this long
const INVITE_RESULT_TTL_HOURS = 24; // and an approved invite's result can be opened this long
const MAX_OPEN_INVITES = 5;
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
  await db.query(
    `UPDATE qr_shares SET status = 'expired' WHERE owner_id = $1 AND kind = 'qr' AND status IN ('open', 'requested')`,
    [req.user.id]
  );
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
        AND (kind = 'qr' OR invitee_email = $3)
      RETURNING id, owner_id`,
    [hash, req.user.id, String(req.user.email || '').toLowerCase()]
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
    `SELECT s.status, s.kind, s.owner_id, s.requester_id, s.expires_at, s.decided_at,
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
  const resultMs = s.kind === 'invite' ? INVITE_RESULT_TTL_HOURS * 3600 * 1000 : RESULT_TTL_MINUTES * 60 * 1000;
  if (status === 'approved' && new Date(s.decided_at).getTime() + resultMs < now) status = 'expired';

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

// ---- Email invites ----------------------------------------------------------------------------

const inviteLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 5,
  max: 5,
  keyGenerator: (req) => req.user.id,
  validate: false,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'You have sent several invitations. Please try again later.' },
});

// A: invite an email address. The reply never says whether that address has an account.
router.post('/invites', inviteLimiter, async (req, res) => {
  const p = z.object({ email: z.string().trim().toLowerCase().email().max(254) }).safeParse(req.body);
  if (!p.success) return res.status(400).json({ error: 'Enter a valid email address' });
  if (!needGenotype(req, res)) return;
  const to = p.data.email;
  if (to === String(req.user.email || '').toLowerCase()) {
    return res.status(400).json({ error: 'That is your own email address' });
  }

  // Sending again to the same address replaces the earlier invite.
  await db.query(
    `UPDATE qr_shares SET status = 'expired'
      WHERE owner_id = $1 AND kind = 'invite' AND invitee_email = $2 AND status IN ('open', 'requested')`,
    [req.user.id, to]
  );
  const open = await db.query(
    `SELECT count(*) AS n FROM qr_shares
      WHERE owner_id = $1 AND kind = 'invite' AND status IN ('open', 'requested') AND expires_at > now()`,
    [req.user.id]
  );
  if (Number(open.rows[0].n) >= MAX_OPEN_INVITES) {
    return res.status(400).json({ error: `You can have ${MAX_OPEN_INVITES} open invitations at a time. Cancel one first.` });
  }

  const code = makeCode();
  const ins = await db.query(
    `INSERT INTO qr_shares (owner_id, code_hash, kind, invitee_email, expires_at)
     VALUES ($1, $2, 'invite', $3, now() + ($4 || ' days')::interval) RETURNING id`,
    [req.user.id, sha(code), to, String(INVITE_TTL_DAYS)]
  );
  try {
    await sendMatchInvite(to, firstName(req.user.full_name), code, INVITE_TTL_DAYS);
  } catch (e) {
    console.error('Invite email failed:', e.message);
    await db.query('DELETE FROM qr_shares WHERE id = $1', [ins.rows[0].id]);
    return res.status(502).json({ error: 'We could not send the email. Please try again.' });
  }
  res.status(201).json({ id: ins.rows[0].id, expires_in_days: INVITE_TTL_DAYS });
});

const liveStatus = (s, now) => {
  if ((s.status === 'open' || s.status === 'requested') && new Date(s.expires_at).getTime() < now) return 'expired';
  if (s.status === 'approved' && new Date(s.decided_at).getTime() + INVITE_RESULT_TTL_HOURS * 3600 * 1000 < now) return 'expired';
  return s.status;
};

// Both lists for the signed-in person: invitations they sent and invitations they accepted.
router.get('/invites', async (req, res) => {
  const now = Date.now();
  const since = new Date(now - 14 * 24 * 3600 * 1000);
  const sent = await db.query(
    `SELECT s.id, s.status, s.invitee_email, s.expires_at, s.decided_at, s.created_at, r.full_name AS other_name
       FROM qr_shares s LEFT JOIN users r ON r.id = s.requester_id
      WHERE s.owner_id = $1 AND s.kind = 'invite' AND NOT s.owner_hidden AND s.created_at > $2
      ORDER BY s.created_at DESC`,
    [req.user.id, since]
  );
  const received = await db.query(
    `SELECT s.id, s.status, s.expires_at, s.decided_at, s.created_at, o.full_name AS other_name
       FROM qr_shares s JOIN users o ON o.id = s.owner_id
      WHERE s.requester_id = $1 AND s.kind = 'invite' AND NOT s.requester_hidden AND s.created_at > $2
      ORDER BY s.created_at DESC`,
    [req.user.id, since]
  );
  res.json({
    sent: sent.rows.map((s) => ({
      id: s.id,
      email: s.invitee_email,
      status: liveStatus(s, now),
      other_name: s.status === 'open' ? null : firstName(s.other_name),
      created_at: s.created_at,
      expires_at: s.expires_at,
    })),
    received: received.rows.map((s) => ({
      id: s.id,
      status: liveStatus(s, now),
      other_name: firstName(s.other_name),
      created_at: s.created_at,
    })),
  });
});

// Either person: remove a finished (expired or declined) invitation from their own list.
router.post('/invites/:id/remove', async (req, res) => {
  if (!UUID.test(req.params.id)) return res.status(400).json({ error: 'Invalid id' });
  const { rows } = await db.query(
    `SELECT status, expires_at, decided_at, owner_id, requester_id FROM qr_shares
      WHERE id = $1 AND kind = 'invite' AND (owner_id = $2 OR requester_id = $2)`,
    [req.params.id, req.user.id]
  );
  const s = rows[0];
  if (!s) return res.status(404).json({ error: 'Invitation not found' });
  if (!['expired', 'declined'].includes(liveStatus(s, Date.now()))) {
    return res.status(400).json({ error: 'Only finished invitations can be removed' });
  }
  await db.query(
        `UPDATE qr_shares SET owner_hidden = owner_hidden OR COALESCE(owner_id = $2, false),
                          requester_hidden = requester_hidden OR COALESCE(requester_id = $2, false) WHERE id = $1`,
    [req.params.id, req.user.id]
  );
  res.json({ ok: true });
});

// A: cancel an invitation that has not been decided yet.
router.delete('/invites/:id', async (req, res) => {
  if (!UUID.test(req.params.id)) return res.status(400).json({ error: 'Invalid id' });
  const { rowCount } = await db.query(
    `UPDATE qr_shares SET status = 'expired'
      WHERE id = $1 AND owner_id = $2 AND kind = 'invite' AND status IN ('open', 'requested')`,
    [req.params.id, req.user.id]
  );
  if (!rowCount) return res.status(404).json({ error: 'Invitation not found' });
  res.json({ ok: true });
});

module.exports = router;