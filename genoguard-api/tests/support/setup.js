// Test harness. Requiring this file first swaps the real database, auth and mail modules for
// test doubles, so the real route files run unchanged against an in-memory Postgres (pg-mem).
// Nothing here touches your real database or sends real email.
const Module = require('module');
const path = require('path');
const SRC = path.join(__dirname, '..', '..', 'src') + path.sep;

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret';

const doubles = {
  db: () => require('./db'),
  auth: () => require('./auth'),
  mail: () => require('./mail'),
};

const realLoad = Module._load;
Module._load = function (request, parent, isMain) {
  const m = /^\.{1,2}\/(db|auth|mail)$/.exec(request);
  if (m && parent && parent.filename && parent.filename.startsWith(SRC)) return doubles[m[1]]();
  return realLoad.apply(this, arguments);
};
