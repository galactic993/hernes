// 決定性チェック（司法）を、束縛するルールの管轄に絞って実行し、違反を立法→憲法へ写像する。
import type { CheckContext, DeterministicCheck, Rule, Violation } from './types'
import { filesIn, readRel } from './util'

export async function runDeterministicChecks(
  rules: Rule[],
  checks: DeterministicCheck[],
): Promise<Violation[]> {
  const byId = new Map(checks.map((c) => [c.meta.id, c]))
  const violations: Violation[] = []

  for (const r of rules) {
    if (r.status !== 'active') continue
    for (const b of r.checks) {
      if (b.kind !== 'deterministic') continue
      const check = byId.get(b.id)
      if (!check) continue
      const ctx: CheckContext = {
        filesIn: () => filesIn(r.jurisdiction),
        readRel,
      }
      const findings = await check.run(ctx)
      for (const f of findings) {
        violations.push({
          power: 'judicial',
          code: 'CHECK_FAILED',
          severity: r.severity,
          subject: f.file,
          ruleId: r.id,
          constitution: r.constitution,
          message: `[${r.id}/${b.id}] ${f.message}`,
          file: f.file,
          line: f.line,
        })
      }
    }
  }

  return violations
}
