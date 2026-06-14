#!/usr/bin/env bash
#
# generate-tests.sh — spec/acceptance + 設計書画像 → acceptance.md + 失敗するテスト
# TDD: テストは実装より前に書き、正しい理由で失敗させる。
#
# 使い方: make tests FEATURE=001-prod-quote-top
#
set -euo pipefail

FEATURE="${FEATURE:?FEATURE is required}"
AGENT_CMD="${AGENT_CMD:-codex exec}"

test -f "specs/$FEATURE/spec.md" || { echo "missing specs/$FEATURE/spec.md"; exit 2; }

echo "==> 受け入れ条件 + 失敗テスト生成: $FEATURE"
$AGENT_CMD "
acceptance-test-designer スキルを使う。
Feature: $FEATURE
specs/$FEATURE/spec.md, specs/$FEATURE/questions.md, AGENTS.md と
design/rendered/ 配下の設計書画像（項目記述書・メッセージ一覧）を参照する。
specs/$FEATURE/acceptance.md と specs/$FEATURE/test-plan.md を作成。
MUST の受け入れ条件についてのみ失敗するテストを追加する（実装コードは書かない）。
項目記述書の制御内容・メッセージは @hernes/shared を単一の出典とし、テストはそのメッセージを検証する。
追加後に pnpm test を実行し、新規テストが期待通りの理由で失敗することを確認する。
"
