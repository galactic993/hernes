# 受け入れ条件 — 制作見積書作成<トップ画面>

## トレーサビリティ・マトリクス

| 条件ID | 要件/項目No | 優先度 | テスト階層 | 実テスト |
|---|---|---|---|---|
| AC-001 | FR-002 / 項目No.1 | MUST | unit | `packages/shared/test/validation.test.ts` |
| AC-002 | FR-002 / 項目No.2 | MUST | unit + integration | shared + `apps/frontend/test/validate.test.ts` |
| AC-003 | FR-002 / 項目No.1 | MUST | unit | shared |
| AC-004 | FR-004 / 項目No.16 | MUST | unit | shared |
| AC-005 | FR-002 / メッセージNo.3,6 | MUST | integration | `apps/backend/test/prod-quotes.test.ts` |
| AC-006 | SEC-001 / メッセージNo.1 | MUST | 手動/未実装 | — |

## 条件

### AC-001 ステータスは有効な値のみ
- Given トップ画面
- When ステータスに有効値(00〜50)以外を指定して検索
- Then 「有効な値を選択してください」を表示する（実装: status enum + errorMap）

### AC-002 見積書Noは11桁以内
- Given トップ画面
- When 見積書Noに12文字を入力
- Then 「11桁以内で入力してください」を表示する

### AC-003 正常な検索条件は通る
- Given ステータス=00(未着手)
- When 検索する
- Then バリデーションを通過する

### AC-004 得意先コードは半角数字・5桁以内
- Given 得意先選択モーダル
- When 得意先コードに `abc` → 「半角数字で入力してください」、`123456` → 「5桁以内で入力してください」
- Then それぞれのメッセージを表示する

### AC-005 検索API: 値不正は400 / 該当なしはサクセス
- Given `POST /api/prod-quotes/search`
- When `{status:'99'}` → 400 + 「入力内容に誤りがあります。各項目をご確認ください」
- When `{status:'00'}`（該当なし）→ 200 + 「該当する制作見積情報が見つかりません」

## 却下条件
- 個人情報（検索結果の中身）をログ出力したら不合格（SEC / 憲法5）
- 権限チェックを経ずに他センターの制作見積が取得できたら不合格

## 手動レビュー条件
- AC-006: 権限 `editorial.prod-quote.create` なしで「アクセス権限がありません」表示・ポータル遷移（認可ミドルウェア実装後にintegrationへ昇格）
