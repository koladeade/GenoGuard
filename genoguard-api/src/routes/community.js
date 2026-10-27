const router = require('express').Router();
const rateLimit = require('express-rate-limit');
const { z } = require('zod');
const db = require('../db');
const { requireAuth, requireRole } = require('../auth');

// Community. Patients and explorers read and write. Admins review reported posts and can delete any post.
// Only a first name is ever shown, never an email, genotype or role.
router.use(requireAuth);

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const REASONS = ['harmful_advice', 'abuse', 'spam', 'privacy', 'other'];
const members = requireRole('patient', 'explorer');
const admins = requireRole('admin');

const firstName = (n) => String(n || '').trim().split(/\s+/)[0] || 'Member';
const byUser = (req) => req.user.id;

const postLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 10,
  max: 10,
  keyGenerator: byUser,
  validate: false,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'You have posted a lot in the last hour. Please try again later.' },
});
const commentLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 40,
  max: 40,
  keyGenerator: byUser,
  validate: false,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'You have commented a lot in the last hour. Please try again later.' },
});

const shapeComment = (r) => ({
  id: r.id,
  body: r.body,
  author: firstName(r.author),
  created_at: r.created_at,
  mine: !!r.mine,
});

// Posts with their author's first name. Comment counts and "did I report this" are added by decorate().
const POST_SELECT = `
  SELECT p.id, p.body, p.created_at, p.author_id, u.full_name AS author
  FROM posts p JOIN users u ON u.id = p.author_id`;

const placeholders = (arr, offset) => arr.map((_, i) => `$${i + offset}`).join(', ');

async function decorate(userId, rows) {
  if (!rows.length) return [];
  const ids = rows.map((r) => r.id);
  const counts = await db.query(
    `SELECT post_id, count(*) AS n FROM comments WHERE post_id IN (${placeholders(ids, 1)}) GROUP BY post_id`,
    ids
  );
  const mine = await db.query(
    `SELECT post_id FROM post_reports WHERE reporter_id = $1 AND post_id IN (${placeholders(ids, 2)})`,
    [userId, ...ids]
  );
  const n = Object.fromEntries(counts.rows.map((c) => [c.post_id, Number(c.n)]));
  const reported = new Set(mine.rows.map((m) => m.post_id));
  return rows.map((r) => ({
    id: r.id,
    body: r.body,
    author: firstName(r.author),
    created_at: r.created_at,
    mine: r.author_id === userId,
    comment_count: n[r.id] || 0,
    reported: reported.has(r.id),
  }));
}

// ---- Feed -----------------------------------------------------------------------------------

router.get('/posts', members, async (req, res) => {
  const q = z
    .object({
      before: z.string().datetime({ offset: true }).optional(),
      limit: z.coerce.number().int().min(1).max(50).default(30),
    })
    .safeParse(req.query);
  if (!q.success) return res.status(400).json({ error: 'Invalid request' });
  const { rows } = await db.query(
    `${POST_SELECT}
     WHERE ($1::timestamptz IS NULL OR p.created_at < $1)
     ORDER BY p.created_at DESC
     LIMIT $2`,
    [q.data.before ?? null, q.data.limit]
  );
  res.json({ posts: await decorate(req.user.id, rows) });
});

router.post('/posts', members, postLimiter, async (req, res) => {
  const r = z.object({ body: z.string().trim().min(1).max(1000) }).safeParse(req.body);
  if (!r.success) return res.status(400).json({ error: 'Write something (up to 1000 characters)' });
  const ins = await db.query(`INSERT INTO posts (author_id, body) VALUES ($1, $2) RETURNING id`, [
    req.user.id,
    r.data.body,
  ]);
  const { rows } = await db.query(`${POST_SELECT} WHERE p.id = $1`, [ins.rows[0].id]);
  res.status(201).json({ post: (await decorate(req.user.id, rows))[0] });
});

router.get('/posts/:id', members, async (req, res) => {
  if (!UUID.test(req.params.id)) return res.status(404).json({ error: 'Post not found' });
  const { rows } = await db.query(`${POST_SELECT} WHERE p.id = $1`, [req.params.id]);
  if (!rows[0]) return res.status(404).json({ error: 'Post not found' });
  const c = await db.query(
    `SELECT c.id, c.body, c.created_at, c.author_id, u.full_name AS author
     FROM comments c JOIN users u ON u.id = c.author_id
     WHERE c.post_id = $1 ORDER BY c.created_at ASC`,
    [req.params.id]
  );
  res.json({
    post: (await decorate(req.user.id, rows))[0],
    comments: c.rows.map((x) => shapeComment({ ...x, mine: x.author_id === req.user.id })),
  });
});

