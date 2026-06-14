# ADR-0001: 仕様駆動 × テスト駆動の自動開発ループ

- Status: Accepted
- Date: 2026-06-13
- Deciders: 開発責任者

## Context

「設計/意図を投げると証拠付きPRが出る」開発フローを作りたい。
ただし全自動を一度に作ると暴走する。AIの出力を判定できる仕組みが先に要る。

## Decision

仕様駆動(SDD) + テスト駆動(TDD) + 自動修復ループを土台に据える。

1. `make verify`（= `pnpm verify` = lint + typecheck + test）を唯一の合否判定器とし、最初に作る。
2. AIへの常時規約は `AGENTS.md`、特定タスク手順は `.agents/skills/*/SKILL.md` に分離する。
3. 人間とAIの合意は `specs/<feature>/` に Markdown/YAML として残し、次工程へ渡す。
4. パイプライン: `設計書 → spec → clarify → acceptance → tests → plan → tasks → implement → verify → repair → evidence → review`。
5. 自動化は Level 1→6 まで段階的に上げる。最初の到達目標は Level 3（自動修復ループ）。

## Consequences

- 良い点: AIの変更が常に検証で止まり、失敗ログから直せる。仕様がテスト可能になる。
- コスト: 各機能で仕様・受け入れ条件・証跡の維持が必要。
- 不変条件: 停止条件（最大3回 / 同一失敗2回 / 人間判断が要るケース）を必ず守る。

## 以後のADRテンプレ

```md
# ADR-XXXX: <title>
- Status: Proposed | Accepted | Superseded by ADR-YYYY
- Date: YYYY-MM-DD
- Deciders: <role(s)>

## Context
## Decision
## Consequences
```
