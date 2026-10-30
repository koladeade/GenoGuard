const router = require('express').Router();
const crypto = require('crypto');
const { z } = require('zod');
const db = require('../db');
const { requireAuth, requireRole } = require('../auth');
const { audit, userLabel } = require('../audit');

// Admin only. Admins see counts, account basics and aggregate research data. They never see
// anyone's genotype, pain log, reminders or location.
router.use(requireAuth, requireRole('admin'));

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const daysAgo = (n) => new Date(Date.now() - n * 24 * 3600 * 1000);
const count = async (sql, params = []) => Number((await db.query(sql, params)).rows[0].n);

// ---- Overview -------------------------------------------------------------------------------

router.get('/overview', async (_req, res) => {
  const roles = await db.query(`SELECT role, count(*) AS n FROM users GROUP BY role`);
  const by = Object.fromEntries(roles.rows.map((r) => [r.role, Number(r.n)]));
  const postReports = await db.query(`SELECT DISTINCT post_id FROM post_reports WHERE status = 'open'`);
  const commentReports = await db.query(`SELECT DISTINCT comment_id FROM comment_reports WHERE status = 'open'`);
  res.json({
    users: { patient: by.patient || 0, explorer: by.explorer || 0, admin: by.admin || 0 },
    new_users_7d: await count(`SELECT count(*) AS n FROM users WHERE created_at > $1`, [daysAgo(7)]),
    disabled_users: await count(`SELECT count(*) AS n FROM users WHERE disabled_at IS NOT NULL`),
    open_post_reports: postReports.rows.length,
    open_comment_reports: commentReports.rows.length,
    posts: await count(`SELECT count(*) AS n FROM posts`),
    open_invitations: await count(
      `SELECT count(*) AS n FROM qr_shares WHERE kind = 'invite' AND status IN ('open', 'requested') AND expires_at > $1`,
      [new Date()]
    ),
    quiz_responses: await count(`SELECT count(*) AS n FROM quiz_responses`),
  });
});

// ---- Users ----------------------------------------------------------------------------------

router.get('/users', async (req, res) => {
  const q = z
    .object({
      q: z.string().trim().max(100).optional(),
      offset: z.coerce.number().int().min(0).default(0),
      limit: z.coerce.number().int().min(1).max(100).default(50),
    })
    .safeParse(req.query);
  if (!q.success) return res.status(400).json({ error: 'Invalid request' });
  const params = [q.data.limit, q.data.offset];
  let where = '';
  if (q.data.q) {
    params.push(`%${q.data.q.toLowerCase()}%`);
    where = `WHERE lower(email) LIKE $3 OR lower(COALESCE(full_name, '')) LIKE $3`;
  }
  const { rows } = await db.query(
    `SELECT id, email, full_name, role, created_at, disabled_at FROM users ${where}
     ORDER BY created_at DESC LIMIT $1 OFFSET $2`,
    params
  );
  res.json({
    users: rows.map((u) => ({
      id: u.id,
      email: u.email,
      name: u.full_name || '',
      role: u.role,
      created_at: u.created_at,
      disabled: !!u.disabled_at,
    })),
    has_more: rows.length === q.data.limit,
  });
});

// Loads a target the admin may act on: not themselves, not another admin.
async function target(req, res) {
  if (!UUID.test(req.params.id)) {
    res.status(404).json({ error: 'User not found' });
    return null;
  }
  const { rows } = await db.query(`SELECT id, role, disabled_at FROM users WHERE id = $1`, [req.params.id]);
  const u = rows[0];
  if (!u) {
    res.status(404).json({ error: 'User not found' });
    return null;
  }
  if (u.id === req.user.id || u.role === 'admin') {
    res.status(400).json({ error: 'Admin accounts cannot be changed here' });
    return null;
  }
  return u;
}

router.post('/users/:id/disable', async (req, res) => {
  const u = await target(req, res);
  if (!u) return;
  await db.query(`UPDATE users SET disabled_at = now() WHERE id = $1`, [u.id]);
  await db.query(`UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL`, [u.id]);
  await audit(req, 'user_disabled', userLabel(u));
  res.json({ ok: true });
});

