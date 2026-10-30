-- GenoGuard accounts schema (safe to re-run: existing tables are upgraded in place)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email           text NOT NULL UNIQUE,              -- stored lowercase
  password_hash   text,                              -- null for Google-only accounts
  role            text NOT NULL CHECK (role IN ('patient', 'explorer', 'admin')),
  has_scd         boolean NOT NULL,
  genotype        text CHECK (genotype IN ('AA','AS','AC','SS','SC')),
  location        text,
  consent_version text NOT NULL,
  consented_at    timestamptz NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT role_matches_scd CHECK (
    role = 'admin'
    OR (has_scd AND role = 'patient')
    OR (NOT has_scd AND role = 'explorer')
  ),
  CONSTRAINT scd_genotype CHECK (NOT has_scd OR genotype IN ('SS','SC'))
);

-- Added with the UI pass (idempotent)
ALTER TABLE users ADD COLUMN IF NOT EXISTS full_name text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS usage_logs_consent boolean NOT NULL DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS google_id text;
ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS users_google_id_key ON users(google_id) WHERE google_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  text NOT NULL UNIQUE,
  expires_at  timestamptz NOT NULL,
  revoked_at  timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS refresh_tokens_user ON refresh_tokens(user_id);

CREATE TABLE IF NOT EXISTS password_resets (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code_hash   text NOT NULL,
  attempts    int NOT NULL DEFAULT 0,
  expires_at  timestamptz NOT NULL,
  used_at     timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS password_resets_user ON password_resets(user_id);

-- Patient pain log
CREATE TABLE IF NOT EXISTS pain_entries (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  occurred_at timestamptz NOT NULL,
  intensity   smallint NOT NULL CHECK (intensity BETWEEN 0 AND 10),
  areas       text[] NOT NULL DEFAULT '{}',
  notes       text,
  is_crisis   boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS pain_entries_user_time ON pain_entries(user_id, occurred_at DESC);

-- Reminders (medication, hydration, appointments) -- append to the end of schema.sql
CREATE TABLE IF NOT EXISTS reminders (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type        text NOT NULL CHECK (type IN ('medication', 'hydration', 'appointment')),
  title       text NOT NULL,
  dose        text,
  doctor      text,
  location    text,
  recurrence  text NOT NULL CHECK (recurrence IN ('once', 'daily', 'every_2_hrs', 'as_needed')),
  time_of_day text CHECK (time_of_day ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'),  -- local wall-clock time
  on_date     date,                                                          -- for 'once' and appointments
  enabled     boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS reminders_user ON reminders(user_id);

CREATE TABLE IF NOT EXISTS reminder_logs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reminder_id uuid NOT NULL REFERENCES reminders(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  day         date NOT NULL,
  taken_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS reminder_logs_lookup ON reminder_logs(reminder_id, day);

CREATE TABLE IF NOT EXISTS water_intake (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  day     date NOT NULL,
  glasses smallint NOT NULL CHECK (glasses BETWEEN 0 AND 30),
  PRIMARY KEY (user_id, day)
);

-- Match by QR: short-lived, single-use share codes. Only a hash of the code is stored, never genotypes.
CREATE TABLE IF NOT EXISTS qr_shares (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code_hash    text NOT NULL,
  status       text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'requested', 'approved', 'declined', 'expired')),
  requester_id uuid REFERENCES users(id) ON DELETE CASCADE,
  expires_at   timestamptz NOT NULL,
  requested_at timestamptz,
  decided_at   timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS qr_shares_code ON qr_shares(code_hash);
CREATE INDEX IF NOT EXISTS qr_shares_owner ON qr_shares(owner_id);

-- In app quiz
CREATE TABLE IF NOT EXISTS quiz_responses (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  intention  smallint NOT NULL CHECK (intention BETWEEN 1 AND 5),
  confidence smallint NOT NULL CHECK (confidence BETWEEN 1 AND 5),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS quiz_responses_user ON quiz_responses(user_id, created_at DESC);

-- Community: posts, comments and reports. Deleting a user or a post removes what hangs off it.
CREATE TABLE IF NOT EXISTS posts (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id  uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body       text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 1000),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS posts_created ON posts(created_at DESC);

CREATE TABLE IF NOT EXISTS comments (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id    uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  author_id  uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body       text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 500),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS comments_post ON comments(post_id, created_at);

-- One report per person per post. 'open' reports form the admin queue; 'dismissed' means an admin kept the post.
CREATE TABLE IF NOT EXISTS post_reports (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id     uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  reporter_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason      text NOT NULL CHECK (reason IN ('harmful_advice', 'abuse', 'spam', 'privacy', 'other')),
  status      text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'dismissed')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (post_id, reporter_id)
);
CREATE INDEX IF NOT EXISTS post_reports_open ON post_reports(status, post_id);

-- Usage logs. Only written when users.usage_logs_consent is true. Event names only: no text, no health data.
CREATE TABLE IF NOT EXISTS usage_events (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event      text NOT NULL CHECK (event IN ('compat_check', 'qr_match', 'learning_open')),
  item       text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS usage_events_user ON usage_events(user_id, created_at DESC);

-- Reports on individual comments. Same idea as post_reports; admins review them (no auto-hide).
CREATE TABLE IF NOT EXISTS comment_reports (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  comment_id  uuid NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
  reporter_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason      text NOT NULL CHECK (reason IN ('harmful_advice', 'abuse', 'spam', 'privacy', 'other')),
  status      text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'dismissed')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (comment_id, reporter_id)
);
CREATE INDEX IF NOT EXISTS comment_reports_open ON comment_reports(status, comment_id);