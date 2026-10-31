# GenoGuard

**Genotype-compatibility awareness and sickle cell care for Nigeria.** A Flutter mobile app with a Node.js / PostgreSQL API.

GenoGuard helps people understand the sickle cell risk for a future child before marriage, share a verified genotype with a partner through a short-lived QR code or email invite, and, for people living with SS or SC, manage everyday care with a pain log, medication, hydration and appointment reminders, weather alerts and a recovery graph. A lightly moderated community and an admin console complete the product.

Final-year Software Engineering capstone, African Leadership University.

| Resource | Link |
|---|---|
| Walkthrough video | <VIDEO_LINK> |
| Technical report (PDF, 5 pages max) | <REPORT_LINK> |
| Source code | https://github.com/koladeade/GenoGuard |
| Live API (Render, free tier) | https://genoguard.onrender.com (health check: `/health`) |

**Contents:** [Quick start](#quick-start-use-the-live-api) · [Features](#features) · [Technical requirements](#technical-requirements) · [Repository structure](#repository-structure) · [Run it locally](#run-it-locally) · [Configuration](#configuration) · [Testing](#testing) · [Deployment](#deployment-render) · [Design decisions](#design-decisions-and-scope-changes) · [Troubleshooting](#troubleshooting) · [Limitations](#limitations)

---

## Quick start (use the live API)

You can run the app without setting up a database or the API. The app talks to the deployed API.

```bash
git clone https://github.com/koladeade/GenoGuard.git
cd GenoGuard/genoguard_app
flutter pub get
flutter run --dart-define=API_URL=https://genoguard.onrender.com
```

- Needs Flutter and an iOS simulator or a connected iPhone (see [requirements](#technical-requirements)).
- The API runs on Render's free tier and **sleeps after 15 minutes idle**. The first request can take up to a minute. Open `https://genoguard.onrender.com/health` first; it should return `{"ok":true}`.
- Create an account in the app to explore. Admin access: email: "admin@gmail.com" password: "password"

## Features

| Area | What it does |
|---|---|
| Accounts | Email + password and Google sign-in; 15-minute JWT access tokens with rotating refresh tokens; password reset by emailed 6-digit code; live password-rules checklist |
| Roles | **Patient** (lives with SS or SC), **Explorer** (anyone else), **Admin**; role-based routing in the app and role checks on every API route |
| Genotype compatibility | Manual check for anyone, using a Punnett square (AA, AS, AC, SS, SC): chance of each child genotype, chance of sickle cell disease, and a risk level |
| Match by QR or email | Person A creates a short-lived code (QR, 5 min) or an email invite (7 days); person B claims it; the owner confirms each time; results expire; rate-limited |
| Patient care | Pain log with a recovery graph; medication, hydration and appointment reminders as local notifications; daily water counter; weather alert card |
| Learn and quiz | Education and screening resources; a quiz with two 5-point ratings (intention to be screened, confidence to discuss genotype), saved with date and time |
| Community | Posts and comments, report buttons, auto-hide after 3 distinct reports, admin review queue |
| Consent and privacy | Explicit consent screen; usage events recorded only after opt-in; account and data deletion |
| Admin | Overview counts, user list (disable / enable / delete), anonymised research summary and CSV export, audit log. Admins never see genotype, pain, reminders or location |

## Technical requirements

| Component | Version / detail |
|---|---|
| Flutter | 3.35.7 (stable) |
| Dart | 3.9.2 |
| Node.js | v22.17.0 (v20 or later works) |
| npm | installed with Node |
| PostgreSQL | 14 or later (Render runs PostgreSQL 18) |
| Development machine | MacBook Air, macOS 26.3.1 |
| Xcode | Xcode 26.6 |
| Test devices | IPhone 16 plus (iOS 26.6.2), release build; iOS simulator |
| Android | Not built or tested (see [limitations](#limitations)) |

**Main packages.** App: `dio`, `provider`, `go_router`, `google_sign_in`, `flutter_secure_storage`, `flutter_local_notifications`, `qr_flutter`, `mobile_scanner`, `flutter_svg`. API: `express` 5, `pg` (node-postgres, no ORM), `zod`, `bcryptjs`, `jsonwebtoken`, `helmet`, `express-rate-limit`. Tests: `pg-mem`, `flutter_test`.

## Repository structure

```
GenoGuard/
├── README.md
├── genoguard-api/                       Node.js + Express 5 + PostgreSQL API
│   ├── package.json                     Dependencies and npm scripts
│   ├── schema.sql                       All tables (applied by `npm run migrate`)
│   ├── .env.example                     Environment variable template
│   ├── src/
│   │   ├── app.js                       Express setup, security middleware, route mounting
│   │   ├── auth.js                      JWT check (requireAuth) and role guard (requireRole)
│   │   ├── db.js                        PostgreSQL connection pool
│   │   ├── audit.js                     Records admin actions in the audit log
│   │   ├── mail.js                      Email delivery (Brevo, SMTP or console)
│   │   ├── migrate.js                   Applies schema.sql
│   │   ├── seed-admin.js                Creates the admin account
│   │   └── routes/
│   │       ├── auth.js                  Register, login, Google, refresh, logout, password reset
│   │       ├── me.js                    Profile, genotype, consent, account deletion
│   │       ├── pain.js                  Pain log entries
│   │       ├── reminders.js             Reminders, daily logs, water counter
│   │       ├── quiz.js                  Knowledge quiz responses
│   │       ├── usage.js                 Opt-in usage events
│   │       ├── qr.js                    QR codes, email invites, claim and confirm
│   │       ├── community.js             Posts, comments, reports, auto-hide, moderation queue
│   │       └── admin.js                 Overview, users, research summary and CSV export, audit
│   └── tests/
│       ├── README.md                    How the tests work and what they cover
│       ├── community.test.js            38 checks: posts, comments, reports, rate limit
│       ├── community-paging-reports.test.js   29 checks: feed paging, comment reports
│       ├── invites.test.js              44 checks: QR codes and email invites
│       ├── admin.test.js                34 checks: roles, users, exports, audit log
│       ├── support/
│       │   ├── setup.js                 Swaps real db/auth/mail for test doubles
│       │   ├── db.js                    In-memory PostgreSQL loaded with schema.sql
│       │   ├── auth.js                  Header-based test authentication
│       │   └── mail.js                  Records emails instead of sending them
│       └── perf/
│           └── latency.js               Latency test at 1, 10 and 25 concurrent requests
└── genoguard_app/                       Flutter app
    ├── pubspec.yaml                     Dependencies and app config
    ├── analysis_options.yaml            Lint rules
    ├── test/
    │   ├── compat_logic_test.dart       13 tests: Punnett-square results and risk levels
    │   └── reminder_logic_test.dart     11 tests: next reminder time, date helpers
    └── lib/
        ├── main.dart                    App entry point and providers
        ├── router.dart                  Role-based routing (patient / explorer / admin)
        ├── core/
        │   ├── api.dart                 HTTP client, base URL, token refresh
        │   ├── token_store.dart         Secure token storage
        │   ├── auth_state.dart          Login, signup, session and consent state
        │   ├── google_auth.dart         Google sign-in
        │   ├── notifications.dart       Local scheduled notifications
        │   ├── usage.dart               Opt-in usage logging
        │   └── ng_states.dart           Nigerian states list for location
        ├── theme/
        │   └── app_theme.dart           Colours, text styles, theme
        ├── widgets/
        │   ├── common.dart              Buttons, cards, text fields, auth scaffold
        │   ├── password_strength.dart   Live password rules checklist
        │   ├── geno_logo.dart           App logo (SVG)
        │   ├── bottom_nav.dart          Bottom navigation bar
        │   ├── nav_row.dart             Tappable list row
        │   └── location_field.dart      Location picker
        ├── screens/
        │   ├── welcome_screen.dart      Welcome / landing
        │   ├── consent_screen.dart      Data consent and usage-log opt-in
        │   ├── signup_screen.dart       Registration
        │   ├── login_screen.dart        Login
        │   ├── reset_screen.dart        Password reset by emailed code
        │   ├── profile_screen.dart      Edit profile, delete account
        │   └── homes.dart               Role home screens
        ├── compat/
        │   ├── compat_logic.dart        Punnett-square calculation and risk levels
        │   └── compat_screens.dart      Compatibility check and result screens
        ├── match/
        │   ├── match_api.dart           QR and invite API calls
        │   └── match_screens.dart       Show/scan code, invite by email, results
        ├── patient/
        │   ├── patient_shell.dart       Patient bottom-tab shell
        │   ├── home_tab.dart            Home: next reminders, weather, recovery
        │   ├── pain_tab.dart            Pain history
        │   ├── pain_entry_sheet.dart    Log a pain episode
        │   ├── pain_state.dart          Pain log state
        │   ├── recovery.dart            Recovery graph
        │   ├── reminders_tab.dart       Reminders list and water counter
        │   ├── reminder_sheet.dart      Create / edit a reminder
        │   ├── reminders_state.dart     Reminder state, scheduling, midnight refresh
        │   ├── reminder_utils.dart      Date and time helpers
        │   ├── weather_service.dart     Weather data and alert rules
        │   ├── weather_card.dart        Weather alert card
        │   ├── profile_tab.dart         Profile menu
        │   ├── pill_tabs.dart           Pill-style tab switcher
        │   └── format.dart              Formatting helpers
        ├── explorer/
        │   ├── explorer_shell.dart      Explorer bottom-tab shell
        │   ├── explorer_home.dart       Explorer home
        │   ├── learn_tab.dart           Learn tab
        │   └── community_tab.dart       Community feed
        ├── learn/
        │   ├── learn_content.dart       Educational and screening content
        │   └── learn_screens.dart       Article and quiz screens
        ├── community/
        │   ├── community_api.dart       Community API calls and models
        │   └── community_screens.dart   Post, comments, report sheet
        ├── admin/
        │   ├── admin_shell.dart         Admin bottom-tab shell, reports queue
        │   ├── admin_api.dart           Admin API calls
        │   ├── overview_tab.dart        Overview counts and audit log
        │   ├── users_tab.dart           User list, disable, delete
        │   └── data_tab.dart            Research summary and CSV export
        └── privacy/
            └── privacy_screen.dart      Privacy and data screen
```

## Run it locally

### 1. Database
```bash
createdb genoguard
```

### 2. API
```bash
cd genoguard-api
cp .env.example .env     # then set DATABASE_URL and JWT_SECRET (see Configuration)
npm install
npm run migrate          # creates the tables ("Schema applied")
npm run dev              # http://localhost:3000
```
Create an admin account:
```bash
ADMIN_EMAIL="admin@example.com" ADMIN_PASSWORD="choose-a-password" npm run seed-admin
```
With no email provider configured, reset codes and invites are printed in the API console, so no email setup is needed to try the app.

### 3. Flutter app
```bash
cd genoguard_app
flutter pub get
flutter run --dart-define=API_URL=http://localhost:3000                       # iOS simulator
flutter run --release -d <device> --dart-define=API_URL=http://<mac-ip>:3000  # physical iPhone
```
On a physical phone use your Mac's LAN IP instead of `localhost`, keep both on the same Wi-Fi, and find the device id with `flutter devices`.

## Configuration

Copy `genoguard-api/.env.example` to `.env`. Secrets are never committed.

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string |
| `JWT_SECRET` | Signing secret; the API refuses to start with `change-me`. Generate: `node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"` |
| `ACCESS_TTL`, `REFRESH_TTL_DAYS` | Token lifetimes (`15m`, `30`) |
| `GOOGLE_CLIENT_IDS` | Comma-separated OAuth client IDs; leave empty to disable Google sign-in |
| `BREVO_API_KEY`, `MAIL_FROM_EMAIL`, `MAIL_FROM_NAME` | Email via Brevo (optional) |
| `SMTP_*` | SMTP alternative (optional) |
| `REPORTS_TO_HIDE` | Reports needed to auto-hide a post (default 3) |

Google sign-in also needs the iOS OAuth client ID and reversed client ID in `genoguard_app/ios/Runner/Info.plist`. Everything else works without it.

## Testing

| Strategy | Command | Coverage |
|---|---|---|
| **Integration tests** (API) | `cd genoguard-api && npm install && npm test` | 145 checks: community, QR and invites, admin. Real route files run against an in-memory PostgreSQL loaded with the real schema; auth, database and mail are test doubles. Covers valid, blank, over-long, wrong-role, unauthenticated, expired and repeated inputs |
| **Unit tests** (Flutter) | `cd genoguard_app && flutter test` | 24 tests: Punnett-square outcomes and risk levels for eight pairings and for all 25 pairs (totals 100%, parent order irrelevant); reminder next-fire time for daily, every-2-hours, one-off and as-needed |
| **Device and usability testing** | manual | Release build on a physical iPhone, full flows including error inputs |
| **Performance** | `node tests/perf/latency.js <url> <email> <password>` (from `genoguard-api`, with a non-admin account) | Median and p95 latency at 1, 10 and 25 concurrent requests |

Results and analysis are in the [technical report](<REPORT_LINK>) and shown in the video. See also `genoguard-api/tests/README.md`.

## Deployment (Render)

- **Database:** Render PostgreSQL (free tier; free databases expire after 30 days).
- **API:** Render web service, root directory `genoguard-api`, build `npm install`, start `npm start`, with the environment variables above.
- **Tables and admin:** run `npm run migrate` and `npm run seed-admin` from your machine with `DATABASE_URL` set to the database's external URL plus `?sslmode=require`.
- **App:** build with `--dart-define=API_URL=https://genoguard.onrender.com`.

## Design decisions and scope changes

- **QR and email invite instead of NFC tap-to-match.** QR works on every phone and the invite covers people who are apart; codes are short-lived and the owner confirms each time.
- **No guardian role.** The app serves patients and regular individuals; admins moderate.
- **Local notifications instead of server push.** Reminders fire on time with the app closed and without internet, and need no paid Apple push service.
- **Public posts and comments with light moderation** (report, auto-hide, admin review) instead of private chat.
- **Privacy by design.** Passwords are hashed with bcrypt (cost 12); reset, QR and invite codes are stored only as SHA-256 hashes; codes come from `crypto.randomInt`; admin exports use HMAC participant IDs; the audit log stores short labels, never names or emails.

## Troubleshooting

| Problem | Fix |
|---|---|
| "Cannot reach server" on the phone | Open `<API_URL>/health` in the phone's browser to wake the server, then retry. Check that the build used `--dart-define=API_URL=...` (the default is `localhost`) |
| `npm test` cannot find the schema | The test harness loads every `schema*.sql` file in `genoguard-api`; run it from `genoguard-api` |
| Reset or invite emails do not arrive | Without Brevo / SMTP settings they are printed in the API console. Invites to new users may land in spam until a sending domain is verified |
| iPhone install fails | Unlock the phone, trust the developer profile, and use a release build. Free signing lasts 7 days |

## Limitations

- Built and tested on **iOS only**. An installable iOS build cannot be distributed without a paid Apple Developer account, so no APK or IPA is included; run from source, or use the video.
- Android and low-end devices are untested; no frame-rate profiling was done.
- A history screen for reminders and appointments is not built; one-off appointments are removed once they pass.
- Light mode is not implemented.
- The free Render API sleeps when idle and the free database expires after 30 days.
- The crisis article and weather thresholds need clinician review, and the consent wording must match the final ethics form.