/**
 * Backend API クライアント。
 * - ベースURLは build 時注入の VITE_API_BASE_URL。
 * - 認証はバックエンド(Hono)へ Clerk セッショントークンを Bearer で渡す。
 * - 機密は持たない（VITE_* は公開バンドルに入る）。
 */
const BASE_URL = import.meta.env.VITE_API_BASE_URL ?? ''

export async function apiFetch(
  path: string,
  token: string | null,
  init: RequestInit = {},
): Promise<Response> {
  const headers = new Headers(init.headers)
  if (token) {
    headers.set('Authorization', `Bearer ${token}`)
  }
  if (!headers.has('content-type') && init.body) {
    headers.set('content-type', 'application/json')
  }
  return fetch(`${BASE_URL}${path}`, { ...init, headers })
}
