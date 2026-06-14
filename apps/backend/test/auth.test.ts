import { describe, expect, it } from 'vitest'
import { app } from '../src/app'

describe('Clerk 認証ミドルウェア', () => {
  it('保護API /api/me はトークン無しで401', async () => {
    const res = await app.request('/api/me')
    expect(res.status).toBe(401)
  })

  it('保護API は不正な Bearer トークンで401', async () => {
    const res = await app.request('/api/me', {
      headers: { authorization: 'Bearer not-a-real-token' },
    })
    expect(res.status).toBe(401)
  })

  it('/healthz は公開で200', async () => {
    const res = await app.request('/healthz')
    expect(res.status).toBe(200)
  })
})
