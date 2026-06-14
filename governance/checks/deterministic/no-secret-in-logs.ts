// 司法（決定性）: 秘密値をログに出さない（R003 ← C5）。
// 行単位ではなくログ呼び出しの引数スパン全体を走査するため、フォーマッタによる複数行折り返しでも検知する。
import type { CheckContext, CheckMeta, Finding } from '../../src/types'

export const meta: CheckMeta = {
  id: 'no-secret-in-logs',
  kind: 'deterministic',
  title: '秘密値をログに出さない',
  jurisdiction: {
    include: ['apps/**', 'packages/**'],
    exclude: ['**/test/**', '**/*.test.ts', '**/*.test.tsx'],
  },
}

const SECRET_IDENTIFIERS = [
  'DATABASE_URL',
  'CLERK_SECRET_KEY',
  'CLERK_WEBHOOK_SECRET',
  'APP_SECRET',
  'REDIS_AUTH_STRING',
]
// console.* / logger.* / log.* のログ呼び出し開始（開きカッコまで）。
const LOG_OPEN = /(?:console|logger|log)\.(?:log|info|warn|error|debug|trace|fatal)\s*\(/g

function lineOf(text: string, index: number): number {
  return text.slice(0, index).split('\n').length
}

// 開きカッコから対応する閉じカッコまで（＝ログ呼び出しの引数スパン）を返す。複数行をまたぐ。
function callSpan(text: string, openIdx: number): string {
  let depth = 0
  for (let i = openIdx; i < text.length; i += 1) {
    const c = text[i]
    if (c === '(') depth += 1
    else if (c === ')') {
      depth -= 1
      if (depth === 0) return text.slice(openIdx, i + 1)
    }
  }
  return text.slice(openIdx, Math.min(text.length, openIdx + 800))
}

// 行コメント(//...) を除去（説明コメント中の秘密名で誤検知しないため）。
function stripLineComments(s: string): string {
  return s
    .split('\n')
    .map((l) => {
      const i = l.indexOf('//')
      return i >= 0 ? l.slice(0, i) : l
    })
    .join('\n')
}

// 識別子の単語境界一致（APP_SECRET_HEADER を APP_SECRET と誤検知しない）。
function hasIdentifier(span: string, id: string): boolean {
  return new RegExp(`(?<![A-Za-z0-9_])${id}(?![A-Za-z0-9_])`).test(span)
}

export function run(ctx: CheckContext): Finding[] {
  const findings: Finding[] = []
  for (const file of ctx.filesIn()) {
    if (!/\.(ts|tsx)$/.test(file)) continue
    const text = ctx.readRel(file)
    for (const m of text.matchAll(LOG_OPEN)) {
      const start = m.index ?? 0
      const openIdx = start + m[0].length - 1 // 開きカッコの位置
      // 呼び出し行自体がコメント行ならスキップ
      const lineStart = text.lastIndexOf('\n', start) + 1
      if (/^\s*(\/\/|\*|#)/.test(text.slice(lineStart, start))) continue
      const span = stripLineComments(callSpan(text, openIdx))
      for (const id of SECRET_IDENTIFIERS) {
        if (hasIdentifier(span, id)) {
          findings.push({
            file,
            line: lineOf(text, start),
            message: `ログ呼び出しに秘密値 ${id} が含まれる可能性`,
          })
        }
      }
    }
  }
  return findings
}
