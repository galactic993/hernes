#!/usr/bin/env bash
#
# migrate.sh — run database migrations via Drizzle.
#
# Applies pending migrations to the database identified by DATABASE_URL.
# Used by:
#   - Preview deploys (Neon branch pr-<PR_NUMBER>)
#   - Staging deploys (Cloud SQL)
#   - Production deploys (Cloud SQL) — must be an explicit, gated step.
#
# Contract:
#   - DATABASE_URL is REQUIRED and read from the environment. If missing, fail
#     immediately. We never accept it as a CLI arg (avoids it landing in shell
#     history / process listings).
#   - DATABASE_URL is NEVER echoed or logged.
#   - Exits non-zero on any failure.
#   - Idempotent: drizzle-kit migrate only applies un-applied migrations, so
#     re-running is safe (already-applied migrations are skipped).
#
# PREREQUISITE (not yet wired in this template):
#   `pnpm --filter @hernes/db exec drizzle-kit migrate` assumes drizzle-kit is a
#   devDependency of @hernes/db and a drizzle.config.ts exists in packages/db
#   pointing at ./src/schema and an ./drizzle migrations dir. At time of writing
#   packages/db only depends on drizzle-orm. Add drizzle-kit + drizzle.config.ts
#   before relying on this in CI. Until then this script will fail fast (which is
#   the desired behaviour — no silent no-op).
#
set -euo pipefail

# --- preflight ---------------------------------------------------------------
if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "ERROR: DATABASE_URL is not set. Refusing to run migrations." >&2
  exit 1
fi

# Resolve repo root from this script's location so it works from any cwd.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." >/dev/null 2>&1 && pwd)"

if ! command -v pnpm >/dev/null 2>&1; then
  echo "ERROR: pnpm not found on PATH." >&2
  exit 1
fi

echo "==> Running Drizzle migrations against the configured database"
echo "    (DATABASE_URL is set; value intentionally not printed)"

# --- run ---------------------------------------------------------------------
# drizzle-kit reads DATABASE_URL from the environment via drizzle.config.ts.
# Run from repo root so pnpm filter resolves the workspace package.
cd "${REPO_ROOT}"
pnpm --filter @hernes/db exec drizzle-kit migrate

echo "==> Migrations applied successfully"
