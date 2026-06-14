---
name: design-to-pr
description: hernes の設計駆動×TDDパイプラインを一気通貫で自走させるオーケストレータ。Excel設計書（画面設計書・テーブル定義書）を起点に、feature採番→画像化→視覚読取→spec→曖昧さレビュー→受け入れ条件＋失敗テスト→DBスキーマ→計画→タスク分解→実装ループ→make verify→修復(最大3回)→証跡→リリースレビュー までを Claude 自身が実行する。ユーザーが「この設計書で機能を作って」「設計書から実装して」「Excelの設計書を渡すので開発を進めて」「新機能を一から回して」「make spec/tests/loop を全部やって」「設計書からPRまで自動で」のように言ったら、コマンドを1つずつ打たせずに必ずこのスキルを使う。必要情報（設計書パス・対象画面/テーブル/イベント・意図・リスク許容）は対話と推論の両方で収集し、停止条件（BLOCKER / 修復3回 / 同一失敗2回 / 人間の価値判断が要る場面）では安全に止まってハンドオフする。
---

# design-to-pr — 設計書からレビュー可能状態まで自走するパイプライン

## これは何か / なぜ要るか

このリポジトリ（hernes）は「設計コンパイラ + テスト判定器 + 修復ループ + 証跡システム」。
本来は `make design / spec / tests / loop / evidence` を順に叩き、`plan`/`tasks` と「テーブル定義→スキーマ」は手で補う必要がある。
実務でそれを毎回手打ちするのは現実的でないので、**このスキルが Claude を AGENT_CMD 役にして全フェーズをセッション内で自走**させる。
`scripts/run-loop.sh` のセッション内版＋対話ゲート付き、と考えてよい。

**鉄則（`AGENTS.md` / `docs/constitution.md` 由来。絶対に曲げない）:**
- 設計書は **JSON抽出せず画像化して視覚的に読む**（埋め込みキャプチャ・I/O図・結合セル・色の意味が落ちるため）。
- **テスト → 実装** の順（TDD）。実装を通すためにテストを削除・弱体化しない。
- メッセージ・列挙値・バリデーション規則は **`@hernes/shared` に単一定義**（直書き禁止）。
- 合否判定器は **`make verify`（lint + typecheck + test）** ただ1つ。証跡なしに成功を主張しない。
- **進む条件より止まる条件が大事。** 価値判断が要る場面では勝手に決めず止まる。

## 実行モード

- **既定（セッション内・対話）:** Claude が各フェーズを実行する。Bash はシェル専用ステップ（採番・画像化・verify・git）に使い、
  認知ステップ（画像読取・spec/テスト/スキーマ/コード作成・修復・レビュー）は下記の既存スキルを読み込んで Claude 自身が行う。
  ゲートでユーザーに確認する。**この説明文の手順はこのモードを指す。**
- **ヘッドレス（無人・任意）:** 完全自動で回したい時は、各 `make` が `AGENT_CMD`（`.env`、既定 `codex exec` / `claude -p`）に委譲する
  既存スクリプトをそのまま使う: `make spec FEATURE=… && make tests FEATURE=… && make loop FEATURE=…`。
  対話ゲートは効かないので、リスクのある機能には使わない。ユーザーが「無人で」「全部おまかせ」と明言した時だけ。

---

## 入力（対話＋非対話で収集する）

着手前に下表を埋める。**プロンプトや会話・`specs/*/design-source.md` から取れるものは推論で埋め、取れない必須項目だけ `AskUserQuestion` で聞く**（質問は一度にまとめる）。

| 項目 | 必須 | 取得方法 / 既定 |
|---|---|---|
| 画面設計書 .xlsx パス | △ | 会話/引数から。無ければ質問。画面が無い機能なら null 可 |
| テーブル定義書 .xlsx パス | △ | 会話/引数から。無ければ質問。新規テーブルが無いなら null 可 |
| feature slug（英小文字ケバブ） | ✓ | タイトルから推論（例: 制作見積書作成トップ → `prod-quote-top`）。連番 NNN は自動採番 |
| タイトル（一文） | ✓ | 会話から。無ければ設計書名から推論 |
| 意図 / 目的 / 対象ユーザー / 解く課題 | ✓ | 会話から。薄ければ `intent.yaml` の不足分だけ質問（phase 0 で確定） |
| 対象範囲（画面・テーブル・代表EVENT No） | ✓ | 設計書読取後に確定。初期値は会話から |
| リスク許容（auto_merge / auto_deploy） | ✓ | **既定すべて false。** 上げる時はユーザー明示が必要 |
| 最終成果物（レビューで止める / commit / PR まで） | ✓ | **既定: レビュー＋証跡で停止し、commit/PR の可否を確認。** 外向き操作は勝手にやらない |

