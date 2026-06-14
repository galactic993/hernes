#!/usr/bin/env bash
#
# scripts/smoke/backend.sh — backend(Hono) のスモークテスト。
#
# 検証内容:
#   1. GET /healthz が 200 を返すこと            (必須)
#   2. GET /api/prod-quotes が 200 を返すこと     (任意 / 公開API)
#
# 使い方:
#   scripts/smoke/backend.sh https://backend-pr-123-xxxx.a.run.app
#   BASE_URL=https://...      scripts/smoke/backend.sh
#   BACKEND_URL=https://...   scripts/smoke/backend.sh   # 互換エイリアス
#
# 振る舞い:
#   - URL は arg1 / BASE_URL / BACKEND_URL の順に解決する。
#   - GET のみの read-only。冪等 / 再実行安全。
#   - 必須チェックに失敗したら非0で終了。
#   - Cloud Run のコールドスタートに備えてリトライする。
#   - 機密はログへ出さない。
#
set -euo pipefail

BASE_URL="${1:-${BASE_URL:-${BACKEND_URL:-}}}"
if [[ -z "${BASE_URL}" ]]; then
  echo "::error::BASE_URL (arg 1 / BASE_URL / BACKEND_URL) is required." >&2
  exit 1
fi

# 末尾スラッシュを除去
BASE_URL="${BASE_URL%/}"

ATTEMPTS="${SMOKE_ATTEMPTS:-10}"
SLEEP_SECONDS="${SMOKE_SLEEP_SECONDS:-6}"

if ! command -v curl >/dev/null 2>&1; then
  echo "::error::curl not found on PATH." >&2
  exit 1
fi

# check_status <path> <expected> <required:true|false>
check_status() {
  local path="$1"
  local expected="$2"
  local required="$3"
  local url="${BASE_URL}${path}"
  local code=""

  echo "Smoke testing backend: ${url} (expect ${expected})"
  for i in $(seq 1 "${ATTEMPTS}"); do
    code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "${url}" || true)"
    if [[ "${code}" == "${expected}" ]]; then
      echo "  OK   ${path} -> HTTP ${code} (attempt ${i})."
      return 0
    fi
    echo "  attempt ${i}/${ATTEMPTS}: ${path} returned '${code:-<none>}', retrying in ${SLEEP_SECONDS}s..."
    sleep "${SLEEP_SECONDS}"
  done

  if [[ "${required}" == "true" ]]; then
    echo "::error::backend smoke failed: ${path} != ${expected} after ${ATTEMPTS} attempts." >&2
    return 1
  fi
  echo "  WARN ${path} != ${expected} (optional); continuing." >&2
  return 0
}

# 必須: health。
check_status "/healthz" "200" "true"

# 任意: 公開リスト API（認証不要）。SMOKE_SKIP_API=1 でスキップ可能。
if [[ "${SMOKE_SKIP_API:-0}" != "1" ]]; then
  check_status "/api/prod-quotes" "200" "false"
fi

echo "backend smoke test passed."
