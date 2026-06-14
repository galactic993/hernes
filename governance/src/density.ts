// AI 実行密度の実 telemetry。プレゼンの「1人あたりトークン使用量 × PR数 / 月」を計算し、
// 桁違いに突出した HOTL 型チームを HITL クラスタから分離する。
// 実データ（Codex 使用量 export ＋ gh の PR 数）を入力に取り、計算自体は純粋関数でテスト可能にする。

export interface DensityRecord {
  team: string
  users: number
  tokens: number
  prs: number
}

export interface TeamDensity {
  team: string
  tokensPerUser: number
  prsPerUser: number
  executionDensity: number
  cohort: 'HOTL' | 'HITL'
}

export interface DensityResult {
  teams: TeamDensity[]
  median: number
  threshold: number
  hotl: string[]
}

// executionDensity = 1人あたりトークン × 1人あたりPR数（自律実行の「密度」proxy）。
// median の HOTL_FACTOR 倍を超える＝桁違いの突出を HOTL とみなす。
const HOTL_FACTOR = 5

export function computeExecutionDensity(records: DensityRecord[]): DensityResult {
  const teams: TeamDensity[] = records.map((r) => {
    const tokensPerUser = r.users > 0 ? r.tokens / r.users : 0
    const prsPerUser = r.users > 0 ? r.prs / r.users : 0
    return {
      team: r.team,
      tokensPerUser,
      prsPerUser,
      executionDensity: tokensPerUser * prsPerUser,
      cohort: 'HITL',
    }
  })

  const sorted = teams.map((t) => t.executionDensity).sort((a, b) => a - b)
  const median = sorted.length === 0 ? 0 : sorted[Math.floor(sorted.length / 2)]
  const threshold = median * HOTL_FACTOR

  for (const t of teams) {
    if (threshold > 0 && t.executionDensity > threshold) t.cohort = 'HOTL'
  }

  return {
    teams: [...teams].sort((a, b) => b.executionDensity - a.executionDensity),
    median,
    threshold,
    hotl: teams.filter((t) => t.cohort === 'HOTL').map((t) => t.team),
  }
}

export function formatDensity(result: DensityResult): string {
  const out: string[] = []
  out.push('━━━ AI 実行密度（トークン使用量 × PR数 / 月・1人あたり）━━━')
  out.push('team                  tokens/user      PR/user   density       cohort')
  for (const t of result.teams) {
    out.push(
      `${t.team.padEnd(20)}  ${Math.round(t.tokensPerUser).toString().padStart(12)}  ${t.prsPerUser
        .toFixed(1)
        .padStart(10)}  ${t.executionDensity.toExponential(2).padStart(10)}   ${t.cohort}`,
    )
  }
  out.push('')
  out.push(
    `median density = ${result.median.toExponential(2)} / HOTL 閾値(>${HOTL_FACTOR}x median)`,
  )
  out.push(
    result.hotl.length > 0
      ? `→ HOTL 型（桁違いに突出）: ${result.hotl.join(', ')}`
      : '→ HOTL 型の外れ値なし（まだ HITL クラスタ）',
  )
  out.push('')
  return out.join('\n')
}
