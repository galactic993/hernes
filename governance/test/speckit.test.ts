import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { buildSpeckitGraph, parseSpeckitSpec, parseSpeckitTasks } from '../src/adapters/speckit'

const FIXTURE = join(dirname(fileURLToPath(import.meta.url)), 'fixtures', 'speckit')

describe('Spec-Kit アダプタ: parseSpeckitSpec', () => {
  it('FR/SC・ユーザーストーリーを抽出する', () => {
    const md = [
      '- **FR-001**: System MUST x',
      '- **SC-001**: under 1s',
      '### User Story 1 - Foo (Priority: P1)',
    ].join('\n')
    const r = parseSpeckitSpec(md)
    expect(r.requirements).toEqual(['FR-001', 'SC-001'])
    expect(r.userStories[0]).toMatchObject({ id: 'US1', priority: 'P1', title: 'Foo' })
  })

  it('コメント/例示ブロック内の [NEEDS CLARIFICATION] は数えない（誤検知防止）', () => {
    const md = [
      '<!-- [NEEDS CLARIFICATION: in comment] -->',
      '*Example of marking unclear requirements:*',
      '',
      '- **FR-006**: example [NEEDS CLARIFICATION: in example]',
      '',
      '### Functional Requirements',
      '- **FR-001**: real [NEEDS CLARIFICATION: genuine]',
    ].join('\n')
    expect(parseSpeckitSpec(md).needsClarification).toBe(1)
  })
})

describe('Spec-Kit アダプタ: parseSpeckitTasks', () => {
  const r = parseSpeckitTasks(
    [
      '- [x] T010 [P] [US1] test in tests/integration/test_x.py',
      '- [ ] T011 [US1] impl in src/services/contest_manager.py',
      '- [ ] T012 [US2] unit in src/__tests__/foo.ts',
      '- [ ] T013 [US1] impl in src/models/[entity].py',
    ].join('\n'),
  )

  it('テストタスクだけを抽出し、完了状態を保持する', () => {
    expect(r.testTasks.map((t) => t.taskId)).toEqual(['T010', 'T012'])
    expect(r.testTasks.find((t) => t.taskId === 'T010')?.done).toBe(true)
  })
  it('test_ の部分一致（contest_manager）を誤ってテスト扱いしない', () => {
    expect(r.testTasks.some((t) => t.filePath.includes('contest_manager'))).toBe(false)
  })
  it('__tests__/ 規約を認識する', () => {
    expect(r.testTasks.find((t) => t.taskId === 'T012')?.filePath).toContain('__tests__')
  })
  it('未置換プレースホルダ（[entity]）を検知する', () => {
    expect(r.hasPlaceholders).toBe(true)
    expect(r.taskCount).toBe(4)
  })
})

describe('Spec-Kit アダプタ: buildSpeckitGraph（fixture）', () => {
  const report = buildSpeckitGraph(FIXTURE)
  const errorCodes = (id: string) =>
    report.violations
      .filter((v) => v.severity === 'error' && v.subject.startsWith(id))
      .map((v) => v.code)

  it('.specify/memory/constitution.md の原則を読む', () => {
    expect(report.constitutionPrinciples.length).toBeGreaterThanOrEqual(3)
  })
  it('001-good（完了テスト＋実在）は error なし', () => {
    expect(errorCodes('001-good')).toEqual([])
  })
  it('002-bad は 未解決clarification と 完了テストの proof リンク切れ を error 検知', () => {
    expect(errorCodes('002-bad')).toContain('SPECKIT_UNRESOLVED_CLARIFICATION')
    expect(errorCodes('002-bad')).toContain('SPECKIT_BROKEN_TEST_PROOF')
  })
  it('003-planned（未着手[ ]テスト＋未作成）は broken-proof にしない', () => {
    expect(errorCodes('003-planned')).toEqual([])
  })
})

describe('Spec-Kit アダプタ: fail-closed', () => {
  it('specs が無いディレクトリは SPECKIT_NO_SPECS（黙って PASS しない）', () => {
    const report = buildSpeckitGraph('/tmp/hernes-nonexistent-speckit-xyz')
    expect(report.violations.map((v) => v.code)).toContain('SPECKIT_NO_SPECS')
  })
})
