#!/usr/bin/env bash
#
# secret-bootstrap.sh — check (or, with --create, create) the long-lived Secret
# Manager CONTAINERS for an env.
#
# Container ownership:
#   Terraform (modules/secret-manager) is the NORMAL owner of the long-lived secret
#   containers AND their IAM (accessor bindings). Creating the same containers here
#   would (a) collide with `terraform apply` (already-exists), and (b) skip the
#   required accessor IAM. So this script DEFAULTS to a read-only CHECK: it reports
#   which expected containers exist / are missing and sets no values.
#   For NON-Terraform setups, pass --create to actually create missing containers
#   (containers only — never a value; IAM is then your responsibility).
#
# Used by:
#   - Operators verifying a project's secret containers (default), or bootstrapping
#     a non-Terraform project (--create).
#
# Contract:
#   - Default (no --create): read-only. describe each expected secret and report.
#   - --create: idempotent describe-or-create (containers only). NEVER sets a value.
#   - Replication is automatic; labels are app=hernes,env=<env>,managed-by=manual.
#   - NEVER sets a secret value. NEVER echoes a secret value (there are none here).
#   - Exits non-zero on any failure (and, in check mode, if any container is missing).
#
# Secret IDs created (per migration contract §1):
#   preview     : preview-clerk-secret-key, preview-clerk-webhook-secret,
#                 preview-neon-api-key, preview-app-secret
#   staging     : staging-database-url, staging-clerk-secret-key,
#                 staging-clerk-webhook-secret, staging-redis-auth-string,
#                 staging-app-secret
#   production  : production-database-url, production-clerk-secret-key,
#                 production-clerk-webhook-secret, production-redis-auth-string,
#                 production-app-secret
#
# Note: the per-PR preview-pr-<N>-database-url secrets are NOT created here; the
# preview GitHub Actions workflow creates and deletes them per PR.
#
# Usage:
#   secret-bootstrap.sh <env: preview|staging|production> [--project <id>]
#
set -euo pipefail

APP_NAME="hernes"

usage() {
  echo "Usage: $(basename "$0") <env: preview|staging|production> [--project <id>] [--create]" >&2
  echo "       default: read-only check. --create: create missing containers (non-Terraform setups)." >&2
}

# --- arg parsing -------------------------------------------------------------
ENV=""
PROJECT=""
CREATE="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    preview|staging|production)
      if [[ -n "${ENV}" ]]; then
        echo "ERROR: env specified more than once." >&2
        usage
        exit 1
      fi
      ENV="$1"
      shift
      ;;
    --project)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --project requires an argument." >&2
        usage
        exit 1
      fi
      PROJECT="$2"
      shift 2
      ;;
    --create)
      CREATE="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unexpected argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "${ENV}" ]]; then
  echo "ERROR: missing required <env> argument." >&2
  usage
  exit 1
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "ERROR: gcloud not found on PATH." >&2
  exit 1
fi

# --- secret set per env ------------------------------------------------------
case "${ENV}" in
  preview)
    SECRET_IDS=(
      "preview-clerk-secret-key"
      "preview-clerk-webhook-secret"
      "preview-neon-api-key"
      "preview-app-secret"
    )
    ;;
  staging)
    SECRET_IDS=(
      "staging-database-url"
      "staging-clerk-secret-key"
      "staging-clerk-webhook-secret"
      "staging-redis-auth-string"
      "staging-app-secret"
    )
    ;;
  production)
    SECRET_IDS=(
      "production-database-url"
      "production-clerk-secret-key"
      "production-clerk-webhook-secret"
      "production-redis-auth-string"
      "production-app-secret"
    )
    ;;
  *)
    echo "ERROR: invalid env: ${ENV} (expected preview|staging|production)." >&2
    exit 1
    ;;
esac

# gcloud --project flag, only when an explicit project was passed.
GCLOUD_PROJECT_ARGS=()
if [[ -n "${PROJECT}" ]]; then
  GCLOUD_PROJECT_ARGS=(--project "${PROJECT}")
fi

LABELS="app=${APP_NAME},env=${ENV},managed-by=manual"

if [[ "${CREATE}" == "true" ]]; then
  echo "==> Creating missing Secret Manager containers for env=${ENV} (--create; non-Terraform setup)"
  echo "    (containers only; no values are set — use secret-put.sh next)"
  echo "    WARNING: Terraform が同じコンテナを管理する場合は --create を使わないこと（apply と衝突する）。"
else
  echo "==> Checking Secret Manager containers for env=${ENV} (read-only)"
  echo "    通常コンテナ + IAM は Terraform（modules/secret-manager）が作成する。"
  echo "    非 Terraform 運用で作成したい場合のみ --create を付ける。"
fi

# --- check (default) or create (--create) each container ---------------------
MISSING=0
for SECRET_ID in "${SECRET_IDS[@]}"; do
  if gcloud secrets describe "${SECRET_ID}" "${GCLOUD_PROJECT_ARGS[@]}" >/dev/null 2>&1; then
    echo "    [exists]  ${SECRET_ID}"
  elif [[ "${CREATE}" == "true" ]]; then
    gcloud secrets create "${SECRET_ID}" \
      --replication-policy=automatic \
      --labels="${LABELS}" \
      "${GCLOUD_PROJECT_ARGS[@]}" >/dev/null
    echo "    [create]  ${SECRET_ID}"
  else
    echo "    [missing] ${SECRET_ID}"
    MISSING=$((MISSING + 1))
  fi
done

if [[ "${CREATE}" != "true" && "${MISSING}" -gt 0 ]]; then
  echo "==> ${MISSING} container(s) missing for env=${ENV}." >&2
  echo "    Terraform で apply するか（推奨）、非 Terraform 運用なら --create を付けて再実行。" >&2
  exit 1
fi

echo "==> Done (env=${ENV}). Next: add values with scripts/gcp/secret-put.sh, e.g.:"
echo "      printf '%s' \"\$VALUE\" | scripts/gcp/secret-put.sh ${SECRET_IDS[0]}${PROJECT:+ --project ${PROJECT}}"
