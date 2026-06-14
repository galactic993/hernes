import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { requirePermission } from './middleware/authz'
import { type AuthContext, clerkAuth } from './middleware/clerk-auth'
import { prodQuotesRoute } from './routes/prod-quotes'

/**
 * CORS は環境ごとの frontend URL のみ許可する（ALLOWED_ORIGINS をカンマ区切りで注入）。
 * `*` + credentials のような危険設定はしない。未設定時はローカル開発のみ許可。
 */
function allowedOrigins(): string[] {
  const fromEnv = (process.env.ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)
  return fromEnv.length > 0 ? fromEnv : ['http://localhost:5173']
}

export const app = new Hono()

app.use('/api/*', cors({ origin: allowedOrigins(), credentials: true }))

app.get('/healthz', (c) => c.text('ok'))

// 公開API（検索・初期表示）
app.route('/api/prod-quotes', prodQuotesRoute)

// 認証必須API（Clerk トークン検証）
const me = new Hono<{ Variables: { auth: AuthContext } }>()
me.use(clerkAuth)
me.get('/', (c) => c.json({ auth: c.get('auth') }))
app.route('/api/me', me)

// 認可必須API（SEC-001: editorial.prod-quote.create が無ければ 403 + ポータル誘導）
const prodQuotesManage = new Hono<{ Variables: { auth: AuthContext } }>()
prodQuotesManage.use(clerkAuth)
prodQuotesManage.use(requirePermission('editorial.prod-quote.create'))
prodQuotesManage.get('/', (c) => c.json({ ok: true, auth: c.get('auth') }))
app.route('/api/prod-quotes/manage', prodQuotesManage)

export type AppType = typeof app
