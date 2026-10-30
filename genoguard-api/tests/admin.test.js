require('./support/setup');
process.env.JWT_SECRET='s3cret';
const express = require('express'); const db = require('./support/db'); const assert = require('assert');
(async () => {
  const id = (n) => `${String(n).repeat(8)}-${String(n).repeat(4)}-${String(n).repeat(4)}-${String(n).repeat(4)}-${String(n).repeat(12)}`;
  const [P1,E1,E2,ADM,ADM2] = [1,2,3,4,5].map(id);
  await db.query(`INSERT INTO users (id,email,full_name,role,usage_logs_consent) VALUES ($1,'p1@x.com','Amaka Obi','patient',true),($2,'e1@x.com','Tunde','explorer',false),($3,'e2@x.com','=Evil','explorer',true),($4,'admin@x.com','Admin One','admin',false),($5,'admin2@x.com','Admin Two','admin',false)`, [P1,E1,E2,ADM,ADM2]);
  await db.query(`INSERT INTO quiz_responses (user_id,intention,confidence) VALUES ($1,5,4),($1,4,4),($2,2,1),($3,3,3)`, [P1,E1,E2]);
  await db.query(`INSERT INTO usage_events (user_id,event,item) VALUES ($1,'compat_check',NULL),($1,'learning_open','quiz'),($2,'learning_open','quiz')`, [P1,E2]);
  const app = express(); app.use(express.json()); app.use('/admin', require('../src/routes/admin')); app.use('/community', require('../src/routes/community'));
  app.use((e,_q,r,_n)=>{console.error(e); r.status(500).json({error:'x'});});
  const srv = app.listen(0); const base = `http://localhost:${srv.address().port}`;
  const call = async (m,p,uid,body)=>{ const r = await fetch(base+p,{method:m,headers:{'content-type':'application/json',...(uid?{'x-uid':uid}:{})},body:body?JSON.stringify(body):undefined}); const t = await r.text(); let j; try{j=JSON.parse(t)}catch{j=t}; return {s:r.status,j,h:r.headers}; };
  let n=0; const ok=(c,m)=>{assert(c,m);n++;};

  ok((await call('GET','/admin/overview',null)).s===401,'auth');
  ok((await call('GET','/admin/overview',P1)).s===403,'patient blocked');
  ok((await call('GET','/admin/users',E1)).s===403,'explorer blocked');
  ok((await call('GET','/admin/research/export?kind=quiz',P1)).s===403,'export blocked for non-admin');

  const ov = (await call('GET','/admin/overview',ADM)).j;
  ok(ov.users.patient===1 && ov.users.explorer===2 && ov.users.admin===2,'role counts');
  ok(ov.new_users_7d===5 && ov.quiz_responses===4 && ov.open_post_reports===0,'overview numbers');

  // users
  const ul = (await call('GET','/admin/users',ADM)).j;
  ok(ul.users.length===5 && ul.users.every(u=>!('genotype' in u)&&!('password_hash' in u)&&!('location' in u)),'users list has no health or secret fields');
  ok((await call('GET','/admin/users?q=AMAKA',ADM)).j.users.length===1,'search by name, case-insensitive');
  ok((await call('GET','/admin/users?q=x.com&limit=2',ADM)).j.has_more===true,'paging flag');
  ok((await call('POST',`/admin/users/${ADM2}/disable`,ADM)).s===400,'cannot disable another admin');
  ok((await call('POST',`/admin/users/${ADM}/disable`,ADM)).s===400,'cannot disable self');
  ok((await call('POST',`/admin/users/nope/disable`,ADM)).s===404,'bad id');
  await db.query(`INSERT INTO refresh_tokens (user_id) VALUES ($1)`,[E1]);
  ok((await call('POST',`/admin/users/${E1}/disable`,ADM)).s===200,'disable');
  ok((await db.query(`SELECT revoked_at FROM refresh_tokens WHERE user_id=$1`,[E1])).rows[0].revoked_at,'sessions revoked');
  ok((await call('GET','/admin/users?q=e1@x',ADM)).j.users[0].disabled===true,'shows disabled');
  ok((await call('GET','/admin/overview',ADM)).j.disabled_users===1,'overview counts disabled');
  ok((await call('POST',`/admin/users/${E1}/enable`,ADM)).s===200,'enable');
  ok((await call('DELETE',`/admin/users/${E2}`,ADM)).s===200,'delete user');
  ok((await db.query(`SELECT count(*)::int c FROM users WHERE id=$1`,[E2])).rows[0].c===0,'user gone');
  ok((await db.query(`SELECT count(*)::int c FROM quiz_responses WHERE user_id=$1`,[E2])).rows[0].c===0,'their data went with them');

  // research
  const rs = (await call('GET','/admin/research/summary',ADM)).j;
  ok(rs.quiz.responses===3 && rs.quiz.participants===2 && rs.quiz.intention.average===3.67 && rs.quiz.intention.counts.join()==='0,1,0,1,1','quiz summary');
  ok(rs.usage.users_with_consent===1 && rs.usage.events.find(e=>e.event==='learning_open'&&e.item==='quiz').count===1,'usage summary');
  const ex = await call('GET','/admin/research/export?kind=quiz',ADM);
  ok(ex.s===200 && /text\/csv/.test(ex.h.get('content-type')),'csv content type');
  const lines = ex.j.trim().split('\n');
  ok(lines[0]==='participant,group,intention_1to5,confidence_1to5,submitted_at' && lines.length===4,'csv rows');
  ok(!ex.j.includes('@') && !ex.j.includes(P1) && !ex.j.includes('Amaka') && /^[0-9a-f]{10},patient,5,4,/.test(lines[1]),'csv anonymised');
  ok(lines[1].split(',')[0]===lines[2].split(',')[0],'same participant id across rows');
  ok((await call('GET','/admin/research/export?kind=usage',ADM)).j.split('\n')[0]==='participant,group,event,item,occurred_at','usage csv');
  ok((await call('GET','/admin/research/export?kind=other',ADM)).s===400,'bad kind');

  // community hooks -> audit
  const post = await call('POST','/community/posts',P1,{body:'hello'});
  await call('POST','/community/posts/'+post.j.post.id+'/report',E1,{reason:'spam'});
  ok((await call('POST',`/community/reports/${post.j.post.id}/dismiss`,ADM)).s===200,'keep post');
  ok((await call('DELETE',`/community/posts/${post.j.post.id}`,ADM)).s===200,'admin deletes post');
  const au = (await call('GET','/admin/audit',ADM)).j.entries;
  const acts = au.map(a=>a.action);
  ok(['user_disabled','user_enabled','user_deleted','data_exported','post_kept','post_deleted'].every(a=>acts.includes(a)),'audit has all actions: '+acts);
  ok(au[0].admin==='Admin' && !JSON.stringify(au).includes('@') && !JSON.stringify(au).includes('Tunde'),'audit has no personal data');
  ok(au.find(a=>a.action==='user_deleted').detail==='explorer 33333333','audit label');
  ok((await call('GET','/admin/audit',P1)).s===403,'audit admin only');
  console.log('ALL OK',n); srv.close(); process.exit(0);
})().catch(e=>{console.error('FAIL',e.message);process.exit(1)});
