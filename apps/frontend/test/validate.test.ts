import { FIELD_MESSAGES } from '@hernes/shared'
import { describe, expect, it } from 'vitest'
import { validateProdQuoteSearch } from '../src/features/prod-quote/validate'

describe('検索フォームのクライアント側バリデーション', () => {
  it('AC: 正常な条件は ok=true', () => {
    const r = validateProdQuoteSearch({ status: '00' })
    expect(r.ok).toBe(true)
  })

  it('AC: 見積書Noが11桁超なら設計書通りのメッセージを返す', () => {
    const r = validateProdQuoteSearch({ status: '00', quotNo: '123456789012' })
    expect(r.ok).toBe(false)
    if (!r.ok) {
      expect(r.errors.quotNo).toContain(FIELD_MESSAGES.QUOT_NO_MAX_LEN)
    }
  })
})
