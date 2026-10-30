require('./support/setup');
const express = require('express');
const db = require('./support/db');
const assert = require('assert');
(async () => {
  const A = '11111111-1111-1111-1111-111111111111', B = '22222222-2222-2222-2222-222222222222', ADM = '33333333-3333-3333-3333-333333333333', C = '44444444-4444-4444-4444-444444444444';
  await db.query(`INSERT INTO users VALUES ($1,'a','Amaka Obi'),($2,'b','Tunde'),($3,'c','Admin One'),($4,'d',NULL)`, [A, B, ADM, C]);
  const app = express(); app.use(express.json()); app.use('/community', require('../src/routes/community'));
  app.use((e, _q, r, _n) => { console.error(e); r.status(500).json({ error: 'Server error' }); });
  const srv = app.listen(0); const base = `http://localhost:${srv.address().port}/community`;
  const call = (m, p, uid, role, body) => fetch(base + p, { method: m, headers: { 'content-type': 'application/json', ...(uid ? { 'x-uid': uid, 'x-role': role } : {}) }, body: body ? JSON.stringify(body) : undefined }).then(async r => ({ s: r.status, j: await r.json() }));
  let n = 0; const ok = (c, m) => { assert(c, m); n++; };

  ok((await call('GET', '/posts')).s === 401, 'no auth');
  ok((await call('GET', '/posts', ADM, 'admin')).s === 403, 'admin cannot read feed');
  ok((await call('POST', '/posts', A, 'patient', { body: '   ' })).s === 400, 'blank post');
  ok((await call('POST', '/posts', A, 'patient', { body: 'x'.repeat(1001) })).s === 400, 'too long');

  const p1 = await call('POST', '/posts', A, 'patient', { body: 'Drinking water helps me.' });
  ok(p1.s === 201 && p1.j.post.author === 'Amaka' && p1.j.post.mine === true && p1.j.post.comment_count === 0, 'create post');
  ok(!('author_id' in p1.j.post) && !JSON.stringify(p1.j.post).includes('@'), 'no private fields leaked');
  const pid = p1.j.post.id;
  await new Promise(r => setTimeout(r, 10));
  const p2 = await call('POST', '/posts', B, 'explorer', { body: 'Does anyone know a good clinic in Abuja?' });
  const pid2 = p2.j.post.id;
  const feed = await call('GET', '/posts', B, 'explorer');
  ok(feed.j.posts.length === 2 && feed.j.posts[0].id === pid2, 'newest first');
  ok(feed.j.posts[0].mine === true && feed.j.posts[1].mine === false, 'mine flag');
  ok((await call('GET', '/posts?before=' + encodeURIComponent(feed.j.posts[0].created_at), B, 'explorer')).j.posts.length === 1, 'before paging');

  const cm = await call('POST', `/posts/${pid}/comments`, B, 'explorer', { body: 'Thank you!' });
  ok(cm.s === 201 && cm.j.comment.author === 'Tunde' && cm.j.comment.mine === true, 'comment');
  ok((await call('POST', `/posts/${pid}/comments`, B, 'explorer', { body: '' })).s === 400, 'blank comment');
  ok((await call('POST', `/posts/00000000-0000-0000-0000-000000000000/comments`, B, 'explorer', { body: 'hi' })).s === 404, 'comment on missing post');
  ok((await call('POST', `/posts/nope/comments`, B, 'explorer', { body: 'hi' })).s === 404, 'bad id');
  const det = await call('GET', `/posts/${pid}`, A, 'patient');
  ok(det.j.comments.length === 1 && det.j.post.comment_count === 1 && det.j.comments[0].mine === false, 'detail');
  ok((await call('DELETE', `/comments/${cm.j.comment.id}`, A, 'patient')).s === 404, 'cannot delete others comment');
  const cm2 = await call('POST', `/posts/${pid}/comments`, A, 'patient', { body: 'mine' });
  ok((await call('DELETE', `/comments/${cm2.j.comment.id}`, A, 'patient')).s === 200, 'delete own comment');

  // anonymous-name fallback
  const p3 = await call('POST', '/posts', C, 'explorer', { body: 'No name set' });
  ok(p3.j.post.author === 'Member', 'fallback name');
  await call('DELETE', `/posts/${p3.j.post.id}`, C, 'explorer');

  // reports
  ok((await call('POST', `/posts/${pid}/report`, A, 'patient', { reason: 'spam' })).s === 400, 'cannot report own');
  ok((await call('POST', `/posts/${pid}/report`, B, 'explorer', { reason: 'nonsense' })).s === 400, 'bad reason');
  ok((await call('POST', `/posts/${pid}/report`, B, 'explorer', { reason: 'harmful_advice' })).s === 201, 'report');
  ok((await call('POST', `/posts/${pid}/report`, B, 'explorer', { reason: 'abuse' })).s === 201, 'duplicate report harmless');
  ok((await db.query('SELECT count(*)::int c FROM post_reports')).rows[0].c === 1, 'one report row');
  ok((await call('GET', '/posts', B, 'explorer')).j.posts.find(p => p.id === pid).reported === true, 'reported flag for reporter');
  ok((await call('GET', '/posts', A, 'patient')).j.posts.find(p => p.id === pid).reported === false, 'not flagged for others');

  ok((await call('GET', '/reports', A, 'patient')).s === 403, 'queue is admin only');
  const q = await call('GET', '/reports', ADM, 'admin');
  ok(q.s === 200 && q.j.reports.length === 1 && q.j.reports[0].post_id === pid && q.j.reports[0].report_count === 1 && q.j.reports[0].reasons[0] === 'harmful_advice', 'queue content');
  ok(q.j.reports[0].author === 'Amaka' && q.j.reports[0].body.includes('water'), 'queue shows post and first name');

  // keep
  ok((await call('POST', `/reports/${pid}/dismiss`, A, 'patient')).s === 403, 'dismiss admin only');
  ok((await call('POST', `/reports/${pid}/dismiss`, ADM, 'admin')).s === 200, 'dismiss');
  ok((await call('GET', '/reports', ADM, 'admin')).j.reports.length === 0, 'queue empty after keep');
  ok((await call('POST', `/reports/${pid}/dismiss`, ADM, 'admin')).s === 404, 'nothing to dismiss twice');

  // delete flow
  await call('POST', `/posts/${pid2}/report`, A, 'patient', { reason: 'abuse' });
  await call('POST', `/posts/${pid2}/comments`, A, 'patient', { body: 'reply' });
  ok((await call('DELETE', `/posts/${pid2}`, A, 'patient')).s === 404, 'cannot delete others post');
  ok((await call('DELETE', `/posts/${pid2}`, ADM, 'admin')).s === 200, 'admin deletes any post');
  ok((await db.query('SELECT count(*)::int c FROM comments WHERE post_id=$1', [pid2])).rows[0].c === 0, 'comments cascade');
  ok((await db.query('SELECT count(*)::int c FROM post_reports WHERE post_id=$1', [pid2])).rows[0].c === 0, 'reports cascade');
  ok((await call('GET', `/posts/${pid2}`, A, 'patient')).s === 404, 'gone');
  ok((await call('DELETE', `/posts/${pid}`, A, 'patient')).s === 200, 'author deletes own');

  // rate limit: 10 posts per hour per user
  let last; for (let i = 0; i < 11; i++) last = await call('POST', '/posts', B, 'explorer', { body: 'spam ' + i });
  ok(last.s === 429, 'post rate limit');
  console.log(n + ' checks passed'); srv.close(); process.exit(0);
})().catch(e => { console.error('FAIL', e.message); process.exit(1); });
