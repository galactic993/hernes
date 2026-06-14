# 統治（governance）— 三権分立による AI 実行の統治 / HOTL

> 問うべきは「書かれているか」ではない。「効いているか」である。
> harness（行政）だけでは HITL の高速化止まり。**統治**で初めて HOTL（Human on the Loop）に到達する。

このドキュメントは、`hernes`（＝harness）の上に載る**統治層**の設計と運用を 1 枚で示す。
実体は `governance/`（立法/司法/SSOT の SSOT データ）＋ `@hernes/governance`（司法エンジン）。
ゲートは **`make govern`**（= `pnpm govern`）で、違反(error)があれば exit 1（CI を落とす / Agent を止める）。

---

## 1. なぜ統治か（HITL → HOTL）

| | HITL（Human in the Loop） | HOTL（Human on the Loop） |
|---|---|---|
| 人間の位置 | フロー内部（律速点） | ループ外部（監督・方向付け） |
| AI の役割 | 実装担当 | 実行・判断主体 |
| 律速要因 | 人間のレビュー | 制約・検証の設計 |
| 最適化対象 | 個人 | ループ構造 |

harness を真剣に作ると開発は劇的に速くなる。しかしそれは「HITL のまま速くなった」だけで、
人間は依然フロー内部の律速点に残る。**人間がループの外から監督できる構造**＝ HOTL に変えるには、
「設計・判断・承認」を人間（特に熟練者）の頭の中から**構造として分離・実体化**する必要がある。

> ADR を書いても、Wiki を整備しても HOTL にはならない。
> 「書かれている」状態は、Agent が参照せず・違反しても止まらず・変更影響を追跡できない。
> ドキュメントを「書く」のではなく、**ルール / チェック / 実行を「制御構造に組み込む」**必要がある。

---

## 2. 三権分立（立法・司法・行政）と憲法

判断を「立法・司法・行政」に分離し、すべてを**憲法**が縛る。

```text
                    ┌───────────────────────┐
                    │   憲法 Constitution    │  普遍的な開発原則 / 改正は人間のみ
                    │ governance/constitution.yaml
                    └───────────┬───────────┘
              準拠               │ 準拠               準拠
        ┌───────────────┐  ┌────┴───────────┐  ┌────────────────┐
        │  立法 (rules)  │→ │  司法 (checks)  │→ │  行政 (harness) │
        │ 何が正しいか   │  │ 適合を裁く      │  │ 実際に実行する  │
        │ governance/rules│ │ governance/checks│ │ make verify/loop │
        └───────────────┘  └────────────────┘  └────────────────┘
```

| 三権 | 役割 | このリポジトリの実体 |
|---|---|---|
| **憲法** | 普遍原則を定義（ルールの上位 SSOT）。改正は人間のみ | `governance/constitution.yaml`（散文は [constitution.md](constitution.md)） |
| **立法（rules）** | 憲法に準拠する具体規範。AI が提案、人間が承認 | `governance/rules/*.yaml` |
| **司法（checks）** | 適合しているかを裁く。**決定性**(Grep/AST) ＋ **意味**(LLM) | `governance/checks/`（`@hernes/governance` が実行） |
| **行政（harness）** | タスク完了の事前定義に沿って実行する | `make verify` / `make loop` / `.agents/skills/*` |

- **決定性チェック（deterministic）**: 機械判定（実装済み・CI を落とす）。例: メッセージ直書き禁止 / 秘密ログ禁止 / verify ゲート存在 / 仕様完全性（C1・C3・C4）。
- **意味チェック（semantic）**: LLM で意味判定（[checks/semantic/](../governance/checks/semantic/) に仕様）。評価器は AGENT_CMD サブプロセスで**実装済み**だが**既定 skip**（`GOVERN_SEMANTIC=1` + `AGENT_CMD` で有効化・warn）。安定後に error 昇格。

> 汎用 harness（Anthropic / OpenAI / Cursor 等）が触れるのは構造的に**行政まで**。
> 立法（何が正しいか＝ドメイン依存）と司法（何を裁くか＝フェーズ依存）は**自社で作るしかない**。

---

## 3. Authority Provenance Graph（立法↔司法の由来）

「書かれている」を「効いている」に変えるための、立法（ルール）と司法（チェック）を
**機械可読・双方向**に接続する層。これがあると次の 3 つを機械的に検知できる:

| 検知 | 意味 | コード |
|---|---|---|
| **①立法なき司法** | チェックは在るが、どのルールにも依拠しない（orphan） | `JUDICIAL_WITHOUT_LEGISLATION` |
| **②司法なき立法** | ルールは在るが、効かせるチェックが無い（＝書かれているが効いていない） | `LEGISLATION_WITHOUT_JUDICIAL` |
| **③越境司法** | チェックが、本来の管轄外まで裁いている | `CROSS_JURISDICTION` |

