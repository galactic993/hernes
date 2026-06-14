// SSOT（原典）と派生データの分離を機械的に守らせる。
// - 派生データはコミットしない（gitignore）
// - 立法/司法は派生データ（governance/graph）を authority として参照しない
import type { SsotManifest, Violation } from './types'
import { existsRel, filesIn, readRel } from './util'

function gitignoreDirs(): string[] {
  if (!existsRel('.gitignore')) return []
  return readRel('.gitignore')
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('#'))
    .map((l) =>
      l
        .replace(/^\//, '')
        .replace(/\/\*+$/, '')
        .replace(/\/$/, ''),
    )
    .filter((l) => l !== '')
}

export function checkSsot(manifest: SsotManifest): Violation[] {
  const violations: Violation[] = []
  const ignored = gitignoreDirs()

  for (const d of manifest.derived) {
    const root = d.replace(/\/\*+$/, '').replace(/\/$/, '')
    const byRootIgnore = ignored.some((g) => root === g || root.startsWith(`${g}/`))
    // governance/graph はローカル .gitignore（governance/graph/.gitignore）で無視される
    const byLocalIgnore = existsRel(`${root}/.gitignore`)
    if (!byRootIgnore && !byLocalIgnore) {
      violations.push({
        power: 'ssot',
        code: 'DERIVED_NOT_IGNORED',
        severity: 'warn',
        subject: root,
        ruleId: 'R006',
        message: `派生データ ${d} が gitignore されていない（判断根拠化・混入のリスク）`,
      })
    }
  }

  // 立法/司法 が派生データ governance/graph を authority として参照していないか。
  // コメント行は除外し、相対パス参照（../graph/authority-graph 等）も検知する。
  const DERIVED_REF = /governance\/graph\/|graph\/(?:authority-graph|spec-graph)/
  for (const f of filesIn({ include: ['governance/rules/**', 'governance/checks/**'] })) {
    const lines = readRel(f).split('\n')
    lines.forEach((line, i) => {
      const code = line.replace(/(#|\/\/).*$/, '') // 行コメントを除去
      if (DERIVED_REF.test(code)) {
        violations.push({
          power: 'ssot',
          code: 'SSOT_REFERENCES_DERIVED',
          severity: 'error',
          subject: f,
          ruleId: 'R006',
          file: f,
          line: i + 1,
          message: `立法/司法 ${f} が派生データ graph を authority として参照している`,
        })
      }
    })
  }

  return violations
}
