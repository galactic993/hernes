import { describe, expect, it } from 'vitest'
import { run as noHardcoded } from '../checks/deterministic/no-hardcoded-screen-messages'
import { run as noSecret } from '../checks/deterministic/no-secret-in-logs'
import { run as verifyGate } from '../checks/deterministic/verify-gate-present'
import type { CheckContext } from '../src/types'

function ctxFor(files: Record<string, string>): CheckContext {
  return { filesIn: () => Object.keys(files), readRel: (r) => files[r] ?? '' }
}

describe('no-secret-in-logs', () => {
  it('複数行に折り返したログ呼び出しの秘密値を検知する（フォーマッタ耐性）', () => {
    const src = ['logger.error(', "  'boom',", '  process.env.DATABASE_URL,', ')'].join('\n')
    const findings = noSecret(ctxFor({ 'apps/x.ts': src }))
    expect(findings).toHaveLength(1)
    expect(findings[0].message).toContain('DATABASE_URL')
  })

  it('より長い安全な識別子(APP_SECRET_HEADER)を誤検知しない（語境界）', () => {
    const src = 'logger.info(`header=${APP_SECRET_HEADER}`)'
    expect(noSecret(ctxFor({ 'apps/x.ts': src }))).toEqual([])
  })

  it('コメント行のログは検知しない', () => {
    const src = '// console.log(process.env.DATABASE_URL) は意図的に削除済み'
    expect(noSecret(ctxFor({ 'apps/x.ts': src }))).toEqual([])
  })

  it('秘密値を含まないログは検知しない', () => {
    expect(noSecret(ctxFor({ 'apps/x.ts': "console.log('listening on 8080')" }))).toEqual([])
  })
})

describe('no-hardcoded-screen-messages', () => {
  it('重複値カタログでも 1 行 1 件に抑える（重複ノイズ排除）', () => {
    const src = "const m = '入力内容に誤りがあります。各項目をご確認ください'"
    const findings = noHardcoded(ctxFor({ 'apps/x.ts': src }))
    expect(findings).toHaveLength(1)
  })

  it('カタログに無い文言は検知しない', () => {
    expect(noHardcoded(ctxFor({ 'apps/x.ts': "const m = 'こんにちは'" }))).toEqual([])
  })
})

describe('verify-gate-present', () => {
  const makefile = 'verify:\n\tpnpm verify\n'

  it('echo で空洞化した verify を検知する', () => {
    const pkg = JSON.stringify({ scripts: { verify: 'echo "lint typecheck test skipped"' } })
    const findings = verifyGate(ctxFor({ 'package.json': pkg, Makefile: makefile }))
    expect(findings.length).toBeGreaterThanOrEqual(3)
  })

  it('lint/typecheck/test を pnpm 実行する verify は通る', () => {
    const pkg = JSON.stringify({
      scripts: {
        verify: 'pnpm lint && pnpm typecheck && pnpm test',
        lint: 'biome check .',
        typecheck: 'tsc',
        test: 'vitest run',
      },
    })
    expect(verifyGate(ctxFor({ 'package.json': pkg, Makefile: makefile }))).toEqual([])
  })
})
