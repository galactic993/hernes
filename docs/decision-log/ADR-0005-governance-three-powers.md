# ADR-0005: 三権分立による AI 実行の統治（HOTL の前提）

- Status: Accepted
- Date: 2026-06-14
- Deciders: 開発責任者 / AI Product Studio

## Context

harness（行政＝実行基盤）を真剣に作ると開発は劇的に速くなるが、それは「HITL（Human in the Loop）の
まま速くなった」だけで、人間はフロー内部の律速点に残る。人間がループの外から監督する **HOTL
（Human on the Loop）** に移るには、「設計・判断・承認」を人間（特に熟練者）の頭の中から**構造として
分離・実体化**する必要がある。

`docs/constitution.md` / ADR / `specs/` は「書かれている」が、Agent が参照せず・違反しても止まらず・
変更影響を追跡できない。「書かれている」状態は HOTL の前提にはなれない。問うべきは「書かれているか」
ではなく「**効いているか**」である。

## Decision

AI 実行を統治するため、判断を **立法・司法・行政** に分離し、**憲法**が三権すべてを縛る構造を採る。

1. **憲法** `governance/constitution.yaml`（散文は `docs/constitution.md`）。普遍原則。改正は人間のみ。
2. **立法（rules）** `governance/rules/*.yaml`。憲法条項を参照する具体規範。司法に束縛されて初めて効く。
3. **司法（checks）** `governance/checks/`。決定性（Grep/AST、実装）＋ 意味（LLM、枠）。
4. **行政（harness）** 既存の `make verify` / `make loop` / `.agents/skills/*`。
5. **Authority Provenance Graph**（`governance/src/authority-graph.ts`）で立法↔司法を機械可読に接続し、
   ①立法なき司法 ②司法なき立法 ③越境司法（＋憲法参照欠落）を検知する。
6. **Specification Provenance Graph**（`governance/src/spec-graph.ts`）で feature→requirement→proof を
   追跡し、dangling 要件・proof リンク切れ・MUST 未証明を検知する。
7. **SSOT と派生データの分離**（`governance/ssot.yaml` / `R006`）。派生データ（`governance/graph/`）は
   gitignore し、判断根拠にしない。立法/司法は派生を authority 参照しない。
8. ゲート **`make govern`**（= `pnpm govern`）を **CI と `make verify` に配線**し、違反(error)で exit 1。
   「効いている」を機械的に強制する。

実装は workspace パッケージ `@hernes/governance`（依存ゼロ寄り: `yaml` のみ。実行は `tsx`）。
エンジン自身も Vitest でテストし（ドグフード）、`make verify` 内で検証される。

## Consequences

- 良い点:
  - ルール違反が CI で止まり（Agent が止まり）、「書かれている」が「効いている」に変わる。
  - 立法・司法・憲法の整合が機械検証され、未配線ルール（書いただけ）が検知される。
  - 仕様→テストの追跡可能性が機械可読になり、リンク切れ・未証明が顕在化する。
  - 行政（汎用 harness）は借りられるが、立法・司法（自社固有の統治）を構造として所有できる。
- コスト:
  - ルール追加には、対応する司法（チェック）の実装と束縛が必要（書くだけでは error で落ちる）。
  - 司法の管轄（jurisdiction）と SSOT/派生の分離を維持する運用が要る。
- 不変条件:
  - 派生データ（`governance/graph/`）を判断の根拠として参照しない（混ぜると統治は崩壊する）。
  - 憲法の改正は人間のみ。立法は AI 提案・人間承認。
  - `make govern` は CI / verify の合否判定器の一部であり、スキップしない。

## 追補（実装の進捗）

- 憲法 **C1（ユーザー価値）/ C3（小さな変更）/ C4（観測可能）** を立法 R007/R008/R009 と
  仕様完全性チェック（`spec-user-value` / `spec-decomposition` / `spec-observability`）で enforced 化。
- **意味（LLM）司法を配線**（`user-value-alignment` / `pii-in-logs` を登録・束縛）。既定 skip・非ブロッキングで、
  `GOVERN_SEMANTIC=1` + `AGENT_CMD` で有効化。評価器(LLM)の本実装は行政(harness) の拡張点。
- **AI 実行密度の proxy 指標**（立法カバレッジ・MUST 要件証明率・手動待ち件数）を `make govern` が表示。
- 立法 6→9 / 司法 11。`make verify`（govern 含む）緑。

詳細な設計・運用・拡張手順は [docs/governance.md](../governance.md)。
背景となる開発ループは [ADR-0001](ADR-0001-spec-test-loop.md)。
