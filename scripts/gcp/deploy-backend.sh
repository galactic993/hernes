#!/usr/bin/env bash
#
# deploy-backend.sh — reusable Cloud Run backend deploy that wires the runtime
# service account and Secret Manager secret refs (per migration contract §2/§3).
#
# This is the canonical backend deploy command. Humans run it directly and the
# GitHub Actions workflows mirror its flags, so runtime secret handling stays
# consistent in one place.
#
# Cloud Run reads secret VALUES directly from Secret Manager at runtime via
# --update-secrets (secret REFERENCES only, never values). The runtime service
# account passed via --service-account must hold roles/secretmanager.secretAccessor
# on each referenced secret. No secret value ever passes through this script.
#
# Secret-env mapping by env (contract §2). Each maps a plain Cloud Run env name
# to a Secret Manager <secret-id>:latest reference:
#
#   preview  (service backend-pr-<N>):
#     DATABASE_URL         = <database-url-secret>:latest   # per-PR, passed as $3
#     CLERK_SECRET_KEY     = preview-clerk-secret-key:latest
#     CLERK_WEBHOOK_SECRET = preview-clerk-webhook-secret:latest
#     APP_SECRET           = preview-app-secret:latest
#
#   staging  (service backend-staging):
#     DATABASE_URL         = staging-database-url:latest
#     CLERK_SECRET_KEY     = staging-clerk-secret-key:latest
#     CLERK_WEBHOOK_SECRET = staging-clerk-webhook-secret:latest
#     REDIS_AUTH_STRING    = staging-redis-auth-string:latest
#     APP_SECRET           = staging-app-secret:latest
#
#   production  (service backend-prod):
#     DATABASE_URL         = production-database-url:latest
#     CLERK_SECRET_KEY     = production-clerk-secret-key:latest
#     CLERK_WEBHOOK_SECRET = production-clerk-webhook-secret:latest
#     REDIS_AUTH_STRING    = production-redis-auth-string:latest
#     APP_SECRET           = production-app-secret:latest
#
# Runtime service account (contract §3): hernes-backend-run@<project>.iam.gserviceaccount.com.
# Pass it via the BACKEND_RUNTIME_SA env var (a Terraform output / GitHub Variable).
#
# Contract:
#   - --update-secrets carries only secret REFERENCES; no value touches the runner.
#   - Backend deploy ALWAYS sets --service-account so the runtime SA can read secrets.
#   - For preview, the per-PR database-url secret id is supplied as the 3rd positional
#     arg (the workflow creates that secret before deploying).
#   - Exits non-zero on any failure. NEVER echoes a secret value.
#
# Required env:
#   BACKEND_RUNTIME_SA  runtime service account email (contract §3)
#   GCP_REGION          Cloud Run region (default: asia-northeast1)
# Optional env:
#   GCP_PROJECT_ID      project id (passed as --project when set)
#   EXTRA_DEPLOY_ARGS   extra args appended verbatim (e.g. VPC connector, env vars)
#
# Usage:
#   deploy-backend.sh <env: preview|staging|production> <service-name> <image> [<database-url-secret-id>]
#
# Examples:
#   BACKEND_RUNTIME_SA=hernes-backend-run@proj.iam.gserviceaccount.com \
#     deploy-backend.sh preview backend-pr-123 \
#       asia-northeast1-docker.pkg.dev/proj/hernes/backend:sha preview-pr-123-database-url
#
#   BACKEND_RUNTIME_SA=hernes-backend-run@proj.iam.gserviceaccount.com \
#     deploy-backend.sh staging backend-staging \
#       asia-northeast1-docker.pkg.dev/proj/hernes/backend:sha
#
set -euo pipefail

DEFAULT_REGION="asia-northeast1"

usage() {
  echo "Usage: $(basename "$0") <env: preview|staging|production> <service-name> <image> [<database-url-secret-id>]" >&2
}

