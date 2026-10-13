-- GenoGuard accounts schema (safe to re-run: existing tables are upgraded in place)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email           text NOT NULL UNIQUE,              -- stored lowercase
  password_hash   text,                              -- null for Google-only accounts
  role            text NOT NULL CHECK (role IN ('patient', 'explorer', 'admin')),
  has_scd         boolean NOT NULL,
  genotype        text CHECK (genotype IN ('AA','AS','AC','SS','SC','CC')),
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
