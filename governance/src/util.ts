// 依存ゼロのパス/glob/ファイル走査ユーティリティ。
import { existsSync, readFileSync, readdirSync } from 'node:fs'
import { dirname, join, relative, sep } from 'node:path'
import { fileURLToPath } from 'node:url'
import type { Jurisdiction } from './types'

// このファイルは governance/src/util.ts。../.. が repo ルート。cwd に依存しない。
export const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
export const GOV_DIR = join(REPO_ROOT, 'governance')

const ALWAYS_SKIP_DIR = new Set(['node_modules', '.git', 'dist', '.turbo', 'coverage'])
const ALWAYS_SKIP_PREFIX = ['governance/graph', 'design/rendered']

export function toPosix(p: string): string {
  return p.split(sep).join('/')
}

// 最小 glob → RegExp。`**`（任意階層・スラッシュ含む）, `**/`（0個以上の階層）, `*`（区切り以外）, `?`。
export function globToRegExp(glob: string): RegExp {
  let re = '^'
  let i = 0
  while (i < glob.length) {
    const c = glob[i]
    if (c === '*') {
      if (glob[i + 1] === '*') {
        i += 2
        if (glob[i] === '/') {
          re += '(?:.*/)?'
          i += 1
        } else {
          re += '.*'
        }
      } else {
        re += '[^/]*'
        i += 1
      }
    } else if (c === '?') {
      re += '[^/]'
      i += 1
    } else if ('.+^${}()|[]\\'.includes(c)) {
      re += `\\${c}`
      i += 1
    } else {
      re += c
      i += 1
    }
  }
  return new RegExp(`${re}$`)
}

export function matchesAny(path: string, globs: string[]): boolean {
  return globs.some((g) => globToRegExp(g).test(path))
}

export function inJurisdiction(path: string, jur: Jurisdiction): boolean {
  if (!matchesAny(path, jur.include)) return false
  if (jur.exclude && matchesAny(path, jur.exclude)) return false
  return true
}

function walk(absDir: string, acc: string[]): void {
  for (const entry of readdirSync(absDir, { withFileTypes: true })) {
    if (entry.isDirectory() && ALWAYS_SKIP_DIR.has(entry.name)) continue
    const abs = join(absDir, entry.name)
    const rel = toPosix(relative(REPO_ROOT, abs))
    if (ALWAYS_SKIP_PREFIX.some((p) => rel === p || rel.startsWith(`${p}/`))) continue
    if (entry.isDirectory()) walk(abs, acc)
    else acc.push(rel)
  }
}

let cachedFiles: string[] | null = null
export function allFiles(): string[] {
  if (!cachedFiles) {
    const acc: string[] = []
    walk(REPO_ROOT, acc)
    acc.sort()
    cachedFiles = acc
  }
  return cachedFiles
}

export function filesIn(jur: Jurisdiction): string[] {
  return allFiles().filter((f) => inJurisdiction(f, jur))
}

export function readRel(rel: string): string {
  return readFileSync(join(REPO_ROOT, rel), 'utf8')
}

export function existsRel(rel: string): boolean {
  return existsSync(join(REPO_ROOT, rel))
}
