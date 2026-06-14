# hernes — 設計駆動 × TDD 自動開発ループ テンプレート

> 作るべきものは「AIエンジニア」ではない。
> **設計コンパイラ + テスト判定器 + 修復ループ + 証跡システム** だ。

人手の **Excel 設計書**（画面設計書・テーブル定義書）を起点に、AI に
**「作って」ではなく「証拠付きで完了状態まで持っていって」** と命令するための土台。
スタックは **Hono + React + TypeScript の pnpm モノレポ**。

```text
Excel設計書 → 画像化(render) → 視覚理解 → spec → 受け入れ条件 → テスト
           → 実装(Hono/React) → verify(lint+typecheck+test) → 修復 → 証跡 → レビュー
```

---

## なぜこの順番か

いきなり全自動を作ると暴走する。まず **“AI が変更して、テストして、失敗理由を読んで、直す”**
という小さい閉ループを作り、そこに設計駆動・TDD・レビューを足す。

```text
1. 判定できる開発環境        → make verify（lint + typecheck + test）
2. AI 用の作業規約           → AGENTS.md
3. 設計書の入力              → specs/<feature>/design-source.md（Excelのパス）
4. 設計書の理解              → design-doc-reader / table-def-reader（画像化して視覚理解）
5. 仕様 → 受け入れ条件 → テスト
6. 実装エージェント          → implementation-loop
7. 検証 → 修復ループ         → validation-repair-loop（最大3回）
8. レビュー / 証跡           → release-reviewer / evidence.md
```

**一番大事な原則: 進む条件より、止まる条件のほうが大事。**

---

## 設計書は「画像化して読む」（JSON抽出しない）

Excel のセル値をテキスト抽出すると、**画面概要の埋め込みキャプチャ・I/Oフロー図・結合セル・色の意味**
（黄=未記入, 青=ヘッダ）が落ちる。だから **PDF/画像化して vision で読む**。150dpi で日本語も図も鮮明。
（経緯: [docs/decision-log/ADR-0002-design-doc-as-image.md](docs/decision-log/ADR-0002-design-doc-as-image.md)）

```bash
make design DESIGN=path/to/画面設計書.xlsx
# → design/rendered/<doc>/page-*.png を生成。これを Read/vision で読む。
```

依存（設計書を読むときだけ必要）:

```bash
brew install --cask libreoffice   # soffice: xlsx → PDF
brew install poppler              # pdftoppm: PDF → PNG
```

---

## ディレクトリ構成

```text
hernes/
  AGENTS.md                 常時ロードの AI 作業規約
  Makefile                  pnpm への薄いラッパ + ループ実行
  package.json / pnpm-workspace.yaml / biome.json / tsconfig.base.json

  apps/
    backend/                Hono (TS)。routes/ がイベント記述書(EVENT No)に対応
    frontend/               React + Vite (TS)。features/<画面>/ が画面設計書に対応
  packages/
    shared/                 @hernes/shared: メッセージ・列挙値・zodバリデーション（単一出典）
    db/                     @hernes/db: Drizzle スキーマ（テーブル定義書由来）

  design/
    source/                 Excel設計書の置き場（実体は外部参照でも可）
    rendered/               render-design.sh の出力PNG（gitignore）

  docs/                     constitution.md / architecture.md / decision-log/
  specs/
    _template/              新機能はこれをコピー
    001-prod-quote-top/     ワークサンプル（制作見積書作成トップ）

  scripts/                  render-design.sh / run-loop.sh / generate-*.sh / collect-evidence.sh
  prompts/invocations.md    招集プロンプト 0〜H（日本語）
  .agents/skills/           8スキル（日本語）
  .github/workflows/ci.yml  CI で pnpm verify
```

