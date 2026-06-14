# テスト計画 — 制作見積書作成<トップ画面>

## カバレッジ要約

| 条件ID | 階層 | テストファイル | 状態 |
|---|---|---|---|
| AC-001 | unit | packages/shared/test/validation.test.ts | PASS |
| AC-002 | unit/integration | shared + apps/frontend/test/validate.test.ts | PASS |
| AC-003 | unit | packages/shared/test/validation.test.ts | PASS |
| AC-004 | unit | packages/shared/test/validation.test.ts | PASS |
| AC-005 | integration | apps/backend/test/prod-quotes.test.ts | PASS |
| AC-006 | integration | apps/backend/test/authz.test.ts | PASS（認可ミドルウェア） |
| AC-007 | integration | apps/backend/test/prod-quot-repository.test.ts | PASS（未着手取得・検索 / センター絞り込みは Phase3） |
| AC-008 | component | apps/frontend/test/prod-quote-ui.test.tsx | PASS（一覧遷移） |
| AC-009 | component | apps/frontend/test/prod-quote-ui.test.tsx | PASS（詳細モーダル） |
| AC-010 | integration | apps/backend/test/prod-quotes.test.ts | PASS（観測ログ・PII非出力） |

## 自動テスト
- shared: 検索/得意先のバリデーションが設計書通りのメッセージを返す
- backend: 検索APIの値不正(400/No.3)・該当なし(200/No.6)
- frontend: クライアント検証が shared スキーマを再利用

## 担保しない（理由）
- 文字コード Shift_JIS: 仕様未確定（questions.md Q-001）。実装は UTF-8 既定。
- e2e（ブラウザ・画面間遷移）: component テストで部品は担保済み。フルフローは Playwright で後続実装（`e2e/`）。
- 「所属センター主管」絞り込み（FR-001）: quots/センターのモデルが未同梱（Phase3 T011）。
