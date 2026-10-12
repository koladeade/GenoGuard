const router = require('express').Router();
const bcrypt = require('bcryptjs');
const { z } = require('zod');
const db = require('../db');
const { requireAuth } = require('../auth');
const { publicUser, roleFor, GENOTYPES } = require('./auth');

router.use(requireAuth);

router.get('/', (req, res) => res.json({ user: publicUser(req.user) }));

// Editing has_scd re-derives the role (patient <-> explorer). Admins keep their role.
router.patch('/', async (req, res) => {
  const r = z
    .object({
      has_scd: z.boolean().optional(),
      genotype: z.enum(GENOTYPES).nullable().optional(),
      location: z.string().trim().max(120).nullable().optional(),
    })
    .safeParse(req.body);
  if (!r.success) return res.status(400).json({ error: r.error.issues[0].message });

  const u = req.user;
  const hasScd = r.data.has_scd ?? u.has_scd;
  const genotype = r.data.genotype !== undefined ? r.data.genotype : u.genotype;
  const location = r.data.location !== undefined ? r.data.location : u.location;
  if (hasScd && !['SS', 'SC'].includes(genotype)) {
    return res.status(400).json({ error: 'The patient side is for people living with SS or SC' });
  }
  const role = u.role === 'admin' ? 'admin' : roleFor(hasScd);
  // admin accounts must still satisfy nothing about SCD; constraint exempts them
  const { rows } = await db.query(
    `UPDATE users SET has_scd=$1, genotype=$2, location=$3, role=$4, updated_at=now()
     WHERE id=$5 RETURNING *`,
    [hasScd, genotype, location, role, u.id]
  );
  res.json({ user: publicUser(rows[0]) });
});

// Hard delete. Re-confirms the password; cascades remove refresh tokens and reset codes.
router.delete('/', async (req, res) => {
  const r = z.object({ password: z.string().min(1).max(72) }).safeParse(req.body);
  if (!r.success) return res.status(400).json({ error: 'Password required' });
  if (!(await bcrypt.compare(r.data.password, req.user.password_hash))) {
    return res.status(401).json({ error: 'Incorrect password' });
  }
  await db.query('DELETE FROM users WHERE id = $1', [req.user.id]);
  res.status(204).end();
});

module.exports = router;