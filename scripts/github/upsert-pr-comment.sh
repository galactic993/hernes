#!/usr/bin/env bash
#
# scripts/github/upsert-pr-comment.sh — PR に「単一の」Preview 環境コメントを upsert する。
#
# 同じ HTML マーカーを持つ既存コメントがあれば編集（PATCH）、無ければ新規作成（POST）。
# これにより、デプロイの度に PR を汚さず 1 コメントへ集約できる。冪等 / 再実行安全。
#
#   marker: <!-- preview-environment-comment -->
#
# 本文の渡し方は 2 通り:
#   (A) 完成した本文をそのまま渡す:
#         BODY_FILE=/path/to/body.md  または  BODY="## Preview ..."
#   (B) 個別フィールドを渡してテーブルを自動生成:
#         FRONTEND_URL / BACKEND_URL / NEON_BRANCH / COMMIT / GCS_PREFIX
#         MIGRATION_RESULT / SMOKE_RESULT / E2E_RESULT
#       （CLI フラグでも可: --frontend-url など。下記参照）
#
# 使い方（環境変数）:
#   GITHUB_TOKEN=...              (必須: pull-requests:write 権限。Actions の GITHUB_TOKEN で可)
#   GITHUB_REPOSITORY=owner/repo  (必須: Actions では自動設定)
#   PR_NUMBER=123                 (必須。または arg1 / --pr)
#
# 使い方（CLI フラグ）:
#   scripts/github/upsert-pr-comment.sh \
#     --pr 123 \
#     --frontend-url https://frontend-pr-123-xxxx.a.run.app \
#     --backend-url  https://backend-pr-123-xxxx.a.run.app \
#     --neon-branch  pr-123 \
#     --commit       "$GITHUB_SHA" \
#     --gcs-prefix   pr/123/ \
#     --migration    success --smoke success --e2e skipped
#
# 機密はログへ出さない（set -x 禁止 / トークンを echo しない）。
#
set -euo pipefail

MARKER="${COMMENT_MARKER:-<!-- preview-environment-comment -->}"

# --- CLI フラグ（環境変数を上書き）------------------------------------------
PR_NUMBER="${PR_NUMBER:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr) PR_NUMBER="${2:-}"; shift 2 ;;
    --repo) GITHUB_REPOSITORY="${2:-}"; shift 2 ;;
    --body) BODY="${2:-}"; shift 2 ;;
    --body-file) BODY_FILE="${2:-}"; shift 2 ;;
    --frontend-url) FRONTEND_URL="${2:-}"; shift 2 ;;
    --backend-url) BACKEND_URL="${2:-}"; shift 2 ;;
    --neon-branch) NEON_BRANCH="${2:-}"; shift 2 ;;
    --commit) COMMIT="${2:-}"; shift 2 ;;
    --gcs-prefix) GCS_PREFIX="${2:-}"; shift 2 ;;
    --migration) MIGRATION_RESULT="${2:-}"; shift 2 ;;
    --smoke) SMOKE_RESULT="${2:-}"; shift 2 ;;
    --e2e) E2E_RESULT="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '2,40p' "$0"; exit 0 ;;
    --) shift; break ;;
    -*) echo "::error::unknown flag: $1" >&2; exit 1 ;;
    *) [[ -z "${PR_NUMBER}" ]] && PR_NUMBER="$1"; shift ;;  # 位置引数: PR番号
  esac
done

: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required (owner/repo)}"
: "${PR_NUMBER:?PR_NUMBER is required (env, arg1, or --pr)}"

# --- status -> ラベル --------------------------------------------------------
status_label() {
  local s
  s="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  case "${s}" in
    success|ok|pass|passed|true) echo "✅ success" ;;
    fail|failed|failure|error|false) echo "❌ failed" ;;
    skip|skipped|disabled|n/a|"") echo "⏭️ skipped" ;;
    *) echo "${1}" ;;
  esac
}

