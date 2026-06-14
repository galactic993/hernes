/**
 * メッセージカタログ。
 * 出典: 02-02_2_編-制作見積-制作見積書作成トップ_画面設計書「メッセージ一覧」シート。
 * 画面表示するメッセージは必ずここを単一の出典とし、コードに直書きしない。
 */
export const SCREEN_MESSAGES = {
  // No.1 権限判定(画面遷移時) - 権限なし
  AUTH_FORBIDDEN: 'アクセス権限がありません',
  // No.2 制作見積情報取得(初期表示) - 応答なし
  INIT_FETCH_NO_RESPONSE: '制作見積情報の取得に失敗しました。時間を空けて再度お試しください',
  // No.3 制作見積情報検索 - 値不正
  SEARCH_INVALID_INPUT: '入力内容に誤りがあります。各項目をご確認ください',
  // No.4 制作見積情報検索 - POST値不正
  SEARCH_POST_INVALID: '制作見積情報の検索に失敗しました',
  // No.5 制作見積情報検索 - 応答なし
  SEARCH_NO_RESPONSE: '制作見積情報の検索に失敗しました。時間を空けて再度お試しください',
  // No.6 制作見積情報検索 - 検索結果なし（区分: サクセス）
  SEARCH_NO_RESULT: '該当する制作見積情報が見つかりません',
  // No.7 得意先検索 - 値不正
  CUSTOMER_SEARCH_INVALID_INPUT: '入力内容に誤りがあります。各項目をご確認ください',
  // No.10 得意先選択 - 値不正
  CUSTOMER_SELECT_REQUIRED: '得意先を選択してください',
} as const

export type ScreenMessageKey = keyof typeof SCREEN_MESSAGES

/**
 * 項目記述書（制御内容→メッセージ）由来の入力エラーメッセージ。
 * 出典: 同画面設計書「項目記述書」シートの「メッセージ」列。
 */
export const FIELD_MESSAGES = {
  // No.1 ステータス: ・必須(初期値あり)
  STATUS_REQUIRED: 'ステータスは入力必須です',
  // No.1 ステータス: ・有効な値のみ
  STATUS_INVALID: '有効な値を選択してください',
  // No.2 見積書No: ・11桁以内
  QUOT_NO_MAX_LEN: '11桁以内で入力してください',
  // No.16 得意先コード: ・半角数字のみ
  CUSTOMER_CODE_DIGITS_ONLY: '半角数字で入力してください',
  // No.16 得意先コード: ・5桁以内
  CUSTOMER_CODE_MAX_LEN: '5桁以内で入力してください',
  // No.20 得意先選択: ・必須
  CUSTOMER_REQUIRED: '得意先を選択してください',
} as const

export type FieldMessageKey = keyof typeof FIELD_MESSAGES
