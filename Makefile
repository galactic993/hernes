# Makefile — pnpm への薄いラッパ + 自動ループのエントリポイント。
# 検証ゲート `make verify` が全AI変更の合否判定器。スタックは pnpm モノレポ。

.PHONY: install verify govern govern-speckit density lint typecheck test test-e2e dev \
        design loop spec tests evidence help

help:
	@echo "セットアップ:"
	@echo "  make install                     pnpm install"
	@echo "検証ゲート:"
	@echo "  make verify                      lint + typecheck + test + govern (= pnpm verify)"
	@echo "  make govern                      三権分立の統治ゲート（立法↔司法↔仕様↔SSOT）"
	@echo "  make density FILE=<records.json> AI実行密度（token×PR/月）でHOTL/HITL分類"
	@echo "  make govern-speckit DIR=<path>   Spec-Kitプロジェクトに統治ゲートを適用"
	@echo "  make lint | typecheck | test"
	@echo "設計書:"
	@echo "  make design DESIGN=<xlsx>        Excel設計書をPNG化（視覚理解用）"
	@echo "自動ループ:"
	@echo "  make spec FEATURE=<id>           設計書読取 → spec.md（曖昧さレビュー込み）"
	@echo "  make tests FEATURE=<id>          spec/acceptance → 失敗するテスト"
	@echo "  make loop FEATURE=<id>           1タスク実装 → verify → 修復(<=3)"
	@echo "  make evidence FEATURE=<id>       evidence.md に検証結果を収集"

install:
	pnpm install

# --- 検証ゲート（pnpm に委譲） ---
verify:
	pnpm verify

# 三権分立の統治ゲート（書かれている→効いている）。違反(error)で exit 1。
govern:
	pnpm govern

# AI 実行密度（token使用量 × PR数 / 月・1人あたり）。HOTL/HITL を分類。
# FILE 省略時はサンプル（governance/density.sample.json）。
density:
	@pnpm --filter @hernes/governance run density "$(or $(FILE),governance/density.sample.json)"

# Spec-Kit プロジェクト（specs/ と .specify/ を持つ）に統治ゲートを適用（書かれている→効いている）。
# DIR 省略時は同梱 fixture。違反(error)で exit 1。
govern-speckit:
	@pnpm --filter @hernes/governance run govern:speckit "$(or $(DIR),governance/test/fixtures/speckit)"

lint:
	pnpm lint

typecheck:
	pnpm typecheck

test:
	pnpm test

test-e2e:
	pnpm test:e2e

dev:
	pnpm --parallel -r dev

# --- 設計書のレンダリング ---
design:
	@scripts/render-design.sh "$(DESIGN)"

# --- 自動ループ ---
loop:
	@FEATURE="$(FEATURE)" scripts/run-loop.sh

spec:
	@FEATURE="$(FEATURE)" scripts/generate-spec.sh

tests:
	@FEATURE="$(FEATURE)" scripts/generate-tests.sh

evidence:
	@FEATURE="$(FEATURE)" scripts/collect-evidence.sh
