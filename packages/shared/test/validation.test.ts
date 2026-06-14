import { describe, expect, it } from 'vitest'
import { FIELD_MESSAGES, customerSearchSchema, prodQuoteSearchSchema } from '../src/index'

/**
 * 「設計書 → テスト」のトレーサビリティ実例。
 * 各 it は 画面設計書「項目記述書」の制御内容とメッセージに 1:1 で対応する。
 */
describe('制作見積情報検索フォーム (項目記述書 No.1,2)', () => {
  it('AC: 正常な検索条件は通る (status=00)', () => {
    const r = prodQuoteSearchSchema.safeParse({ status: '00' })
    expect(r.success).toBe(true)
  })

  it('AC: 見積書Noが11桁超ならエラー（・11桁以内）', () => {
    const r = prodQuoteSearchSchema.safeParse({ status: '00', quotNo: '123456789012' })
    expect(r.success).toBe(false)
    if (!r.success) {
      expect(r.error.issues[0]?.message).toBe(FIELD_MESSAGES.QUOT_NO_MAX_LEN)
    }
  })

  it('AC: ステータスが有効値以外ならエラー（・有効な値のみ）', () => {
    const r = prodQuoteSearchSchema.safeParse({ status: '99' })
    expect(r.success).toBe(false)
    if (!r.success) {
      expect(r.error.issues[0]?.message).toBe(FIELD_MESSAGES.STATUS_INVALID)
    }
  })
})

describe('得意先選択モーダル (項目記述書 No.16)', () => {
  it('AC: 得意先コードが半角数字以外ならエラー（・半角数字のみ）', () => {
    const r = customerSearchSchema.safeParse({ customerCode: 'abc' })
    expect(r.success).toBe(false)
    if (!r.success) {
      expect(r.error.issues[0]?.message).toBe(FIELD_MESSAGES.CUSTOMER_CODE_DIGITS_ONLY)
    }
  })

  it('AC: 得意先コードが5桁超ならエラー（・5桁以内）', () => {
    const r = customerSearchSchema.safeParse({ customerCode: '123456' })
    expect(r.success).toBe(false)
    if (!r.success) {
      expect(r.error.issues[0]?.message).toBe(FIELD_MESSAGES.CUSTOMER_CODE_MAX_LEN)
    }
  })

  it('AC: 5桁の半角数字は通る', () => {
    const r = customerSearchSchema.safeParse({ customerCode: '12345' })
    expect(r.success).toBe(true)
  })
})
