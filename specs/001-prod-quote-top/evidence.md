# 証跡 — 制作見積書作成<トップ画面>

## サマリ

検索バリデーション（項目記述書 No.1,2,16）とメッセージ（メッセージ一覧 No.3,6）、検索APIスタブ、
検索フォームを実装。`@hernes/shared` を単一の出典としてフロント/サーバ/テストが共有。

## 受け入れ条件の状態

| ID | 状態 | 証跡 |
|---|---|---|
| AC-001 | PASS | `pnpm --filter @hernes/shared test` |
| AC-002 | PASS | shared + `pnpm --filter @hernes/frontend test` |
| AC-003 | PASS | shared |
| AC-004 | PASS | shared |
| AC-005 | PASS | `pnpm --filter @hernes/backend test` |
| AC-006 | BLOCKED | 認可ミドルウェア未実装（T010）|

## 実行コマンド

```bash
make verify   # = pnpm verify (lint + typecheck + test)
```

## 結果

```text
biome check .            → Checked 30 files. No fixes applied.
pnpm -r typecheck        → packages/shared, packages/db, apps/backend, apps/frontend : Done
vitest run               → Test Files 3 passed (3) / Tests 10 passed (10)
  - packages/shared/test/validation.test.ts (6)
  - apps/backend/test/prod-quotes.test.ts (2)
  - apps/frontend/test/validate.test.ts (2)
```

## 変更ファイル

- packages/shared/src/{messages,status,validation/prod-quote-search,index}.ts (+test)
- packages/db/src/schema/prod-quots.ts, src/index.ts
- apps/backend/src/{app,index,routes/prod-quotes}.ts (+test)
- apps/frontend/src/{App,main}.tsx, features/prod-quote/{validate,SearchForm}.tsx (+test)

## リスク / 未解決

- 認可（AC-006）未実装。実DB検索・得意先モーダルは未着手（T010〜T012）。
- Q-001(検索方式), Q-002(共/売テーブル定義) 未解決。

## 人間レビュー要否

Yes（受け入れ条件の承認 / 共・売テーブル定義書の提供）

## 推奨

NEEDS_HUMAN_REVIEW（検索の最小機能は緑。認可と実DB検索は次ループ）
