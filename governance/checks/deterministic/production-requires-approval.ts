// 司法（決定性）: 本番デプロイは承認必須（GitHub Environment approval）。R012 ← C5。
import type { CheckContext, CheckMeta, Finding } from '../../src/types'

export const meta: CheckMeta = {
  id: 'production-requires-approval',
  kind: 'deterministic',
  title: '本番デプロイは承認必須（environment: production）',
  jurisdiction: { include: ['.github/workflows/deploy-production.yml'] },
}

export function run(ctx: CheckContext): Finding[] {
  const findings: Finding[] = []
  for (const file of ctx.filesIn()) {
    if (!/environment:\s*production/.test(ctx.readRel(file))) {
      findings.push({
        file,
        message: '本番デプロイに environment: production（approval ゲート）が無い',
      })
    }
  }
  return findings
}
