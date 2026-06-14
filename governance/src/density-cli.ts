// AI 実行密度 CLI。実データ（[{team,users,tokens,prs}] の JSON）を読み、HOTL/HITL を分類して表示する。
// 実データの作り方は docs/governance.md / scripts/governance/collect-pr-counts.sh を参照。
import { readFileSync } from 'node:fs'
import { isAbsolute, join } from 'node:path'
import type { DensityRecord } from './density'
import { computeExecutionDensity, formatDensity } from './density'

const arg = process.argv[2]
if (!arg) {
  process.stderr.write('usage: density <records.json>  （records: [{team,users,tokens,prs}]）\n')
  process.exit(2)
}

// pnpm --filter は cwd をパッケージ配下へ変える。呼び出し元(INIT_CWD)基準でパスを解決する。
const base = process.env.INIT_CWD ?? process.cwd()
const path = isAbsolute(arg) ? arg : join(base, arg)
const records = JSON.parse(readFileSync(path, 'utf8')) as DensityRecord[]
const result = computeExecutionDensity(records)
if (process.argv.includes('--json')) {
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`)
} else {
  process.stdout.write(formatDensity(result))
}
