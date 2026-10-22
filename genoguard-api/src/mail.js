const nodemailer = require('nodemailer');

const FROM_EMAIL = process.env.MAIL_FROM_EMAIL || '';
const FROM_NAME = process.env.MAIL_FROM_NAME || 'GenoGuard';

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

async function viaBrevo({ to, subject, text, html }) {
  const res = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: { 'api-key': process.env.BREVO_API_KEY, 'content-type': 'application/json', accept: 'application/json' },
    body: JSON.stringify({
      sender: { name: FROM_NAME, email: FROM_EMAIL },
      to: [{ email: to }],
      subject,
      textContent: text,
      htmlContent: html,
    }),
  });
  if (!res.ok) throw new Error(`Brevo ${res.status}: ${(await res.text()).slice(0, 200)}`);
}

async function viaSmtp({ to, subject, text, html }) {
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
}

async function send(msg) {
  if (process.env.BREVO_API_KEY) {
    if (!FROM_EMAIL) throw new Error('MAIL_FROM_EMAIL is not set');
    return viaBrevo(msg);
  }
  if (process.env.SMTP_HOST) return viaSmtp(msg);
  console.log(`\n[dev] Email to ${msg.to}\nSubject: ${msg.subject}\n${msg.text}\n`);
}

async function sendResetCode(to, code) {
  return send({
    to,
    subject: 'Your GenoGuard password reset code',
    text: `Your GenoGuard reset code is ${code}.\n\nIt expires in 15 minutes. If you did not ask for this, you can ignore this email.`,
    html: `<div style="font-family:Arial,sans-serif;max-width:420px">
      <h2 style="margin:0 0 12px">Reset your password</h2>
      <p>Use this code in the GenoGuard app:</p>
      <p style="font-size:32px;letter-spacing:6px;font-weight:bold;margin:16px 0">${esc(code)}</p>
      <p style="color:#666">It expires in 15 minutes. If you did not ask for this, you can ignore this email.</p>
    </div>`,
  });
}

// Sent once, right after an account is created. `user` is the new users row.
async function sendWelcome(user) {
  const first = (user.full_name || '').trim().split(/\s+/)[0] || 'there';
  const isPatient = user.role === 'patient';
  const intro = isPatient
    ? 'You can now log your pain, track your recovery, and set reminders for your medication, water and appointments.'
    : 'You can now test genotype compatibility, learn about screening, and join the community.';
  return send({
    to: user.email,
    subject: 'Welcome to GenoGuard',
    text: `Hi ${first},\n\nYour GenoGuard account has been created successfully.\n\n${intro}\n\nIf you did not create this account, please reply to this email.\n\nThe GenoGuard team`,
    html: `<div style="font-family:Arial,sans-serif;max-width:480px">
      <h2 style="margin:0 0 12px">Welcome to GenoGuard, ${esc(first)}!</h2>
      <p>Your account has been created successfully.</p>
      <p>${esc(intro)}</p>
      <p style="color:#666">If you did not create this account, please reply to this email.</p>
      <p>The GenoGuard team</p>
    </div>`,
  });
}

module.exports = { sendResetCode, sendWelcome };