少なくとも「画面設計書 or テーブル定義書のどちらか1つのパス」と「タイトル」が無いと始められない。両方欠けていれば質問する。

---

## パイプライン全体（誰が何をするか）

> `0 設計書読取 → A spec → B 曖昧さ → C 受入+失敗テスト → (C') テーブル→スキーマ → D 計画 → E タスク → F 実装 →(G 修復)→ H レビュー`

| Ph | 内容 | 実行主体 | 参照スキル / コマンド | 主な成果物 | 直後のゲート |
|---|---|---|---|---|---|
| 前 | 依存・green 確認 | Bash | `make verify` | — | 失敗なら原因を直すまで進まない |
| 0a | feature 採番＋雛形 | Bash | `scripts/new-feature.sh` | `specs/<F>/`、`design-source.md` | — |
| 0b | 設計書を画像化 | Bash | `make design DESIGN=<xlsx>`（画面・テーブル両方） | `design/rendered/<doc>/page-*.png` | soffice/poppler が無ければ停止して導入案内 |
| 0c | 画像を視覚読取→intent/spec | Claude | `.agents/skills/design-doc-reader/SKILL.md` | `intent.yaml`、`spec.md` | I/O図が画像に写っているか確認 |
| A | （設計書が薄い時のみ）意図補完 | Claude | `.agents/skills/intent-to-spec/SKILL.md` | `spec.md` 追補 | — |
| B | 曖昧さレビュー | Claude | `.agents/skills/spec-clarifier/SKILL.md` | `questions.md` | **BLOCKER があれば停止**（下記ゲート1） |
| C | 受け入れ条件＋失敗テスト | Claude | `.agents/skills/acceptance-test-designer/SKILL.md` | `acceptance.md`、`test-plan.md`、`*/test/*` | `pnpm test` で新規テストが**正しい理由で赤**を確認 |
| C' | テーブル定義→スキーマ | Claude | `.agents/skills/table-def-reader/SKILL.md` | `packages/db/src/schema/*`、列挙値→`@hernes/shared` | `pnpm typecheck` が通る |
| D | 実装計画 | Claude | `prompts/invocations.md` の D | `plan.md` | 新規依存が要るなら停止（ゲート2） |
| E | タスク分解 | Claude | `prompts/invocations.md` の E | `tasks.md`（テストを実装より前に） | — |
| F | 1タスク実装 | Claude | `.agents/skills/implementation-loop/SKILL.md` | コード＋`evidence.md`/`tasks.md` 更新 | `make verify` |
| G | 修復（F が赤の時） | Claude | `.agents/skills/validation-repair-loop/SKILL.md` | 最小修正＋`loop-log.md` | **停止条件**（ゲート3） |
| — | F/G を tasks.md が尽きるまで繰り返す | Claude | — | 全タスク [x] | — |
| H | リリースレビュー | Claude | `.agents/skills/release-reviewer/SKILL.md` | 判定 + `evidence.md` | READY/STAGING/NEEDS_HUMAN/BLOCKED |
| 後 | commit / PR（任意） | Bash | git / `gh` | ブランチ・PR | **ユーザーが明示した時だけ**（ゲート4） |

`C` と `C'` は順不同（テストは shared/db を参照するので、スキーマを先に作ってからテストを赤にする方が素直な機能もある）。
`make spec/tests/loop` は**叩かない**（あれは別プロセスの codex/claude を呼ぶヘッドレス用）。本モードでは Claude が直接やる。

---

## ゲートと停止条件（必ず守る）

止まるべき所で止まるのがこのスキルの価値。停止＝失敗ではなく、人間に判断を返すこと。

