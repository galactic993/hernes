# タスク — 制作見積書作成<トップ画面>

> テストを先に置き、最小増分で実装。`make loop` は次の未完了タスクを1つずつ処理する。
> Phase 1〜2 の検索バリデーション部分は本テンプレで実装済み（サンプル）。

## Phase 0: 設計理解
- [x] T000: 画面設計書・テーブル定義書を `make design` で画像化し、視覚的に読み spec/acceptance を作成

## Phase 1: テスト（先に書く）
- [x] T001: ステータス/見積書Noのバリデーションテスト（AC-001,002,003）
  - Files: `packages/shared/test/validation.test.ts`
  - Validation: `pnpm --filter @hernes/shared test`
- [x] T002: 得意先コードのバリデーションテスト（AC-004）
  - Files: 同上
- [x] T003: 検索APIのテスト（AC-005）
  - Files: `apps/backend/test/prod-quotes.test.ts`

## Phase 2: 実装（最小）
- [x] T004: 共有バリデーション・メッセージ・列挙値（@hernes/shared）
  - Files: `packages/shared/src/{messages,status,validation/prod-quote-search}.ts`
  - Done when: AC-001〜004 を満たす
- [x] T005: prod_quots スキーマ（@hernes/db）
  - Files: `packages/db/src/schema/prod-quots.ts`
- [x] T006: 検索API（Hono, 値不正→No.3 / 該当なし→No.6）
  - Files: `apps/backend/src/routes/prod-quotes.ts`
- [x] T007: 検索フォーム（React, 共有スキーマでクライアント検証）
  - Files: `apps/frontend/src/features/prod-quote/*`

## Phase 3: 未実装（次にループを回す対象）
- [ ] T010: 認可ミドルウェア（editorial.prod-quote.create / AC-006）
  - Files: `apps/backend/src/middleware/authz.ts`, route 適用
  - Validation: integration テスト追加 → `make verify`
  - Done when: 権限なしで「アクセス権限がありません」+ ポータル遷移、テスト緑
- [ ] T011: prod_quots 検索の実DB問い合わせ（スタブ置換 / FR-001,002）
  - Files: `apps/backend/src/routes/prod-quotes.ts`, `@hernes/db` クエリ
- [ ] T012: 得意先選択モーダル UI（FR-004 / EVENT0012〜0016）

## Phase 4: 証跡
- [ ] T999: evidence.md 更新、`make verify` が通ることを確認
