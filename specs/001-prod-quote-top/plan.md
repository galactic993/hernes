# 実装計画 — 制作見積書作成<トップ画面>

## 概要

既存スタック（Hono / React / shared / db）の範囲で最小実装。検索フォームのバリデーションとメッセージを
`@hernes/shared` に単一定義し、フロント/サーバで共有する。

## 影響モジュール

- `packages/shared`: 検索/得意先のzodスキーマ、メッセージ、ステータス列挙
- `packages/db`: `prod_quots` スキーマ
- `apps/backend`: `routes/prod-quotes.ts`（検索）、`middleware/authz.ts`（権限・未実装）
- `apps/frontend`: `features/prod-quote/`（検索フォーム、得意先モーダル・未実装）

## データモデル

- `prod_quots`（編-テーブル定義書）。FK は `見積.quot_id`（共/売のテーブル定義書は別途）。

## API

- POST `/api/prod-quotes/search`（EVENT0009）
- GET `/api/prod-quotes`（初期表示, EVENT0001 / FR-001・未実装）
- 得意先検索（EVENT0014・未実装）

## セキュリティ

- 認可ミドルウェアで `editorial.prod-quote.create` を検証（AC-006）。個人情報の非ログ出力。

## 観測可能性

- 検索の件数・所要時間・失敗率メトリクス。

## 移行/ロールバック

- `prod_quots` 等は後方互換の追加。ロールバックはエンドポイント無効化。

## テスト戦略

- unit: shared バリデーション（メッセージ一致）
- integration: Hono `app.request`（ステータス/メッセージ）
- e2e: `e2e/` Playwright（検索→一覧、後続）

## リスク

- 文字コード/最大件数が未確定（questions.md）
- 共/売テーブル定義（得意先・組織・社員）の参照解決

## 実装増分

1. 検索バリデーション＋API（実装済み）
2. 認可ミドルウェア
3. 実DB検索 / 得意先モーダル
