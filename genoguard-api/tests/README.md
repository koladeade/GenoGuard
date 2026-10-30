# API integration tests

These tests run the real Express route files (community, invites/QR, admin) against an
in-memory PostgreSQL ([pg-mem](https://github.com/oguimbal/pg-mem)) loaded with the project's
real `schema_*.sql` files. Auth, the database pool and email are replaced by test doubles in
`tests/support/`, so nothing touches a real database or sends a real email.

## Run

```bash
cd genoguard-api
npm install --save-dev pg-mem     # once
npm test
```

## What is covered

| Suite | Checks | Covers |
|---|---|---|
| `community.test.js` | 38 | posts, comments, validation, ownership, post reports, auto-hide threshold, rate limit |
| `community-paging-reports.test.js` | 29 | feed paging (`before`/`limit`/`has_more`), comment reports, admin report queue |
| `invites.test.js` | 44 | QR codes and email invites: expiry, claiming, one-time use, remove/cancel, mail failure, limits |
| `admin.test.js` | 34 | role gating, user list/disable/enable/delete, anonymised CSV export, research summary, audit log |
| **Total** | **145** | |

Inputs include valid, blank, over-length, wrong-role, unauthenticated, expired and repeated
requests, so both the expected result and the error response are checked.

The line `Invite email failed: mail down` printed during `invites.test.js` is expected: that test
simulates a mail outage to prove the invite is rolled back cleanly.

## Limits

pg-mem does not support every Postgres feature, so queries were written to work in both. The
Flutter app has no automated tests; it was tested by hand on a physical iPhone.
