// 司法（決定性）: 行政(harness) の verify ゲートが「実在」することを保証（R005 ← C2）。
// 単語の部分一致ではなく、verify が実際に pnpm スクリプトを呼んでいるか・そのスクリプトが存在するかで判定する
// （echo 等での空洞化を検知する）。
import type { CheckContext, CheckMeta, Finding } from '../../src/types'

export const meta: CheckMeta = {
  id: 'verify-gate-present',
  kind: 'deterministic',
  title: '検証ゲート(verify)の存在',
  jurisdiction: { include: ['package.json', 'Makefile'] },
}

export function run(ctx: CheckContext): Finding[] {
  const findings: Finding[] = []
  const pkg = JSON.parse(ctx.readRel('package.json')) as { scripts?: Record<string, string> }
  const scripts = pkg.scripts ?? {}
  const verify = scripts.verify ?? ''

  // verify が呼び出している pnpm スクリプト名（pnpm <name> / pnpm run <name>）。
  const referenced = [...verify.matchAll(/\bpnpm\s+(?:run\s+)?([a-z][\w:-]*)/g)].map((m) => m[1])

  for (const part of ['lint', 'typecheck', 'test']) {
    if (!referenced.includes(part)) {
      findings.push({
        file: 'package.json',
        message: `verify が pnpm ${part} を実行していない（行政ゲートの空洞化）`,
      })
    }
  }
  // 参照しているスクリプトが実在するか（存在しない名前を呼ぶ空ゲートを検知）。
  for (const name of referenced) {
    if (!(name in scripts)) {
      findings.push({
        file: 'package.json',
        message: `verify が参照する script "${name}" が package.json に存在しない`,
      })
    }
  }
  if (!/^verify:/m.test(ctx.readRel('Makefile'))) {
    findings.push({ file: 'Makefile', message: 'Makefile に verify ターゲットが無い' })
  }
  return findings
}