```yaml
stop_conditions:                  # docs/constitution.md / README より
  max_repair_attempts: 3          # 1タスクの修復は最大3回
  repeated_failure_limit: 2       # 同一失敗が2回続いたら停止
  require_human_review_when:
    - "プロダクト/価値判断が必要"
    - "セキュリティ/認可ポリシーが不明確"
    - "新規依存の追加が必要"
    - "破壊的なDBマイグレーション"
    - "公開API/公開挙動の変更"
    - "テストと仕様が矛盾"
    - "verify の出力が変化しない（無限ループの兆候）"
```

- **ゲート1（B直後）:** `questions.md` に **BLOCKER** があれば D 以降に進まない。対話モードなら BLOCKER をユーザーに提示して解消、無人なら停止しハンドオフ。
- **ゲート2（D）:** 新規依存・破壊的migration・公開API変更が必要と判明したら、理由と選択肢を出して**承認を取る**まで進めない。
- **ゲート3（G）:** 上記 `stop_conditions` のいずれかで `evidence.md` にハンドオフ（残失敗・推定原因・次の一手）を書いて停止。
- **ゲート4（後）:** commit/push/PR は外向き操作。**ユーザーが明示的に頼んだ時だけ**。main ブランチ上なら必ず先にブランチを切る。
  PR 本文末尾には Claude Code 生成の表記を入れる。

各フェーズ着手時にタスクリスト（TaskCreate/TaskUpdate があれば）で進捗を可視化し、どのゲートで止まったか必ず明示する。

---

## 実行手順（対話モード）

### 0. 前提チェック
1. リポジトリルートで作業しているか確認（`specs/_template` がある）。
2. **Node ≥20 が有効か確認**（`node -v`）。このリポジトリは Node 22 前提（`package.json` の engines: `>=20`）。
   非対話シェルや `make` のサブシェルでは nvm が読まれず古い node（例: v18）に落ち、corepack/pnpm が `URL.canParse is not a function` で落ちることがある。
   その場合は v20+ を有効化してから進む（例: `export PATH="$HOME/.nvm/versions/node/v22.*/bin:$PATH"` か `nvm use 22`）。PATH は `make` の子プロセスにも継承されるので、export してから `make …` を呼べばよい。
3. `node_modules` が無ければ `make install`（= pnpm install）。
4. `make verify` を実行し、**緑のベースライン**を確認。赤なら、まず既存の失敗を直すか、ユーザーに方針を聞く（新機能を赤の上に積まない）。
5. 設計書を画像化するので `soffice`（LibreOffice）と `pdftoppm`（poppler）を確認。無ければ次を案内して停止:
   `brew install --cask libreoffice && brew install poppler`

### 1. 入力収集（対話＋推論）
- 会話・引数・既存 `specs/*/design-source.md` から上の入力表を埋める。
- 足りない必須項目（設計書パス／タイトル／意図の核／リスク許容／最終成果物）だけを **1回の `AskUserQuestion`** でまとめて聞く。
- 既存 feature の続きを頼まれた場合は新規採番せず、その `specs/<F>/` の**既存成果物を見て再開フェーズを判定**（下記「再開」）。

### 2. ブートストラップ（phase 0a）
```bash
scripts/new-feature.sh --slug <slug> \
  --screen "<画面設計書.xlsx or 省略>" \
  --table  "<テーブル定義書.xlsx or 省略>" \
  --title  "<タイトル>"
```
最終行に出る `specs/<NNN>-<slug>` を以後の `<F>` とする。`design-source.md` は自動記入済み。

### 3. 設計書読取（phase 0b–0c）
```bash
make design DESIGN="<画面設計書.xlsx>"
make design DESIGN="<テーブル定義書.xlsx>"   # ある場合
```
`design/rendered/<doc>/page-*.png` を **Read（vision）で全ページ視覚的に読む**。文字が小さければ `DPI=200 make design …`。
`.agents/skills/design-doc-reader/SKILL.md` に従い、画面概要・イベント記述書・項目記述書・参照仕様・メッセージ一覧を `intent.yaml` と `spec.md` に写経する。
**各要件に出典（シート名・項目No・EVENT No）を併記**。判断できない点は推測せず `questions.md`/spec の未解決へ。
> 品質チェック: I/Oフロー図がレンダリング画像に**写っている**こと（写っていなければ元xlsxを書き換えてしまった疑い→元から再レンダリング）。

