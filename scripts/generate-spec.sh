#!/usr/bin/env bash
#
# generate-spec.sh — Excel設計書 → 画像化 → 視覚理解 → spec.md → questions.md
#
# 使い方: make spec FEATURE=001-prod-quote-top
#   specs/<feature>/design-source.md に対象Excelのパスとシートを明記しておくこと。
#
set -euo pipefail

FEATURE="${FEATURE:?FEATURE is required}"
AGENT_CMD="${AGENT_CMD:-codex exec}"

test -f "specs/$FEATURE/design-source.md" \
  || { echo "missing specs/$FEATURE/design-source.md（対象設計書のパスを書く）"; exit 2; }

echo "==> 設計書読み取り（render → vision）: $FEATURE"
$AGENT_CMD "
design-doc-reader スキルを使う。
Feature: $FEATURE
specs/$FEATURE/design-source.md に書かれた Excel設計書を scripts/render-design.sh で画像化し、
ページ画像を視覚的に読み取って specs/$FEATURE/intent.yaml（未作成なら下書き）と specs/$FEATURE/spec.md を作る。
実装コードは書かない。各要件に出典（シート名・項目No・EVENT No）を併記する。
"

echo "==> 曖昧さレビュー: $FEATURE"
$AGENT_CMD "
spec-clarifier スキルを使う。
Feature: $FEATURE
docs/constitution.md, specs/$FEATURE/intent.yaml, specs/$FEATURE/spec.md を読む。
specs/$FEATURE/questions.md を作成/更新し、課題を BLOCKER / MAJOR / MINOR で分類する。
BLOCKER があれば計画着手は不可と明記する。
"

echo "==> 完了。specs/$FEATURE/questions.md を確認してから次へ。"
