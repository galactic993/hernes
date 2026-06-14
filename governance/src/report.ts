// 人間向けレポート整形。
import type { GovernReport, Violation } from './types'

const POWER_LABEL: Record<string, string> = {
  constitution: '憲法',
  legislative: '立法',
  judicial: '司法',
  executive: '行政',
  specification: '仕様',
  ssot: 'SSOT',
}

function formatViolation(v: Violation): string {
  const where = v.file ? ` (${v.file}${v.line ? `:${v.line}` : ''})` : ''
  const cite = v.ruleId
    ? `${v.ruleId}${v.constitution?.length ? `←${v.constitution.join(',')}` : ''}`
    : ''
  const mark = v.severity === 'error' ? '✗' : '⚠'
  return `  ${mark} [${POWER_LABEL[v.power] ?? v.power}] ${v.code} ${cite}\n     ${v.message}${where}`
}

export function formatReport(r: GovernReport): string {
  const out: string[] = []
  out.push('━━━ hernes governance（三権分立 / HOTL 統治ゲート）━━━')
  out.push(
    `憲法 ${r.counts.constitution} 条 / 立法 ${r.counts.rules} ルール / ` +
      `司法 ${r.counts.checks} チェック / 仕様 ${r.counts.features} feature`,
  )
  const m = r.metrics
  const provenPct = m.mustTotal === 0 ? 100 : Math.round((m.mustProven / m.mustTotal) * 100)
  out.push(
    `AI実行密度(proxy): 立法カバレッジ ${m.enforcedRules}/${r.counts.rules}・` +
      `MUST要件証明率 ${m.mustProven}/${m.mustTotal} (${provenPct}%)・手動待ち ${m.manualConditions} 件`,
  )
  out.push(
    `意味(LLM)司法: ${r.semantic.registered} 件登録 / ${
      r.semantic.enabled ? '有効' : '既定skip（GOVERN_SEMANTIC=1 + AGENT_CMD で有効化）'
    }`,
  )
  out.push('')

  if (r.violations.length === 0) {
    out.push('✅ 違反なし。すべてのルールが効いている（書かれている＝効いている）。')
  } else {
    if (r.errors.length) {
      out.push(`✗ ERROR ${r.errors.length} 件（CI を落とす）:`)
      for (const v of r.errors) out.push(formatViolation(v))
      out.push('')
    }
    if (r.warnings.length) {
      out.push(`⚠ WARN ${r.warnings.length} 件（次の宿題 / 非ブロッキング）:`)
      for (const v of r.warnings) out.push(formatViolation(v))
      out.push('')
    }
  }

  out.push(r.ok ? '結果: PASS（exit 0）' : `結果: FAIL（exit 1） — ERROR ${r.errors.length} 件`)
  out.push('')
  return out.join('\n')
}
