// Authority Provenance Graph: 立法(rule)↔司法(check) の由来を機械可読に接続し、
// ①立法なき司法 ②司法なき立法 ③越境司法（＋憲法参照の欠落）を検知する。
import type {
  AuthorityGraph,
  CheckMeta,
  Constitution,
  Jurisdiction,
  Rule,
  Violation,
} from './types'
import { filesIn } from './util'

// 管轄を「展開ファイル集合」で評価する。glob 文字列比較では include/exclude を厳密に扱えないため。
// テスト用に差し替え可能（既定は実リポジトリを走査する filesIn）。
export type FileResolver = (jur: Jurisdiction) => string[]

export function buildAuthorityGraph(
  constitution: Constitution,
  rules: Rule[],
  checkMetas: CheckMeta[],
  resolveFiles: FileResolver = filesIn,
): AuthorityGraph {
  const violations: Violation[] = []
  const principleIds = new Set(constitution.principles.map((p) => p.id))
  const checkById = new Map(checkMetas.map((c) => [c.id, c]))
  const referencedCheckIds = new Set<string>()
  const activeRules = rules.filter((r) => r.status === 'active')

  for (const r of activeRules) {
    // 立法は憲法に準拠（C? 参照が実在するか／そもそも参照しているか）
    if (r.constitution.length === 0) {
      violations.push({
        power: 'legislative',
        code: 'CONSTITUTION_REF_MISSING',
        severity: 'error',
        subject: r.id,
        ruleId: r.id,
        message: `ルール ${r.id} が憲法条項を参照していない（立法の根拠が憲法に無い）`,
      })
    }
    for (const cid of r.constitution) {
      if (!principleIds.has(cid)) {
        violations.push({
          power: 'legislative',
          code: 'CONSTITUTION_REF_MISSING',
          severity: 'error',
          subject: r.id,
          ruleId: r.id,
          message: `ルール ${r.id} が参照する憲法条項 ${cid} が存在しない`,
        })
      }
    }

    // ②司法なき立法: error 重大度なのに効かせる司法が無い（書かれているが効いていない）
    if (r.severity === 'error' && r.checks.length === 0) {
      violations.push({
        power: 'legislative',
        code: 'LEGISLATION_WITHOUT_JUDICIAL',
        severity: 'error',
        subject: r.id,
        ruleId: r.id,
        constitution: r.constitution,
        message: `ルール ${r.id} は error だが、効かせる司法(checks)が無い（司法なき立法）`,
      })
    }

    for (const b of r.checks) {
      referencedCheckIds.add(b.id)
      const cm = checkById.get(b.id)
      if (!cm) {
        violations.push({
          power: 'legislative',
          code: 'CHECK_NOT_FOUND',
          severity: 'error',
          subject: r.id,
          ruleId: r.id,
          message: `ルール ${r.id} が束縛する司法 ${b.id} が存在しない`,
        })
        continue
      }
      // ③越境司法: 司法の管轄(展開ファイル集合)がルールの管轄に収まっているか。
      // 集合包含で評価するため、ルール/司法 双方の include・exclude を厳密に反映できる。
      const ruleFiles = new Set(resolveFiles(r.jurisdiction))
      const escaped = resolveFiles(cm.jurisdiction).filter((f) => !ruleFiles.has(f))
      if (escaped.length > 0) {
        violations.push({
          power: 'judicial',
          code: 'CROSS_JURISDICTION',
          severity: 'error',
          subject: cm.id,
          ruleId: r.id,
          message: `司法 ${cm.id} の管轄がルール ${r.id} の管轄外に及ぶ（越境司法）: 例 ${escaped
            .slice(0, 3)
            .join(', ')}`,
        })
      }
    }
  }

  // ①立法なき司法: 有効な(active)ルールに束縛されていない司法（orphan check）
  for (const cm of checkMetas) {
    if (!referencedCheckIds.has(cm.id)) {
      violations.push({
        power: 'judicial',
        code: 'JUDICIAL_WITHOUT_LEGISLATION',
        severity: 'error',
        subject: cm.id,
        message: `司法 ${cm.id} は有効な(active)ルールに束縛されていない（立法なき司法）`,
      })
    }
  }

  return {
    nodes: [
      ...constitution.principles.map((p) => ({
        id: p.id,
        type: 'constitution' as const,
        label: p.name,
      })),
      ...activeRules.map((r) => ({ id: r.id, type: 'rule' as const, label: r.title })),
      ...checkMetas.map((c) => ({ id: c.id, type: 'check' as const, label: c.title })),
    ],
    edges: [
      ...activeRules.flatMap((r) =>
        r.constitution.map((c) => ({ from: r.id, to: c, kind: 'complies' as const })),
      ),
      ...activeRules.flatMap((r) =>
        r.checks.map((b) => ({ from: r.id, to: b.id, kind: 'enforced-by' as const })),
      ),
    ],
    violations,
  }
}
