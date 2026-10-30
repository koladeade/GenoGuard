const router = require('express').Router();
const bcrypt = require('bcryptjs');
const { z } = require('zod');
const db = require('../db');
const { requireAuth } = require('../auth');
const { publicUser, roleFor, GENOTYPES } = require('./auth');

router.use(requireAuth);

router.get('/', (req, res) => res.json({ user: publicUser(req.user) }));

router.patch('/', async (req, res) => {
  const r = z
    .object({
      full_name: z.string().trim().min(1, 'Enter your name').max(120).optional(),
      has_scd: z.boolean().optional(),
      genotype: z.enum(GENOTYPES).nullable().optional(),
      location: z.string().trim().max(120).nullable().optional(),
      usage_logs_consent: z.boolean().optional(),
    })
    .safeParse(req.body);
  if (!r.success) return res.status(400).json({ error: r.error.issues[0].message });

  const u = req.user;
  const fullName = r.data.full_name ?? u.full_name;
  const hasScd = r.data.has_scd ?? u.has_scd;
  const genotype = r.data.genotype !== undefined ? r.data.genotype : u.genotype;
  const location = r.data.location !== undefined ? r.data.location : u.location;
  const usageLogs = r.data.usage_logs_consent ?? u.usage_logs_consent;
  if (hasScd && !['SS', 'SC'].includes(genotype)) {
    return res.status(400).json({ error: 'The patient side is for people living with SS or SC' });
  }
  const role = u.role === 'admin' ? 'admin' : roleFor(hasScd);
  const { rows } = await db.query(
    `UPDATE users SET full_name=$1, has_scd=$2, genotype=$3, location=$4, role=$5, usage_logs_consent=$6, updated_at=now()
     WHERE id=$7 RETURNING *`,
    [fullName, hasScd, genotype, location, role, usageLogs, u.id]
  );
  res.json({ user: publicUser(rows[0]) });
});

router.delete('/', async (req, res) => {
  const r = z
    .object({ password: z.string().max(72).optional(), confirm: z.boolean().optional() })
    .safeParse(req.body || {});
  if (!r.success) return res.status(400).json({ error: 'Invalid request' });

  if (req.user.password_hash) {
    if (!r.data.password) return res.status(400).json({ error: 'Password required' });
    if (!(await bcrypt.compare(r.data.password, req.user.password_hash))) {
      return res.status(401).json({ error: 'Incorrect password' });
    }
  } else if (r.data.confirm !== true) {
    return res.status(400).json({ error: 'Please confirm deletion' });
  }
  await db.query('DELETE FROM users WHERE id = $1', [req.user.id]);
  res.status(204).end();
});

module.exports = router;