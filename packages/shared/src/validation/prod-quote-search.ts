import { z } from 'zod'
import { FIELD_MESSAGES } from '../messages'
import { PROD_QUOTE_STATUS_CODES } from '../status'

/**
 * 制作見積情報検索フォームの入力スキーマ。
 * 出典: 画面設計書「項目記述書」No.1,2,3,5,6（EVENT0002,0003,0004,0006,0007）。
 * 制御内容（必須・桁数・有効値）とメッセージを zod に1対1で写経している。
 * フロント(React)・バックエンド(Hono)双方がこの単一スキーマを使う。
 */
export const prodQuoteSearchSchema = z.object({
  // No.1 ステータス: ・必須(初期値あり) / ・有効な値のみ
  status: z.enum(PROD_QUOTE_STATUS_CODES, {
    errorMap: (issue) => ({
      message:
        issue.code === 'invalid_type'
          ? FIELD_MESSAGES.STATUS_REQUIRED
          : FIELD_MESSAGES.STATUS_INVALID,
    }),
  }),
  // No.2 見積書No: ・任意 / ・11桁以内
  quotNo: z.string().max(11, FIELD_MESSAGES.QUOT_NO_MAX_LEN).optional(),
  // No.3 得意先: ・任意
  customer: z.string().optional(),
  // No.5 見積件名: ・任意
  quotTitle: z.string().optional(),
  // No.6 品名: ・任意
  productName: z.string().optional(),
})

export type ProdQuoteSearchInput = z.infer<typeof prodQuoteSearchSchema>

/**
 * 得意先選択モーダルの入力スキーマ。
 * 出典: 画面設計書「項目記述書」No.16,17（EVENT0012,0013）。
 */
export const customerSearchSchema = z.object({
  // No.16 得意先コード: ・任意 / ・半角数字のみ / ・5桁以内
  customerCode: z
    .string()
    .regex(/^[0-9]*$/, FIELD_MESSAGES.CUSTOMER_CODE_DIGITS_ONLY)
    .max(5, FIELD_MESSAGES.CUSTOMER_CODE_MAX_LEN)
    .optional(),
  // No.17 得意先名: ・任意
  customerName: z.string().optional(),
})

export type CustomerSearchInput = z.infer<typeof customerSearchSchema>
