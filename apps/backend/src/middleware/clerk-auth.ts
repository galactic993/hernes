import { createMiddleware } from 'hono/factory'
import { type JWTPayload, createRemoteJWKSet, jwtVerify } from 'jose'

/**
 * Clerk セッショントークン検証ミドルウェア（Java版 ClerkAuthenticationFilter の Hono/TS 翻案）。
 *
 * - Authorization: Bearer <token>、無ければ Cookie `__session` を読む。
 * - Clerk の JWKS で署名検証し、issuer・authorized parties(azp) を検証する。
 * - 検証後 userId / sessionId / orgId を Variables.auth に載せる。
 * - 機密(CLERK_SECRET_KEY)はトークン検証には不要。JWKS 公開鍵のみで検証する。
 */
export type AuthContext = {
  userId: string
  sessionId?: string
  orgId?: string
}

type Env = { Variables: { auth: AuthContext } }

let jwksCache: ReturnType<typeof createRemoteJWKSet> | null = null

function getJwks() {
  const url = process.env.CLERK_JWKS_URL
  if (!url) {
    throw new Error('CLERK_JWKS_URL is not set')
  }
  if (!jwksCache) {
    jwksCache = createRemoteJWKSet(new URL(url))
  }
  return jwksCache
}

function authorizedParties(): string[] {
  return (process.env.CLERK_AUTHORIZED_PARTIES ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)
}

export const clerkAuth = createMiddleware<Env>(async (c, next) => {
  const authz = c.req.header('authorization')
  const fromHeader = authz?.startsWith('Bearer ') ? authz.slice('Bearer '.length) : null
  const cookie = c.req.header('cookie') ?? ''
  const sessionMatch = cookie.match(/(?:^|;\s*)__session=([^;]+)/)
  const token = fromHeader ?? (sessionMatch?.[1] ? decodeURIComponent(sessionMatch[1]) : null)

  if (!token) {
    return c.json({ message: 'Unauthorized' }, 401)
  }

  let payload: JWTPayload
  try {
    const verified = await jwtVerify(token, getJwks(), {
      issuer: process.env.CLERK_ISSUER,
    })
    payload = verified.payload
  } catch {
    return c.json({ message: 'Unauthorized' }, 401)
  }

  // authorized parties (azp) チェック
  const allowed = authorizedParties()
  const azp = typeof payload.azp === 'string' ? payload.azp : undefined
  if (allowed.length > 0 && azp !== undefined && !allowed.includes(azp)) {
    return c.json({ message: 'Forbidden: azp not allowed' }, 403)
  }

  c.set('auth', {
    userId: String(payload.sub ?? ''),
    sessionId: typeof payload.sid === 'string' ? payload.sid : undefined,
    orgId: typeof payload.org_id === 'string' ? payload.org_id : undefined,
  })

  await next()
})
