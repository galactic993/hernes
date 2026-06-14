import { describe, expect, it } from 'vitest'
import { govern } from '../src/govern'

describe('統治ゲート全体（govern）', () => {
  it('現リポジトリは統治ゲートを通過する（error ゼロ＝書かれている＝効いている）', async () => {
    const r = await govern()
    if (!r.ok) {
      // 失敗時に原因を出す（デバッグ容易性 / 憲法 C4）
      for (const e of r.errors) process.stderr.write(`${e.code} ${e.message}\n`)
    }
    expect(r.errors).toEqual([])
    expect(r.ok).toBe(true)
  })

  it('三権（立法/司法）と憲法が登録されている', async () => {
    const r = await govern()
    expect(r.counts.constitution).toBeGreaterThanOrEqual(6)
    expect(r.counts.rules).toBeGreaterThanOrEqual(6)
    expect(r.counts.checks).toBeGreaterThanOrEqual(6)
  })
})
