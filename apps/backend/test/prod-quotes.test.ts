import { SCREEN_MESSAGES } from '@hernes/shared'
import { afterEach, describe, expect, it, vi } from 'vitest'
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

describe('NFR-001: 検索フローの観測可能性（個人情報を出さない）', () => {
  afterEach(() => {
    vi.restoreAllMocks()
  })

  it('AC-010: 検索実行を件数付きでログし、結果レコードの中身は出さない', async () => {
    const spy = vi.spyOn(console, 'info').mockImplementation(() => {})
    const res = await app.request('/api/prod-quotes/search', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ status: '00' }),
    })
    expect(res.status).toBe(200)
    expect(spy).toHaveBeenCalled()
    const [message, payload] = spy.mock.calls[0]
    expect(String(message)).toContain('search')
    expect(payload).toMatchObject({ count: expect.any(Number) })
    // 結果レコード配列そのものをログに渡していない（個人情報の非出力）
    expect(JSON.stringify(spy.mock.calls)).not.toContain('"items"')
  })
})
