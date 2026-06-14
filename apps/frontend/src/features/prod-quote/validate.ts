import { prodQuoteSearchSchema } from '@hernes/shared'

/**
 * クライアント側の検索条件バリデーション。
 * 画面設計書「項目記述書」制御区分=JavaScript に相当。
 * サーバ(PHP→Hono)と同じ @hernes/shared スキーマを使い、二重定義しない。
 */
export function validateProdQuoteSearch(input: unknown) {
  const r = prodQuoteSearchSchema.safeParse(input)
  if (r.success) {
    return { ok: true as const, value: r.data }
  }
  return { ok: false as const, errors: r.error.flatten().fieldErrors }
}
