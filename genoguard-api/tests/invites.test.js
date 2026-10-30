require('./support/setup');
const express = require('express'); const db = require('./support/db'); const mail = require('./support/mail'); const assert = require('assert');
(async () => {
  const id = (n) => `${String(n).repeat(8)}-${String(n).repeat(4)}-${String(n).repeat(4)}-${String(n).repeat(4)}-${String(n).repeat(12)}`;
  const [A,B,C,D] = [1,2,3,4].map(id);
  await db.query(`INSERT INTO users VALUES ($1,'amaka@x.com','Amaka Obi','AS'),($2,'tunde@x.com','Tunde Ade','AA'),($3,'chi@x.com','Chi','AA'),($4,'nogeno@x.com','Dayo',NULL)`, [A,B,C,D]);
  const app = express(); app.use(express.json()); app.use('/qr', require('../src/routes/qr'));
  app.use((e,_q,r,_n)=>{console.error(e); r.status(500).json({error:'x'});});
  const srv = app.listen(0); const base = `http://localhost:${srv.address().port}/qr`;
  const call = (m,p,uid,body)=>fetch(base+p,{method:m,headers:{'content-type':'application/json',...(uid?{'x-uid':uid}:{})},body:body?JSON.stringify(body):undefined}).then(async r=>({s:r.status,j:await r.json()}));
  let n=0; const ok=(c,m)=>{assert(c,m);n++;};

  ok((await call('POST','/invites',null,{email:'a@b.com'})).s===401,'auth');
  ok((await call('POST','/invites',C,{email:'nope'})).s===400,'bad email');
  ok((await call('POST','/invites',C,{email:'CHI@x.com'})).s===400,'own email (case-insens.)');
  ok((await call('POST','/invites',D,{email:'tunde@x.com'})).s===400,'needs genotype');
  ok(mail.sent.length===0,'nothing sent yet');

  mail.fail = true;
  ok((await call('POST','/invites',C,{email:'tunde@x.com'})).s===502,'email failure -> 502');
  ok((await db.query(`SELECT count(*)::int c FROM qr_shares`)).rows[0].c===0,'failed invite not stored');
  mail.fail = false;

  const inv = await call('POST','/invites',A,{email:' Tunde@X.com '});
  ok(inv.s===201 && inv.j.id && !('code' in inv.j),'invite created; code not returned to inviter');
  ok(mail.sent.length===1 && mail.sent[0].to==='tunde@x.com' && mail.sent[0].name==='Amaka' && /^[A-Z0-9]{8}$/.test(mail.sent[0].code),'email sent with first name + code');
  const code1 = mail.sent[0].code;

  // resend replaces the earlier code
  const inv2 = await call('POST','/invites',A,{email:'tunde@x.com'});
  const code2 = mail.sent[1].code;
  ok(code1!==code2,'new code on resend');
  ok((await call('POST','/claim',B,{code:code1})).s===404,'old code dead');

  // wrong person (right code, other account) cannot claim; reply does not leak
  const wrong = await call('POST','/claim',C,{code:code2});
  ok(wrong.s===404 && /invalid or has expired/.test(wrong.j.error),'other account cannot use the code');
  ok((await call('POST','/claim',A,{code:code2})).s===400,'owner cannot claim own');

  // lists
  let la = await call('GET','/invites',A);
  ok(la.j.sent.length===2 && la.j.sent.filter(x=>x.status==='open').length===1 && la.j.sent.find(x=>x.status==='open').other_name===null,'sent list');
  ok((await call('GET','/invites',B)).j.received.length===0,'nothing received yet');

  // invited person claims (email stored lowercase, matches)
  const cl = await call('POST','/claim',B,{code:code2});
  ok(cl.s===200 && cl.j.other_name==='Amaka','invitee claims');
  la = await call('GET','/invites',A);
  const open = la.j.sent.find(x=>x.id===inv2.j.id);
  ok(open.status==='requested' && open.other_name==='Tunde','owner sees request');
  const lb = await call('GET','/invites',B);
  ok(lb.j.received.length===1 && lb.j.received[0].status==='requested' && lb.j.received[0].other_name==='Amaka','invitee sees pending');
  ok(!JSON.stringify(la.j).includes('AA') && !JSON.stringify(lb.j).includes('"AS"'),'no genotype in lists');

  // no genotype before approval
  let st = await call('GET',`/shares/${open.id}`,B);
  ok(st.j.status==='requested' && !st.j.you,'no genotype before approval');
  ok((await call('POST',`/shares/${open.id}/decision`,B,{allow:true})).s===409,'invitee cannot approve');
  ok((await call('POST',`/shares/${open.id}/decision`,A,{allow:true})).s===200,'owner approves');
  st = await call('GET',`/shares/${open.id}`,B);
  ok(st.j.status==='approved' && st.j.you==='AA' && st.j.partner==='AS','result for invitee');
  st = await call('GET',`/shares/${open.id}`,A);
  ok(st.j.you==='AS' && st.j.partner==='AA','result for owner');
  ok((await call('GET',`/shares/${open.id}`,C)).s===404,'third party cannot read');

  // result window is 24h for invites: 11 minutes later still fine, 25 h later expired
  await db.query(`UPDATE qr_shares SET decided_at = $2 WHERE id = $1`, [open.id, new Date(Date.now()-11*60*1000)]);
  ok((await call('GET',`/shares/${open.id}`,B)).j.status==='approved','still open after 11 min');
  await db.query(`UPDATE qr_shares SET decided_at = $2 WHERE id = $1`, [open.id, new Date(Date.now()-25*3600*1000)]);
  ok((await call('GET',`/shares/${open.id}`,B)).j.status==='expired','expired after 25 h');
  ok((await call('GET','/invites',B)).j.received[0].status==='expired','list shows expired');

  // QR codes unaffected: creating a QR code does not cancel invites, and vice versa
  const inv3 = await call('POST','/invites',A,{email:'chi@x.com'});
  const q = await call('POST','/shares',A);
  ok(q.s===201,'qr create');
  ok((await call('GET','/invites',A)).j.sent.find(x=>x.id===inv3.j.id).status==='open','qr create leaves invites alone');
  const q2 = await call('POST','/shares',A);
  ok((await call('GET',`/shares/${q.j.id}`,A)).j.status==='expired','old qr code replaced');
  ok((await call('POST','/claim',C,{code:q2.j.code})).s===200,'anyone can still claim a QR code');

  // cancel + cap + expiry
  ok((await call('DELETE',`/invites/${inv3.j.id}`,B)).s===404,'only owner cancels');
  ok((await call('DELETE',`/invites/${inv3.j.id}`,A)).s===200,'owner cancels');
  ok((await call('GET','/invites',A)).j.sent.find(x=>x.id===inv3.j.id).status==='expired','cancelled shows expired');
  ok((await call('POST','/invites',A,{email:'a1@x.com'})).s===201 && (await call('POST','/invites',A,{email:'a2@x.com'})).s===201,'5th invite in the hour ok');
  
  // remove: only finished invitations, only from my own list
  const lb2 = (await call('GET','/invites',B)).j.received[0];
  ok(lb2.status==='expired','precondition: expired');
  ok((await call('POST',`/invites/${lb2.id}/remove`,C)).s===404,'stranger cannot remove');
  ok((await call('POST',`/invites/${lb2.id}/remove`,B)).s===200,'invitee removes expired');
  ok((await call('GET','/invites',B)).j.received.length===0,'gone from invitee list');
  ok((await call('GET','/invites',A)).j.sent.some(x=>x.id===lb2.id),'still in sender list');
  const live = (await call('GET','/invites',A)).j.sent.find(x=>x.status==='open');
  ok((await call('POST',`/invites/${live.id}/remove`,A)).s===400,'live invite cannot be removed');
  ok((await call('POST',`/invites/${lb2.id}/remove`,A)).s===200,'sender removes too');
  ok(!(await call('GET','/invites',A)).j.sent.some(x=>x.id===lb2.id),'gone from sender list');
  console.log('ALL OK', n); srv.close(); process.exit(0);
})().catch(e=>{console.error('FAIL',e.stack.split('\n').slice(0,3).join(' / '));process.exit(1)});
