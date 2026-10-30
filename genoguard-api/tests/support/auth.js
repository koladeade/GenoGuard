// Test auth: the caller is identified by headers instead of a JWT.
//   x-uid  = user id (must exist in the users table when the route reads the row)
//   x-role = optional role override; otherwise the role stored on the user row, else 'patient'
const db = require('./db');

exports.requireAuth = async (req, res, next) => {
  const uid = req.headers['x-uid'];
  if (!uid) return res.status(401).json({ error: 'Unauthorized' });
  const { rows } = await db.query('SELECT * FROM users WHERE id = $1', [uid]);
  const row = rows[0] || { id: uid };
  req.user = { ...row, role: req.headers['x-role'] || row.role || 'patient' };
  next();
};

exports.requireRole = (...roles) => (req, res, next) =>
  roles.includes(req.user.role) ? next() : res.status(403).json({ error: 'Forbidden' });
