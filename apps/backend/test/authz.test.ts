import { SCREEN_MESSAGES } from '@hernes/shared'
import { Hono } from 'hono'
import { describe, expect, it } from 'vitest'
import { hasPermission, requirePermission } from '../src/middleware/authz'
import type { AuthContext } from '../src/middleware/clerk-auth'

const PERM = 'editorial.prod-quote.create'

function appWith(auth: AuthContext) {
  const a = new Hono<{ Variables: { auth: AuthContext } }>()
  a.use('*', async (c, next) => {
    c.set('auth', auth)
    await next()
  })
  a.use('*', requirePermission(PERM))
  a.get('/', (c) => c.json({ ok: true }))
  return a
}

describe('認可 requirePermission（SEC-001 / AC-006）', () => {
  it('権限なしは 403 +「アクセス権限がありません」+ ポータル誘導', async () => {
    const res = await appWith({ userId: 'u', permissions: [] }).request('/')
    expect(res.status).toBe(403)
    const json = (await res.json()) as { message: string; redirectTo: string }
    expect(json.message).toBe(SCREEN_MESSAGES.AUTH_FORBIDDEN)
    expect(json.redirectTo).toBe('/portal')
  })

  it('権限ありは通過する', async () => {
    const res = await appWith({ userId: 'u', permissions: [PERM] }).request('/')
    expect(res.status).toBe(200)
  })
})

describe('hasPermission', () => {
  it('権限の有無を判定する', () => {
    expect(hasPermission({ userId: 'u', permissions: [PERM] }, PERM)).toBe(true)
    expect(hasPermission({ userId: 'u', permissions: [] }, PERM)).toBe(false)
    expect(hasPermission(undefined, PERM)).toBe(false)
  })
})
