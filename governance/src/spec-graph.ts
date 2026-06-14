// Specification Provenance Graph: feature→requirement→proof を機械可読に追跡する。
// 「この機能は何の仕様に基づき、どのテストで証明されているか」「変更したら何に影響するか」。
//
// 重要な設計方針: 表が壊れたら「黙って通す(fail-open)」のではなく「error で落とす(fail-closed)」。
// 統治ゲートが自分の検査を静かに無効化することを許さない。
import { existsSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import type { AcceptanceCondition, SpecFeature, SpecGraph, Violation } from './types'
import { REPO_ROOT, readRel } from './util'

const REQ_RE = /\b(?:FR|NFR|SEC)-\d{3}\b/g
const TEST_PATH_RE = /`([^`]*\.test\.[a-z]+)`/g
const MANUAL_RE = /手動|未実装|manual|TBD/i

// 列ヘッダの別名（正規化済み: 小文字・空白/全角空白除去）。表記揺れ・日英差・列順に耐える。
const ID_ALIASES = ['条件id', 'criterionid']
const REQ_ALIASES = ['要件', '項目', 'requirement', 'req']
const PRIO_ALIASES = ['優先', 'priority']
const LAYER_ALIASES = ['テスト階層', '階層', 'testlevel', 'level']
const PROOF_ALIASES = ['実テスト', '証跡', 'エビデンス', 'proof', 'evidence']

interface Columns {
  id: number
  req: number
  prio: number
  layer: number
  proof: number
}

export interface TraceabilityParse {
  conditions: AcceptanceCondition[]
  headerCount: number
  defects: { table: number; message: string }[]
}

function unique(values: string[]): string[] {
  return [...new Set(values)]
}

function matchAll(text: string, re: RegExp): string[] {
  return [...text.matchAll(re)].map((m) => m[1])
}

function normHeader(s: string): string {
  return s.replace(/[\s　]/g, '').toLowerCase()
}

function findCol(cells: string[], aliases: string[]): number {
  return cells.findIndex((c) => {
    const n = normHeader(c)
    return aliases.some((a) => n.includes(a))
  })
}

// acceptance.md のトレーサビリティ表を読む。複数表・表間の空行・列の表記揺れに耐える。
// 表が検出できない/必須列が欠ける場合は defects として返し、上位で fail-closed にする。
export function parseTraceability(md: string): TraceabilityParse {
  const conditions: AcceptanceCondition[] = []
  const defects: { table: number; message: string }[] = []
  let headerCount = 0
  let cols: Columns | null = null

  for (const line of md.split('\n')) {
    if (!line.trim().startsWith('|')) {
      // 表の外に出た → 次の表を読めるようリセット（break しない＝複数表に対応）
      cols = null
      continue
    }
    const cells = line
      .split('|')
      .slice(1, -1)
      .map((c) => c.trim())
    if (cells.every((c) => /^[-:\s]*$/.test(c))) continue // 区切り行

    if (cols === null) {
      const idIdx = findCol(cells, ID_ALIASES)
      if (idIdx === -1) continue // トレーサビリティ表ではない（別の表）→ 行を無視
      if (/^AC-/i.test(cells[idIdx] ?? '')) continue // ヘッダ無しのデータ行は読まない
      headerCount += 1
      cols = {
        id: idIdx,
        req: findCol(cells, REQ_ALIASES),
        prio: findCol(cells, PRIO_ALIASES),
        layer: findCol(cells, LAYER_ALIASES),
        proof: findCol(cells, PROOF_ALIASES),
      }
      const missing: string[] = []
      if (cols.req === -1) missing.push('要件')
      if (cols.prio === -1) missing.push('優先度')
      if (cols.proof === -1) missing.push('実テスト')
      if (missing.length > 0) {
        defects.push({ table: headerCount, message: `必須列が見つからない: ${missing.join(', ')}` })
      }
      continue
    }

    const at = (i: number) => (i >= 0 && i < cells.length ? cells[i] : '')
    const id = at(cols.id)
    if (!/^AC-/.test(id)) continue
    conditions.push({
      id,
      requirementRef: at(cols.req),
      priority: at(cols.prio),
      layer: at(cols.layer),
      proof: at(cols.proof),
    })
  }

  return { conditions, headerCount, defects }
}

// 1 feature の評価（純粋関数）。exists でテストパスの実在を注入し、ユニットテスト可能にする。
export function evaluateFeature(
  feature: SpecFeature,
  parse: TraceabilityParse,
  exists: (rel: string) => boolean,
): Violation[] {
  const { id, requirements } = feature
  const violations: Violation[] = []

  // fail-closed #1: 表自体の構造欠陥（必須列欠落）
  for (const def of parse.defects) {
    violations.push({
      power: 'specification',
      code: 'SPEC_TABLE_MALFORMED',
      severity: 'error',
      subject: `${id}/table${def.table}`,
      ruleId: 'R004',
      message: `${id}: トレーサビリティ表#${def.table} の${def.message}（検査不能＝fail-closed）`,
    })
  }
  // fail-closed #2: 要件があるのにトレーサビリティ表が見つからない（黙ってスキップさせない）
  if (parse.headerCount === 0 && requirements.length > 0) {
    violations.push({
      power: 'specification',
      code: 'SPEC_NO_TRACEABILITY',
      severity: 'error',
      subject: id,
      ruleId: 'R004',
      message: `${id}: spec に要件があるのに acceptance.md にトレーサビリティ表が無い（検査不能＝fail-closed）`,
    })
  }

  const reqSet = new Set(requirements)
  const coveredReqs = new Set<string>()

  for (const cond of feature.conditions) {
    for (const rq of unique(cond.requirementRef.match(REQ_RE) ?? [])) {
      coveredReqs.add(rq)
      if (!reqSet.has(rq)) {
        violations.push({
          power: 'specification',
          code: 'SPEC_DANGLING_REQUIREMENT',
          severity: 'error',
          subject: `${id}/${cond.id}`,
          ruleId: 'R004',
          message: `${id}: 受け入れ条件 ${cond.id} が参照する要件 ${rq} が spec.md に存在しない`,
        })
      }
    }

    // proof = バックティックで囲まれたテストパス（機械実行可能な proof）のみを認める。
    const proofs = matchAll(cond.proof, TEST_PATH_RE)
    for (const p of proofs) {
      if (!exists(p)) {
        violations.push({
          power: 'specification',
          code: 'SPEC_BROKEN_PROOF',
          severity: 'error',
          subject: `${id}/${cond.id}`,
          ruleId: 'R001',
          file: p,
          message: `${id}: 受け入れ条件 ${cond.id} の proof "${p}" が存在しない（リンク切れ）`,
        })
      }
    }

    // MUST は「機械実行可能な proof（実在するテストパス）」を要する。
    // proof 欄が空・ダッシュ・出典名(例 'shared')などプローズだけ＝proof 無しとみなす（手動は除外）。
    const manual = MANUAL_RE.test(cond.layer) || MANUAL_RE.test(cond.proof)
    const hasExecutableProof = proofs.some((p) => exists(p))
    if (cond.priority.toUpperCase().includes('MUST') && !manual && !hasExecutableProof) {
      violations.push({
        power: 'specification',
        code: 'SPEC_MUST_UNPROVEN',
        severity: 'error',
        subject: `${id}/${cond.id}`,
        ruleId: 'R001',
        message: `${id}: MUST 条件 ${cond.id} に機械実行可能な proof(テスト) が無い（proof="${cond.proof}"）`,
      })
    }
  }

  // 未カバー要件（警告 / 次の宿題 / 非ブロッキング）
  for (const rq of requirements) {
    if (!coveredReqs.has(rq)) {
      violations.push({
        power: 'specification',
        code: 'SPEC_UNCOVERED_REQUIREMENT',
        severity: 'warn',
        subject: `${id}/${rq}`,
        ruleId: 'R004',
        message: `${id}: 要件 ${rq} を参照する受け入れ条件が無い（未証明）`,
      })
    }
  }

  return violations
}

export function buildSpecGraph(): SpecGraph {
  const features: SpecFeature[] = []
  const violations: Violation[] = []
  const specsDir = join(REPO_ROOT, 'specs')
  if (!existsSync(specsDir)) return { features, violations }

  const dirs = readdirSync(specsDir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && d.name !== '_template')
    .map((d) => d.name)
    .sort()

  const exists = (rel: string) => existsSync(join(REPO_ROOT, rel))

  for (const id of dirs) {
    const specRel = `specs/${id}/spec.md`
    const accRel = `specs/${id}/acceptance.md`
    if (!existsSync(join(REPO_ROOT, specRel)) || !existsSync(join(REPO_ROOT, accRel))) continue

    const requirements = unique(readRel(specRel).match(REQ_RE) ?? [])
    const parse = parseTraceability(readRel(accRel))
    const feature: SpecFeature = { id, requirements, conditions: parse.conditions }
    features.push(feature)
    violations.push(...evaluateFeature(feature, parse, exists))
  }

  return { features, violations }
}
