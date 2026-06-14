import { sql } from 'drizzle-orm'
import {
  bigint,
  bigserial,
  char,
  date,
  decimal,
  pgTable,
  smallint,
  timestamp,
  varchar,
} from 'drizzle-orm/pg-core'

/**
 * prod_quots（論理名: 制作見積）
 * 出典: 編-テーブル定義書 / 「制作見積」シート。物理名・データ型・桁数・PK/FK・Default を写経。
 *
 * | No | 論理名               | 物理名             | 型            | 制約                         |
 * |----|----------------------|--------------------|---------------|------------------------------|
 * | 1  | 制作見積id           | prod_quot_id       | BIGSERIAL     | PK, UK, 自動採番             |
 * | 2  | 見積id               | quot_id            | BIGINT        | FK(見積.quot_id) cascade     |
 * | 3  | 基準価格             | cost               | DECIMAL(12,0) | NOT NULL, 12桁以内・少数なし |
 * | 4  | 制作見積書アップ先   | quot_doc_path      | VARCHAR(255)  |                              |
 * | 5  | 関連資料             | reference_doc_path | VARCHAR(255)  |                              |
 * | 6  | 営業提出日           | submission_on      | DATE          |                              |
 * | 7  | ステータス           | prod_quot_status   | CHAR(2)       | NOT NULL, Default '00'       |
 * | 8  | バージョン           | version            | SMALLINT      | NOT NULL, Default 1          |
 * | 9  | 作成日               | created_at         | TIMESTAMP(0)  | NOT NULL, CURRENT_TIMESTAMP  |
 * | 10 | 更新日               | updated_at         | TIMESTAMP(0)  | NOT NULL, CURRENT_TIMESTAMP  |
 */
export const prodQuots = pgTable('prod_quots', {
  prodQuotId: bigserial('prod_quot_id', { mode: 'bigint' }).primaryKey(),
  quotId: bigint('quot_id', { mode: 'bigint' }).notNull(),
  cost: decimal('cost', { precision: 12, scale: 0 }).notNull(),
  quotDocPath: varchar('quot_doc_path', { length: 255 }),
  referenceDocPath: varchar('reference_doc_path', { length: 255 }),
  submissionOn: date('submission_on'),
  prodQuotStatus: char('prod_quot_status', { length: 2 }).notNull().default('00'),
  version: smallint('version').notNull().default(1),
  createdAt: timestamp('created_at', { precision: 0 }).notNull().default(sql`CURRENT_TIMESTAMP`),
  updatedAt: timestamp('updated_at', { precision: 0 }).notNull().default(sql`CURRENT_TIMESTAMP`),
})

export type ProdQuot = typeof prodQuots.$inferSelect
export type NewProdQuot = typeof prodQuots.$inferInsert
