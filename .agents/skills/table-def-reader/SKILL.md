---
name: table-def-reader
description: Excelテーブル定義書をPDF/画像化して視覚的に読み取り、Drizzle(@hernes/db)スキーマとTS型・共有列挙値へ落とす。
---

# テーブル定義書読み取りスキル（テーブル定義書 → スキーマ）

## 目的

Excel テーブル定義書を、`@hernes/db` の Drizzle スキーマ（PostgreSQL）と TypeScript 型へ変換する。
画面設計書と同様、**画像化して視覚的に読む**（結合セル・備考の列挙値・色を取りこぼさないため）。

## 入力

- 対象のテーブル定義書(.xlsx)

## 出力

- `design/rendered/<doc>/page-*.png`
- `packages/db/src/schema/<table>.ts`（+ `schema/index.ts` へ re-export）
- 列挙値は `packages/shared/src/` の定数として切り出す

## 手順

1. `scripts/render-design.sh <xlsx>` で画像化し、**テーブル一覧**と各テーブルシートを読む。
2. 各列の **論理名 / 物理名 / データ型 / 桁数 / Not Null / PK / UK / FK / Default / 備考** を読み取る。
3. 物理名・型・制約を `drizzle-orm/pg-core` で 1:1 に表現する：
   - `BIGSERIAL` → `bigserial(..).primaryKey()` / `CHAR(2)` → `char(.., { length: 2 })`
   - `DECIMAL(12,0)` → `decimal(.., { precision: 12, scale: 0 })`
   - `Default '00'` → `.default('00')` / `CURRENT_TIMESTAMP` → `.default(sql\`CURRENT_TIMESTAMP\`)`
4. Default の列挙値（例: ステータス `00:未着手 / 10:制作見積中 …`）は `@hernes/shared` の定数として切り出し、**スキーマ・バリデーション・UI で共有**する（直書き禁止）。
5. FK・cascade は備考に従う。

## 品質基準

- 物理名・型・桁数・Not Null・PK / FK が定義書と一致
- 列挙値が `@hernes/shared` に単一定義され、複数箇所に直書きされていない
- `pnpm typecheck` が通る（型として成立している）
