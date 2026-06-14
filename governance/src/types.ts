// 三権分立（立法/司法/行政）統治の型定義。
// 立法 = rules（憲法に準拠する具体規範） / 司法 = checks（適合を裁く） / 行政 = harness（実行）。

export type Severity = 'error' | 'warn'

export type CheckKind = 'deterministic' | 'spec-graph' | 'ssot' | 'semantic'

export type Power =
  | 'constitution'
  | 'legislative'
  | 'judicial'
  | 'executive'
  | 'specification'
  | 'ssot'

// --- 憲法（最上位 SSOT） ---
export interface ConstitutionPrinciple {
  id: string
  name: string
  statement: string
}

export interface Constitution {
  version: number
  title: string
  amendableBy: string
  principles: ConstitutionPrinciple[]
}

// --- 管轄（越境司法の検出に使う） ---
export interface Jurisdiction {
  include: string[]
  exclude?: string[]
}

// --- 立法（rule） ---
export interface RuleCheckBinding {
  kind: CheckKind
  id: string
}

export interface Rule {
  id: string
  title: string
  constitution: string[]
  statement: string
  severity: Severity
  status: 'active' | 'draft' | 'retired'
  jurisdiction: Jurisdiction
  checks: RuleCheckBinding[]
}

// --- 司法（check） ---
export interface CheckMeta {
  id: string
  kind: CheckKind
  title: string
  jurisdiction: Jurisdiction
}

export interface Finding {
  file: string
  line?: number
  message: string
}

export interface CheckContext {
  // ルールの管轄に絞り込んだファイル一覧（repo 相対 / POSIX）
  filesIn: () => string[]
  // repo 相対パスを読む
  readRel: (rel: string) => string
}

export interface DeterministicCheck {
  meta: CheckMeta
  run: (ctx: CheckContext) => Finding[] | Promise<Finding[]>
}

// --- SSOT マニフェスト ---
export interface SsotManifest {
  ssot: string[]
  derived: string[]
}

// --- 違反 ---
export interface Violation {
  power: Power
  code: string
  severity: Severity
  subject: string
  message: string
  ruleId?: string
  constitution?: string[]
  file?: string
  line?: number
}

// --- 派生データ: Authority Provenance Graph（立法↔司法の由来） ---
export type AuthorityNodeType = 'constitution' | 'rule' | 'check'
export type AuthorityEdgeKind = 'complies' | 'enforced-by'

export interface AuthorityNode {
  id: string
  type: AuthorityNodeType
  label: string
}

export interface AuthorityEdge {
  from: string
  to: string
  kind: AuthorityEdgeKind
}

export interface AuthorityGraph {
  nodes: AuthorityNode[]
  edges: AuthorityEdge[]
  violations: Violation[]
}

// --- 派生データ: Specification Provenance Graph（feature→requirement→proof） ---
export interface AcceptanceCondition {
  id: string
  requirementRef: string
  priority: string
  layer: string
  proof: string
}

export interface SpecFeature {
  id: string
  requirements: string[]
  conditions: AcceptanceCondition[]
}

export interface SpecGraph {
  features: SpecFeature[]
  violations: Violation[]
}

// --- govern の総合結果 ---
export interface GovernReport {
  ok: boolean
  violations: Violation[]
  errors: Violation[]
  warnings: Violation[]
  authorityGraph: AuthorityGraph
  specGraph: SpecGraph
  counts: {
    constitution: number
    rules: number
    checks: number
    features: number
  }
  // 意味(LLM)司法の状態
  semantic: {
    enabled: boolean
    registered: number
  }
  // AI 実行密度の proxy（統治カバレッジ）。Agent が人手なしに自走できる度合いの近似。
  metrics: {
    enforcedRules: number
    mustTotal: number
    mustProven: number
    manualConditions: number
  }
}
