# アーキテクチャ

> `plan.md` 生成エージェントがここを参照して整合性を取る。実装が進むたび更新し、コードと乖離させない（憲法6）。

## システム概要

人手の Excel 設計書（管理会計システムの画面設計書・テーブル定義書）を起点に、
TypeScript モノレポで Web アプリを実装する。元設計は Laravel/PHP 表記だが、本リポジトリでは **Hono + React** で作り直す。

## 技術スタック

| レイヤ | 採用 | 備考 |
|---|---|---|
| パッケージ管理 | pnpm（ワークスペース） | `apps/*`, `packages/*` |
| 言語 | TypeScript（strict） | `tsconfig.base.json` を各パッケージが extends |
| バックエンド | Hono + `@hono/node-server` | `apps/backend` |
| フロントエンド | React + Vite | `apps/frontend` |
| 共有 | `@hernes/shared`（zod） | メッセージ・列挙値・バリデーション規則の単一出典 |
| DB スキーマ | `@hernes/db`（Drizzle / PostgreSQL） | テーブル定義書から生成 |
| Lint/Format | Biome | `biome.json` |
| テスト | Vitest（unit/integration）+ Playwright（e2e, `e2e/`） | |
| 型 | tsc `--noEmit`（各パッケージ） | |

## モジュールマップ

```text
apps/
  backend/    Hono API。routes/ がイベント記述書(EVENT No)に対応
  frontend/   React。features/<画面>/ が画面設計書に対応
packages/
  shared/     画面設計書「項目記述書/メッセージ一覧」由来の zod スキーマ・メッセージ・列挙値
  db/         テーブル定義書由来の Drizzle スキーマ
```

## 設計書 → コードの対応規約

| 設計書の要素 | 落とし先 |
|---|---|
| 項目記述書 制御内容（必須/桁数/有効値/形式） | `packages/shared/src/validation/*`（zod）|
| 項目記述書 メッセージ列 / メッセージ一覧 | `packages/shared/src/messages.ts` |
| テーブル定義書 列定義 | `packages/db/src/schema/*`（Drizzle）|
| Default の列挙値（ステータス等） | `packages/shared/src/status.ts` 等の定数 |
| イベント記述書 EVENT No | `apps/backend/src/routes/*` のハンドラ / フロントのイベント |
| 制御区分 JavaScript / PHP | フロント(React) / サーバ(Hono)。**同じ shared スキーマを共有** |

## 横断的関心事

- **認可:** イベント記述書の権限判定（例 `editorial.prod-quote.create`）をミドルウェアで検証し、テストで担保。
- **観測可能性:** 重要フロー（検索・登録）にログ/メトリクス。個人情報は出さない。
- **設定/秘密情報:** `.env`（`.env.example` 参照）。

## 制約・不変条件

- メッセージ・列挙値・バリデーションは `@hernes/shared` 単一定義（直書き禁止）。
- `make verify` が全 AI 変更の合否判定器。

## 意思決定ログ

[decision-log/](decision-log/) を参照。
