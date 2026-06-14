import { Hono } from 'hono'
import { cors } from 'hono/cors'
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

// 公開API
app.route('/api/prod-quotes', prodQuotesRoute)

// 認証必須API（Clerk トークン検証）
const me = new Hono<{ Variables: { auth: AuthContext } }>()
me.use(clerkAuth)
me.get('/', (c) => c.json({ auth: c.get('auth') }))
app.route('/api/me', me)

export type AppType = typeof app
