// 統治ゲートのオーケストレーション。
// 立法↔司法（Authority Graph）＋ 決定性司法 ＋ 仕様(Spec Graph/完全性) ＋ SSOT ＋ 意味司法 を統合判定する。
import { buildAuthorityGraph } from './authority-graph'
import {
  ENGINE_CHECK_META,
  loadConstitution,
  loadDeterministicChecks,
  loadRules,
  loadSsotManifest,
} from './load'
import { runDeterministicChecks } from './run-checks'
import { SEMANTIC_CHECK_META, runSemanticChecks } from './semantic'
import { checkSpecCompleteness } from './spec-completeness'
import { buildSpecGraph } from './spec-graph'
import { checkSsot } from './ssot'
import type { GovernReport, Rule, Violation } from './types'

const MANUAL_RE = /手動|未実装|manual/i

function isMustNonManual(priority: string, layer: string, proof: string): boolean {
  return priority.toUpperCase().includes('MUST') && !MANUAL_RE.test(`${layer} ${proof}`)
}

// 立法が「効いている」= 決定性 or spec-graph or ssot の司法に束縛されている（意味司法のみは未評価なので除く）。
function isEnforced(rule: Rule): boolean {
  return rule.checks.some((c) => c.kind !== 'semantic')
}

export async function govern(): Promise<GovernReport> {
  const constitution = loadConstitution()
  const rules = loadRules()
  const detChecks = loadDeterministicChecks()
  const ssotManifest = loadSsotManifest()

  const checkMetas = [...detChecks.map((c) => c.meta), ...ENGINE_CHECK_META, ...SEMANTIC_CHECK_META]
  const authorityGraph = buildAuthorityGraph(constitution, rules, checkMetas)
  const specGraph = buildSpecGraph()
  const detViolations = await runDeterministicChecks(rules, detChecks)
  const completenessViolations = checkSpecCompleteness()
  const ssotViolations = checkSsot(ssotManifest)
  const semantic = runSemanticChecks()

  const violations: Violation[] = [
    ...authorityGraph.violations,
    ...detViolations,
    ...specGraph.violations,
    ...completenessViolations,
    ...ssotViolations,
    ...semantic.violations,
  ]
  const errors = violations.filter((v) => v.severity === 'error')
  const warnings = violations.filter((v) => v.severity === 'warn')

  const activeRules = rules.filter((r) => r.status === 'active')
  const conditions = specGraph.features.flatMap((f) => f.conditions)
  const mustNonManual = conditions.filter((c) => isMustNonManual(c.priority, c.layer, c.proof))
  const unproven = violations.filter((v) => v.code === 'SPEC_MUST_UNPROVEN').length

  return {
    ok: errors.length === 0,
    violations,
    errors,
    warnings,
    authorityGraph,
    specGraph,
    counts: {
      constitution: constitution.principles.length,
      rules: activeRules.length,
      checks: checkMetas.length,
      features: specGraph.features.length,
    },
    semantic: { enabled: semantic.enabled, registered: semantic.registered },
    metrics: {
      enforcedRules: activeRules.filter(isEnforced).length,
      mustTotal: mustNonManual.length,
      mustProven: mustNonManual.length - unproven,
      manualConditions: conditions.filter((c) => MANUAL_RE.test(`${c.layer} ${c.proof}`)).length,
    },
  }
}
