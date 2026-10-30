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

// A post with this many open reports from different people is hidden from everyone but its author
// until an admin keeps it (reports closed) or deletes it.
const HIDE_AFTER = Number(process.env.REPORTS_TO_HIDE) || 3;

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

// Ids of posts this person must not see: hidden ones that are not their own.
async function hiddenFrom(userId) {
  const { rows } = await db.query(
    `SELECT r.post_id, p.author_id FROM post_reports r JOIN posts p ON p.id = r.post_id WHERE r.status = 'open'`
  );
  const n = {};
  for (const x of rows) if (x.author_id !== userId) n[x.post_id] = (n[x.post_id] || 0) + 1;
  return Object.keys(n).filter((id) => n[id] >= HIDE_AFTER);
}

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
  const open = await db.query(
    `SELECT post_id, count(*) AS n FROM post_reports WHERE status = 'open' AND post_id IN (${placeholders(ids, 1)}) GROUP BY post_id`,
    ids
  );
  const openN = Object.fromEntries(open.rows.map((c) => [c.post_id, Number(c.n)]));
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
    hidden: (openN[r.id] || 0) >= HIDE_AFTER, // only ever true for the author's own view
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
  const hidden = await hiddenFrom(req.user.id);
  const params = [q.data.limit];
  const where = [];
  if (q.data.before) {
    params.push(q.data.before);
    where.push(`p.created_at < $${params.length}`);
  }
  if (hidden.length) {
    where.push(`p.id NOT IN (${placeholders(hidden, params.length + 1)})`);
    params.push(...hidden);
  }
  const { rows } = await db.query(
    `${POST_SELECT}
     ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
     ORDER BY p.created_at DESC
     LIMIT $1`,
    params
  );
  res.json({ posts: await decorate(req.user.id, rows), has_more: rows.length === q.data.limit });
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
  if ((await hiddenFrom(req.user.id)).includes(req.params.id)) {
    return res.status(404).json({ error: 'Post not found' });
  }
  const c = await db.query(
    `SELECT c.id, c.body, c.created_at, c.author_id, u.full_name AS author
     FROM comments c JOIN users u ON u.id = c.author_id
     WHERE c.post_id = $1 ORDER BY c.created_at ASC`,
    [req.params.id]
  );
  const cids = c.rows.map((x) => x.id);
  const mineReported = cids.length
    ? await db.query(
        `SELECT comment_id FROM comment_reports WHERE reporter_id = $1 AND comment_id IN (${placeholders(cids, 2)})`,
        [req.user.id, ...cids]
      )
    : { rows: [] };
  const reportedC = new Set(mineReported.rows.map((x) => x.comment_id));
  res.json({
    post: (await decorate(req.user.id, rows))[0],
    comments: c.rows.map((x) => ({ ...shapeComment({ ...x, mine: x.author_id === req.user.id }), reported: reportedC.has(x.id) })),
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

// Authors can delete their own comment. Admins can delete any comment (after review).
router.delete('/comments/:id', async (req, res) => {
  if (!UUID.test(req.params.id)) return res.status(404).json({ error: 'Comment not found' });
  const isAdmin = req.user.role === 'admin';
  const { rowCount } = await db.query(
    `DELETE FROM comments WHERE id = $1 AND ($3::boolean OR author_id = $2)`,
    [req.params.id, req.user.id, isAdmin]
  );
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

router.post('/comments/:id/report', members, async (req, res) => {
  if (!UUID.test(req.params.id)) return res.status(404).json({ error: 'Comment not found' });
  const r = z.object({ reason: z.enum(REASONS) }).safeParse(req.body);
  if (!r.success) return res.status(400).json({ error: 'Pick a reason' });
  const c = await db.query(`SELECT author_id FROM comments WHERE id = $1`, [req.params.id]);
  if (!c.rows[0]) return res.status(404).json({ error: 'Comment not found' });
  if (c.rows[0].author_id === req.user.id) return res.status(400).json({ error: 'You cannot report your own comment' });
  await db.query(
    `INSERT INTO comment_reports (comment_id, reporter_id, reason) VALUES ($1, $2, $3)
     ON CONFLICT (comment_id, reporter_id) DO NOTHING`,
    [req.params.id, req.user.id, r.data.reason]
  );
  res.status(201).json({ ok: true });
});

// ---- Admin queue ----------------------------------------------------------------------------

// Comments with open reports, oldest report first. Comments are not auto-hidden; admins decide.
router.get('/reports/comments', admins, async (_req, res) => {
  const { rows } = await db.query(
    `SELECT c.id, c.body, c.created_at, c.post_id, u.full_name AS author,
            count(r.id) AS report_count, min(r.created_at) AS first_reported
     FROM comments c
     JOIN users u ON u.id = c.author_id
     JOIN comment_reports r ON r.comment_id = c.id AND r.status = 'open'
     GROUP BY c.id, c.body, c.created_at, c.post_id, u.full_name
     ORDER BY min(r.created_at) ASC`
  );
  const reasons = await db.query(`SELECT comment_id, reason FROM comment_reports WHERE status = 'open'`);
  const byComment = {};
  for (const x of reasons.rows) (byComment[x.comment_id] ||= []).push(x.reason);
  res.json({
    reports: rows.map((r) => ({
      comment_id: r.id,
      post_id: r.post_id,
      body: r.body,
      author: firstName(r.author),
      posted_at: r.created_at,
      report_count: Number(r.report_count),
      reasons: [...new Set(byComment[r.id] || [])],
    })),
  });
});

router.post('/reports/comments/:id/dismiss', admins, async (req, res) => {
  if (!UUID.test(req.params.id)) return res.status(404).json({ error: 'Comment not found' });
  const { rowCount } = await db.query(
    `UPDATE comment_reports SET status = 'dismissed' WHERE comment_id = $1 AND status = 'open'`,
    [req.params.id]
  );
  if (!rowCount) return res.status(404).json({ error: 'No open reports for that comment' });
  res.json({ ok: true });
});

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