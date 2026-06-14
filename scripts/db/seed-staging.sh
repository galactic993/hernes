#!/usr/bin/env bash
#
# seed-staging.sh — OPTIONAL seed for the Staging database (Cloud SQL).
#
# This is NOT run automatically by any deploy workflow. Staging data is meant to
# be longer-lived than Preview; only run this by hand when you deliberately want
# to (re)populate reference/demo data.
#
#   *** There is intentionally NO seed-production.sh. ***
#   Production data must never be seeded by script and is never auto-seeded.
#   Any production data setup is a manual, audited, out-of-band operation.
#
# Contract:
#   - DATABASE_URL is REQUIRED (read from env). If missing, fail immediately.
#   - DATABASE_URL is NEVER echoed or logged.
#   - Idempotent / re-run safe (upserts only).
#   - Exits non-zero on any failure.
#   - Refuses to run unless explicitly confirmed via ALLOW_STAGING_SEED=1, so it
#     cannot be triggered accidentally from CI.
#
# PREREQUISITE (not yet wired in this template):
#   Same `pnpm --filter @hernes/db run seed` entrypoint as preview (see
#   seed-preview.sh). Provide it before use. Keep all INSERTs idempotent.
#
set -euo pipefail

if [[ "${ALLOW_STAGING_SEED:-0}" != "1" ]]; then
  echo "ERROR: refusing to seed staging without explicit opt-in." >&2
  echo "       Re-run with ALLOW_STAGING_SEED=1 if you really mean it." >&2
  exit 1
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "ERROR: DATABASE_URL is not set. Refusing to seed staging database." >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." >/dev/null 2>&1 && pwd)"

if ! command -v pnpm >/dev/null 2>&1; then
  echo "ERROR: pnpm not found on PATH." >&2
  exit 1
fi

echo "==> Seeding STAGING database (manual, opt-in). Idempotent upserts only."
echo "    (DATABASE_URL is set; value intentionally not printed)"

cd "${REPO_ROOT}"
pnpm --filter @hernes/db run seed

echo "==> Staging seed complete"
