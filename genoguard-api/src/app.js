require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const { requireAuth, requireRole } = require('./auth');

if (!process.env.JWT_SECRET || process.env.JWT_SECRET === 'change-me') {
  console.error('Set a real JWT_SECRET in .env');
  process.exit(1);
}

const app = express();
app.set('trust proxy', 1); // Render sits behind a proxy
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10kb' }));

const authLimiter = rateLimit({ windowMs: 15 * 60 * 1000, limit: 30, standardHeaders: true, legacyHeaders: false });

app.get('/health', (_req, res) => res.json({ ok: true }));
app.use('/auth', authLimiter, require('./routes/auth'));
app.use('/me', require('./routes/me'));
app.use('/pain', require('./routes/pain'));
app.use('/reminders', require('./routes/reminders'));
app.use('/qr', require('./routes/qr'));
app.use('/quiz', require('./routes/quiz'));

// Example role-guarded routes; the moderation and patient features hang off these later.
app.get('/admin/ping', requireAuth, requireRole('admin'), (_req, res) => res.json({ ok: true }));
app.get('/patient/ping', requireAuth, requireRole('patient'), (_req, res) => res.json({ ok: true }));

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Server error' });
});

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`GenoGuard API on :${port}`));