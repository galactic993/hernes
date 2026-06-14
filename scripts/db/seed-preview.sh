#!/usr/bin/env bash
#
# seed-preview.sh — seed the Preview database (Neon branch pr-<PR_NUMBER>).
#
# Intended to run after migrate.sh during a Preview deploy so each PR gets a
# small, deterministic dataset to click around in.
#
# Contract:
#   - DATABASE_URL is REQUIRED (read from env). If missing, fail immediately.
#   - DATABASE_URL is NEVER echoed or logged.
#   - MUST be idempotent / re-run safe. Seed logic should use upserts
#     (INSERT ... ON CONFLICT DO NOTHING / DO UPDATE) so repeated deploys to the
#     same Neon branch do not duplicate rows or error out.
#   - Preview-only. This script must never be pointed at staging/production;
#     guard rails for that live in the deploy workflow (APP_ENV=preview).
#   - Exits non-zero on any failure.
#
# PREREQUISITE (not yet wired in this template):
#   A seed entrypoint in @hernes/db, e.g. `pnpm --filter @hernes/db run seed`
#   backed by packages/db/src/seed.ts (tsx). That script does not exist yet; add
#   it before enabling seeding in CI. Keep all INSERTs idempotent.
#
set -euo pipefail

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "ERROR: DATABASE_URL is not set. Refusing to seed preview database." >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." >/dev/null 2>&1 && pwd)"

if ! command -v pnpm >/dev/null 2>&1; then
  echo "ERROR: pnpm not found on PATH." >&2
  exit 1
fi

echo "==> Seeding PREVIEW database (Neon branch). Idempotent upserts only."
echo "    (DATABASE_URL is set; value intentionally not printed)"

cd "${REPO_ROOT}"
# tsx-based seed runner. Idempotency is the seed script's responsibility.
pnpm --filter @hernes/db run seed

echo "==> Preview seed complete"
