---
name: spec-clarifier
description: フィーチャ仕様の曖昧さ・矛盾・検証不能な要件・未決事項を、計画/実装の前に洗い出す。
---

# 仕様明確化スキル

## 目的

曖昧・矛盾した要件のまま実装に入るのを防ぐ。

## 入力

- `docs/constitution.md`
- `specs/<feature>/intent.yaml`
- `specs/<feature>/spec.md`

## 出力

- `specs/<feature>/questions.md`
- 必要なら spec.md へ「明確化提案」を追記

## 手順

1. spec と intent を読む。
2. 曖昧さ・矛盾・抜けているエッジケース・検証不能な要件を見つける。
3. 各課題を分類する：`BLOCKER` / `MAJOR` / `MINOR`。
4. 各課題に次を書く：影響する要件ID / なぜ重要か / ステークホルダーへの質問 / 安全なデフォルト（あれば）。
5. 実装コードは書かない。
6. 憲法が許す場合を除き、ビジネス判断を黙って解決しない。

## 停止条件

`BLOCKER` が1つでもあれば、実装に着手してはならない。
