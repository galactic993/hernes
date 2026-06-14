---
name: acceptance-test-designer
description: 仕様と設計書から受け入れ条件・トレーサビリティ・失敗するテストを作る。TDDで実装前に使う。
---

# 受け入れテスト設計スキル

## 目的

仕様を、実行可能（またはレビュー可能）なテストへ変換する。

## 入力

- `specs/<feature>/spec.md`
- `specs/<feature>/questions.md`
- `design/rendered/` 配下の設計書画像（項目記述書・メッセージ一覧）
- 既存のテスト
- `AGENTS.md`

## 出力

- `specs/<feature>/acceptance.md`
- `specs/<feature>/test-plan.md`
- 各パッケージ配下のテストファイル（`packages/*/test`, `apps/*/test`）

## 手順

1. 仕様と設計書画像を読む。
2. Given / When / Then 形式の受け入れ条件を作る。
3. 各条件を要件ID・項目No・EVENT No に対応づける（トレーサビリティ）。
4. 適切なテスト階層を選ぶ：unit（`@hernes/shared` のバリデーション）/ integration（Hono の `app.request`）/ e2e（`e2e/` の Playwright）/ 手動レビュー。
5. 実装より前にテストを書く。未実装時に「正しい理由で」失敗すること。
6. 既存テストを弱めない。本番コードは変更しない。
7. 項目記述書の制御内容・メッセージは `@hernes/shared` を単一の出典とし、テストはそのメッセージ定数を検証する（文字列の二重定義をしない）。

## 出力要件

カバレッジ要約を含める：
- 自動テストで担保した条件
- 手動検証する条件
- 担保しない条件とその理由
