// 立法/司法/SSOT マニフェストのロード。司法（決定性）は明示登録（checks/deterministic/index）。
import { readdirSync } from 'node:fs'
import { join } from 'node:path'
import { parse } from 'yaml'
import { DETERMINISTIC_CHECKS } from '../checks/deterministic/index'
import type { CheckMeta, Constitution, DeterministicCheck, Rule, SsotManifest } from './types'
import { GOV_DIR, readRel } from './util'

export function loadConstitution(): Constitution {
  return parse(readRel('governance/constitution.yaml')) as Constitution
}

export function loadRules(): Rule[] {
  const dir = join(GOV_DIR, 'rules')
  return readdirSync(dir)
    .filter((f) => f.endsWith('.yaml'))
    .sort()
    .map((f) => parse(readRel(`governance/rules/${f}`)) as Rule)
}

export function loadSsotManifest(): SsotManifest {
  return parse(readRel('governance/ssot.yaml')) as SsotManifest
}

export function loadDeterministicChecks(): DeterministicCheck[] {
  return DETERMINISTIC_CHECKS
}

// 行政(engine)が提供する司法。rules がこれらに束縛することで「司法なき立法」を防ぐ。
export const ENGINE_CHECK_META: CheckMeta[] = [
  {
    id: 'spec-proof-integrity',
    kind: 'spec-graph',
    title: '受け入れ条件(MUST)の proof 整合（リンク切れ・未証明を検知）',
    jurisdiction: { include: ['specs/**'] },
  },
  {
    id: 'spec-traceability',
    kind: 'spec-graph',
    title: '要件→条件→テストの接続整合（dangling 要件を検知）',
    jurisdiction: { include: ['specs/**'] },
  },
  {
    id: 'ssot-derived-separation',
    kind: 'ssot',
    title: 'SSOT と派生データの分離',
    jurisdiction: { include: ['**'] },
  },
  {
    id: 'spec-user-value',
    kind: 'spec-graph',
    title: 'ユーザー価値の宣言（intent の user_problem / desired_outcome）',
    jurisdiction: { include: ['specs/**'] },
  },
  {
    id: 'spec-decomposition',
    kind: 'spec-graph',
    title: '小さな変更への分解（tasks.md）',
    jurisdiction: { include: ['specs/**'] },
  },
  {
    id: 'spec-observability',
    kind: 'spec-graph',
    title: '観測可能性の宣言（spec の NFR）',
    jurisdiction: { include: ['specs/**'] },
  },
]
