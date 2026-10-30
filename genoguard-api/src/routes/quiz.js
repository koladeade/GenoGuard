const router = require('express').Router();
const { z } = require('zod');
const db = require('../db');
const { requireAuth, requireRole } = require('../auth');

// Knowledge quiz. Patients and explorers can submit
router.use(requireAuth, requireRole('patient', 'explorer'));

const schema = z.object({
  intention: z.number().int().min(1).max(5),
  confidence: z.number().int().min(1).max(5),
});

const shape = (r) => ({
  id: r.id,
  intention: r.intention,
  confidence: r.confidence,
  created_at: r.created_at,
});

router.post('/', async (req, res) => {
  const r = schema.safeParse(req.body);
  if (!r.success) return res.status(400).json({ error: 'Pick a rating from 1 to 5 for each question' });
  const { rows } = await db.query(
    `INSERT INTO quiz_responses (user_id, intention, confidence) VALUES ($1, $2, $3) RETURNING *`,
    [req.user.id, r.data.intention, r.data.confidence]
  );
  res.status(201).json({ response: shape(rows[0]) });
});


router.get('/latest', async (req, res) => {
  const { rows } = await db.query(
    `SELECT * FROM quiz_responses WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1`,
    [req.user.id]
  );
  res.json({ response: rows[0] ? shape(rows[0]) : null });
});

module.exports = router;