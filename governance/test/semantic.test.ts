import { afterEach, describe, expect, it, vi } from 'vitest'
import { loadSemanticSpecs, runSemanticChecks } from '../src/semantic'

describe('意味(LLM)司法の配線', () => {
  afterEach(() => {
    vi.unstubAllEnvs()
  })

  it('checks/semantic/*.md を登録として読み込む', () => {
    const ids = loadSemanticSpecs().map((s) => s.id)
    expect(ids).toContain('user-value-alignment')
    expect(ids).toContain('pii-in-logs')
  })

  it('既定では skip（CI 非ブロッキング・違反ゼロ）', () => {
    vi.stubEnv('GOVERN_SEMANTIC', '')
    const r = runSemanticChecks()
    expect(r.enabled).toBe(false)
    expect(r.violations).toEqual([])
    expect(r.registered).toBeGreaterThanOrEqual(2)
  })

  it('有効化したが評価器(AGENT_CMD)が無いと warn（ブロックしない）', () => {
    vi.stubEnv('GOVERN_SEMANTIC', '1')
    vi.stubEnv('AGENT_CMD', '')
    const r = runSemanticChecks()
    expect(r.enabled).toBe(true)
    expect(r.violations.every((v) => v.severity === 'warn')).toBe(true)
    expect(r.violations.map((v) => v.code)).toContain('SEMANTIC_NO_EVALUATOR')
  })
})
