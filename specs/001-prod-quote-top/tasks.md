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

## Phase 3
- [x] T010: 認可ミドルウェア（editorial.prod-quote.create / AC-006）
  - Files: `apps/backend/src/middleware/authz.ts`, app.ts で `/api/prod-quotes/manage` に適用
  - Done: 権限なしで「アクセス権限がありません」+ portal、`apps/backend/test/authz.test.ts` 緑
- [~] T011: prod_quots のリポジトリ層（FR-001 未着手取得 / FR-002 検索）
  - Files: `apps/backend/src/repositories/prod-quot-repository.ts`（インメモリ実装 + Drizzle 配線点）
  - Done: 取得・検索を integration で証明。**残**: 実DB(Drizzle)配線・「所属センター主管」絞り込み（quots/センターのモデル）
- [x] T012: 得意先選択モーダル UI（FR-004） + 一覧/詳細 UI（FR-003/005）
  - Files: `apps/frontend/src/features/prod-quote/{SearchResults,DetailModal,CustomerSelectModal,ProdQuoteTop}.tsx`
  - Done: component テスト緑。**残**: ブラウザ e2e（Playwright / `e2e/`）

## Phase 4: 証跡
- [ ] T999: evidence.md 更新、`make verify` が通ることを確認