加えて **憲法参照の欠落**（`CONSTITUTION_REF_MISSING`）も検知する（立法は必ず憲法条項に紐づく）。

各 rule は `constitution`（準拠する憲法条項）と `checks`（束縛する司法）と `jurisdiction`（管轄）を宣言する。
派生グラフは `governance/graph/authority-graph.json` に出力される（**派生データ＝判断根拠にしない**）。

---

## 4. Specification Provenance Graph（機能の成立を追跡）

「この機能は、何の仕様に基づき、どのテストで証明されているか」「変更したら何に影響するか」を機械可読に追跡する。

```text
feature（機能） ──graph──▶ requirement（仕様） ──graph──▶ proof（テスト）
```

入力は `specs/<feature>/`（`spec.md` の要件 FR/NFR/SEC ＋ `acceptance.md` のトレーサビリティ表）。検知:

| コード | 重大度 | 意味 |
|---|---|---|
| `SPEC_DANGLING_REQUIREMENT` | error | 受け入れ条件が、spec に存在しない要件を参照している |
| `SPEC_BROKEN_PROOF` | error | 受け入れ条件の proof（テストパス）が実在しない（リンク切れ） |
| `SPEC_MUST_UNPROVEN` | error | MUST 条件に機械実行可能な proof（実在するテストパス）が無い。proof 欄が空・ダッシュ・出典名(例 `shared`)などプローズだけの場合も未証明とみなす（手動条件は除外） |
| `SPEC_TABLE_MALFORMED` | error | トレーサビリティ表の必須列（要件/優先度/実テスト）が欠落（検査不能＝fail-closed） |
| `SPEC_NO_TRACEABILITY` | error | spec に要件があるのに acceptance.md に表が無い（検査不能＝fail-closed） |
| `SPEC_UNCOVERED_REQUIREMENT` | warn | 要件を参照する受け入れ条件が無い（**次の宿題**・非ブロッキング） |

> **fail-closed 原則**: 表のヘッダ崩れ・列名の表記揺れ・複数表分割で検査が「黙ってスキップ」されると、
> 統治ゲートが自分の役目を静かに失う。パーサは複数表・表記揺れに耐え、表が壊れたら warn ではなく error にする。

派生グラフは `governance/graph/spec-graph.json`。
2 つの graph（Authority × Specification）が揃って初めて「機能・非機能の統治」が完成する。

---

## 4.5 仕様完全性（憲法 C1 / C3 / C4 の実体化）

抽象的な憲法原則も「効いている」状態にするため、spec の完全性として決定的に enforce する。

| 憲法 | 立法 | 司法（決定性） | 検知 |
|---|---|---|---|
| C1 ユーザー価値 | R007 | `spec-user-value`：intent.yaml に user_problem / desired_outcome | `SPEC_NO_USER_VALUE` |
| C3 小さな変更 | R008 | `spec-decomposition`：tasks.md に 3 件以上のタスク | `SPEC_NOT_DECOMPOSED` |
| C4 観測可能 | R009 | `spec-observability`：spec.md に観測可能性(NFR)の記述 | `SPEC_NO_OBSERVABILITY` |

C1 はさらに意味司法（`user-value-alignment`）で深く裁く（既定 skip / `GOVERN_SEMANTIC=1` + `AGENT_CMD` で有効化）。

## 5. SSOT と派生データの分離（最重要原則）

**自動生成される情報を、判断の根拠として参照させてはならない。** 混ぜると統治は必ず崩壊する。

| | SSOT（原典） | 派生データ |
|---|---|---|
| 定義 | 人が定義・承認したもの | 機械が自動生成・再生成できるもの |
| 例 | 機能要件 / ドメインルール / テスト・assertion | 変更影響分析 / 自動生成された依存図 / 集計サマリ |
| 参照 | 判断の根拠として参照可（変更に承認） | 判断根拠にしない（索引・ナビゲーションのみ） |

`governance/ssot.yaml` が原典 / 派生を宣言する。**派生（`governance/graph/`）は gitignore され、
立法/司法はこれを authority として参照してはならない**（`R006` / `SSOT_REFERENCES_DERIVED` で検知）。
統治エンジンは構造上、`governance/graph/` を入力（真実の源）として読み込まない。

---

## 6. 使い方

```bash
make govern        # 統治ゲート（= pnpm govern）。違反(error)で exit 1
make verify        # lint + typecheck + test + govern（全体の合否判定器）
pnpm govern:json   # 機械可読出力（CI/他ツール連携用）

# 意味(LLM)司法を有効化（既定 skip / 非ブロッキング warn）
GOVERN_SEMANTIC=1 AGENT_CMD='codex exec' pnpm govern

# AI 実行密度（token × PR / 月）で HOTL/HITL を分類（実データは Codex 使用量 + gh から）
make density FILE=governance/density.sample.json
scripts/governance/collect-pr-counts.sh 2025-05-01   # author 別 PR 数を gh で集計
```

