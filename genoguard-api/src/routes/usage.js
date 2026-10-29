const router = require('express').Router();
const rateLimit = require('express-rate-limit');
const { z } = require('zod');
const db = require('../db');
const { requireAuth } = require('../auth');

// Usage logs. The server checks the user's consent on every call, so nothing is recorded without it,
// whatever the app sends. Events are a fixed list of names (never free text).
router.use(requireAuth);

const limiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 120,
  max: 120,
  keyGenerator: (req) => req.user.id,
  validate: false,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests' },
});

const ITEMS = ['what-is-scd', 'genotypes', 'test-before-marriage', 'pain-crisis', 'quiz'];

const eventSchema = z
  .object({
    event: z.enum(['compat_check', 'qr_match', 'learning_open']),
    item: z.enum(ITEMS).optional(),
  })
  .refine((d) => (d.event === 'learning_open') === (d.item !== undefined), {
    message: 'Invalid event',
  });

// Record one event. No consent means nothing is stored (204 either way, so the app never has to care).
router.post('/', limiter, async (req, res) => {
  const r = eventSchema.safeParse(req.body);
  if (!r.success) return res.status(400).json({ error: 'Invalid event' });
  if (req.user.usage_logs_consent === true) {
    await db.query(`INSERT INTO usage_events (user_id, event, item) VALUES ($1, $2, $3)`, [
      req.user.id,
      r.data.event,
      r.data.item ?? null,
    ]);
  }
  res.status(204).end();
});

// How many events are stored for me.
router.get('/', async (req, res) => {
  const { rows } = await db.query(`SELECT count(*) AS n FROM usage_events WHERE user_id = $1`, [req.user.id]);
  res.json({ count: Number(rows[0].n), consented: req.user.usage_logs_consent === true });
});

// Delete my stored events.
router.delete('/', async (req, res) => {
  await db.query(`DELETE FROM usage_events WHERE user_id = $1`, [req.user.id]);
  res.status(204).end();
});

module.exports = router;