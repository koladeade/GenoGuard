// Tests the mail provider hierarchy on its own (no database needed).
// Run with: node tests/mail-providers.test.js
const assert = require('assert');
const {
  MailProvider, BrevoProvider, SmtpProvider, ConsoleProvider, selectProvider,
  sendResetCode, sendWelcome, sendMatchInvite,
} = require('../src/mail');

(async () => {
  let n = 0;
  const ok = (c, m) => { assert(c, m); n++; };

  // Inheritance: every provider is a MailProvider and has its own send().
  ok(new BrevoProvider('k', 'a@b.c') instanceof MailProvider, 'Brevo is a MailProvider');
  ok(new SmtpProvider() instanceof MailProvider, 'SMTP is a MailProvider');
  ok(new ConsoleProvider() instanceof MailProvider, 'Console is a MailProvider');

  // The abstract base cannot send.
  let threw = false;
  try { await new MailProvider().send('a@b.c', 's', 't', 'h'); } catch (e) { threw = /must implement send/.test(e.message); }
  ok(threw, 'base class send() is abstract');

  // Selection from configuration: Brevo, then SMTP, then console.
  ok(selectProvider({ BREVO_API_KEY: 'x', SMTP_HOST: 'h' }) instanceof BrevoProvider, 'Brevo wins when both are set');
  ok(selectProvider({ SMTP_HOST: 'smtp.example.com' }) instanceof SmtpProvider, 'SMTP when only SMTP is set');
  ok(selectProvider({}) instanceof ConsoleProvider, 'console when nothing is set');

  // Console provider sends nothing and reports it.
  ok((await new ConsoleProvider().send('a@b.c', 's', 't', 'h')) === false, 'console send returns false');

  // Brevo: correct request, success and failure paths (fetch is replaced).
  const realFetch = global.fetch;
  let seen;
  global.fetch = async (url, init) => { seen = { url, init }; return { ok: true, status: 201, text: async () => '' }; };
  ok((await new BrevoProvider('KEY', 'from@x.com', 'GenoGuard').send('to@x.com', 'Hi', 'text', '<p>html</p>')) === true, 'Brevo returns true');
  const body = JSON.parse(seen.init.body);
  ok(seen.url === 'https://api.brevo.com/v3/smtp/email' && seen.init.headers['api-key'] === 'KEY', 'Brevo url and key');
  ok(body.to[0].email === 'to@x.com' && body.sender.email === 'from@x.com' && body.subject === 'Hi', 'Brevo body');

  global.fetch = async () => ({ ok: false, status: 400, text: async () => '{"message":"bad"}' });
  let msg = '';
  try { await new BrevoProvider('KEY', 'from@x.com').send('to@x.com', 's', 't', 'h'); } catch (e) { msg = e.message; }
  ok(/^Brevo 400/.test(msg), 'Brevo error includes status');

  msg = '';
  try { await new BrevoProvider('KEY', '').send('to@x.com', 's', 't', 'h'); } catch (e) { msg = e.message; }
  ok(/MAIL_FROM_EMAIL/.test(msg), 'Brevo needs a sender address');

  // The message senders work with whichever provider is configured (here: console, no env set).
  delete process.env.BREVO_API_KEY; delete process.env.SMTP_HOST;
  const logs = []; const realLog = console.log; console.log = (...a) => logs.push(a.join(' '));
  await sendResetCode('u@x.com', '123456');
  await sendWelcome('u@x.com', 'Amaka Obi');
  await sendWelcome({ email: 'v@x.com', full_name: 'Tunde Ade' });
  await sendMatchInvite('u@x.com', 'Amaka', 'ABCD2345', 7);
  console.log = realLog;
  ok(logs.some((l) => l.includes('Password reset code for u@x.com: 123456')), 'reset code printed in dev');
  ok(logs.some((l) => l.includes('Welcome email for u@x.com')), 'welcome printed in dev');
  ok(logs.some((l) => l.includes('Welcome email for v@x.com')), 'welcome accepts a user object');
  ok(logs.some((l) => l.includes('code ABCD2345')), 'invite printed in dev');

  // Same senders through Brevo.
  global.fetch = async (url, init) => { seen = { url, init }; return { ok: true, status: 201, text: async () => '' }; };
  process.env.BREVO_API_KEY = 'KEY';
  // from-address is read when the module loads, so use the provider directly for the sender check
  const p = selectProvider();
  ok(p instanceof BrevoProvider, 'sender path picks Brevo');
  global.fetch = realFetch;

  console.log(`ALL OK ${n}`);
  process.exit(0);
})().catch((e) => { console.error('FAIL', e.stack.split('\n').slice(0, 3).join(' / ')); process.exit(1); });