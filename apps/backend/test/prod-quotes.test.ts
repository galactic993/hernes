import { SCREEN_MESSAGES } from '@hernes/shared'
import { describe, expect, it } from 'vitest'
import { app } from '../src/app'

describe('POST /api/prod-quotes/search', () => {
  it('AC: 不正な検索条件は400 + メッセージ一覧No.3', async () => {
    const res = await app.request('/api/prod-quotes/search', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ status: '99' }),
    })
    expect(res.status).toBe(400)
    const json = (await res.json()) as { message: string }
    expect(json.message).toBe(SCREEN_MESSAGES.SEARCH_INVALID_INPUT)
  })

  it('AC: 正常な検索条件・該当なしは200 + メッセージ一覧No.6', async () => {
    const res = await app.request('/api/prod-quotes/search', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ status: '00' }),
    })
    expect(res.status).toBe(200)
    const json = (await res.json()) as { message: string }
    expect(json.message).toBe(SCREEN_MESSAGES.SEARCH_NO_RESULT)
  })
})