# --- arg parsing -------------------------------------------------------------
if [[ $# -lt 3 || $# -gt 4 ]]; then
  usage
  exit 1
fi

ENV="$1"
SERVICE_NAME="$2"
IMAGE="$3"
DB_URL_SECRET="${4:-}"

if ! command -v gcloud >/dev/null 2>&1; then
  echo "ERROR: gcloud not found on PATH." >&2
  exit 1
fi

if [[ -z "${BACKEND_RUNTIME_SA:-}" ]]; then
  echo "ERROR: BACKEND_RUNTIME_SA is not set (runtime service account email)." >&2
  exit 1
fi

REGION="${GCP_REGION:-${DEFAULT_REGION}}"

# --- build the per-env secret-ref map ----------------------------------------
# Each entry is ENV_NAME=<secret-id>:latest — references only, never values.
case "${ENV}" in
  preview)
    if [[ -z "${DB_URL_SECRET}" ]]; then
      echo "ERROR: preview requires the per-PR database-url secret id as the 4th argument." >&2
      usage
      exit 1
    fi
    UPDATE_SECRETS="DATABASE_URL=${DB_URL_SECRET}:latest"
    UPDATE_SECRETS+=",CLERK_SECRET_KEY=preview-clerk-secret-key:latest"
    UPDATE_SECRETS+=",CLERK_WEBHOOK_SECRET=preview-clerk-webhook-secret:latest"
    UPDATE_SECRETS+=",APP_SECRET=preview-app-secret:latest"
    ;;
  staging)
    UPDATE_SECRETS="DATABASE_URL=staging-database-url:latest"
    UPDATE_SECRETS+=",CLERK_SECRET_KEY=staging-clerk-secret-key:latest"
    UPDATE_SECRETS+=",CLERK_WEBHOOK_SECRET=staging-clerk-webhook-secret:latest"
    UPDATE_SECRETS+=",REDIS_AUTH_STRING=staging-redis-auth-string:latest"
    UPDATE_SECRETS+=",APP_SECRET=staging-app-secret:latest"
    ;;
  production)
    UPDATE_SECRETS="DATABASE_URL=production-database-url:latest"
    UPDATE_SECRETS+=",CLERK_SECRET_KEY=production-clerk-secret-key:latest"
    UPDATE_SECRETS+=",CLERK_WEBHOOK_SECRET=production-clerk-webhook-secret:latest"
    UPDATE_SECRETS+=",REDIS_AUTH_STRING=production-redis-auth-string:latest"
    UPDATE_SECRETS+=",APP_SECRET=production-app-secret:latest"
    ;;
  *)
    echo "ERROR: invalid env: ${ENV} (expected preview|staging|production)." >&2
    usage
    exit 1
    ;;
esac

# Reject a stray database-url secret id for staging/production (it is implied by env).
if [[ "${ENV}" != "preview" && -n "${DB_URL_SECRET}" ]]; then
  echo "ERROR: a database-url secret id is only accepted for preview (got '${DB_URL_SECRET}' for ${ENV})." >&2
  usage
  exit 1
fi

# gcloud --project flag, only when an explicit project was passed.
GCLOUD_PROJECT_ARGS=()
if [[ -n "${GCP_PROJECT_ID:-}" ]]; then
  GCLOUD_PROJECT_ARGS=(--project "${GCP_PROJECT_ID}")
fi

# Optional extra deploy args (e.g. --vpc-connector, --set-env-vars for non-secret config).
EXTRA_ARGS=()
if [[ -n "${EXTRA_DEPLOY_ARGS:-}" ]]; then
  # shellcheck disable=SC2206 # intentional word-splitting of caller-supplied args
  EXTRA_ARGS=(${EXTRA_DEPLOY_ARGS})
fi

echo "==> Deploying backend service '${SERVICE_NAME}' (env=${ENV}, region=${REGION})"
echo "    image:           ${IMAGE}"
echo "    service-account: ${BACKEND_RUNTIME_SA}"
echo "    secret refs:     ${UPDATE_SECRETS}"
echo "    (values are read by Cloud Run from Secret Manager; none touch this host)"

# --- deploy ------------------------------------------------------------------
gcloud run deploy "${SERVICE_NAME}" \
  --image="${IMAGE}" \
  --region="${REGION}" \
  --service-account="${BACKEND_RUNTIME_SA}" \
  --update-secrets="${UPDATE_SECRETS}" \
  "${GCLOUD_PROJECT_ARGS[@]}" \
  "${EXTRA_ARGS[@]}"

echo "==> Deployed '${SERVICE_NAME}' (env=${ENV})"
