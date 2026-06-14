// 統治ゲート CLI。違反(error)があれば exit 1（＝CI を落とす / Agent を止める）。
// 派生データ（graph JSON）を governance/graph に書き出す（判断根拠にはしない＝gitignore 済み）。
import { mkdirSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { govern } from './govern'
import { formatReport } from './report'
import { GOV_DIR } from './util'

async function main(): Promise<void> {
  const json = process.argv.includes('--json')
  const report = await govern()

  const graphDir = join(GOV_DIR, 'graph')
  mkdirSync(graphDir, { recursive: true })
  writeFileSync(
    join(graphDir, 'authority-graph.json'),
    `${JSON.stringify(report.authorityGraph, null, 2)}\n`,
  )
  writeFileSync(join(graphDir, 'spec-graph.json'), `${JSON.stringify(report.specGraph, null, 2)}\n`)

  if (json) {
    process.stdout.write(
      `${JSON.stringify({ ok: report.ok, counts: report.counts, violations: report.violations }, null, 2)}\n`,
    )
  } else {
    process.stdout.write(formatReport(report))
  }
  process.exit(report.ok ? 0 : 1)
}

main().catch((err: unknown) => {
  process.stderr.write(`govern failed: ${err instanceof Error ? err.stack : String(err)}\n`)
  process.exit(2)
})
