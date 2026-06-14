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
# WIRING (not yet wired in this template):
#   `drizzle-kit migrate` assumes drizzle-kit is a devDependency of @hernes/db and
#   a drizzle.config.ts exists (packages/db/drizzle.config.ts) pointing at
#   ./src/schema and a migrations dir. At time of writing packages/db only depends
#   on drizzle-orm.
#   Until drizzle-kit + drizzle.config.ts are wired this script FAILS FAST (exit 1) — it never
#   reports a successful migration while applying nothing. CI invokes it only when the migration
#   step is enabled via the `RUN_DB_MIGRATIONS` repo Variable (default off), so an unwired scaffold
#   simply skips the step (visible in the Actions UI) and deploys stay green. Set RUN_DB_MIGRATIONS
#   = true only after wiring drizzle-kit + packages/db/drizzle.config.ts (+ migrations).
#   Once wired, migrations are applied normally and REAL errors fail the run.
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

# Run from repo root so the pnpm workspace filter resolves @hernes/db.
cd "${REPO_ROOT}"

# --- wiring check: skip (loud, non-silent) until drizzle-kit + config exist ---
# Locate a drizzle config (preferred: packages/db/drizzle.config.ts).
DRIZZLE_CONFIG=""
for cand in "packages/db/drizzle.config.ts" "drizzle.config.ts"; do
  if [[ -f "${REPO_ROOT}/${cand}" ]]; then
    DRIZZLE_CONFIG="${cand}"
    break
  fi
done

if ! pnpm --filter @hernes/db exec drizzle-kit --version >/dev/null 2>&1 || [[ -z "${DRIZZLE_CONFIG}" ]]; then
  # 未配線なら FAIL FAST（no silent no-op）。「migration したつもりで何も適用していない」を防ぐ。
  # CI では migration step 自体を vars.RUN_DB_MIGRATIONS=true のときだけ実行する設計なので、
  # 未配線の scaffold では step がそもそも走らず deploy は通る（migration を有効化したら配線必須）。
  echo "ERROR: drizzle-kit / drizzle.config が未配線のため migration を適用できません。" >&2
  echo "       @hernes/db に drizzle-kit(devDependency) と drizzle.config.ts（+ migrations）を用意してください。" >&2
  echo "       CI の migration step は vars.RUN_DB_MIGRATIONS=true のときだけ実行されます。" >&2
  exit 1
fi

# --- run ---------------------------------------------------------------------
# drizzle-kit reads DATABASE_URL from the environment via drizzle.config.ts.
echo "==> Running Drizzle migrations against the configured database"
echo "    (DATABASE_URL is set; value intentionally not printed)"
pnpm --filter @hernes/db exec drizzle-kit migrate --config "${DRIZZLE_CONFIG}"

echo "==> Migrations applied successfully"
