const nodemailer = require('nodemailer');

let transport = null;
if (process.env.SMTP_HOST) {
  transport = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT || 587),
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
  });
}

async function sendResetCode(to, code) {
  const text = `Your GenoGuard password reset code is ${code}. It expires in 15 minutes. If you didn't ask for this, you can ignore this email.`;
  if (!transport) {
    console.log(`[dev mail] reset code for ${to}: ${code}`);
    return;
  }
  await transport.sendMail({
    from: process.env.MAIL_FROM,
    to,
    subject: 'Your GenoGuard reset code',
    text,
  });
}

module.exports = { sendResetCode };