import { SCREEN_MESSAGES } from '@hernes/shared'
import { createMiddleware } from 'hono/factory'
import type { AuthContext } from './clerk-auth'

/**
 * 認可（権限）チェック。SEC-001: 権限が無ければ「アクセス権限がありません」を表示しポータルへ。
 * 認証(clerkAuth)で載った auth.permissions（Clerk の org_permissions）を判定する。
 */
export function hasPermission(auth: AuthContext | undefined, permission: string): boolean {
  return auth?.permissions?.includes(permission) ?? false
}

export function requirePermission(permission: string) {
  return createMiddleware<{ Variables: { auth: AuthContext } }>(async (c, next) => {
    if (!hasPermission(c.get('auth'), permission)) {
      // メッセージ一覧 No.1「権限なし」。FE はこの redirectTo でポータルへ遷移する。
      return c.json({ message: SCREEN_MESSAGES.AUTH_FORBIDDEN, redirectTo: '/portal' }, 403)
    }
    await next()
  })
}
