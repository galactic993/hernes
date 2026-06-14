# テスト計画 — 制作見積書作成<トップ画面>

## カバレッジ要約

| 条件ID | 階層 | テストファイル | 状態 |
|---|---|---|---|
| AC-001 | unit | packages/shared/test/validation.test.ts | PASS |
| AC-002 | unit/integration | shared + apps/frontend/test/validate.test.ts | PASS |
| AC-003 | unit | packages/shared/test/validation.test.ts | PASS |
| AC-004 | unit | packages/shared/test/validation.test.ts | PASS |
| AC-005 | integration | apps/backend/test/prod-quotes.test.ts | PASS |
| AC-006 | manual | — | 未実装（認可ミドルウェア待ち） |

## 自動テスト
- shared: 検索/得意先のバリデーションが設計書通りのメッセージを返す
- backend: 検索APIの値不正(400/No.3)・該当なし(200/No.6)
- frontend: クライアント検証が shared スキーマを再利用

## 手動検証
- AC-006: 権限なし時の表示・遷移

## 担保しない（理由）
- 文字コード Shift_JIS: 仕様未確定（questions.md Q-001）
- e2e（ブラウザ）: 初期表示・遷移は Playwright で後続実装
