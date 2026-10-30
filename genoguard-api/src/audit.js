const db = require('./db');

// Records an admin action. Never throws: a failed log line must not undo or block the action itself.
async function audit(req, action, detail) {
  try {
    const first = String(req.user.full_name || '').trim().split(/\s+/)[0] || 'Admin';
    await db.query(`INSERT INTO admin_audit (admin_id, admin_label, action, detail) VALUES ($1, $2, $3, $4)`, [
      req.user.id,
      first,
      action,
      detail ?? null,
    ]);
  } catch (e) {
    console.error('Audit log failed:', e.message);
  }
}

// A short label for a user that carries no personal data, e.g. "patient 3fa85f64".
const userLabel = (u) => `${u.role} ${String(u.id).slice(0, 8)}`;

module.exports = { audit, userLabel };