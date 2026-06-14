import { describe, expect, it } from 'vitest'
import {
  type TraceabilityParse,
  buildSpecGraph,
  evaluateFeature,
  parseTraceability,
} from '../src/spec-graph'
import type { AcceptanceCondition, SpecFeature } from '../src/types'

function cond(p: Partial<AcceptanceCondition>): AcceptanceCondition {
  return {
    id: 'AC-001',
    requirementRef: 'FR-001',
    priority: 'MUST',
    layer: 'unit',
    proof: '',
    ...p,
  }
}
function parse(
  conditions: AcceptanceCondition[],
  extra: Partial<TraceabilityParse> = {},
): TraceabilityParse {
  return { conditions, headerCount: 1, defects: [], ...extra }
}
function feature(requirements: string[], conditions: AcceptanceCondition[]): SpecFeature {
  return { id: 'FX', requirements, conditions }
}
function codes(vs: { code: string }[]): string[] {
  return vs.map((v) => v.code)
}

describe('parseTraceability', () => {
  it('単一表を解析する', () => {
    const md = [
      '| 条件ID | 要件/項目No | 優先度 | テスト階層 | 実テスト |',
      '|---|---|---|---|---|',
      '| AC-001 | FR-002 | MUST | unit | `packages/shared/test/validation.test.ts` |',
      '| AC-002 | SEC-001 | MUST | 手動/未実装 | — |',
    ].join('\n')
    const r = parseTraceability(md)
    expect(r.conditions).toHaveLength(2)
    expect(r.headerCount).toBe(1)
    expect(r.defects).toEqual([])
    expect(r.conditions[0].proof).toContain('validation.test.ts')
  })

  it('複数表にまたがる AC をすべて拾う（break しない）', () => {
    const md = [
      '| 条件ID | 要件 | 優先度 | テスト階層 | 実テスト |',
      '|---|---|---|---|---|',
      '| AC-001 | FR-001 | MUST | unit | `a.test.ts` |',
      '',
      '## 別ブロック',
      '',
      '| 条件ID | 要件 | 優先度 | テスト階層 | 実テスト |',
      '|---|---|---|---|---|',
      '| AC-002 | FR-002 | MUST | unit | `b.test.ts` |',
    ].join('\n')
    const r = parseTraceability(md)
    expect(r.conditions.map((c) => c.id)).toEqual(['AC-001', 'AC-002'])
    expect(r.headerCount).toBe(2)
  })

  it('ヘッダの表記揺れ（全角スペース）でも解析できる', () => {
    const md = [
      '| 条件　ID | 要件 | 優先度 | テスト階層 | 実テスト |',
      '|---|---|---|---|---|',
      '| AC-001 | FR-001 | MUST | unit | `a.test.ts` |',
    ].join('\n')
    expect(parseTraceability(md).conditions).toHaveLength(1)
  })

  it('必須列が欠けたら defect を返す（fail-closed の材料）', () => {
    const md = [
      '| 条件ID | 要件 | 優先度 | テスト階層 |',
      '|---|---|---|---|',
      '| AC-001 | FR-001 | MUST | unit |',
    ].join('\n')
    const r = parseTraceability(md)
    expect(r.defects).toHaveLength(1)
    expect(r.defects[0].message).toContain('実テスト')
  })
})

describe('evaluateFeature', () => {
  it('プローズだけの proof（例: shared）の MUST 条件は未証明として error', () => {
    const c = cond({ proof: 'shared', priority: 'MUST', layer: 'unit' })
    const vs = evaluateFeature(feature(['FR-001'], [c]), parse([c]), () => true)
    expect(codes(vs)).toContain('SPEC_MUST_UNPROVEN')
  })

  it('実在するテストパス proof の MUST 条件は通る', () => {
    const c = cond({ proof: '`a.test.ts`', priority: 'MUST', requirementRef: 'FR-001' })
    const vs = evaluateFeature(feature(['FR-001'], [c]), parse([c]), (p) => p === 'a.test.ts')
    expect(codes(vs)).not.toContain('SPEC_MUST_UNPROVEN')
    expect(codes(vs)).not.toContain('SPEC_BROKEN_PROOF')
  })

  it('存在しないテストパスは SPEC_BROKEN_PROOF', () => {
    const c = cond({ proof: '`missing.test.ts`', requirementRef: 'FR-001' })
    const vs = evaluateFeature(feature(['FR-001'], [c]), parse([c]), () => false)
    expect(codes(vs)).toContain('SPEC_BROKEN_PROOF')
  })

  it('手動条件は MUST でも未証明にしない', () => {
    const c = cond({ proof: '—', priority: 'MUST', layer: '手動/未実装' })
    const vs = evaluateFeature(feature(['FR-001'], [c]), parse([c]), () => true)
    expect(codes(vs)).not.toContain('SPEC_MUST_UNPROVEN')
  })

  it('spec に無い要件を参照したら SPEC_DANGLING_REQUIREMENT', () => {
    const c = cond({ requirementRef: 'FR-999', proof: '`a.test.ts`' })
    const vs = evaluateFeature(feature(['FR-001'], [c]), parse([c]), () => true)
    expect(codes(vs)).toContain('SPEC_DANGLING_REQUIREMENT')
  })

  it('要件があるのに表が無いと fail-closed（SPEC_NO_TRACEABILITY）', () => {
    const vs = evaluateFeature(feature(['FR-001'], []), parse([], { headerCount: 0 }), () => true)
    expect(codes(vs)).toContain('SPEC_NO_TRACEABILITY')
  })

  it('未カバー要件は warn（非ブロッキング）', () => {
    const c = cond({ requirementRef: 'FR-001', proof: '`a.test.ts`' })
    const vs = evaluateFeature(feature(['FR-001', 'FR-002'], [c]), parse([c]), () => true)
    const uncovered = vs.find((v) => v.code === 'SPEC_UNCOVERED_REQUIREMENT')
    expect(uncovered?.severity).toBe('warn')
    expect(uncovered?.subject).toContain('FR-002')
  })
})

describe('buildSpecGraph（実 specs）', () => {
  it('既存 spec に error が無く feature を検出する', () => {
    const g = buildSpecGraph()
    expect(g.violations.filter((v) => v.severity === 'error')).toEqual([])
    expect(g.features.length).toBeGreaterThan(0)
  })
})
