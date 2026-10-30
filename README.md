# GenoGuard

GenoGuard is a Flutter mobile app and Node.js API for **genotype-compatibility awareness and day-to-day sickle cell care in Nigeria**. It lets anyone check the sickle cell risk for a future child, share a verified genotype with a partner by short-lived QR code or email invite, and gives people living with SS or SC a pain log, medication and water reminders, weather alerts and a recovery graph. A moderated community space and an admin console complete the product.

Final-year Software Engineering capstone, African Leadership University.

| | |
|---|---|
| Walkthrough video | **<ADD VIDEO LINK>** |
| Technical report (PDF) | **<ADD REPORT LINK>** |
| Repository | **https://github.com/koladeade/GenoGuard.git** |

## Features

| Area | What it does |
|---|---|
| Accounts | Email + password and Google sign-in; JWT access tokens (15 min) with rotating refresh tokens; password reset by emailed 6-digit code; password strength guide |
| Roles | **Patient** (lives with SS or SC), **Explorer** (anyone else), **Admin**; role-based routing in the app and role checks on every API route |
| Genotype compatibility | Manual check for anyone, using a Punnett square (AA, AS, AC, SS, SC) with the chance of each child genotype and a risk level |
| Match by QR or email | Person A creates a short-lived code (QR, 5 min) or an email invite (7 days); person B claims it; the owner confirms each time; results expire; rate-limited |
| Patient care | Pain log with a recovery graph, medication / hydration / appointment reminders with local notifications, daily water counter, weather alert card |
| Learn and quiz | Learning content and a quiz with two 5-point questions (intention to be screened, confidence to discuss genotype), saved with date and time |
| Community | Posts and comments, report buttons, auto-hide after 3 distinct reports, admin review queue |
| Consent and privacy | Explicit consent screen; usage events recorded only after opt-in; account and data deletion |
| Admin | Overview counts, user list (disable / enable / delete), anonymised research summary and CSV export, audit log of admin actions. Admins never see genotype, pain, reminders or location |

## Technical requirements

| | |
|---|---|
| Flutter | **3.35.7** (Dart SDK in `pubspec.yaml`) |
| Node.js | **v22.17.0** (v20 or later recommended) |
| PostgreSQL | 14 or later |
| Development machine | macOS, Xcode (iOS simulator and physical iPhone) |
| Tested on | Physical iPhone (release build) and iOS simulator |
| Main packages | App: dio, provider, go_router, google_sign_in, flutter_secure_storage, flutter_local_notifications, qr_flutter, mobile_scanner, flutter_svg. API: express 5, pg (node-postgres, no ORM), zod, bcryptjs, jsonwebtoken, express-rate-limit |

## Repository structure

```
GenoGuard/
├── genoguard-api/                 Node.js + Express 5 + PostgreSQL
│   ├── schema*.sql                Database schema
│   ├── src/
│   │   ├── app.js                 App setup and route mounting
│   │   ├── auth.js, db.js         JWT middleware, connection pool
│   │   ├── audit.js, mail.js      Admin audit log, email delivery
│   │   └── routes/                auth, me, pain, reminders, quiz, usage, qr, community, admin
│   ├── scripts/                   Admin helper scripts
│   └── tests/                     Integration tests (145 checks) + support doubles
└── genoguard_app/                 Flutter app
    └── lib/
        ├── core/                  API client, auth state, notifications, Google auth
        ├── theme/, widgets/       Design tokens and reusable widgets
        ├── screens/               Welcome, consent, signup, login, reset, profile
        ├── compat/                Compatibility logic (Punnett square) and screens
        ├── match/                 QR / email-invite matching
        ├── patient/               Pain, reminders, recovery, weather, patient shell
        ├── explorer/, learn/      Explorer shell, learning content and quiz
        ├── community/             Posts, comments, reporting
        ├── admin/                 Overview, users, research data, audit
        └── privacy/               Privacy and data screen
```

## Installation

### 1. Database
```bash
createdb genoguard
psql genoguard -f genoguard-api/schema.sql
```
(The admin, community, invite and other tables are in `schema.sql` or the other `schema_*.sql` files; run any that exist.)

### 2. API
```bash
cd genoguard-api
cp .env.example .env        # then fill in DATABASE_URL and JWT_SECRET
npm install
npm run dev                 # http://localhost:3000
```
Generate a secret with `node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"`.
Without SMTP or Brevo settings, reset codes and invites are printed to the console, so email is not required for testing.

Create an admin: set `ADMIN_EMAIL` and `ADMIN_PASSWORD` in `.env`, then `npm run seed-admin`.

### 3. Flutter app
```bash
cd genoguard_app
flutter pub get
flutter run --dart-define=API_URL=http://localhost:3000            # simulator
flutter run --release -d <device> --dart-define=API_URL=http://<mac-ip>:3000   # physical iPhone
```
On a physical phone use your Mac's LAN IP instead of `localhost`, and keep both on the same Wi-Fi.
Google sign-in needs credentials; see `GOOGLE_SETUP.md`. Everything else works without it.

### 4. Tests
```bash
cd genoguard-api
npm install
npm test
```

## Testing

- **API integration tests** (`genoguard-api/tests/`): 145 checks over community, invites/QR and admin routes, run against an in-memory Postgres loaded with the real schema. They cover valid and invalid input, role checks, expiry, rate limits and anonymisation of exports. See `tests/README.md`.
- **Device and usability testing**: release build on a physical iPhone, covering the full user flows (see the report and video).

## Privacy and security notes

- Passwords are hashed with bcrypt (cost 12); reset codes and QR / invite codes are stored only as hashes.
- Codes are generated with Node's `crypto.randomInt`; claiming is rate-limited.
- Admin research exports use HMAC participant IDs; the audit log stores short labels, never names or emails.
- Secrets live in `.env`, which is not committed.

## Platform note

The app is built and tested on iOS. An installable iOS build cannot be distributed without a paid Apple Developer account, so this repository includes the source, the walkthrough video and a deployable API instead of an APK.