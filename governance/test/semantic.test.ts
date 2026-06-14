import { afterEach, describe, expect, it, vi } from 'vitest'
import { loadSemanticSpecs, parseVerdict, runSemanticChecks } from '../src/semantic'

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
    expect(r.violations.map((v) => v.code)).toContain('SEMANTIC_NO_EVALUATOR')
    expect(r.violations.every((v) => v.severity === 'warn')).toBe(true)
  })

  it('評価器が fail を返すと SEMANTIC_FAIL(warn) を出す（非ブロッキング）', () => {
    vi.stubEnv('GOVERN_SEMANTIC', '1')
    const executor = () => 'analysis...\n{"verdict":"fail","reason":"ユーザー価値が不明"}'
    const r = runSemanticChecks({ executor })
    const fails = r.violations.filter((v) => v.code === 'SEMANTIC_FAIL')
    expect(fails.length).toBeGreaterThanOrEqual(1)
    expect(fails.every((v) => v.severity === 'warn')).toBe(true)
    expect(fails[0].message).toContain('ユーザー価値が不明')
  })

  it('評価器が pass を返すと違反ゼロ', () => {
    vi.stubEnv('GOVERN_SEMANTIC', '1')
    const r = runSemanticChecks({ executor: () => '{"verdict":"pass","reason":"ok"}' })
    expect(r.violations).toEqual([])
  })

  it('評価器が例外を投げると SEMANTIC_ERROR(warn) を出す', () => {
    vi.stubEnv('GOVERN_SEMANTIC', '1')
    const r = runSemanticChecks({
      executor: () => {
        throw new Error('timeout')
      },
    })
    expect(r.violations.map((v) => v.code)).toContain('SEMANTIC_ERROR')
    expect(r.violations.every((v) => v.severity === 'warn')).toBe(true)
  })
})

describe('parseVerdict', () => {
  it('末尾の JSON verdict を取り出す', () => {
    expect(parseVerdict('foo\n{"verdict":"fail","reason":"x"}').verdict).toBe('fail')
  })
  it('verdict が無ければ unknown', () => {
    expect(parseVerdict('no json here').verdict).toBe('unknown')
  })
  it('壊れた JSON は unknown', () => {
    expect(parseVerdict('{"verdict":"fail" reason}').verdict).toBe('unknown')
  })
})
