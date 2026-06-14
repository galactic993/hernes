#!/usr/bin/env bash
#
# secret-put.sh — upsert a single Secret Manager secret VALUE from stdin.
#
# Adds a new version to an EXISTING <secret-id>. The value is read from STDIN via
# --data-file=- so it never appears on argv, in the process listing, or in shell history.
#
# Container ownership:
#   Terraform (modules/secret-manager) owns the long-lived secret CONTAINERS + IAM.
#   This script does NOT create containers by default — silently creating one would
#   bypass Terraform's IAM and later collide with `terraform apply`. If the container
#   is missing it FAILS with guidance. For non-Terraform setups, pass --create-missing
#   to explicitly opt into creating the container here.
#
# Used by:
#   - Operators seeding / rotating a long-lived secret whose container already exists
#     (created by Terraform, or by secret-bootstrap.sh --create in non-Terraform setups).
#
# Contract:
#   - The secret VALUE is read from STDIN only (never a CLI arg).
#   - The value is NEVER echoed or logged. We print only the secret id and a
#     "version added" confirmation.
#   - Each call adds exactly one new version (Secret Manager versions are immutable).
#   - Exits non-zero on any failure.
#
# Usage:
#   secret-put.sh <secret-id> [--project <id>] [--create-missing]   # reads VALUE from stdin
#
# Examples:
#   printf '%s' "$VALUE" | secret-put.sh staging-app-secret
#   secret-put.sh preview-clerk-secret-key --project my-dev-project < secret.txt
#
set -euo pipefail

APP_NAME="hernes"

usage() {
  echo "Usage: $(basename "$0") <secret-id> [--project <id>] [--create-missing]   (reads VALUE from stdin)" >&2
}

# --- arg parsing -------------------------------------------------------------
SECRET_ID=""
PROJECT=""
CREATE_MISSING="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --project requires an argument." >&2
        usage
        exit 1
      fi
      PROJECT="$2"
      shift 2
      ;;
    --create-missing)
      CREATE_MISSING="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "ERROR: unexpected option: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [[ -n "${SECRET_ID}" ]]; then
        echo "ERROR: secret-id specified more than once." >&2
        usage
        exit 1
      fi
      SECRET_ID="$1"
      shift
      ;;
  esac
done

if [[ -z "${SECRET_ID}" ]]; then
  echo "ERROR: missing required <secret-id> argument." >&2
  usage
  exit 1
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "ERROR: gcloud not found on PATH." >&2
  exit 1
fi

# Refuse to read a value from an interactive terminal: stdin MUST be piped/redirected
# so the value never lands in scrollback or has to be typed visibly.
if [[ -t 0 ]]; then
  echo "ERROR: no value on stdin. Pipe the secret value in, e.g.:" >&2
  echo "       printf '%s' \"\$VALUE\" | $(basename "$0") ${SECRET_ID}" >&2
  exit 1
fi

# gcloud --project flag, only when an explicit project was passed.
GCLOUD_PROJECT_ARGS=()
if [[ -n "${PROJECT}" ]]; then
  GCLOUD_PROJECT_ARGS=(--project "${PROJECT}")
fi

# --- container must exist (Terraform owns it) --------------------------------
# 黙ってコンテナを作ると Terraform の所有/IAM をバイパスし、後の apply と衝突する。
# 既定では存在しなければ fail。非 Terraform 運用のみ --create-missing で明示作成を許可。
if ! gcloud secrets describe "${SECRET_ID}" "${GCLOUD_PROJECT_ARGS[@]}" >/dev/null 2>&1; then
  if [[ "${CREATE_MISSING}" == "true" ]]; then
    echo "==> Secret container ${SECRET_ID} not found; creating it (--create-missing)"
    gcloud secrets create "${SECRET_ID}" \
      --replication-policy=automatic \
      --labels="app=${APP_NAME},managed-by=manual" \
      "${GCLOUD_PROJECT_ARGS[@]}" >/dev/null
  else
    echo "ERROR: secret container '${SECRET_ID}' does not exist." >&2
    echo "       通常は Terraform（modules/secret-manager）がコンテナ + IAM を作成する。" >&2
    echo "       先に terraform apply するか、非 Terraform 運用なら --create-missing を付けて再実行。" >&2
    exit 1
  fi
fi

# --- add a new version from stdin --------------------------------------------
# --data-file=- reads the value from stdin: it never touches argv or the logs.
gcloud secrets versions add "${SECRET_ID}" \
  --data-file=- \
  "${GCLOUD_PROJECT_ARGS[@]}" >/dev/null

echo "==> ${SECRET_ID}: version added"
