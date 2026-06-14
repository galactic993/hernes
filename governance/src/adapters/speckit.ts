// Spec-Kit（github/spec-kit）アダプタ。
// Spec-Kit が出力する specs/<NNN>/spec.md・tasks.md・.specify/memory/constitution.md を読み、
// hernes governance の「効いている」ゲート（違反で CI exit 1）を被せる。
// Spec-Kit 本体の constitution/clarify/analyze は AI 参照・LLM レビュー（書かれている）層。
import { existsSync, readFileSync, readdirSync } from 'node:fs'
import { join, resolve } from 'node:path'
import type { Violation } from '../types'

const REQ_RE = /\*\*((?:FR|SC|NFR)-\d+)\*\*/g
const STORY_RE = /^###\s+User Story\s+(\d+)\s*-\s*(.+?)\s*\(Priority:\s*(P\d+)\)/gim
const CLARIFY_RE = /\[NEEDS CLARIFICATION/gi
// チェックボックス状態（[ ] / [x]）を捕捉する。
const TASK_RE = /^\s*-\s*\[([ xX])\]\s*(T\d+)\b(.*)$/gm
const STORY_TAG_RE = /\[(US\d+)\]/
// パス判定は空白分割トークン単位（ReDoS 回避）。スラッシュを含み拡張子で終わるもの。
const PATH_TOKEN_RE = /^[\w.-]+(?:\/[\w.-]+)+\.[A-Za-z0-9]{1,6}$/
// テストパス: tests/・__tests__/・/test_（語頭境界）・_test.・.test.・.spec.
const TEST_PATH_RE = /(?:^|\/)(?:tests?|__tests__)\/|(?:^|\/)test_|_test\.|\.test\.|\.spec\./i
// 未置換テンプレ・プレースホルダ（[name] / [entity] 等）を含むパス様トークン（[US1]/[P] は対象外）。
const PLACEHOLDER_PATH_RE = /\[[a-z][\w-]*\][\w./-]*\.[A-Za-z0-9]{1,6}$|\/[\w.-]*\[[a-z][\w-]*\]/
const MAX_TOKEN = 256

export interface SpeckitUserStory {
  id: string
  title: string
  priority: string
}

export interface SpeckitTestTask {
  taskId: string
  story?: string
  filePath: string
  done: boolean
}

export interface SpeckitTaskParse {
  testTasks: SpeckitTestTask[]
  hasPlaceholders: boolean
  taskCount: number
}

export interface SpeckitFeature {
  id: string
  requirements: string[]
  userStories: SpeckitUserStory[]
  testTasks: SpeckitTestTask[]
  needsClarification: number
  hasTasks: boolean
}

export interface SpeckitReport {
  projectDir: string
  features: SpeckitFeature[]
  violations: Violation[]
  constitutionPrinciples: string[]
}

function uniq(values: string[]): string[] {
  return [...new Set(values)]
}

// HTML コメントと「Example of marking unclear requirements」の例示ブロックを除去（誤検知防止）。
function stripIllustrative(md: string): string {
  return md
    .replace(/<!--[\s\S]*?-->/g, '')
    .replace(/\*Example of marking unclear requirements:?\*[\s\S]*?(?=\n#{1,6}\s|$)/gi, '')
}

export function parseSpeckitSpec(md: string): {
  requirements: string[]
  userStories: SpeckitUserStory[]
  needsClarification: number
} {
  const requirements = uniq([...md.matchAll(REQ_RE)].map((m) => m[1]))
  const userStories: SpeckitUserStory[] = [...md.matchAll(STORY_RE)].map((m) => ({
    id: `US${m[1]}`,
    title: m[2].trim(),
    priority: m[3],
  }))
  const needsClarification = (stripIllustrative(md).match(CLARIFY_RE) ?? []).length
  return { requirements, userStories, needsClarification }
}

export function parseSpeckitTasks(md: string): SpeckitTaskParse {
  const testTasks: SpeckitTestTask[] = []
  let hasPlaceholders = false
  let taskCount = 0
  for (const m of md.matchAll(TASK_RE)) {
    taskCount += 1
    const done = m[1].toLowerCase() === 'x'
    const taskId = m[2]
    const rest = m[3] ?? ''
    const story = STORY_TAG_RE.exec(rest)?.[1]
    for (const tok of rest.split(/\s+/)) {
      if (tok.length === 0 || tok.length > MAX_TOKEN) continue
      if (PLACEHOLDER_PATH_RE.test(tok)) hasPlaceholders = true
      if (PATH_TOKEN_RE.test(tok) && TEST_PATH_RE.test(tok)) {
        testTasks.push({ taskId, story, filePath: tok, done })
      }
    }
  }
  return { testTasks, hasPlaceholders, taskCount }
}

function parseConstitution(projectDir: string): string[] {
  const p = join(projectDir, '.specify', 'memory', 'constitution.md')
  if (!existsSync(p)) return []
  const md = readFileSync(p, 'utf8')
  const start = md.indexOf('## Core Principles')
  const section = start >= 0 ? md.slice(start) : md
  return [...section.matchAll(/^###\s+(.+)$/gm)].map((m) => m[1].trim())
}

// proof パスは projectDir 配下に解決される場合のみ存在判定する（../ で外へ抜けるのを禁止）。
function defaultExists(root: string): (rel: string) => boolean {
  return (rel) => {
    const abs = resolve(root, rel)
    if (abs !== root && !abs.startsWith(`${root}/`)) return false
    return existsSync(abs)
  }
}

export function buildSpeckitGraph(
  projectDir: string,
  exists?: (rel: string) => boolean,
): SpeckitReport {
  const root = resolve(projectDir)
  const existsFn = exists ?? defaultExists(root)
  const features: SpeckitFeature[] = []
  const violations: Violation[] = []
  const specsDir = join(root, 'specs')
  let specCount = 0

  if (existsSync(specsDir)) {
    const dirs = readdirSync(specsDir, { withFileTypes: true })
      .filter((d) => d.isDirectory())
      .map((d) => d.name)
      .sort()

    for (const id of dirs) {
      const specPath = join(specsDir, id, 'spec.md')
      if (!existsSync(specPath)) continue
      specCount += 1
      const spec = parseSpeckitSpec(readFileSync(specPath, 'utf8'))
      const tasksPath = join(specsDir, id, 'tasks.md')
      const tasks = existsSync(tasksPath)
        ? parseSpeckitTasks(readFileSync(tasksPath, 'utf8'))
        : { testTasks: [], hasPlaceholders: false, taskCount: 0 }
      const hasTasks = tasks.taskCount > 0
      features.push({
        id,
        requirements: spec.requirements,
        userStories: spec.userStories,
        testTasks: tasks.testTasks,
        needsClarification: spec.needsClarification,
        hasTasks,
      })

      // gate 1: 未解決の [NEEDS CLARIFICATION]（Spec-Kit clarify は助言。ここで CI を落とす）
      if (spec.needsClarification > 0) {
        violations.push({
          power: 'specification',
          code: 'SPECKIT_UNRESOLVED_CLARIFICATION',
          severity: 'error',
          subject: id,
          message: `${id}: 未解決の [NEEDS CLARIFICATION] が ${spec.needsClarification} 件（実装前に解消すべき）`,
        })
      }

      // gate 2: 未置換のテンプレ・プレースホルダ（tasks.md が生成されたが未記入）
      if (tasks.hasPlaceholders) {
        violations.push({
          power: 'specification',
          code: 'SPECKIT_PLACEHOLDER_TASKS',
          severity: 'error',
          subject: id,
          message: `${id}: tasks.md に未置換のプレースホルダ（[name]/[entity] 等のパス）が残っている`,
        })
      }

      // gate 3: 完了済み([x])テストタスクの proof が実在しない（書いて完了扱いだが未作成）
      // 未着手([ ])のテストは TDD の正常な初期状態なので broken-proof にしない。
      for (const t of tasks.testTasks) {
        if (t.done && !existsFn(t.filePath)) {
          violations.push({
            power: 'specification',
            code: 'SPECKIT_BROKEN_TEST_PROOF',
            severity: 'error',
            subject: `${id}/${t.taskId}`,
            file: t.filePath,
            message: `${id}: 完了済みテストタスク ${t.taskId} の proof "${t.filePath}" が存在しない`,
          })
        }
      }

      // fail-closed: タスクを生む内容（FR/NFR or ユーザーストーリー）があるのに tasks.md にタスクが無い
      const taskBearing =
        spec.requirements.some((r) => /^(?:FR|NFR)-/.test(r)) || spec.userStories.length > 0
      if (taskBearing && !hasTasks) {
        violations.push({
          power: 'specification',
          code: 'SPECKIT_NO_TASKS',
          severity: 'error',
          subject: id,
          message: `${id}: 要件/ストーリーがあるのに tasks.md にタスクが無い（検査不能＝fail-closed）`,
        })
      }

      // gate 4: P1（最重要）ユーザーストーリーにテストが無い（warn / 段階導入）
      const storiesWithTests = new Set(tasks.testTasks.map((t) => t.story).filter(Boolean))
      for (const us of spec.userStories) {
        if (us.priority === 'P1' && !storiesWithTests.has(us.id)) {
          violations.push({
            power: 'specification',
            code: 'SPECKIT_P1_UNTESTED',
            severity: 'warn',
            subject: `${id}/${us.id}`,
            message: `${id}: P1 ユーザーストーリー ${us.id}「${us.title}」にテストタスクが無い`,
          })
        }
      }
    }
  }

  // fail-closed: 検査対象がゼロ（specs/ が無い／spec.md が1つも無い）。黙って PASS させない。
  if (specCount === 0) {
    violations.push({
      power: 'specification',
      code: 'SPECKIT_NO_SPECS',
      severity: 'error',
      subject: projectDir,
      message: `${projectDir}: specs/<NNN>/spec.md が見つからない（検査対象ゼロ＝fail-closed。DIR/パスを確認）`,
    })
  }

  return { projectDir, features, violations, constitutionPrinciples: parseConstitution(root) }
}
