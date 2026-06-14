import type { ProdQuot } from '@hernes/db'

/**
 * 制作見積リポジトリ（FR-001 取得 / FR-002 検索）。
 * 実装を差し替え可能にし、ルートを実DBから独立してテストできるようにする（ヘキサゴナル）。
 */
export interface ProdQuotSearchCriteria {
  status?: string
  quotNo?: string
  customerCode?: string
}

export interface ProdQuotRepository {
  // FR-001: 未着手(status='00')の制作見積を取得する。
  // NOTE: 「所属センター主管」での絞り込みは quots/センターのモデル（本テンプレ未同梱）が必要。Phase3(T011)。
  findUnstarted(): Promise<ProdQuot[]>
  // FR-002: 条件（ステータス等）で検索する。
  search(criteria: ProdQuotSearchCriteria): Promise<ProdQuot[]>
}

const STATUS_UNSTARTED = '00'

// テンプレ既定のインメモリ実装（seed 注入でテスト可能）。
export function inMemoryProdQuotRepository(seed: ProdQuot[] = []): ProdQuotRepository {
  return {
    async findUnstarted() {
      return seed.filter((q) => q.prodQuotStatus === STATUS_UNSTARTED)
    },
    async search(criteria) {
      return seed.filter((q) => !criteria.status || q.prodQuotStatus === criteria.status)
    },
  }
}

// 実 DB 実装（Drizzle）の配線ポイント:
//   import { schema } from '@hernes/db'
//   export function drizzleProdQuotRepository(db): ProdQuotRepository {
//     return {
//       findUnstarted: () => db.select().from(schema.prodQuots).where(eq(schema.prodQuots.prodQuotStatus, '00')),
//       search: (c) => db.select().from(schema.prodQuots).where(/* criteria + センター join */),
//     }
//   }
