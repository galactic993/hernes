// 司法（決定性）: 画面メッセージの直書き禁止。@hernes/shared を唯一の出典に（R002 ← C6）。
import { FIELD_MESSAGES, SCREEN_MESSAGES } from '@hernes/shared'
import type { CheckContext, CheckMeta, Finding } from '../../src/types'

export const meta: CheckMeta = {
  id: 'no-hardcoded-screen-messages',
  kind: 'deterministic',
  title: '画面メッセージの直書き禁止（@hernes/shared を唯一の出典に）',
  jurisdiction: {
    include: ['apps/**', 'packages/**'],
    exclude: ['packages/shared/**', '**/test/**', '**/*.test.ts', '**/*.test.tsx'],
  },
}

// 値の重複を排除（同一文言が複数キーで定義されていても 1 件として扱う）。
const CATALOG = [...new Set([...Object.values(SCREEN_MESSAGES), ...Object.values(FIELD_MESSAGES)])]

export function run(ctx: CheckContext): Finding[] {
  const findings: Finding[] = []
  for (const file of ctx.filesIn()) {
    if (!/\.(ts|tsx)$/.test(file)) continue
    const lines = ctx.readRel(file).split('\n')
    lines.forEach((line, i) => {
      const matched = CATALOG.filter((msg) => line.includes(msg))
      // 包含関係にある短い方を落とし、1 行につき最長一致のみ報告（重複ノイズを抑える）。
      const longest = matched.filter((m) => !matched.some((o) => o !== m && o.includes(m)))
      for (const msg of longest) {
        findings.push({
          file,
          line: i + 1,
          message: `共有カタログのメッセージ "${msg}" が直書きされている。@hernes/shared を参照すること`,
        })
      }
    })
  }
  return findings
}
