import { SCREEN_MESSAGES, prodQuoteSearchSchema } from '@hernes/shared'
import { Hono } from 'hono'
import {
  type ProdQuotRepository,
  inMemoryProdQuotRepository,
} from '../repositories/prod-quot-repository'

/**
 * 制作見積ルート。リポジトリを注入し、実DBから独立してテスト可能にする。
 * バリデーション・メッセージは @hernes/shared（= 画面設計書 由来）を単一の出典とする。
 */
// prod_quots の id は bigint。JSON はそのままでは bigint を直列化できないため文字列化する。
function toJsonSafe<T>(value: T): unknown {
  return JSON.parse(JSON.stringify(value, (_k, v) => (typeof v === 'bigint' ? v.toString() : v)))
}

export function createProdQuotesRoute(
  repository: ProdQuotRepository = inMemoryProdQuotRepository(),
) {
  const route = new Hono()

  // FR-001: 初期表示（未着手一覧の取得）。「所属センター主管」絞り込みは Phase3(T011)。
  route.get('/', async (c) => {
    const items = await repository.findUnstarted()
    // NFR-001: 件数のみ観測ログ（個人情報は出さない）。
    console.info('prod-quote initial fetch', { count: items.length })
    if (items.length === 0) {
      return c.json({ items, message: SCREEN_MESSAGES.SEARCH_NO_RESULT })
    }
    return c.json({ items: toJsonSafe(items) })
  })

  // FR-002: 制作見積情報検索（EVENT0009）。
  route.post('/search', async (c) => {
    const body = await c.req.json().catch(() => null)
    const parsed = prodQuoteSearchSchema.safeParse(body)
    if (!parsed.success) {
      // メッセージ一覧 No.3「制作見積情報検索 - 値不正」
      return c.json(
        { message: SCREEN_MESSAGES.SEARCH_INVALID_INPUT, errors: parsed.error.flatten() },
        400,
      )
    }

    const items = await repository.search({ status: parsed.data.status })
    // NFR-001: 件数のみ観測ログ（個人情報は出さない）。
    console.info('prod-quote search executed', { count: items.length })

    if (items.length === 0) {
      // メッセージ一覧 No.6「検索結果なし」（区分: サクセス）
      return c.json({ items, message: SCREEN_MESSAGES.SEARCH_NO_RESULT })
    }
    return c.json({ items: toJsonSafe(items) })
  })

  return route
}

// 既定（公開・空リポジトリ）。実 DB 配線時は createProdQuotesRoute(drizzleRepo) に差し替える。
export const prodQuotesRoute = createProdQuotesRoute()
