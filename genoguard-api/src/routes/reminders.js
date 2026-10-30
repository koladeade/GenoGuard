const router = require('express').Router();
const { z } = require('zod');
const db = require('../db');
const { requireAuth, requireRole } = require('../auth');


router.use(requireAuth, requireRole('patient'));

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DAY = /^\d{4}-\d{2}-\d{2}$/;
const HHMM = /^([01]\d|2[0-3]):[0-5]\d$/;

const ALLOWED = {
  medication: ['once', 'daily'],
  hydration: ['once', 'daily', 'every_2_hrs'],
  appointment: ['once'],
};

const COLS = `r.id, r.type, r.title, r.dose, r.doctor, r.location, r.recurrence,
  r.time_of_day, to_char(r.on_date, 'YYYY-MM-DD') AS on_date, r.enabled`;

const validDay = (s) => {
  if (typeof s !== 'string' || !DAY.test(s)) return false;
  const d = new Date(`${s}T00:00:00Z`);
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === s;
};

const optText = (max) =>
  z
    .string()
    .trim()
    .max(max)
    .optional()
    .nullable()
    .transform((v) => (v ? v : null));

const bodySchema = z.object({
  type: z.enum(['medication', 'hydration', 'appointment']),
  title: z.string().trim().min(1, 'Add a name').max(120),
  dose: optText(60),
  doctor: optText(80),
  location: optText(120),
  repeat: z.enum(['once', 'daily', 'every_2_hrs']),
  time_of_day: z.string().regex(HHMM, 'Time must be HH:MM').optional().nullable(),
  on_date: z.string().optional().nullable(),
});


function parseReminder(body) {
  const p = bodySchema.safeParse(body);
  if (!p.success) return { error: p.error.issues[0]?.message || 'Invalid reminder' };
  const v = p.data;
  if (!ALLOWED[v.type].includes(v.repeat)) return { error: `A ${v.type} reminder cannot repeat "${v.repeat}"` };

  if (!v.time_of_day) return { error: 'Choose a time' };
  const needsDate = v.repeat === 'once';
  if (needsDate && !validDay(v.on_date)) return { error: 'Choose a date' };

  return {
    row: {
      type: v.type,
      title: v.title,
      dose: v.type === 'medication' ? v.dose : null,
      doctor: v.type === 'appointment' ? v.doctor : null,
      location: v.type === 'appointment' ? v.location : null,
      recurrence: v.repeat,
      time_of_day: v.time_of_day,
      on_date: needsDate ? v.on_date : null,
    },
  };
}


router.get('/', async (req, res) => {
  const day = req.query.day;
  if (!validDay(day)) return res.status(400).json({ error: 'day must be YYYY-MM-DD' });
  const { rows } = await db.query(
    `SELECT ${COLS},
            (SELECT count(*) FROM reminder_logs l WHERE l.reminder_id = r.id AND l.day = $2::date)::int AS taken_count
       FROM reminders r
      WHERE r.user_id = $1 AND r.recurrence <> 'as_needed'
      ORDER BY r.time_of_day NULLS LAST, r.created_at`,
    [req.user.id, day]
  );
  res.json({ reminders: rows });
});

router.post('/', async (req, res) => {
  const r = parseReminder(req.body);
  if (r.error) return res.status(400).json({ error: r.error });
  const x = r.row;
  const { rows } = await db.query(
    `INSERT INTO reminders (user_id, type, title, dose, doctor, location, recurrence, time_of_day, on_date)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
     RETURNING id`,
    [req.user.id, x.type, x.title, x.dose, x.doctor, x.location, x.recurrence, x.time_of_day, x.on_date]
  );
  res.status(201).json({ id: rows[0].id });
});


