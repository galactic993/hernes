// 仕様完全性チェック（司法 / engine 提供）。
// 憲法 C1(ユーザー価値) / C3(小さな変更) / C4(観測可能) を、spec の完全性として決定的に enforce する。
// 「効いている」ためには、抽象的な原則を機械判定可能な spec 要件へ実体化する必要がある。
import { existsSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { parse } from 'yaml'
import type { Violation } from './types'
import { REPO_ROOT, readRel } from './util'

interface IntentDoc {
  intent?: { user_problem?: string; desired_outcome?: string }
}

const TASK_RE = /^\s*-\s*\[[ xX]\]/gim
const OBSERVABILITY_RE = /観測|ログ|メトリク|トレース|trace|metric|observab|logging/i

export interface CompletenessInput {
  id: string
  intentRaw?: string
  tasksRaw?: string
  specRaw?: string
}

// 1 feature の spec 完全性を評価する（純粋関数 / テスト可能）。
export function evaluateCompleteness(input: CompletenessInput): Violation[] {
  const { id } = input
  const violations: Violation[] = []

  // C1: ユーザー価値が articulate されているか（intent.user_problem / desired_outcome）
  let intent: IntentDoc['intent']
  try {
    intent = input.intentRaw ? (parse(input.intentRaw) as IntentDoc).intent : undefined
  } catch {
    intent = undefined
  }
  if (!intent?.user_problem?.trim() || !intent?.desired_outcome?.trim()) {
    violations.push({
      power: 'specification',
      code: 'SPEC_NO_USER_VALUE',
      severity: 'error',
      subject: id,
      ruleId: 'R007',
      constitution: ['C1'],
      message: `${id}: intent.yaml に user_problem / desired_outcome が無い（ユーザー価値が不明）`,
    })
  }

  // C3: 小さな変更へ分解されているか（tasks.md のタスク数）
  const taskCount = input.tasksRaw ? (input.tasksRaw.match(TASK_RE) ?? []).length : 0
  if (taskCount < 3) {
    violations.push({
      power: 'specification',
      code: 'SPEC_NOT_DECOMPOSED',
      severity: 'error',
      subject: id,
      ruleId: 'R008',
      constitution: ['C3'],
      message: `${id}: tasks.md のタスクが ${taskCount} 件（小さく独立した変更へ分解されていない）`,
    })
  }

  // C4: 観測可能性が spec に宣言されているか
  if (!input.specRaw || !OBSERVABILITY_RE.test(input.specRaw)) {
    violations.push({
      power: 'specification',
      code: 'SPEC_NO_OBSERVABILITY',
      severity: 'error',
      subject: id,
      ruleId: 'R009',
      constitution: ['C4'],
      message: `${id}: spec.md に観測可能性(ログ/メトリクス)の要件が無い`,
    })
  }

  return violations
}

export function checkSpecCompleteness(): Violation[] {
  const specsDir = join(REPO_ROOT, 'specs')
  if (!existsSync(specsDir)) return []
  const violations: Violation[] = []
  const dirs = readdirSync(specsDir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && d.name !== '_template')
    .map((d) => d.name)
    .sort()

  for (const id of dirs) {
    const read = (f: string) =>
      existsSync(join(REPO_ROOT, `specs/${id}/${f}`)) ? readRel(`specs/${id}/${f}`) : undefined
    violations.push(
      ...evaluateCompleteness({
        id,
        intentRaw: read('intent.yaml'),
        tasksRaw: read('tasks.md'),
        specRaw: read('spec.md'),
      }),
    )
  }
  return violations
}