- CI（`.github/workflows/ci.yml`）の "Governance gate" ステップで強制（PR で落ちる）。
- ローカルの `make verify` にも含まれる（行政＝harness の合否判定器に統治を組み込む）。
- 派生グラフは実行のたび `governance/graph/*.json` に再生成される（コミットしない）。

### 立法（ルール）を追加する

`governance/rules/RNNN-*.yaml` を作る。`constitution`（憲法条項）と `checks`（束縛する司法）を必ず宣言する。
`severity: error` なのに `checks` が空だと **②司法なき立法** で落ちる（書いただけでは通らない）。

### 司法（決定性チェック）を追加する

1. `governance/checks/deterministic/<id>.ts` に `meta`（id/kind/title/jurisdiction）と `run(ctx)` を実装。
2. `governance/checks/deterministic/index.ts` に 1 行追加して登録。
3. いずれかの rule の `checks` から `id` で束縛する（しないと **①立法なき司法** で落ちる）。

---

## 7. 明日から自社で問えること（書かれているか、ではなく効いているか）

1. **判断の根拠は、機械的にチェック可能な形か？** → 違反したら CI が落ち、Agent が止まる状態か。ADR / 設計書 / Wiki は Level 1 に過ぎない。
2. **派生情報と原典は、機械的に区別されているか？** → 自動生成物が判断根拠になっていないか。「便利だから」で混ざっていないか。
3. **ルール・検証・実行の繋がりは、Agent が追跡し、Agent が止められるか？** → 人間が記憶や経験で繋いでいないか。

---

## 8. プレゼン概念 → リポジトリ実体の対応

| プレゼンの概念 | このリポジトリの実体 |
|---|---|
| 憲法（Constitution） | `governance/constitution.yaml`（+ `docs/constitution.md`） |
| 立法 AI（ルール） | `governance/rules/*.yaml` |
| 司法 AI（検証 / contracts・guards） | `governance/checks/`（決定性＝実装 / 意味＝枠） |
| 行政 AI（実行 / workflow・agent） | `make verify` / `make loop` / `.agents/skills/*` |
| Authority Provenance Graph | `governance/src/authority-graph.ts`（→ `graph/authority-graph.json`） |
| Specification Provenance Graph | `governance/src/spec-graph.ts`（→ `graph/spec-graph.json`） |
| SSOT と派生データの分離 | `governance/ssot.yaml` ＋ `R006` / `governance/graph` の gitignore |
| 「効いている」（違反で CI が落ちる） | `make govern` を CI / verify に配線 |

---

## 9. 現状（MVP）と今後

**実装済み**:

- 三権分立モデル / 憲法 / Authority・Specification 両 graph / SSOT 分離。
- 立法 **12 ルール** / 司法 **14 チェック**（決定性 6・spec/ssot engine 6・意味 2）。
- 憲法 **C1〜C6 を enforced rule 化**（R001-R006 + 仕様完全性 R007-R009、§4.5）。
- **セキュリティ・DevOps 統治**（R010 SA JSON キー禁止 / R011 CI が govern 実行 / R012 本番承認必須）。
- 意味（LLM）司法の**評価器を本実装**（AGENT_CMD サブプロセス・注入可能・既定 skip／非ブロッキング warn）。
- **AI 実行密度の実 telemetry**（`make density`：token × PR / 月で HOTL・HITL を分類。`scripts/governance/collect-pr-counts.sh` ＋ Codex 使用量を入力に）。加えて report に proxy 指標を表示。
- `SPEC_UNCOVERED_REQUIREMENT` の解消＝全要件が受け入れ条件＋テストに接続（**手動条件 0**）。
- 機能の実装＋証明: 認可ミドルウェア(AC-006) / 取得・検索リポジトリ(AC-007) / 一覧遷移・詳細/得意先モーダル(AC-008/009 component)。
- CI・`make verify` への配線。

**今後（真の外部依存・継続）**:

- 実 DB（Drizzle）配線と「所属センター主管」絞り込み（quots/センターのモデル設計が要る product 判断）。
- ブラウザ e2e（Playwright / `e2e/`）— 画面間フルフローの担保。
- 意味司法の `warn → error` 昇格（本番運用データで安定を確認してから）。
- AI 実行密度の継続観測（自社の実データを `make density` に供給して定点観測）。
- 保守品質・性能・コストへの統治拡大（プレゼン同様、ここは挑戦中）。

> 「Yesterday is Dead.」— 今日の統治も、明日にはレガシー。変わり続けるために、効かせ続ける。
