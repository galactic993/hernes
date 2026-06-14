import type { ProdQuot } from '@hernes/db'
import { SCREEN_MESSAGES, prodQuoteSearchSchema } from '@hernes/shared'
import { Hono } from 'hono'

export const prodQuotesRoute = new Hono()

/**
 * 制作見積情報検索（イベント記述書 EVENT0009「検索」ボタン押下時）。
 * バリデーション・メッセージは @hernes/shared（= 画面設計書 由来）を単一の出典とする。
 */
prodQuotesRoute.post('/search', async (c) => {
  const body = await c.req.json().catch(() => null)
  const parsed = prodQuoteSearchSchema.safeParse(body)

  if (!parsed.success) {
    // メッセージ一覧 No.3「制作見積情報検索 - 値不正」
    return c.json(
      { message: SCREEN_MESSAGES.SEARCH_INVALID_INPUT, errors: parsed.error.flatten() },
      400,
    )
  }

  // TODO(impl): @hernes/db の prodQuots を検索する。テンプレではスタブ。
  const items: ProdQuot[] = []

  if (items.length === 0) {
    // メッセージ一覧 No.6「制作見積情報検索 - 検索結果なし」（区分: サクセス）
    return c.json({ items, message: SCREEN_MESSAGES.SEARCH_NO_RESULT })
  }

  return c.json({ items })
})