// Authors can delete their own post. Admins can delete any post (after review).
router.delete('/posts/:id', async (req, res) => {
  if (!UUID.test(req.params.id)) return res.status(404).json({ error: 'Post not found' });
  const isAdmin = req.user.role === 'admin';
  const { rowCount } = await db.query(
    `DELETE FROM posts WHERE id = $1 AND ($3::boolean OR author_id = $2)`,
    [req.params.id, req.user.id, isAdmin]
  );
  if (!rowCount) return res.status(404).json({ error: 'Post not found' });
  res.json({ ok: true });
});

// ---- Comments -------------------------------------------------------------------------------

router.post('/posts/:id/comments', members, commentLimiter, async (req, res) => {
  if (!UUID.test(req.params.id)) return res.status(404).json({ error: 'Post not found' });
  const r = z.object({ body: z.string().trim().min(1).max(500) }).safeParse(req.body);
  if (!r.success) return res.status(400).json({ error: 'Write a comment (up to 500 characters)' });
  const exists = await db.query(`SELECT 1 FROM posts WHERE id = $1`, [req.params.id]);
  if (!exists.rows[0]) return res.status(404).json({ error: 'Post not found' });
  const ins = await db.query(
    `INSERT INTO comments (post_id, author_id, body) VALUES ($1, $2, $3) RETURNING id`,
    [req.params.id, req.user.id, r.data.body]
  );
  const { rows } = await db.query(
    `SELECT c.id, c.body, c.created_at, u.full_name AS author
     FROM comments c JOIN users u ON u.id = c.author_id WHERE c.id = $1`,
    [ins.rows[0].id]
  );
  res.status(201).json({ comment: shapeComment({ ...rows[0], mine: true }) });
});

router.delete('/comments/:id', members, async (req, res) => {
  if (!UUID.test(req.params.id)) return res.status(404).json({ error: 'Comment not found' });
  const { rowCount } = await db.query(`DELETE FROM comments WHERE id = $1 AND author_id = $2`, [
    req.params.id,
    req.user.id,
  ]);
  if (!rowCount) return res.status(404).json({ error: 'Comment not found' });
  res.json({ ok: true });
});

// ---- Reports --------------------------------------------------------------------------------

router.post('/posts/:id/report', members, async (req, res) => {
  if (!UUID.test(req.params.id)) return res.status(404).json({ error: 'Post not found' });
  const r = z.object({ reason: z.enum(REASONS) }).safeParse(req.body);
  if (!r.success) return res.status(400).json({ error: 'Pick a reason' });
  const post = await db.query(`SELECT author_id FROM posts WHERE id = $1`, [req.params.id]);
  if (!post.rows[0]) return res.status(404).json({ error: 'Post not found' });
  if (post.rows[0].author_id === req.user.id) return res.status(400).json({ error: 'You cannot report your own post' });
  // Reporting twice is harmless: the second one is ignored.
  await db.query(
    `INSERT INTO post_reports (post_id, reporter_id, reason) VALUES ($1, $2, $3)
     ON CONFLICT (post_id, reporter_id) DO NOTHING`,
    [req.params.id, req.user.id, r.data.reason]
  );
  res.status(201).json({ ok: true });
});

// ---- Admin queue ----------------------------------------------------------------------------

// Posts with open reports, oldest report first.
router.get('/reports', admins, async (_req, res) => {
  const { rows } = await db.query(
    `SELECT p.id, p.body, p.created_at, u.full_name AS author,
            count(r.id) AS report_count, min(r.created_at) AS first_reported
     FROM posts p
     JOIN users u ON u.id = p.author_id
     JOIN post_reports r ON r.post_id = p.id AND r.status = 'open'
     GROUP BY p.id, p.body, p.created_at, u.full_name
     ORDER BY min(r.created_at) ASC`
  );
  const reasons = await db.query(`SELECT post_id, reason FROM post_reports WHERE status = 'open'`);
  const byPost = {};
  for (const x of reasons.rows) (byPost[x.post_id] ||= []).push(x.reason);
  res.json({
    reports: rows.map((r) => ({
      post_id: r.id,
      body: r.body,
      author: firstName(r.author),
      posted_at: r.created_at,
      report_count: Number(r.report_count),
      first_reported: r.first_reported,
      reasons: [...new Set(byPost[r.id] || [])],
    })),
  });
});

// "Keep": the post stays and its open reports are closed.
router.post('/reports/:postId/dismiss', admins, async (req, res) => {
  if (!UUID.test(req.params.postId)) return res.status(404).json({ error: 'Post not found' });
  const { rowCount } = await db.query(
    `UPDATE post_reports SET status = 'dismissed' WHERE post_id = $1 AND status = 'open'`,
    [req.params.postId]
  );
  if (!rowCount) return res.status(404).json({ error: 'No open reports for that post' });
  res.json({ ok: true });
});
// "Delete": DELETE /community/posts/:id (admins may delete any post; its comments and reports go with it).

module.exports = router;