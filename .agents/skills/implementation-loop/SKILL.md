---
name: implementation-loop
description: specs/<feature>/tasks.md の次の未完了タスクをTDDで実装し、検証して証跡を更新する。
---

# 実装ループスキル

## 目的

小さく検証可能なタスクを一度に1つだけ実装する。

## 入力

- `AGENTS.md`
- `docs/constitution.md`
- `specs/<feature>/spec.md`
- `specs/<feature>/acceptance.md`
- `specs/<feature>/plan.md`
- `specs/<feature>/tasks.md`
- 現在のテスト結果

## 出力

- コード変更（`apps/*` または `packages/*`）
- `specs/<feature>/evidence.md` の更新
- `specs/<feature>/tasks.md` の更新

## 手順

1. 次の未完了タスクを特定する。
2. 対応する受け入れ条件を確認する。
3. 既存テストを確認する。
4. テストが無ければ先にテストを書く。
5. 最小の本番コード変更を実装する。
   - メッセージ・列挙値・バリデーション規則は `@hernes/shared` を単一の出典とし、直書きしない。
   - バックエンドは Hono、フロントは React。両者で同じ shared スキーマを使う。
6. タスク固有のテストを実行する（`pnpm --filter <pkg> test` など）。
7. `make verify`（= `pnpm verify`）で全体検証する。
8. evidence.md に「変更ファイル / 実行コマンド / 合否 / 残課題」を記録する。
9. 検証が通った場合のみタスクを完了にする。

## 厳守

- 検証を通すためにテストを削除しない。
- 無関係なリファクタをしない。
- spec を更新せずに公開挙動を変えない。
- spec とテストが矛盾したら停止して報告する。
