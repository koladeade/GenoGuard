const nodemailer = require('nodemailer');

const FROM_EMAIL = process.env.MAIL_FROM_EMAIL || '';
const FROM_NAME = process.env.MAIL_FROM_NAME || 'GenoGuard';

const esc = (v) => String(v).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);


class MailProvider {
 
  async send(_to, _subject, _text, _html) {
    throw new Error(`${this.constructor.name} must implement send()`);
  }
}

class BrevoProvider extends MailProvider {
  constructor(apiKey = process.env.BREVO_API_KEY, fromEmail = FROM_EMAIL, fromName = FROM_NAME) {
    super();
    this.apiKey = apiKey;
    this.fromEmail = fromEmail;
    this.fromName = fromName;
  }

  async send(to, subject, text, html) {
    if (!this.fromEmail) throw new Error('MAIL_FROM_EMAIL is not set');
    const res = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: { 'api-key': this.apiKey, 'content-type': 'application/json', accept: 'application/json' },
      body: JSON.stringify({
        sender: { name: this.fromName, email: this.fromEmail },
        to: [{ email: to }],
        subject,
        textContent: text,
        htmlContent: html,
      }),
    });
    if (!res.ok) throw new Error(`Brevo ${res.status}: ${(await res.text()).slice(0, 200)}`);
    return true;
  }
}

class SmtpProvider extends MailProvider {
  async send(to, subject, text, html) {
    const transport = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: Number(process.env.SMTP_PORT || 587),
      secure: Number(process.env.SMTP_PORT) === 465,
      auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } : undefined,
    });
    await transport.sendMail({
      from: process.env.MAIL_FROM || `"${FROM_NAME}" <${FROM_EMAIL}>`,
      to,
      subject,
      text,
      html,
    });
    return true;
  }
}

/** Development fallback: sends nothing, so the caller prints what the developer needs to see. */
class ConsoleProvider extends MailProvider {
  async send() {
    return false;
  }
}


function selectProvider(env = process.env) {
  if (env.BREVO_API_KEY) return new BrevoProvider(env.BREVO_API_KEY);
  if (env.SMTP_HOST) return new SmtpProvider();
  return new ConsoleProvider();
}

async function deliver(to, subject, text, html) {
  return selectProvider().send(to, subject, text, html);
}

// ---------------------------------------------------------------------------------------------
// Messages
// ---------------------------------------------------------------------------------------------

// Welcome email sent after signup.
async function sendWelcome(a, b) {
  // Accepts (email, name), (name, email) or a user object.
  let to = a;
  let name = b;
  if (a && typeof a === 'object') {
    to = a.email;
    name = a.full_name || a.name;
  } else if (!String(a).includes('@') && String(b).includes('@')) {
    to = b;
    name = a;
  }
  const first = String(name || '').trim().split(/\s+/)[0] || 'there';
  const subject = 'Welcome to GenoGuard';
  const text =
    `Hi ${first},\n\nWelcome to GenoGuard. Your account is ready.\n\n` +
    `If you did not create this account, you can ignore this email.`;
  const html = `<div style="font-family:Arial,sans-serif;max-width:420px">
     <h2 style="margin:0 0 12px">Welcome to GenoGuard, ${esc(first)}</h2>
     <p>Your account is ready.</p>
     <p style="color:#666">If you did not create this account, you can ignore this email.</p>
   </div>`;
  if (!(await deliver(to, subject, text, html))) console.log(`\n[dev] Welcome email for ${to}\n`);
}

async function sendResetCode(to, code) {
  const subject = 'Your GenoGuard password reset code';
  const text = `Your GenoGuard reset code is ${code}.\n\nIt expires in 15 minutes. If you did not ask for this, you can ignore this email.`;
  const html = `<div style="font-family:Arial,sans-serif;max-width:420px">
     <h2 style="margin:0 0 12px">Reset your password</h2>
     <p>Use this code in the GenoGuard app:</p>
     <p style="font-size:32px;letter-spacing:6px;font-weight:bold;margin:16px 0">${code}</p>
     <p style="color:#666">It expires in 15 minutes. If you did not ask for this, you can ignore this email.</p>
   </div>`;
  if (!(await deliver(to, subject, text, html))) console.log(`\n[dev] Password reset code for ${to}: ${code}\n`);
}

// Invitation to compare genotypes.
async function sendMatchInvite(to, inviterName, code, days) {
  const who = esc(inviterName);
  const pretty = `${code.slice(0, 4)} ${code.slice(4)}`;
  const subject = `${inviterName} invited you to check genotype compatibility on GenoGuard`;
  const text =
    `${inviterName} invited you to check genotype compatibility on GenoGuard.\n\n` +
    `1. Install GenoGuard and sign in with this email address (${to}).\n` +
    `2. Open Match by QR, then Scan a code, and type this code: ${pretty}\n\n` +
    `${inviterName} must approve before anything is shared. The code works for ${days} days. ` +
    `If you do not know ${inviterName}, ignore this email.`;
  const html = `<div style="font-family:Arial,sans-serif;max-width:440px">
     <h2 style="margin:0 0 12px">${who} invited you to GenoGuard</h2>
     <p>Check genotype compatibility together. Install the app and sign in with <b>${esc(to)}</b>, then open <b>Match by QR</b> &rarr; <b>Scan a code</b> and type:</p>
     <p style="font-size:30px;letter-spacing:5px;font-weight:bold;margin:16px 0">${pretty}</p>
     <p style="color:#666">${who} must approve before anything is shared. The code works for ${days} days. If you do not know ${who}, ignore this email.</p>
   </div>`;
  if (!(await deliver(to, subject, text, html))) console.log(`\n[dev] Match invite for ${to} from ${inviterName}: code ${code}\n`);
}

module.exports = {
  sendResetCode,
  sendMatchInvite,
  sendWelcome,
  // exported so the providers can be tested on their own
  MailProvider,
  BrevoProvider,
  SmtpProvider,
  ConsoleProvider,
  selectProvider,
};