| 場所 | 役割 |
|---|---|
| `AGENTS.md` | 常に守るルール |
| `.agents/skills/*/SKILL.md` | 特定タスクの手順（設計読取・仕様化・テスト設計・実装・修復・レビュー）|
| `specs/` | 人間とAIの合意（設計出典・仕様・受け入れ条件・タスク・証跡）|
| `packages/shared` | 設計書のメッセージ/規則/列挙値の**単一の真実** |

---

## クイックスタート

```bash
# 0) セットアップ（Node 20+ / pnpm）
make install            # = pnpm install

# 1) 検証ゲートを通す（最重要）
make verify             # lint + typecheck + test + govern。ワークサンプルは緑で出荷済み
make govern             # 統治ゲート単体（三権分立 / 書かれている→効いている）

# 2) 新機能を始める
cp -r specs/_template specs/002-your-feature
$EDITOR specs/002-your-feature/design-source.md   # 対象Excelのパスを書く

# 3) 設計書を画像化して読む → 仕様 → テスト → 実装ループ
make design DESIGN=...path/to/画面設計書.xlsx
make spec   FEATURE=002-your-feature
make tests  FEATURE=002-your-feature
make loop   FEATURE=002-your-feature
```

各ステップの招集プロンプトは [prompts/invocations.md](prompts/invocations.md)。
使うエージェント CLI は `.env`（`AGENT_CMD`）で差し替え（`codex exec` / `claude -p` など）。

---

## ワークサンプル: 制作見積書作成トップ

`specs/001-prod-quote-top/` は実際の画面設計書（管理会計システム / 編集管理）から起こした例。
設計書 → テストの連鎖が動く形で実装済み:

- 項目記述書の制御内容（必須・11桁以内・半角数字5桁）→ `@hernes/shared` の zod スキーマ
- メッセージ一覧（値不正・検索結果なし）→ `@hernes/shared` のメッセージカタログ
- テーブル定義書「制作見積」→ `@hernes/db` の `prod_quots` Drizzle スキーマ
- 検索API（Hono）・検索フォーム（React）が同じ shared を共有
- `make verify` で 10 テスト緑（shared 6 / backend 2 / frontend 2）

次にループを回す対象は認可ミドルウェア（`editorial.prod-quote.create`）と実DB検索（`tasks.md` の Phase 3）。

---

## 自動化レベル（段階的に上げる）

| Lv | 自動化範囲 |
|---|---|
| 1 | AI補助（人間が仕様、AIがテスト/実装、人間レビュー）|
| 2 | 半自動TDD（人間が設計書、AIが仕様/テスト/実装/`make verify`）|
| 3 | **自動修復ループ**（失敗ログを読んで最大3回再試行 → 証跡 or ハンドオフ）|
| 4 | 自動PR（ブランチ・実装・検証・PR本文・リスク）|
| 5 | 自動staging（merge後 deploy + smoke、production は人間承認）|
| 6 | 条件付きproduction（低リスクのみ。feature flag / rollback / 監視必須）|

**最初から Lv6 を狙わない。まず Lv3 まで作る。**

---

## 停止条件（必須）

```yaml
stop_conditions:
  max_repair_attempts: 3
  repeated_failure_limit: 2
  require_human_review_when:
    - "product decision required"
    - "security policy unclear"
    - "new dependency required"
    - "database migration destructive"
    - "public API change"
    - "test and spec conflict"
    - "verification output does not change"
```

---

## 統治層（governance / HOTL）

> harness（行政＝実行基盤）だけでは **HITL の高速化止まり**。次は **統治**で「書かれている」を
> 「効いている」に変え、**HOTL（Human on the Loop）** へ。問いは「AIをどう使うか」ではなく「AI実行をどう統治するか」。

判断を **立法・司法・行政** に分離し、**憲法**が三権を縛る。違反したら `make govern` が CI を落とす（Agent が止まる）。

```text
憲法 governance/constitution.yaml（改正は人間のみ）
  └ 立法 governance/rules/*.yaml ─enforced-by→ 司法 governance/checks/ ─→ 行政 make verify/loop
```

