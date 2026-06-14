import { describe, expect, it } from 'vitest'
import { buildAuthorityGraph } from '../src/authority-graph'
import type { CheckMeta, Constitution, Jurisdiction, Rule } from '../src/types'
import { inJurisdiction } from '../src/util'

const constitution: Constitution = {
  version: 1,
  title: 't',
  amendableBy: 'human-only',
  principles: [{ id: 'C1', name: 'a', statement: 's' }],
}

// 決定的なファイル集合で管轄を評価する（実リポジトリに依存しない）。
const FILES = ['apps/a.ts', 'apps/legacy/b.ts', 'packages/p.ts', 'specs/s.md']
const resolver = (jur: Jurisdiction): string[] => FILES.filter((f) => inJurisdiction(f, jur))

function rule(p: Partial<Rule>): Rule {
  return {
    id: 'R',
    title: 't',
    constitution: ['C1'],
    statement: 's',
    severity: 'error',
    status: 'active',
    jurisdiction: { include: ['apps/**'] },
    checks: [],
    ...p,
  }
}

function checkMeta(p: Partial<CheckMeta>): CheckMeta {
  return {
    id: 'chk',
    kind: 'deterministic',
    title: 't',
    jurisdiction: { include: ['apps/**'] },
    ...p,
  }
}

describe('Authority Provenance Graph', () => {
  it('②司法なき立法: error ルールに司法が無いと検知する', () => {
    const g = buildAuthorityGraph(constitution, [rule({ checks: [] })], [], resolver)
    expect(g.violations.map((v) => v.code)).toContain('LEGISLATION_WITHOUT_JUDICIAL')
  })

  it('①立法なき司法: どのルールにも束縛されない司法を検知する', () => {
    const g = buildAuthorityGraph(
      constitution,
      [rule({ id: 'R1', checks: [{ kind: 'deterministic', id: 'bound' }] })],
      [checkMeta({ id: 'bound' }), checkMeta({ id: 'orphan' })],
      resolver,
    )
    const orphans = g.violations
      .filter((v) => v.code === 'JUDICIAL_WITHOUT_LEGISLATION')
      .map((v) => v.subject)
    expect(orphans).toContain('orphan')
    expect(orphans).not.toContain('bound')
  })

  it('③越境司法: 司法の管轄がルールより広いと検知する', () => {
    const g = buildAuthorityGraph(
      constitution,
      [
        rule({
          id: 'R1',
          jurisdiction: { include: ['apps/**'] },
          checks: [{ kind: 'deterministic', id: 'wide' }],
        }),
      ],
      [checkMeta({ id: 'wide', jurisdiction: { include: ['packages/**'] } })],
      resolver,
    )
    expect(g.violations.map((v) => v.code)).toContain('CROSS_JURISDICTION')
  })

  it('③越境司法: ルールが exclude した下位領域に司法が及ぶと検知する（集合包含）', () => {
    const g = buildAuthorityGraph(
      constitution,
      [
        rule({
          id: 'R1',
          jurisdiction: { include: ['apps/**'], exclude: ['apps/legacy/**'] },
          checks: [{ kind: 'deterministic', id: 'leaky' }],
        }),
      ],
      [checkMeta({ id: 'leaky', jurisdiction: { include: ['apps/**'] } })],
      resolver,
    )
    expect(g.violations.map((v) => v.code)).toContain('CROSS_JURISDICTION')
  })

  it('憲法参照の欠落（存在しない条項）を検知する', () => {
    const g = buildAuthorityGraph(
      constitution,
      [rule({ constitution: ['C9'], checks: [{ kind: 'deterministic', id: 'bound' }] })],
      [checkMeta({ id: 'bound' })],
      resolver,
    )
    expect(g.violations.map((v) => v.code)).toContain('CONSTITUTION_REF_MISSING')
  })

  it('整合した三権（管轄一致）は違反ゼロ', () => {
    const g = buildAuthorityGraph(
      constitution,
      [
        rule({
          id: 'R1',
          jurisdiction: { include: ['apps/**'] },
          checks: [{ kind: 'deterministic', id: 'ok' }],
        }),
      ],
      [checkMeta({ id: 'ok', jurisdiction: { include: ['apps/**'] } })],
      resolver,
    )
    expect(g.violations).toEqual([])
  })
})
