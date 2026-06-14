---
name: intent-to-spec
description: intent.yaml の意図・制約を検証可能なフィーチャ仕様(spec.md)へ変換する。設計書が無い/補足が必要なときに使う。
---

# 意図→仕様 スキル

## 目的

曖昧な意図を、明確でテスト可能なフィーチャ仕様へ変える。
（設計書がある場合は先に [design-doc-reader] を使い、本スキルは補足・統合に使う）

## 入力

- `docs/constitution.md`
- `specs/<feature>/intent.yaml`
- 既存の `specs/<feature>/spec.md`（あれば）

## 出力

- `specs/<feature>/spec.md`
- 必要なら `specs/<feature>/questions.md`

## 手順

1. プロジェクト憲法を読む。
2. intent.yaml を読む。
3. ユーザー・ゴール・非ゴール・制約・ステークホルダーを洗い出す。
4. 意図を検証可能な要件へ変換する。
5. 安定した ID を振る：`FR-*`（機能）/ `NFR-*`（非機能）/ `SEC-*`（セキュリティ）。
6. 明示的な制約でない限り実装詳細は書かない。
7. 前提（Assumptions）と未解決（Open questions）は分けて書く。
8. すべての要件はテストまたはレビューで検証可能であること。

## 品質基準

- すべての要件が観測可能
- すべての非ゴールが明示
- 前提が明記されている
- 未解決が隠されていない
- セキュリティ/プライバシー制約が保持されている
