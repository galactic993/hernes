# ADR-0003: スタックは Hono + React + TypeScript の pnpm モノレポ

- Status: Accepted
- Date: 2026-06-13
- Deciders: 開発責任者

## Context

元設計は Laravel/PHP（画面設計書のI/O図・制御区分PHPに表れる）。本リポジトリでは作り直す。

## Decision

- **モノレポ**: pnpm ワークスペース（`apps/*`, `packages/*`）。
- **バックエンド**: Hono（`@hono/node-server`）。`apps/backend`。
- **フロントエンド**: React + Vite。`apps/frontend`。
- **共有**: `@hernes/shared`（zod）にメッセージ・列挙値・バリデーション規則を単一定義。フロント/サーバが同じスキーマを使う。
- **DB**: `@hernes/db`（Drizzle / PostgreSQL）。テーブル定義書から生成。
- **品質**: Biome（lint/format）+ tsc（型）+ Vitest（test）。`make verify` で統合。

## Consequences

- 設計書の制御区分 JavaScript/PHP を、フロント/サーバの**同一バリデーションスキーマ**へ統合できる（二重定義の排除）。
- TypeScript で設計書の型・列挙値を端から端まで通せる。
- 元の Laravel 実装とは1:1でないため、移植時は「挙動」をテストで固定し、フレームワーク差は許容する。
