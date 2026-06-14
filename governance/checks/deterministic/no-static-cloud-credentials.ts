// 司法（決定性）: 静的クラウド資格情報の禁止（WIF 一択 / SA JSON キー禁止）。R010 ← C5。
// CI/IaC に SA JSON キーや埋め込み秘密鍵が入らないことを機械判定する（development-harness §21 準拠）。
import type { CheckContext, CheckMeta, Finding } from '../../src/types'

export const meta: CheckMeta = {
  id: 'no-static-cloud-credentials',
  kind: 'deterministic',
  title: '静的クラウド資格情報の禁止（WIF 一択 / SA JSON キー禁止）',
  jurisdiction: { include: ['.github/**', 'infra/**'] },
}

const PATTERNS: { re: RegExp; what: string }[] = [
  { re: /credentials_json\s*:/, what: 'credentials_json（SA JSON キー）' },
  { re: /-----BEGIN [A-Z ]*PRIVATE KEY-----/, what: '埋め込み秘密鍵' },
  { re: /--key-file=/, what: 'SA キーファイル参照（--key-file）' },
]

export function run(ctx: CheckContext): Finding[] {
  const findings: Finding[] = []
  for (const file of ctx.filesIn()) {
    if (!/\.(ya?ml|tf|tfvars|sh)$/.test(file)) continue
    const lines = ctx.readRel(file).split('\n')
    lines.forEach((line, i) => {
      for (const p of PATTERNS) {
        if (p.re.test(line)) {
          findings.push({
            file,
            line: i + 1,
            message: `${p.what} を検出。WIF / Secret Manager を使うこと`,
          })
        }
      }
    })
  }
  return findings
}
