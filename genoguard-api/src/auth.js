const jwt = require('jsonwebtoken');
const db = require('./db');

// Loads the user from the DB on every request, so role changes and deleted
// accounts take effect immediately instead of waiting for the token to expire.
async function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Not signed in' });
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET, { algorithms: ['HS256'] });
    const { rows } = await db.query('SELECT * FROM users WHERE id = $1', [payload.sub]);
    if (!rows[0]) return res.status(401).json({ error: 'Not signed in' });
    req.user = rows[0];
    next();
  } catch {
    res.status(401).json({ error: 'Session expired' });
  }
}

const requireRole = (...roles) => (req, res, next) =>
  roles.includes(req.user.role) ? next() : res.status(403).json({ error: 'Not allowed' });

module.exports = { requireAuth, requireRole };