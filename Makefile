# Makefile — pnpm への薄いラッパ + 自動ループのエントリポイント。
# 検証ゲート `make verify` が全AI変更の合否判定器。スタックは pnpm モノレポ。

.PHONY: install verify lint typecheck test test-e2e dev \
        design loop spec tests evidence help

help:
	@echo "セットアップ:"
	@echo "  make install                     pnpm install"
	@echo "検証ゲート:"
	@echo "  make verify                      lint + typecheck + test (= pnpm verify)"
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
