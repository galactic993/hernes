import type { ProdQuot } from '@hernes/db'
import { describe, expect, it } from 'vitest'
import { inMemoryProdQuotRepository } from '../src/repositories/prod-quot-repository'

function quot(p: Partial<ProdQuot>): ProdQuot {
  return {
    prodQuotId: 1n,
    quotId: 1n,
    cost: '1000',
    quotDocPath: null,
    referenceDocPath: null,
    submissionOn: null,
    prodQuotStatus: '00',
    version: 1,
    createdAt: new Date(),
    updatedAt: new Date(),
    ...p,
  }
}

describe('inMemoryProdQuotRepository（FR-001 / FR-002 / AC-007）', () => {
  const seed = [
    quot({ prodQuotId: 1n, prodQuotStatus: '00' }),
    quot({ prodQuotId: 2n, prodQuotStatus: '10' }),
    quot({ prodQuotId: 3n, prodQuotStatus: '00' }),
  ]

  it('FR-001: findUnstarted は未着手(00)のみ返す', async () => {
    const repo = inMemoryProdQuotRepository(seed)
    expect((await repo.findUnstarted()).map((q) => q.prodQuotId)).toEqual([1n, 3n])
  })

  it('FR-002: search はステータスで絞る', async () => {
    const repo = inMemoryProdQuotRepository(seed)
    expect((await repo.search({ status: '10' })).map((q) => q.prodQuotId)).toEqual([2n])
  })

  it('空リポジトリは空配列を返す', async () => {
    expect(await inMemoryProdQuotRepository().findUnstarted()).toEqual([])
  })
})
