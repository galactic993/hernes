// 意味（semantic / LLM）司法の本配線。
// 決定性チェックと違い非決定的・コストが伴うため、既定では skip（CI 非ブロッキング）。
// GOVERN_SEMANTIC=1 かつ AGENT_CMD（codex exec / claude -p 等）設定時のみ有効化する。
// 評価器(LLM)の呼び出しは行政(harness) の拡張点。安定したものだけ warn→error に昇格する。
import { existsSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import type { CheckMeta, Violation } from './types'
import { GOV_DIR, readRel } from './util'

export interface SemanticSpec {
  id: string
  title: string
}

// checks/semantic/*.md を読み、id とタイトルを取り出す（中身はプロンプト仕様）。
export function loadSemanticSpecs(): SemanticSpec[] {
  const dir = join(GOV_DIR, 'checks', 'semantic')
  if (!existsSync(dir)) return []
  const specs: SemanticSpec[] = []
  for (const f of readdirSync(dir)
    .filter((name) => name.endsWith('.md'))
    .sort()) {
    const md = readRel(`governance/checks/semantic/${f}`)
    const id = /(?:^|\n)[-*]?\s*id:\s*`?([a-z0-9-]+)`?/i.exec(md)?.[1] ?? f.replace(/\.md$/, '')
    const title = /^#\s*[^\n]*?:\s*([^\n]+)/m.exec(md)?.[1]?.trim() ?? id
    specs.push({ id, title })
  }
  return specs
}

// 意味司法の管轄（authority graph 用）。束縛する rule の管轄と一致させる。
export const SEMANTIC_CHECK_META: CheckMeta[] = [
  {
    id: 'user-value-alignment',
    kind: 'semantic',
    title: '変更がユーザー価値に整合しているか（LLM 判定）',
    jurisdiction: { include: ['specs/**'] },
  },
  {
    id: 'pii-in-logs',
    kind: 'semantic',
    title: '個人情報をログに出していないか（LLM 判定）',
    jurisdiction: {
      include: ['apps/**', 'packages/**'],
      exclude: ['**/test/**', '**/*.test.ts', '**/*.test.tsx'],
    },
  },
]

export interface SemanticResult {
  enabled: boolean
  registered: number
  violations: Violation[]
}

export function runSemanticChecks(): SemanticResult {
  const specs = loadSemanticSpecs()
  // 既定: skip（CI 非ブロッキング）。
  if (process.env.GOVERN_SEMANTIC !== '1') {
    return { enabled: false, registered: specs.length, violations: [] }
  }
  // 有効化されたが評価器(AGENT_CMD)が無い → 助言(warn)で気づかせる（ブロックしない）。
  if (!process.env.AGENT_CMD) {
    return {
      enabled: true,
      registered: specs.length,
      violations: [
        {
          power: 'judicial',
          code: 'SEMANTIC_NO_EVALUATOR',
          severity: 'warn',
          subject: 'semantic',
          message: 'GOVERN_SEMANTIC=1 だが AGENT_CMD（LLM 評価器）が未設定。意味司法は評価されない',
        },
      ],
    }
  }
  // AGENT_CMD による LLM 評価はここに実装する（行政の拡張点）。
  // 非決定的・ネットワーク依存のため MVP では評価器を同梱せず、配線(登録・スキップ・拡張点)までを提供する。
  return { enabled: true, registered: specs.length, violations: [] }
}