### 4. spec 補完 → 曖昧さレビュー（phase A–B）
- 設計書が薄い箇所は `intent-to-spec` で補う。要件IDは `FR-*`/`NFR-*`/`SEC-*`。
- `spec-clarifier` で `questions.md` を作り、BLOCKER/MAJOR/MINOR に分類。**ゲート1**を適用。

### 5. 受け入れ条件＋失敗テスト ＋ スキーマ（phase C / C'）
- `acceptance-test-designer` で Given/When/Then の `acceptance.md` と `test-plan.md`、そして **MUST 条件の失敗テスト**を追加。
  メッセージ・規則は `@hernes/shared` を単一出典にし、テストはその定数を検証する（文字列の二重定義をしない）。
- テーブル定義書があれば `table-def-reader` で `@hernes/db` の Drizzle スキーマと列挙値（→`@hernes/shared`）を作る。
- `pnpm test` を実行し、新規テストが**正しい理由で赤**になることを確認（実装はまだ書かない）。`pnpm typecheck` でスキーマの型成立を確認。

### 6. 計画 → タスク分解（phase D–E）
- `prompts/invocations.md` の D に従い `plan.md`（データモデル/API/UI/セキュリティ/観測/ロールバック/テスト戦略）。**ゲート2**。
- E に従い `tasks.md`。各タスクは小さく独立検証可能、受け入れ条件に対応づけ、変更ファイルと検証コマンドを書き、**テストを実装より前**に置く。

### 7. 実装ループ（phase F/G を反復）
`tasks.md` の未完了タスクが尽きるまで、1タスクずつ:
1. `implementation-loop` に従い**次の未完了タスク1つだけ**を最小実装（複数同時にやらない）。
2. 最も狭い関連テスト → `make verify`。
3. 緑なら `evidence.md`（変更ファイル/コマンド/合否）と `tasks.md` の `[x]` を更新し次へ。
4. 赤なら `validation-repair-loop` で根本原因を特定→最小修正→再 verify。**ゲート3**（最大3回・同一失敗2回・要人間判断で停止しハンドオフ）。

### 8. 証跡 → レビュー（phase H）
```bash
make evidence FEATURE=<F>     # make verify の生ログを evidence.md に追記（PASS/FAIL）
```
`release-reviewer` で受け入れ条件の充足・証跡・リスクを点検し、`READY_FOR_MERGE / READY_FOR_STAGING_ONLY / NEEDS_HUMAN_REVIEW / BLOCKED` を1つ推奨。

### 9. 仕上げ（任意・ゲート4）
ユーザーが commit/PR を望む場合のみ: main ならブランチを切り、`make verify` 緑を確認して commit、`gh` で PR（本文にリスク・証跡サマリ）。

---

## 再開（idempotency）

途中まで進んだ feature を再度頼まれたら、最初からやり直さず**成果物の有無で再開地点を判定**する:

| 既にある | 次にやる |
|---|---|
| `spec.md` 無し | phase 0 から |
| `spec.md` あり / `questions.md` 無し | phase B から |
| `questions.md` に未解決 BLOCKER | ゲート1（解消が先） |
| `acceptance.md` 無し | phase C から |
| `tasks.md` 無し | phase D–E から |
| `tasks.md` に未完了 [ ] あり | phase F（その次のタスク）から |
| 全タスク [x] | phase H（レビュー）から |

`make design` は出力が `design/rendered/<doc>/` に既にあれば再実行不要（読み直しだけでよい）。

---

## アンチパターン（やらない）

- 設計書のセル値を openpyxl 等で JSON 抽出して spec を起こす（画像で読む。元xlsxは読み取り専用）。
- テストを書く前に実装する／verify を通すためにテストを消す・緩める。
- メッセージ・列挙値・バリデーションを `@hernes/shared` 以外に直書きする。
- 1ループで複数タスクをまとめて実装する。
- BLOCKER/価値判断/新規依存/破壊的migration を勝手に決めて進む。
- 証跡（実行コマンドと結果）なしに「できました」と言う。
- ユーザーに頼まれていないのに commit/push/PR する。
- `make spec/tests/loop`（ヘッドレス用）と本モードを混ぜて二重実行する。
