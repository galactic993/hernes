---
name: release-reviewer
description: 完了したフィーチャを、仕様・受け入れ条件・テスト・証跡・リスク・リリース準備の観点でレビューする。
---

# リリースレビュースキル

## 目的

完了したフィーチャが merge / staging / production のどこまで進めてよいかを判定する。

## 入力

- 変更ファイル（git diff）
- `specs/<feature>/spec.md`
- `specs/<feature>/acceptance.md`
- `specs/<feature>/evidence.md`
- CI 結果

## 出力

- リリース準備レポート
- merge 推奨
- デプロイ推奨

## 手順

1. すべての受け入れ条件が対応済みか確認する。
2. 証跡のコマンドと結果を確認する。
3. リスク領域を確認する：セキュリティ / データ移行 / ロールバック / 観測可能性 / 性能。
4. ドキュメントが更新されているか確認する。
5. 次のいずれか1つを推奨する：
   - `READY_FOR_MERGE`
   - `READY_FOR_STAGING_ONLY`
   - `NEEDS_HUMAN_REVIEW`
   - `BLOCKED`

## 厳守

次の場合は production デプロイを推奨してはならない：
- テストが失敗している
- セキュリティ要件が未検証
- リスクのある変更にロールバック経路が無い
- 証跡が欠けている
