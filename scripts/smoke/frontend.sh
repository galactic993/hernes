#!/usr/bin/env bash
#
# scripts/smoke/frontend.sh — frontend(React+Vite, nginx:8080) のスモークテスト。
#
# 検証内容:
#   1. GET /        が 200 を返すこと   (index.html 配信)  (必須)
#   2. GET /healthz が 200 を返すこと   (nginx health)     (必須)
#
# 使い方:
#   scripts/smoke/frontend.sh https://frontend-pr-123-xxxx.a.run.app
#   BASE_URL=https://...      scripts/smoke/frontend.sh
#   FRONTEND_URL=https://...  scripts/smoke/frontend.sh   # 互換エイリアス
#
# 振る舞い:
#   - URL は arg1 / BASE_URL / FRONTEND_URL の順に解決する。
#   - GET のみの read-only。冪等 / 再実行安全。
#   - いずれか失敗で非0終了。Cloud Run コールドスタートに備えてリトライ。
#   - 機密はログへ出さない。
#
# 注意: nginx 側に `location = /healthz { return 200; }` 相当の設定が必要。
#       フロントの nginx.conf に health エンドポイントを用意しておくこと。
#
set -euo pipefail

BASE_URL="${1:-${BASE_URL:-${FRONTEND_URL:-}}}"
if [[ -z "${BASE_URL}" ]]; then
  echo "::error::BASE_URL (arg 1 / BASE_URL / FRONTEND_URL) is required." >&2
  exit 1
fi

BASE_URL="${BASE_URL%/}"

ATTEMPTS="${SMOKE_ATTEMPTS:-10}"
SLEEP_SECONDS="${SMOKE_SLEEP_SECONDS:-6}"

if ! command -v curl >/dev/null 2>&1; then
  echo "::error::curl not found on PATH." >&2
  exit 1
fi

# check_status <path>
check_status() {
  local path="$1"
  local url="${BASE_URL}${path}"
  local code=""

  echo "Smoke testing frontend: ${url} (expect 200)"
  for i in $(seq 1 "${ATTEMPTS}"); do
    code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "${url}" || true)"
    if [[ "${code}" == "200" ]]; then
      echo "  OK   ${path} -> HTTP ${code} (attempt ${i})."
      return 0
    fi
    echo "  attempt ${i}/${ATTEMPTS}: ${path} returned '${code:-<none>}', retrying in ${SLEEP_SECONDS}s..."
    sleep "${SLEEP_SECONDS}"
  done

  echo "::error::frontend smoke failed: ${path} != 200 after ${ATTEMPTS} attempts." >&2
  return 1
}

check_status "/"
check_status "/healthz"

echo "frontend smoke test passed."