router.post('/users/:id/enable', async (req, res) => {
  const u = await target(req, res);
  if (!u) return;
  await db.query(`UPDATE users SET disabled_at = NULL WHERE id = $1`, [u.id]);
  await audit(req, 'user_enabled', userLabel(u));
  res.json({ ok: true });
});

// Permanent. Everything the person created goes with the account.
router.delete('/users/:id', async (req, res) => {
  const u = await target(req, res);
  if (!u) return;
  await db.query(`DELETE FROM users WHERE id = $1`, [u.id]);
  await audit(req, 'user_deleted', userLabel(u));
  res.json({ ok: true });
});

// ---- Research data --------------------------------------------------------------------------

router.get('/research/summary', async (_req, res) => {
  const quiz = await db.query(`SELECT user_id, intention, confidence FROM quiz_responses`);
  const n = quiz.rows.length;
  const avg = (k) => (n ? Math.round((quiz.rows.reduce((s, r) => s + r[k], 0) / n) * 100) / 100 : null);
  const dist = (k) => [1, 2, 3, 4, 5].map((v) => quiz.rows.filter((r) => r[k] === v).length);
  const usage = await db.query(`SELECT event, item, count(*) AS n FROM usage_events GROUP BY event, item`);
  res.json({
    quiz: {
      responses: n,
      participants: new Set(quiz.rows.map((r) => r.user_id)).size,
      intention: { average: avg('intention'), counts: dist('intention') }, // counts for ratings 1..5
      confidence: { average: avg('confidence'), counts: dist('confidence') },
    },
    usage: {
      users_with_consent: await count(`SELECT count(*) AS n FROM users WHERE usage_logs_consent = true`),
      events: usage.rows.map((r) => ({ event: r.event, item: r.item, count: Number(r.n) })),
    },
  });
});

// Participant ids are a keyed hash of the user id: stable across exports, not reversible without the secret.
const pid = (userId) =>
  crypto.createHmac('sha256', process.env.JWT_SECRET || '').update(String(userId)).digest('hex').slice(0, 10);
const csvCell = (v) => {
  let s = v == null ? '' : v instanceof Date ? v.toISOString() : String(v);
  if (/^[=+\-@]/.test(s)) s = "'" + s; // keeps spreadsheets from running text as a formula
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};
const toCsv = (head, rows) => [head, ...rows].map((r) => r.map(csvCell).join(',')).join('\n') + '\n';

router.get('/research/export', async (req, res) => {
  const k = z.enum(['quiz', 'usage']).safeParse(req.query.kind);
  if (!k.success) return res.status(400).json({ error: 'kind must be quiz or usage' });
  let csv;
  if (k.data === 'quiz') {
    const { rows } = await db.query(
      `SELECT q.user_id, u.role, q.intention, q.confidence, q.created_at
       FROM quiz_responses q JOIN users u ON u.id = q.user_id ORDER BY q.created_at ASC`
    );
    csv = toCsv(
      ['participant', 'group', 'intention_1to5', 'confidence_1to5', 'submitted_at'],
      rows.map((r) => [pid(r.user_id), r.role, r.intention, r.confidence, r.created_at])
    );
  } else {
    const { rows } = await db.query(
      `SELECT e.user_id, u.role, e.event, e.item, e.created_at
       FROM usage_events e JOIN users u ON u.id = e.user_id ORDER BY e.created_at ASC`
    );
    csv = toCsv(
      ['participant', 'group', 'event', 'item', 'occurred_at'],
      rows.map((r) => [pid(r.user_id), r.role, r.event, r.item, r.created_at])
    );
  }
  await audit(req, 'data_exported', k.data);
  res.type('text/csv').send(csv);
});

// ---- Audit log ------------------------------------------------------------------------------

router.get('/audit', async (_req, res) => {
  const { rows } = await db.query(
    `SELECT id, admin_label, action, detail, created_at FROM admin_audit ORDER BY created_at DESC LIMIT 100`
  );
  res.json({
    entries: rows.map((r) => ({
      id: r.id,
      admin: r.admin_label,
      action: r.action,
      detail: r.detail,
      at: r.created_at,
    })),
  });
});

module.exports = router;