# --- 本文の決定 --------------------------------------------------------------
# BODY_FILE / BODY が与えられればそれを尊重。無ければフィールドからテーブル生成。
if [[ -n "${BODY_FILE:-}" ]]; then
  BODY_CONTENT="$(cat "${BODY_FILE}")"
elif [[ -n "${BODY:-}" ]]; then
  BODY_CONTENT="${BODY}"
else
  fe="${FRONTEND_URL:-—}"
  be="${BACKEND_URL:-—}"
  neon="${NEON_BRANCH:-—}"
  prefix_raw="${GCS_PREFIX:-}"
  commit_raw="${COMMIT:-}"

  commit_cell="—"
  [[ -n "${commit_raw}" ]] && commit_cell="\`${commit_raw:0:12}\`"
  prefix_cell="—"
  [[ -n "${prefix_raw}" ]] && prefix_cell="\`${prefix_raw}\`"

  BODY_CONTENT="$(cat <<EOF
## 🚀 Preview environment for PR #${PR_NUMBER}

| Resource | Value |
| --- | --- |
| Frontend | ${fe} |
| Backend | ${be} |
| Neon branch | \`${neon}\` |
| Commit | ${commit_cell} |
| GCS prefix | ${prefix_cell} |

| Step | Result |
| --- | --- |
| Migration | $(status_label "${MIGRATION_RESULT:-}") |
| Smoke | $(status_label "${SMOKE_RESULT:-}") |
| E2E | $(status_label "${E2E_RESULT:-}") |

<sub>Updated automatically on each deploy. Preview resources are torn down when the PR closes; the Neon branch and GCS prefix \`pr/${PR_NUMBER}/\` are ephemeral (preview bucket lifecycle: 14 days).</sub>
EOF
)"
fi

# マーカーを必ず先頭に付与（再検出できるように）。
FULL_BODY="${MARKER}"$'\n'"${BODY_CONTENT}"

API="https://api.github.com"
AUTH=(-H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28")

# --- gh CLI 経路（Actions ランナーに同梱）-----------------------------------
if command -v gh >/dev/null 2>&1; then
  export GH_TOKEN="${GITHUB_TOKEN}"
  existing_id="$(gh api "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" --paginate \
    --jq "map(select(.body | contains(\"${MARKER}\"))) | .[0].id // empty" 2>/dev/null || true)"

  tmp="$(mktemp)"
  trap 'rm -f "${tmp}"' EXIT
  printf '%s' "${FULL_BODY}" > "${tmp}"
  if [[ -n "${existing_id}" ]]; then
    echo "Updating existing PR comment (id=${existing_id})."
    gh api -X PATCH "repos/${GITHUB_REPOSITORY}/issues/comments/${existing_id}" \
      -F "body=@${tmp}" >/dev/null
  else
    echo "Creating new PR comment."
    gh api -X POST "repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
      -F "body=@${tmp}" >/dev/null
  fi
  echo "PR comment upserted."
  exit 0
fi

# --- curl + jq フォールバック -----------------------------------------------
if ! command -v jq >/dev/null 2>&1; then
  echo "::error::Neither gh nor jq is available; cannot upsert PR comment." >&2
  exit 1
fi

existing_id="$(curl -fsS "${AUTH[@]}" \
  "${API}/repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments?per_page=100" \
  | jq -r --arg m "${MARKER}" 'map(select(.body | contains($m))) | .[0].id // empty')"

# jq で本文を安全に JSON エンコード。
payload="$(jq -n --arg body "${FULL_BODY}" '{body: $body}')"

if [[ -n "${existing_id}" ]]; then
  echo "Updating existing PR comment (id=${existing_id})."
  curl -fsS -X PATCH "${AUTH[@]}" \
    "${API}/repos/${GITHUB_REPOSITORY}/issues/comments/${existing_id}" \
    -d "${payload}" >/dev/null
else
  echo "Creating new PR comment."
  curl -fsS -X POST "${AUTH[@]}" \
    "${API}/repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
    -d "${payload}" >/dev/null
fi

echo "PR comment upserted."