| 三権 | 実体 | 何を保証するか |
|---|---|---|
| 憲法 | `governance/constitution.yaml` | 普遍原則（`docs/constitution.md` のミラー） |
| 立法（rules） | `governance/rules/*.yaml` | 憲法に準拠する具体規範。司法に束縛されて初めて効く |
| 司法（checks） | `governance/checks/`（決定性＝実装 / 意味＝枠） | 適合を裁く。違反で CI が落ちる |
| 行政（harness） | `make verify` / `make loop` / `.agents/skills/*` | タスク完了まで実行する |

- **Authority Provenance Graph**: 立法↔司法を接続し ①立法なき司法 ②司法なき立法 ③越境司法 を検知。
- **Specification Provenance Graph**: feature→requirement→proof を追跡し、リンク切れ・未証明を検知。
- **SSOT と派生データの分離**: 派生（`governance/graph/`）は gitignore し、判断根拠にしない。
- **憲法 C1〜C6 を立法 9 ルールで enforced 化**（ユーザー価値・テスト・小さな変更・観測可能・秘密/PII・設計が真実の源）。意味(LLM)司法は配線済み（既定 skip / `GOVERN_SEMANTIC=1` で有効化）。
- **AI 実行密度(proxy)** を `make govern` が表示（立法カバレッジ・MUST 要件証明率・手動待ち件数）。

```bash
make govern             # 三権分立の統治ゲート（= pnpm govern）。違反(error)で exit 1
```

設計・運用・拡張は **[docs/governance.md](docs/governance.md)** / [ADR-0005](docs/decision-log/ADR-0005-governance-three-powers.md)。

---

## デプロイ基盤（プレビュー環境プラットフォーム）

PR ごとに Frontend / Backend / DB を自動作成し、Staging / Production も同じ CI/CD で管理する
GCP ベースの基盤を同梱（Vercel Preview 相当）。詳細・セットアップ・運用・トラブルシュートは
**[docs/development-harness.md](docs/development-harness.md)** に集約。

```text
Preview(PR#123)         Staging                 Production
  FE: frontend-pr-123     frontend-staging        frontend-prod     (Cloud Run, nginx:8080)
  BE: backend-pr-123      backend-staging         backend-prod      (Cloud Run, Hono:8080)
  DB: Neon branch pr-123  Cloud SQL staging       Cloud SQL prod
  GCS: pr/123/ prefix     staging bucket          production bucket
  Redis: 無効             Memorystore staging     Memorystore prod
  Secrets: GCP Secret Manager（環境別 secret id / Cloud Run が --update-secrets で参照）
  Auth: Clerk（FE=publishable / BE=Hono+jose でJWKS検証）
```

- IaC: `infra/terraform/`（8モジュール）+ state 用 `infra/bootstrap/`
- CI/CD: `.github/workflows/`（ci / preview / preview-cleanup / deploy-staging / deploy-production / nightly-cleanup）
- Docker: `apps/{frontend,backend}/Dockerfile`（pnpmモノレポ対応、Cloud Run `8080`）
- 認証: FE=`@clerk/clerk-react`、BE=`apps/backend/src/middleware/clerk-auth.ts`（jose JWKS / issuer / azp 検証）+ CORS
- GCP認証は Workload Identity Federation（JSONキー不要）。secret は **GCP Secret Manager** が source of truth で、
  Cloud Run が `--update-secrets` で直接参照する（値を GitHub runner に持ち回らない / GitHub Secrets に長期 secret を置かない）。

> ⚠️ これは scaffold。実運用には GCP / Neon / Clerk のアカウントと、
> docs の「Required GitHub Variables / Secret Manager secrets / 手動セットアップ」が必要。

---

## スキル設置先について

スキルは `.agents/skills/`（Codex / Spec-Kit 流儀）に置いている。
Claude Code でスキルとして認識させたい場合は `.claude/skills/` にコピー or シンボリックリンクを張る。
