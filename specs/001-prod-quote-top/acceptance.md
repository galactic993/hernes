# 受け入れ条件 — 制作見積書作成<トップ画面>

## トレーサビリティ・マトリクス

| 条件ID | 要件/項目No | 優先度 | テスト階層 | 実テスト |
|---|---|---|---|---|
| AC-001 | FR-002 / 項目No.1 | MUST | unit | `packages/shared/test/validation.test.ts` |
| AC-002 | FR-002 / 項目No.2 | MUST | unit + integration | shared + `apps/frontend/test/validate.test.ts` |
| AC-003 | FR-002 / 項目No.1 | MUST | unit | `packages/shared/test/validation.test.ts` |
| AC-004 | FR-004 / 項目No.16 | MUST | unit | `packages/shared/test/validation.test.ts` |
| AC-005 | FR-002 / メッセージNo.3,6 | MUST | integration | `apps/backend/test/prod-quotes.test.ts` |
| AC-006 | SEC-001 / メッセージNo.1 | MUST | integration | `apps/backend/test/authz.test.ts` |
| AC-007 | FR-001 | MUST | integration | `apps/backend/test/prod-quot-repository.test.ts` |
| AC-008 | FR-003 | MUST | component | `apps/frontend/test/prod-quote-ui.test.tsx` |
| AC-009 | FR-005 | MUST | component | `apps/frontend/test/prod-quote-ui.test.tsx` |
| AC-010 | NFR-001 | MUST | integration | `apps/backend/test/prod-quotes.test.ts` |

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

### AC-007 初期表示で未着手一覧を取得（FR-001 / Phase3 T011 未実装）
- Given ログイン済みユーザーがトップ画面を開く
- When 初期表示
- Then 所属センター主管の未着手の制作見積が一覧表示される（実DB問い合わせは未実装）

### AC-008 一覧行から詳細/作成へ遷移（FR-003 / Phase3 UI 未実装）
- Given 一覧に行がある
- When 見積書No・選択を押す
- Then 詳細/作成へ遷移する

### AC-009 見積情報・制作見積内容の詳細モーダル（FR-005 / Phase3 UI 未実装）
- Given 一覧行
- When 詳細を開く
- Then モーダルで詳細が表示される

### AC-010 検索フローは観測可能・個人情報を出さない（NFR-001）
- Given `POST /api/prod-quotes/search`
- When 検索を実行
- Then 実行ログ（件数）を出力し観測可能にする。検索結果レコードの中身（個人情報）はログに出さない（実装: 件数のみ構造化ログ）

## 却下条件
- 個人情報（検索結果の中身）をログ出力したら不合格（SEC / 憲法5）
- 権限チェックを経ずに他センターの制作見積が取得できたら不合格

## 補足（実装層と残課題）
- AC-008 / AC-009 はコンポーネントテスト(component)で証明。**ブラウザ e2e（画面間遷移）は Playwright で後続**（`e2e/`）。
- AC-007（補足）: データ取得（未着手・検索）は integration 証明済み。「所属センター主管」絞り込みは
  quots/センターのモデル（本テンプレ未同梱）が必要で Phase3(T011)。実 DB 配線は `drizzleProdQuotRepository` に差し替え。
