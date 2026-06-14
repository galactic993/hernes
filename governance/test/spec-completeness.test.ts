import { describe, expect, it } from 'vitest'
import { checkSpecCompleteness, evaluateCompleteness } from '../src/spec-completeness'

const goodIntent = 'intent:\n  user_problem: "課題"\n  desired_outcome: "成果"\n'
const goodTasks = '- [x] T1\n- [ ] T2\n- [x] T3\n'
const goodSpec = '## 非機能要件\n- NFR-001: 検索フローはログ/メトリクスで観測可能\n'

function codes(vs: { code: string }[]): string[] {
  return vs.map((v) => v.code)
}

describe('evaluateCompleteness（憲法 C1/C3/C4 の実体化）', () => {
  it('完全な spec は違反ゼロ', () => {
    expect(
      evaluateCompleteness({
        id: 'F',
        intentRaw: goodIntent,
        tasksRaw: goodTasks,
        specRaw: goodSpec,
      }),
    ).toEqual([])
  })

  it('C1: user_problem/desired_outcome 欠落で SPEC_NO_USER_VALUE', () => {
    const vs = evaluateCompleteness({
      id: 'F',
      intentRaw: 'intent:\n  purpose: x\n',
      tasksRaw: goodTasks,
      specRaw: goodSpec,
    })
    expect(codes(vs)).toContain('SPEC_NO_USER_VALUE')
  })

  it('C3: タスク 3 未満で SPEC_NOT_DECOMPOSED', () => {
    const vs = evaluateCompleteness({
      id: 'F',
      intentRaw: goodIntent,
      tasksRaw: '- [ ] T1\n',
      specRaw: goodSpec,
    })
    expect(codes(vs)).toContain('SPEC_NOT_DECOMPOSED')
  })

  it('C4: 観測可能性の記述が無いと SPEC_NO_OBSERVABILITY', () => {
    const vs = evaluateCompleteness({
      id: 'F',
      intentRaw: goodIntent,
      tasksRaw: goodTasks,
      specRaw: '## 概要\n機能の説明',
    })
    expect(codes(vs)).toContain('SPEC_NO_OBSERVABILITY')
  })
})

describe('checkSpecCompleteness（実 specs）', () => {
  it('既存 spec は完全（error ゼロ）', () => {
    expect(checkSpecCompleteness()).toEqual([])
  })
})
