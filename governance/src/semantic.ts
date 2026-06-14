// 意味（semantic / LLM）司法。AGENT_CMD（codex exec / claude -p 等）を評価器として呼び出す。
// 非決定的・コスト/ネットワーク依存のため、既定では skip（CI 非ブロッキング）。
// GOVERN_SEMANTIC=1 で有効化。違反は warn（段階導入）。安定したものだけ後で error へ昇格する。
import { spawnSync } from 'node:child_process'
import { existsSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import type { CheckMeta, Violation } from './types'
import { GOV_DIR, readRel } from './util'

export interface SemanticSpec {
  id: string
  title: string
  body: string
}

export interface SemanticVerdict {
  verdict: 'pass' | 'fail' | 'unknown'
  reason: string
}

// 評価器（LLM）。テストのため注入可能。prompt を渡し、モデル出力テキストを返す。
export type SemanticExecutor = (prompt: string) => string

export function loadSemanticSpecs(): SemanticSpec[] {
  const dir = join(GOV_DIR, 'checks', 'semantic')
  if (!existsSync(dir)) return []
  const specs: SemanticSpec[] = []
  for (const f of readdirSync(dir)
    .filter((name) => name.endsWith('.md'))
    .sort()) {
    const body = readRel(`governance/checks/semantic/${f}`)
    const id = /(?:^|\n)[-*]?\s*id:\s*`?([a-z0-9-]+)`?/i.exec(body)?.[1] ?? f.replace(/\.md$/, '')
    const title = /^#\s*[^\n]*?:\s*([^\n]+)/m.exec(body)?.[1]?.trim() ?? id
    specs.push({ id, title, body })
  }
  return specs
}

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

export function buildPrompt(spec: SemanticSpec): string {
  return [
    'あなたは AI 駆動開発の「司法（意味判定）」です。以下の司法仕様に従い、現在のリポジトリ/変更を評価してください。',
    '出力は最後に必ず JSON を 1 つだけ含めてください: {"verdict":"pass|fail","reason":"<簡潔な理由>"}',
    '',
    `## 司法仕様: ${spec.id}`,
    spec.body,
  ].join('\n')
}

export function parseVerdict(output: string): SemanticVerdict {
  const matches = output.match(/\{[^{}]*"verdict"\s*:\s*"(?:pass|fail|unknown)"[^{}]*\}/g)
  const last = matches?.[matches.length - 1]
  if (!last) return { verdict: 'unknown', reason: '評価器出力に JSON verdict が無い' }
  try {
    const parsed = JSON.parse(last) as Partial<SemanticVerdict>
    const verdict =
      parsed.verdict === 'pass' || parsed.verdict === 'fail' ? parsed.verdict : 'unknown'
    return { verdict, reason: typeof parsed.reason === 'string' ? parsed.reason : '' }
  } catch {
    return { verdict: 'unknown', reason: '評価器出力の JSON 解析に失敗' }
  }
}

function agentExecutor(prompt: string): string {
  const cmd = process.env.AGENT_CMD ?? ''
  const [program, ...args] = cmd.split(' ').filter(Boolean)
  const res = spawnSync(program, args, {
    input: prompt,
    encoding: 'utf8',
    timeout: Number(process.env.GOVERN_SEMANTIC_TIMEOUT_MS ?? 120000),
    maxBuffer: 10 * 1024 * 1024,
  })
  if (res.error) throw res.error
  if (res.status !== 0) throw new Error(`AGENT_CMD exit ${res.status}: ${res.stderr ?? ''}`)
  return res.stdout ?? ''
}

export interface SemanticResult {
  enabled: boolean
  registered: number
  violations: Violation[]
}

// executor は省略時、GOVERN_SEMANTIC=1 かつ AGENT_CMD があれば agentExecutor を使う（テストでは注入）。
export function runSemanticChecks(opts: { executor?: SemanticExecutor } = {}): SemanticResult {
  const specs = loadSemanticSpecs()
  if (process.env.GOVERN_SEMANTIC !== '1') {
    return { enabled: false, registered: specs.length, violations: [] }
  }
  const executor = opts.executor ?? (process.env.AGENT_CMD ? agentExecutor : undefined)
  if (!executor) {
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

  const violations: Violation[] = []
  for (const spec of specs) {
    try {
      const verdict = parseVerdict(executor(buildPrompt(spec)))
      if (verdict.verdict === 'fail') {
        violations.push({
          power: 'judicial',
          code: 'SEMANTIC_FAIL',
          severity: 'warn',
          subject: spec.id,
          message: `意味司法 ${spec.id} が fail: ${verdict.reason}`,
        })
      }
    } catch (err) {
      violations.push({
        power: 'judicial',
        code: 'SEMANTIC_ERROR',
        severity: 'warn',
        subject: spec.id,
        message: `意味司法 ${spec.id} の評価器エラー: ${err instanceof Error ? err.message : String(err)}`,
      })
    }
  }
  return { enabled: true, registered: specs.length, violations }
}
