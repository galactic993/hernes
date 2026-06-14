// Spec-Kit プロジェクトに hernes governance の決定論ゲートを適用する CLI。
//   make govern-speckit DIR=../my-speckit-project
// Spec-Kit は「書かれている」（constitution/clarify/analyze は AI 参照・LLM レビュー）。
// これは「効いている」（未解決 clarify・テスト proof のリンク切れを CI で落とす）を足す層。
import { isAbsolute, join } from 'node:path'
import { buildSpeckitGraph } from './adapters/speckit'
import type { Violation } from './types'

function format(report: ReturnType<typeof buildSpeckitGraph>): string {
  const out: string[] = []
  out.push('━━━ hernes governance × Spec-Kit（効いている層）━━━')
  out.push(
    `project ${report.projectDir} / feature ${report.features.length} / 憲法 ${report.constitutionPrinciples.length} 原則`,
  )
  out.push('')
  const errors = report.violations.filter((v) => v.severity === 'error')
  const warns = report.violations.filter((v) => v.severity === 'warn')
  const line = (v: Violation) =>
    `  ${v.severity === 'error' ? '✗' : '⚠'} ${v.code}  ${v.message}${v.file ? ` (${v.file})` : ''}`
  if (report.violations.length === 0) {
    out.push('✅ 違反なし（Spec-Kit 仕様が機械検証を通過）。')
  } else {
    if (errors.length) {
      out.push(`✗ ERROR ${errors.length} 件（CI を落とす）:`)
      for (const v of errors) out.push(line(v))
      out.push('')
    }
    if (warns.length) {
      out.push(`⚠ WARN ${warns.length} 件:`)
      for (const v of warns) out.push(line(v))
      out.push('')
    }
  }
  out.push(
    errors.length === 0
      ? '結果: PASS（exit 0）'
      : `結果: FAIL（exit 1） — ERROR ${errors.length} 件`,
  )
  out.push('')
  return out.join('\n')
}

const arg = process.argv[2]
if (!arg) {
  process.stderr.write('usage: govern-speckit <spec-kit-project-dir>\n')
  process.exit(2)
}
const base = process.env.INIT_CWD ?? process.cwd()
const dir = isAbsolute(arg) ? arg : join(base, arg)
try {
  const report = buildSpeckitGraph(dir)
  if (process.argv.includes('--json')) {
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`)
  } else {
    process.stdout.write(format(report))
  }
  process.exit(report.violations.some((v) => v.severity === 'error') ? 1 : 0)
} catch (err) {
  // 読めない/壊れたファイル等は整形メッセージで非0終了（生スタックを出さない）。
  process.stderr.write(
    `govern-speckit failed: ${err instanceof Error ? err.message : String(err)}\n`,
  )
  process.exit(2)
}
