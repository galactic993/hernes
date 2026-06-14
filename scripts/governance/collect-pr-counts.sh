#!/usr/bin/env bash
# AI 実行密度の実データ収集（GitHub 側）: author 別の月次 PR 数を gh で集計する。
# Codex の使用済みトークン数（team/users/tokens）と結合して density 入力 JSON を作る。
#
# 使い方:
#   scripts/governance/collect-pr-counts.sh [SINCE=YYYY-MM-DD]
#   → [{author, prs}] を stdout に出力。
#
# 規約: secret を echo しない / set -x は使わない。
set -euo pipefail

SINCE="${1:-$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d '30 days ago' +%Y-%m-%d)}"

gh pr list --state all --search "created:>=${SINCE}" --limit 1000 \
  --json author \
  --jq 'group_by(.author.login) | map({author: .[0].author.login, prs: length}) | sort_by(-.prs)'