router.get('/water', async (req, res) => {
  if (!validDay(req.query.day)) return res.status(400).json({ error: 'day must be YYYY-MM-DD' });
  const { rows } = await db.query('SELECT glasses FROM water_intake WHERE user_id = $1 AND day = $2::date', [
    req.user.id,
    req.query.day,
  ]);
  res.json({ glasses: rows[0]?.glasses ?? 0 });
});

router.put('/water', async (req, res) => {
  const p = z.object({ day: z.string(), glasses: z.number().int().min(0).max(30) }).safeParse(req.body);
  if (!p.success || !validDay(p.data.day)) return res.status(400).json({ error: 'Invalid water entry' });
  await db.query(
    `INSERT INTO water_intake (user_id, day, glasses) VALUES ($1, $2::date, $3)
     ON CONFLICT (user_id, day) DO UPDATE SET glasses = EXCLUDED.glasses`,
    [req.user.id, p.data.day, p.data.glasses]
  );
  res.json({ glasses: p.data.glasses });
});

const idGuard = (req, res, next) =>
  UUID.test(req.params.id) ? next() : res.status(400).json({ error: 'Invalid reminder id' });

router.put('/:id', idGuard, async (req, res) => {
  const r = parseReminder(req.body);
  if (r.error) return res.status(400).json({ error: r.error });
  const x = r.row;
  const { rowCount } = await db.query(
    `UPDATE reminders
        SET type=$3, title=$4, dose=$5, doctor=$6, location=$7, recurrence=$8, time_of_day=$9, on_date=$10,
            updated_at=now()
      WHERE id=$1 AND user_id=$2`,
    [req.params.id, req.user.id, x.type, x.title, x.dose, x.doctor, x.location, x.recurrence, x.time_of_day, x.on_date]
  );
  if (!rowCount) return res.status(404).json({ error: 'Reminder not found' });
  res.status(204).end();
});

router.patch('/:id', idGuard, async (req, res) => {
  const p = z.object({ enabled: z.boolean() }).safeParse(req.body);
  if (!p.success) return res.status(400).json({ error: 'enabled must be true or false' });
  const { rowCount } = await db.query(
    'UPDATE reminders SET enabled=$3, updated_at=now() WHERE id=$1 AND user_id=$2',
    [req.params.id, req.user.id, p.data.enabled]
  );
  if (!rowCount) return res.status(404).json({ error: 'Reminder not found' });
  res.status(204).end();
});

router.delete('/:id', idGuard, async (req, res) => {
  const { rowCount } = await db.query('DELETE FROM reminders WHERE id=$1 AND user_id=$2', [
    req.params.id,
    req.user.id,
  ]);
  if (!rowCount) return res.status(404).json({ error: 'Reminder not found' });
  res.status(204).end();
});


router.post('/:id/log', idGuard, async (req, res) => {
  if (!validDay(req.body?.day)) return res.status(400).json({ error: 'day must be YYYY-MM-DD' });
  const found = await db.query('SELECT recurrence FROM reminders WHERE id=$1 AND user_id=$2', [
    req.params.id,
    req.user.id,
  ]);
  if (!found.rows.length) return res.status(404).json({ error: 'Reminder not found' });
  const day = req.body.day;
  const dup = await db.query('SELECT 1 FROM reminder_logs WHERE reminder_id=$1 AND day=$2::date', [req.params.id, day]);
  if (dup.rows.length) return res.status(204).end();
  await db.query('INSERT INTO reminder_logs (reminder_id, user_id, day) VALUES ($1,$2,$3::date)', [
    req.params.id,
    req.user.id,
    day,
  ]);
  res.status(201).end();
});


router.delete('/:id/log', idGuard, async (req, res) => {
  if (!validDay(req.query.day)) return res.status(400).json({ error: 'day must be YYYY-MM-DD' });
  await db.query('DELETE FROM reminder_logs WHERE reminder_id=$1 AND user_id=$2 AND day=$3::date', [
    req.params.id,
    req.user.id,
    req.query.day,
  ]);
  res.status(204).end();
});

module.exports = router;