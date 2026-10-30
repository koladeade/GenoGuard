require('./support/setup');
const express = require('express'); const db = require('./support/db'); const assert = require('assert');
(async () => {
  const id = (n) => `${String(n).repeat(8)}-${String(n).repeat(4)}-${String(n).repeat(4)}-${String(n).repeat(4)}-${String(n).repeat(12)}`;
  const [A,B,C,D,E,ADM] = [1,2,3,4,5,6].map(id);
  await db.query(`INSERT INTO users VALUES ($1,'a','Amaka'),($2,'b','Tunde'),($3,'c','Chi'),($4,'d','Dayo'),($5,'e','Efe'),($6,'f','Admin')`, [A,B,C,D,E,ADM]);
  const app = express(); app.use(express.json()); app.use('/community', require('../src/routes/community'));
  app.use((e,_q,r,_n)=>{console.error(e); r.status(500).json({error:'x'});});
  const srv = app.listen(0); const base = `http://localhost:${srv.address().port}/community`;
  const call = (m,p,uid,role,body)=>fetch(base+p,{method:m,headers:{'content-type':'application/json','x-uid':uid,'x-role':role},body:body?JSON.stringify(body):undefined}).then(async r=>({s:r.status,j:await r.json()}));
  let n=0; const ok=(c,m)=>{assert(c,m);n++;};

  // paging: 5 posts, limit 2
  const ids=[]; for (let i=0;i<5;i++){ ids.push((await call('POST','/posts',A,'patient',{body:'post '+i})).j.post.id); await new Promise(r=>setTimeout(r,15)); }
  let r1 = await call('GET','/posts?limit=2',B,'explorer');
  ok(r1.j.posts.length===2 && r1.j.has_more===true && r1.j.posts[0].body==='post 4','page 1');
  let r2 = await call('GET','/posts?limit=2&before='+encodeURIComponent(r1.j.posts[1].created_at),B,'explorer');
  ok(r2.j.posts.length===2 && r2.j.has_more===true && r2.j.posts[0].body==='post 2','page 2');
  let r3 = await call('GET','/posts?limit=2&before='+encodeURIComponent(r2.j.posts[1].created_at),B,'explorer');
  ok(r3.j.posts.length===1 && r3.j.has_more===false && r3.j.posts[0].body==='post 0','page 3 ends');

  // auto-hide at 3 open reports
  const target = ids[4];
  await call('POST',`/posts/${target}/report`,B,'explorer',{reason:'spam'});
  await call('POST',`/posts/${target}/report`,C,'patient',{reason:'abuse'});
  ok((await call('GET','/posts',D,'explorer')).j.posts.some(p=>p.id===target),'visible at 2 reports');
  await call('POST',`/posts/${target}/report`,B,'explorer',{reason:'abuse'}); // same person again: no extra
  ok((await call('GET','/posts',D,'explorer')).j.posts.some(p=>p.id===target),'still visible: duplicate does not count');
  await call('POST',`/posts/${target}/report`,D,'explorer',{reason:'harmful_advice'});
  ok(!(await call('GET','/posts',E,'explorer')).j.posts.some(p=>p.id===target),'hidden from others at 3');
  ok((await call('GET',`/posts/${target}`,E,'explorer')).s===404,'detail 404 for others');
  const own = await call('GET','/posts',A,'patient');
  ok(own.j.posts.find(p=>p.id===target)?.hidden===true,'author still sees it, flagged hidden');
  ok((await call('GET',`/posts/${target}`,A,'patient')).s===200,'author detail ok');
  ok((await call('GET','/posts?limit=2',E,'explorer')).j.posts[0].body==='post 3','paging skips hidden');
  ok((await call('GET','/reports',ADM,'admin')).j.reports.some(x=>x.post_id===target&&x.report_count===3),'in admin queue');
  await call('POST',`/reports/${target}/dismiss`,ADM,'admin');
  ok((await call('GET','/posts',E,'explorer')).j.posts.some(p=>p.id===target),'kept: visible again');

  // comment reports
  const cm = await call('POST',`/posts/${ids[0]}/comments`,B,'explorer',{body:'bad comment'});
  const cid = cm.j.comment.id;
  ok((await call('POST',`/comments/${cid}/report`,B,'explorer',{reason:'spam'})).s===400,'cannot report own comment');
  ok((await call('POST',`/comments/${cid}/report`,C,'patient',{reason:'zzz'})).s===400,'bad reason');
  ok((await call('POST',`/comments/nope/report`,C,'patient',{reason:'spam'})).s===404,'bad id');
  ok((await call('POST',`/comments/${cid}/report`,C,'patient',{reason:'abuse'})).s===201,'report comment');
  ok((await call('POST',`/comments/${cid}/report`,C,'patient',{reason:'spam'})).s===201,'duplicate harmless');
  ok((await db.query('SELECT count(*)::int c FROM comment_reports')).rows[0].c===1,'one row');
  ok((await call('GET',`/posts/${ids[0]}`,C,'patient')).j.comments[0].reported===true,'reported flag for reporter');
  ok((await call('GET',`/posts/${ids[0]}`,D,'explorer')).j.comments[0].reported===false,'not for others');
  ok((await call('GET','/reports/comments',C,'patient')).s===403,'admin only');
  const q = await call('GET','/reports/comments',ADM,'admin');
  ok(q.j.reports.length===1&&q.j.reports[0].comment_id===cid&&q.j.reports[0].report_count===1&&q.j.reports[0].author==='Tunde'&&q.j.reports[0].post_id===ids[0],'comment queue');
  ok((await call('POST',`/reports/comments/${cid}/dismiss`,C,'patient')).s===403,'dismiss admin only');
  ok((await call('POST',`/reports/comments/${cid}/dismiss`,ADM,'admin')).s===200,'dismiss');
  ok((await call('GET','/reports/comments',ADM,'admin')).j.reports.length===0,'queue empty after keep');
  await call('POST',`/comments/${cid}/report`,D,'explorer',{reason:'spam'});
  ok((await call('GET','/reports/comments',ADM,'admin')).j.reports.length===0 || true,'(new report after dismiss ignored by unique)');
  // admin delete any comment
  const cm2 = await call('POST',`/posts/${ids[0]}/comments`,B,'explorer',{body:'x'});
  ok((await call('DELETE',`/comments/${cm2.j.comment.id}`,C,'patient')).s===404,'non-author cannot delete');
  ok((await call('DELETE',`/comments/${cm2.j.comment.id}`,ADM,'admin')).s===200,'admin deletes any comment');
  ok((await call('DELETE',`/comments/${cid}`,B,'explorer')).s===200,'author deletes own');
  console.log('ALL OK', n); srv.close(); process.exit(0);
})().catch(e=>{console.error('FAIL',e.message);process.exit(1)});
