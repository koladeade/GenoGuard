const router = require('express').Router();
const { z } = require('zod');
const db = require('../db');
const { requireAuth, requireRole } = require('../auth');

const AREAS = ['Back', 'Chest', 'Legs', 'Arms', 'Abdomen', 'Joints', 'Head'];

// Patients only. Every query is scoped to req.user.id, so nobody can read another user's log.
router.use(requireAuth, requireRole('patient'));

const shape = (r) => ({
  id: r.id,
  occurred_at: r.occurred_at,
  intensity: r.intensity,
  areas: r.areas,
  notes: r.notes,
  is_crisis: r.is_crisis,
});

const entrySchema = z
  .object({
    occurred_at: z.string().datetime({ offset: true }),
    intensity: z.number().int().min(0).max(10),
    areas: z.array(z.enum(AREAS)).max(AREAS.length).default([]),
    notes: z.string().trim().max(1000).optional(),
    is_crisis: z.boolean().default(false),
  })
  .refine((d) => Date.parse(d.occurred_at) <= Date.now() + 24 * 3600 * 1000, {
    message: 'That date is in the future',
    path: ['occurred_at'],
  });

router.get('/', async (req, res) => {
  const q = z
    .object({
      from: z.string().datetime({ offset: true }).optional(),
      to: z.string().datetime({ offset: true }).optional(),
      limit: z.coerce.number().int().min(1).max(1000).default(500),
    })
    .safeParse(req.query);
  if (!q.success) return res.status(400).json({ error: 'Invalid request' });
  const { rows } = await db.query(
    `SELECT * FROM pain_entries
     WHERE user_id = $1
       AND ($2::timestamptz IS NULL OR occurred_at >= $2)
       AND ($3::timestamptz IS NULL OR occurred_at <= $3)
     ORDER BY occurred_at DESC
     LIMIT $4`,
    [req.user.id, q.data.from ?? null, q.data.to ?? null, q.data.limit]
  );
  res.json({ entries: rows.map(shape) });
});

router.post('/', async (req, res) => {
  const r = entrySchema.safeParse(req.body);
  if (!r.success) return res.status(400).json({ error: r.error.issues[0].message });
  const d = r.data;
  const { rows } = await db.query(
    `INSERT INTO pain_entries (user_id, occurred_at, intensity, areas, notes, is_crisis)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
    [req.user.id, d.occurred_at, d.intensity, d.areas, d.notes ?? null, d.is_crisis]
  );
  res.status(201).json({ entry: shape(rows[0]) });
});

// ---- Home-screen numbers ----------------------------------------------------
// "Days" are calendar days in the user's own time zone. The app sends tz_offset (minutes east of UTC).
const dayDiff = (a, b) => Math.round((Date.parse(`${a}T00:00:00Z`) - Date.parse(`${b}T00:00:00Z`)) / 86400000);
const addDays = (day, n) => new Date(Date.parse(`${day}T00:00:00Z`) + n * 86400000).toISOString().slice(0, 10);

router.get('/summary', async (req, res) => {
  const q = z
    .object({
      tz_offset: z.coerce.number().int().min(-840).max(840).default(0),
      days: z.coerce.number().int().refine((d) => [7, 14, 30].includes(d), 'days must be 7, 14 or 30').default(14),
    })
    .safeParse(req.query);
  if (!q.success) return res.status(400).json({ error: 'Invalid request' });
  const { tz_offset: off, days } = q.data;
  const uid = req.user.id;
  const localDay = `(occurred_at + $2 * interval '1 minute')::date`;

  const crises = (
    await db.query(
      `SELECT DISTINCT to_char(${localDay}, 'YYYY-MM-DD') AS day
       FROM pain_entries WHERE user_id = $1 AND is_crisis ORDER BY day`,
      [uid, off]
    )
  ).rows.map((r) => r.day);

  const empty = { span_days: 0, reaches_today: false, points: [], change_pct: null };
  if (!crises.length) return res.json({ days_since_crisis: null, personal_best: null, recovery: empty });

  const today = new Date(Date.now() + off * 60000).toISOString().slice(0, 10);
  const last = crises[crises.length - 1];
  const since = Math.max(0, dayDiff(today, last));

  // Personal best = longest gap between crises, counting the current streak.
  let best = since;
  for (let i = 1; i < crises.length; i++) best = Math.max(best, dayDiff(crises[i], crises[i - 1]));

  // Recovery = daily average pain over the first `days` days after the latest crisis (capped at today).
  const span = Math.min(days, since);
  const rows = (
    await db.query(
      `SELECT to_char(${localDay}, 'YYYY-MM-DD') AS day, AVG(intensity)::float AS avg
       FROM pain_entries
       WHERE user_id = $1 AND ${localDay} BETWEEN $3::date AND $4::date
       GROUP BY 1 ORDER BY 1`,
      [uid, off, last, addDays(last, span)]
    )
  ).rows;
  const points = rows.map((r) => ({ day: dayDiff(r.day, last), avg: Math.round(r.avg * 10) / 10 }));

  let changePct = null;
  if (points.length >= 2 && points[0].avg > 0) {
    changePct = Math.round(((points[0].avg - points[points.length - 1].avg) / points[0].avg) * 100);
  }

  res.json({
    days_since_crisis: since,
    personal_best: best,
    recovery: { span_days: span, reaches_today: since <= days, points, change_pct: changePct },
  });
});

router.delete('/:id', async (req, res) => {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(req.params.id)) {
    return res.status(400).json({ error: 'Invalid entry id' });
  }
  const { rowCount } = await db.query('DELETE FROM pain_entries WHERE id = $1 AND user_id = $2', [
    req.params.id,
    req.user.id,
  ]);
  if (!rowCount) return res.status(404).json({ error: 'Entry not found' });
  res.status(204).end();
});

module.exports = router;