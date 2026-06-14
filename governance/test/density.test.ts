import { describe, expect, it } from 'vitest'
import { computeExecutionDensity } from '../src/density'

describe('computeExecutionDensity（AI 実行密度）', () => {
  it('1人あたり token × PR を計算する', () => {
    const r = computeExecutionDensity([{ team: 'a', users: 10, tokens: 1000, prs: 100 }])
    expect(r.teams[0].tokensPerUser).toBe(100)
    expect(r.teams[0].prsPerUser).toBe(10)
    expect(r.teams[0].executionDensity).toBe(1000)
  })

  it('桁違いに突出したチームを HOTL に分類する', () => {
    const r = computeExecutionDensity([
      { team: 'hotl', users: 5, tokens: 5_000_000_000, prs: 500 },
      { team: 'a', users: 10, tokens: 1_000_000, prs: 50 },
      { team: 'b', users: 10, tokens: 1_200_000, prs: 60 },
      { team: 'c', users: 10, tokens: 900_000, prs: 40 },
    ])
    expect(r.hotl).toContain('hotl')
    expect(r.hotl).not.toContain('a')
  })

  it('users=0 を安全に扱う', () => {
    const r = computeExecutionDensity([{ team: 'x', users: 0, tokens: 100, prs: 10 }])
    expect(r.teams[0].executionDensity).toBe(0)
  })
})
