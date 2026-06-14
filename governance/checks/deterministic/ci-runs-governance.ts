// 司法（決定性）: CI が統治ゲート(govern)を実行することを保証。R011 ← C2。
// 「行政が統治を通る」ことを CI レベルで担保し、ゲートの未配線を検知する。
import type { CheckContext, CheckMeta, Finding } from '../../src/types'

export const meta: CheckMeta = {
  id: 'ci-runs-governance',
  kind: 'deterministic',
  title: 'CI が統治ゲート(govern)を実行する',
  jurisdiction: { include: ['.github/workflows/ci.yml'] },
}

export function run(ctx: CheckContext): Finding[] {
  const findings: Finding[] = []
  for (const file of ctx.filesIn()) {
    if (!/govern/.test(ctx.readRel(file))) {
      findings.push({ file, message: 'CI が govern（統治ゲート）を実行していない' })
    }
  }
  return findings
}
