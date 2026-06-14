# AGENTS.md

> 作業前に必ず読む「このリポジトリでの AI 作業規約」。

## ミッション

このリポジトリは **設計駆動 (SDD) × テスト駆動 (TDD)** で開発する。
人手の Excel 設計書（画面設計書・テーブル定義書）が要件の起点。
spec と受け入れ条件が無いまま実装に飛ばない。

## スタック

- pnpm モノレポ（`apps/*`, `packages/*`）／ TypeScript（strict）
- バックエンド: Hono（`apps/backend`）／ フロント: React + Vite（`apps/frontend`）
- 共有: `@hernes/shared`（zod。メッセージ・列挙値・バリデーション規則の**単一出典**）
- DB: `@hernes/db`（Drizzle / PostgreSQL）
- Lint/Format: Biome ／ Test: Vitest ／ 型: tsc

## リポジトリ構成

- `specs/`：機能ごとの設計出典・仕様・受け入れ条件・証跡（`_template/` をコピーして開始）
- `design/`：Excel設計書（`source/`）とレンダリング結果（`rendered/`）
- `docs/`：憲法・アーキテクチャ・ADR
- `scripts/`：`render-design.sh` ほか自動ループ
- `.agents/skills/`：タスク別手順（必要時にロード）

## 設計書の扱い（重要）

- 設計書は **JSON抽出せず、画像化して視覚的に読む**：`scripts/render-design.sh <xlsx>` → `design/rendered/<doc>/page-*.png` を Read/vision で読む。
- 画面概要の埋め込みキャプチャ・I/O図・結合セル・色の意味を取りこぼさないため。
- 制御区分 JavaScript=フロント / PHP=サーバ。両者は同じ `@hernes/shared` スキーマを使う。元設計の Laravel/PHP は参考。

## 必須ワークフロー

1. `docs/constitution.md` を読む。
2. 対象の `specs/<feature>/` を読む（`design-source.md` の Excel を画像化して理解）。
3. 受け入れ条件を確認する。
4. 実装より前にテストを書く/更新する。
5. テストを満たす最小の変更を実装する。
6. `make verify` を実行する。
7. 失敗したら原因を読んで修復する。
8. 修復3回失敗で停止し、ハンドオフを書く。
9. `specs/<feature>/evidence.md` を更新する。

## コマンド

- 検証: `make verify`（= `pnpm verify` = lint + typecheck + test）
- 個別: `pnpm lint` / `pnpm typecheck` / `pnpm test` / `pnpm --filter <pkg> test`
- 設計書画像化: `make design DESIGN=<xlsx>`
- ループ: `make loop FEATURE=<id>`

## 完了の定義

- 受け入れ条件を満たす
- 関連テストが存在する
- `make verify` が通る
- 公開挙動が文書化されている
- 無関係なファイルを変更していない
- `evidence.md` に実行コマンドと結果がある

## 禁止事項

- 検証を通すためにテストを削除しない。
- spec を更新せずに公開API/挙動を変えない。
- メッセージ・列挙値・バリデーションを `@hernes/shared` 以外に直書きしない。
- 正当な理由なく本番依存を追加しない。
- 検証をスキップしない。証跡なしに成功を主張しない。
