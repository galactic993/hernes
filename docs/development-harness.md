# 開発ハーネス / デプロイ運用ガイド（development-harness）

> このファイル 1 枚で、Preview / Staging / Production の構築・デプロイ・運用・撤去を回せることを目的とする。
> 対象アプリ: **hernes**（pnpm モノレポ）。frontend = React + Vite（nginx で 8080 配信）、backend = **Hono (TypeScript)**。
> リージョン: **asia-northeast1**。
>
> 重要: backend は **Java ではない**。Spring Boot / Flyway / actuator は使わない。
> health は `GET /healthz`、実行は `tsx`、マイグレーションは Drizzle（`@hernes/db`）。

---

## 目次

1. [Architecture overview（環境マトリクス）](#1-architecture-overview環境マトリクス)
2. [Frontend 方針（React + Vite / Next.js 移行しない）](#2-frontend-方針react--vite--nextjs-移行しない)
3. [Backend 方針（Hono / TypeScript）](#3-backend-方針hono--typescript)
4. [Biome 運用](#4-biome-運用)
5. [Clerk 認証設計](#5-clerk-認証設計)
6. [CORS 方針](#6-cors-方針)
7. [Setup prerequisites（前提ツール）](#7-setup-prerequisites前提ツール)
8. [GCP setup](#8-gcp-setup)
9. [Terraform apply 手順（bootstrap → terraform）](#9-terraform-apply-手順bootstrap--terraform)
10. [Workload Identity Federation setup](#10-workload-identity-federation-setup)
11. [GCP Secret Manager setup（secret コンテナ / IAM）](#11-gcp-secret-manager-setupsecret-コンテナ--iam)
12. [Required Secret Manager secrets（preview / staging / production）](#12-required-secret-manager-secretspreview--staging--production)
13. [Required GitHub repository variables](#13-required-github-repository-variables)
14. [GitHub Environments（production approval）設定](#14-github-environmentsproduction-approval設定)
15. [Preview workflow の流れ](#15-preview-workflow-の流れ)
16. [Staging 手順](#16-staging-手順)
17. [Production 手順（承認 / migration / rollback）](#17-production-手順承認--migration--rollback)
18. [Cleanup（自動 / nightly orphan 掃除）](#18-cleanup自動--nightly-orphan-掃除)
19. [Troubleshooting](#19-troubleshooting)
20. [Cost 注意](#20-cost-注意)
21. [Security 注意](#21-security-注意)
22. [Clerk redirect URL / allowed origin / authorized domain 注意](#22-clerk-redirect-url--allowed-origin--authorized-domain-注意)
23. [VITE_* に機密を入れてはいけない理由](#23-vite_-に機密を入れてはいけない理由)

---

## 1. Architecture overview（環境マトリクス）

3 環境（**Preview / Staging / Production**）すべてが Cloud Run（asia-northeast1）上で動く。
DB は **Preview だけ Neon**（ブランチ DB）、**Staging / Production は Cloud SQL for PostgreSQL（完全分離）**。
Redis（Memorystore）は **Staging 以上のみ**。Preview は `REDIS_ENABLED=false`。

```text
                ┌──────────────────────────────────────────────────────────┐
   GitHub PR ──▶│  Preview (PR ごと)   frontend-pr-<N> / backend-pr-<N>     │
                │  DB: Neon branch pr-<N>   Redis: なし   GCS: prefix pr/<N>/ │
                └──────────────────────────────────────────────────────────┘
  push to main ─▶  Staging   frontend-staging / backend-staging
                │  DB: Cloud SQL(staging)   Redis: Memorystore(staging)
  tag / 手動  ─▶  Production frontend-prod / backend-prod （Environment 承認必須）
                   DB: Cloud SQL(prod)       Redis: Memorystore(prod)
```

| 項目 | Preview (PR) | Staging | Production |
|---|---|---|---|
| トリガ | PR open / synchronize | `main` への push | tag / 手動 dispatch（**承認必須**） |
| GCP プロジェクト | `GCP_PROJECT_ID_DEV` | `GCP_PROJECT_ID_STAGING` | `GCP_PROJECT_ID_PRODUCTION` |
| Cloud Run（FE） | `frontend-pr-<PR_NUMBER>` | `frontend-staging` | `frontend-prod` |
| Cloud Run（BE） | `backend-pr-<PR_NUMBER>` | `backend-staging` | `backend-prod` |
| DB | **Neon** branch `pr-<PR_NUMBER>`（親 = `NEON_PARENT_BRANCH`） | **Cloud SQL** for PostgreSQL | **Cloud SQL** for PostgreSQL |
| Redis | **なし**（`REDIS_ENABLED=false`） | Memorystore（Direct VPC egress） | Memorystore（Direct VPC egress） |
| GCS | `gs://hernes-preview-<project>` prefix `pr/<PR_NUMBER>/` | `gs://hernes-staging-<project>` | `gs://hernes-production-<project>` |
| Clerk | preview instance（key 群 = preview） | staging | production |
| `APP_ENV` | `preview` | `staging` | `production` |
| MAIL / PAYMENT / NOTIFICATION | `mock` / `sandbox` / `disabled` | 実モードに近い | 実モード |
| ライフサイクル | PR close で削除 / GCS は 14 日で自動削除 | 常設 | 常設 |
| Secret 接頭辞（Secret Manager） | `preview-*`（+ PR ごと `preview-pr-<N>-database-url`） | `staging-*` | `production-*` |

共通ラベル（全リソースに付与）:

```text
app=hernes  env=<env>  pr=<PR_NUMBER>  managed-by=github-actions  commit-sha=<sha>
```

> GitHub Actions では PR 番号は `${{ github.event.number }}` を使う。

---

## 2. Frontend 方針（React + Vite / Next.js 移行しない）

- frontend は **React + Vite**。**Next.js へは移行しない**（SSR/RSC を前提にしない。SPA + API 分離で十分）。
- ビルド成果物（`dist/`）を **nginx で 8080 配信**する。Cloud Run のコンテナポートは **8080** 固定。
- ビルド時に注入する値は **公開して安全な値のみ**（[§23](#23-vite_-に機密を入れてはいけない理由)）。

frontend build args（コンテナビルド時に渡す）:

| build arg | 値 | 備考 |
|---|---|---|
| `VITE_APP_ENV` | `preview` / `staging` / `production` | |
| `VITE_API_BASE_URL` | backend の URL | 環境ごとの Cloud Run URL |
| `VITE_CLERK_PUBLISHABLE_KEY` | Clerk **publishable** key | 公開鍵。secret key は**絶対渡さない** |

nginx は 8080 を listen し、SPA フォールバック（`try_files ... /index.html`）を行う想定。
Dockerfile は multi-stage（node でビルド → nginx で配信）。

---

## 3. Backend 方針（Hono / TypeScript）

- backend は **Hono (TypeScript)**。エントリは `apps/backend/src/index.ts` → `app.ts`。
- listen は **8080**。health は **`GET /healthz`**（`apps/backend/src/app.ts` で `c.text('ok')` を返す）。
- 実行は **`tsx`**（トランスパイル不要でそのまま起動）。
- マイグレーションは **Drizzle（`@hernes/db`）**。Flyway は使わない。

主要エンドポイント（実装済み）:

| メソッド | パス | 認証 | 内容 |
|---|---|---|---|
| GET | `/healthz` | なし | ヘルスチェック（Cloud Run startup/liveness） |
| GET | `/api/me` | **Clerk 必須** | 検証済み `auth`（userId/sessionId/orgId）を返す |
| * | `/api/prod-quotes` | 公開 | 業務ルート例 |

backend env（**preview** の例。Staging/Prod は値だけ差し替え）:

| key | preview 値 | 備考 |
|---|---|---|
| `APP_ENV` | `preview` | |
| `DATABASE_URL` | Neon **pooled** 接続文字列 | secret。ログ出力禁止 |
| `REDIS_ENABLED` | `false` | preview は Redis を作らない/使わない |
| `GCS_BUCKET` | preview bucket | `hernes-preview-<project>` |
| `GCS_PREFIX` | `pr/<PR_NUMBER>/` | object prefix |
| `CLERK_SECRET_KEY` | preview | secret |
| `CLERK_JWKS_URL` | preview | トークン検証に使用 |
| `CLERK_ISSUER` | preview | issuer 検証 |
| `CLERK_WEBHOOK_SECRET` | preview | webhook 署名検証 |
| `ALLOWED_ORIGINS` | frontend preview URL | CORS allowlist |
| `MAIL_MODE` | `mock` | |
| `PAYMENT_MODE` | `sandbox` | |
| `NOTIFICATION_MODE` | `disabled` | |

> Staging / Production では `REDIS_ENABLED=true` とし、Memorystore へ **Direct VPC egress** で接続する。
> `DATABASE_URL` は Cloud SQL の接続文字列（Cloud SQL connector もしくは private IP）に変わる。

---

## 4. Biome 運用

Lint / Format は **Biome 一本**（`biome.json`）。ESLint / Prettier は使わない。

| コマンド | 用途 |
|---|---|
| `pnpm lint`（= `biome check .`） | lint + format チェック（書き込みなし） |
| `pnpm lint:fix`（= `biome check --write .`） | 自動修正 |
| `pnpm format`（= `biome format --write .`） | フォーマットのみ |

CI / デプロイの検証ゲートは **`pnpm verify`**（= `make verify`）:

```bash
pnpm verify    # = pnpm lint && pnpm typecheck && pnpm test
```

CI（`.github/workflows/ci.yml`）でも push / PR に対し `pnpm verify` を再現する（CI とローカルゲートを完全一致させる）。
デプロイ系 workflow は、ビルド前にこの `verify` の成功を前提とする。

> 設定要点（`biome.json`）: indent=space2 / lineWidth=100 / quote=single / semicolons=asNeeded / trailingCommas=all。
> `design/`・`specs/`・`**/dist`・`**/node_modules` は ignore 済み。

---

## 5. Clerk 認証設計

責務を **FE（publishable key）** と **BE（token verification）** で明確に分離する。

```text
[Browser/React] --Clerk SDK(publishable key)--> サインイン
        │  Authorization: Bearer <session JWT>  (または Cookie __session)
        ▼
[Hono backend] clerkAuth middleware (jose + JWKS)
        │  1) token 取得 (Bearer 優先, なければ __session cookie)
        │  2) JWKS(createRemoteJWKSet) で署名検証
        │  3) issuer 検証 (CLERK_ISSUER)
        │  4) azp(authorized parties) 検証 (CLERK_AUTHORIZED_PARTIES)
        ▼
   c.set('auth', { userId, sessionId?, orgId? })
```

実装は `apps/backend/src/middleware/clerk-auth.ts`。要点:

- **BE のトークン検証に `CLERK_SECRET_KEY` は不要**。JWKS の**公開鍵のみ**で `jwtVerify` する。
- token は `Authorization: Bearer <token>` を優先し、無ければ Cookie `__session` を読む。
- `issuer` を `CLERK_ISSUER` で検証。`azp` を `CLERK_AUTHORIZED_PARTIES`（カンマ区切り）で検証し、許可外なら **403**。
- 検証失敗 / token 無しは **401**。
- FE は `VITE_CLERK_PUBLISHABLE_KEY` のみ使用。`CLERK_SECRET_KEY` は **FE build arg に渡さない**（[§23](#23-vite_-に機密を入れてはいけない理由)）。

環境別に **別 Clerk instance / 別 key 群**（preview / staging / production）を使う。
**機密のみ** Secret Manager（`<env>-clerk-secret-key` / `<env>-clerk-webhook-secret`）に置き、
**公開値**（publishable key / JWKS URL / issuer / authorized parties）は GitHub Variables（`vars.*`）で管理する。

| key | 置き場所（source） | FE/BE |
|---|---|---|
| `CLERK_PUBLISHABLE_KEY` → `VITE_CLERK_PUBLISHABLE_KEY` | GitHub Variables `VITE_CLERK_PUBLISHABLE_KEY_<ENV>` → FE build arg | FE |
| `CLERK_SECRET_KEY` | **Secret Manager** `<env>-clerk-secret-key` → Cloud Run `--update-secrets` | BE のみ |
| `CLERK_JWKS_URL` | GitHub Variables `CLERK_JWKS_URL_<ENV>` → BE env（公開値） | BE |
| `CLERK_ISSUER` | GitHub Variables `CLERK_ISSUER_<ENV>` → BE env（公開値） | BE |
| `CLERK_AUTHORIZED_PARTIES` | GitHub Variables `CLERK_AUTHORIZED_PARTIES_<ENV>` → BE env（カンマ区切りの許可 azp 一覧 / 公開値） | BE |
| `CLERK_WEBHOOK_SECRET` | **Secret Manager** `<env>-clerk-webhook-secret` → Cloud Run `--update-secrets` | BE |

---

## 6. CORS 方針

backend は **環境別の frontend URL のみ**を許可する。実装は `apps/backend/src/app.ts`。

- `ALLOWED_ORIGINS`（カンマ区切り）を env で注入。`/api/*` にのみ CORS を適用。
- `credentials: true`。**`origin: '*'` + credentials の組み合わせは禁止**。
- 未設定時は `http://localhost:5173`（ローカル開発）だけを許可（フェイルセーフ）。

| 環境 | `ALLOWED_ORIGINS` |
|---|---|
| ローカル | `http://localhost:5173`（既定フォールバック） |
| Preview | その PR の `frontend-pr-<PR_NUMBER>` URL |
| Staging | `frontend-staging` の URL |
| Production | `frontend-prod` の URL（独自ドメインがあればそれも） |

> Preview は frontend URL が PR ごとに変わるため、デプロイ workflow で **backend の `ALLOWED_ORIGINS` に frontend URL を後から注入**する
> （frontend を先に deploy → URL 取得 → backend を deploy/更新、の順）。

---

## 7. Setup prerequisites（前提ツール）

ローカル / 運用者に必要なもの:

| ツール | バージョン | 用途 |
|---|---|---|
| Node.js | **22 LTS** | ランタイム |
| pnpm | **10** | モノレポ管理 |
| gcloud CLI | 最新 | GCP 操作 / Cloud Run / WIF 確認 |
| Terraform | >= 1.6 | インフラ provisioning（secret コンテナ + IAM。値は扱わない） |
| Docker | 最新 | コンテナビルド（ローカル検証用） |
| GitHub CLI `gh` | 最新 | variables / environments 設定 |

ローカルセットアップ:

```bash
pnpm install            # = make install
cp .env.example .env    # ローカル用の値を記入（DATABASE_URL 等）
pnpm verify             # lint + typecheck + test が緑になるか確認
pnpm dev:backend        # backend を 8080 で起動
pnpm dev:frontend       # frontend を Vite dev (5173) で起動
```

---

## 8. GCP setup

各環境を **別 GCP プロジェクト**に分ける（dev=preview / staging / production）。
最低限、各プロジェクトで以下を有効化:

```bash
# 環境ごとに PROJECT_ID を差し替えて実行
PROJECT_ID="<your-project-id>"

gcloud config set project "$PROJECT_ID"

gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  sts.googleapis.com \
  sqladmin.googleapis.com \
  redis.googleapis.com \
  compute.googleapis.com \
  storage.googleapis.com \
  secretmanager.googleapis.com \
  servicenetworking.googleapis.com
```

Artifact Registry（**asia-northeast1**, repos: `hernes-frontend` / `hernes-backend`）:

```bash
gcloud artifacts repositories create hernes-frontend \
  --repository-format=docker --location=asia-northeast1 \
  --description="hernes frontend images"

gcloud artifacts repositories create hernes-backend \
  --repository-format=docker --location=asia-northeast1 \
  --description="hernes backend images"
```

> Redis / Cloud SQL / VPC / Direct VPC egress は **Staging / Production プロジェクトのみ**。Preview プロジェクトには作らない。

---

## 9. Terraform apply 手順（bootstrap → terraform）

二段構え。**bootstrap**（state バケット・WIF・SA など “Terraform を回すための土台”）を先に作り、その後に **terraform**（アプリ用インフラ）を apply する。

想定レイアウト（`.tf` は別タスクで作成する。ここでは手順を示す）:

```text
infra/
  bootstrap/   # tf state バケット, WIF pool/provider, deploy SA, IAM
  terraform/   # Artifact Registry, Cloud SQL, Memorystore, VPC, GCS, Cloud Run(土台)
    environments/
      staging/   # *.tfvars（example は .tfvars.example）
      production/
```

### 9-1. bootstrap（最初に 1 回 / 環境ごと）

```bash
# infra/bootstrap で実行
terraform -chdir=infra/bootstrap init
terraform -chdir=infra/bootstrap plan  -var="project_id=<PROJECT_ID>" -var="region=asia-northeast1"
terraform -chdir=infra/bootstrap apply -var="project_id=<PROJECT_ID>" -var="region=asia-northeast1"
```

bootstrap が作るもの: Terraform 用 GCS state バケット、WIF Pool/Provider、deploy 用 Service Account とその IAM、Artifact Registry リポジトリ。

### 9-2. terraform（アプリ用インフラ / 環境ごと）

```bash
# state は bootstrap で作った GCS バケットを backend に指定
terraform -chdir=infra/terraform/environments/staging init \
  -backend-config="bucket=<TF_STATE_BUCKET>" \
  -backend-config="prefix=staging"

terraform -chdir=infra/terraform/environments/staging plan  -var-file=staging.tfvars
terraform -chdir=infra/terraform/environments/staging apply -var-file=staging.tfvars
```

`*.tfvars` は **コミットしない**。`*.tfvars.example` をテンプレートとして置く（例）:

```hcl
# staging.tfvars.example
project_id        = "hernes-staging-xxxxx"
region            = "asia-northeast1"
redis_enabled     = true
cloudsql_tier     = "db-custom-1-3840"
gcs_bucket_name   = "hernes-staging-hernes-staging-xxxxx"
```

> Cloud Run サービスそのものは GitHub Actions（ビルド → deploy）側で作成/更新する運用も可。
> その場合 Terraform は「土台（registry/DB/redis/VPC/bucket/IAM）」までを管理し、リビジョン更新は CI に任せる。

---

## 10. Workload Identity Federation setup

GitHub Actions → GCP の認証は **WIF**（`google-github-actions/auth`）。**SA JSON キーは禁止**。
`repository` / `ref`（branch） / `environment` claim で制限する。

bootstrap Terraform で作るのが基本だが、手動コマンドの例:

```bash
PROJECT_ID="<PROJECT_ID>"
POOL="github-pool"
PROVIDER="github-provider"
REPO="<org>/<repo>"          # 例: your-org/hernes
SA="hernes-deployer@${PROJECT_ID}.iam.gserviceaccount.com"

# Pool
gcloud iam workload-identity-pools create "$POOL" \
  --location=global --display-name="GitHub Actions Pool"

# Provider（issuer = GitHub OIDC）。attribute / condition で repo を限定
gcloud iam workload-identity-pools providers create-oidc "$PROVIDER" \
  --location=global --workload-identity-pool="$POOL" \
  --display-name="GitHub OIDC" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref,attribute.environment=assertion.environment" \
  --attribute-condition="assertion.repository=='${REPO}'"

# deploy SA に必要 role（最小権限）
# run.admin は Cloud Run の service と Job（staging/prod の migration Job）の両方に効く。
for ROLE in roles/run.admin roles/artifactregistry.writer roles/iam.serviceAccountUser; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SA}" --role="$ROLE"
done

# Secret Manager 権限（§11-3 と一致させる）。Terraform の secret-manager モジュールが
# 付与するが、WIF を手動構築する場合は以下も必要:
#   - dev(preview) の deploy SA だけ roles/secretmanager.admin（dev project）。
#     preview-pr-* の作成/version/削除 + per-PR accessor 付与 + preview-neon-api-key 読取に使う。
#   - staging/production の deploy SA には secret role を付けない
#     （migration は backend runtime SA で動く Cloud Run Job が行い、DATABASE_URL を
#      --update-secrets で受け取る。GitHub runner は DB secret を読まない）。
# 例（dev project のみ）:
#   gcloud projects add-iam-policy-binding "$DEV_PROJECT_ID" \
#     --member="serviceAccount:${DEV_SA}" --role="roles/secretmanager.admin"

# この repo の WIF principal に SA の impersonation を許可
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
gcloud iam service-accounts add-iam-policy-binding "$SA" \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL}/attribute.repository/${REPO}"
```

GitHub Actions 側（抜粋）。**`id-token: write` 必須**:

```yaml
permissions:
  contents: read
  id-token: write          # WIF に必要

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: google-github-actions/auth@v2
        with:
          project_id: ${{ vars.GCP_PROJECT_ID_STAGING }}
          workload_identity_provider: ${{ vars.GCP_WIF_PROVIDER_STAGING }}
          service_account: ${{ vars.GCP_DEPLOY_SERVICE_ACCOUNT_STAGING }}
      - uses: google-github-actions/setup-gcloud@v2
```

> production 用 provider は **environment claim** で production に限定し、`main` 以外の ref を弾く condition を付けることが望ましい。

---

## 11. GCP Secret Manager setup（secret コンテナ / IAM）

secret の **値の source of truth は GCP Secret Manager**。
Cloud Run は実行時に `--update-secrets` で直接参照する（値を GitHub runner に持ち回らない / GitHub Secrets に長期 secret を置かない）。

**役割分担**:

- **Terraform は secret コンテナ（`google_secret_manager_secret`）と IAM のみ**を管理し、**secret の値は扱わない**。
  値は `gcloud secrets versions add`（または `secret-put.sh`）で out-of-band に投入する。
  実体は `infra/terraform/modules/secret-manager`（root から各環境ごとに呼び出し）。**コンテナの正規の所有者は Terraform**。
- スクリプト: `scripts/gcp/secret-bootstrap.sh`（既定は **read-only チェック**。期待コンテナの存在を確認。
  非 Terraform 運用でコンテナを作りたいときだけ `--create`）、
  `scripts/gcp/secret-put.sh`（1 つの secret 値を stdin / `--data-file=-` で upsert。コンテナが無ければ既定で fail。
  非 Terraform 運用は `--create-missing`）。

### 11-1. secret コンテナの作成（= Terraform）／確認

コンテナは **Terraform で作る**（推奨。`terraform apply` がコンテナ + accessor IAM を宣言的に作る）。
スクリプトで作成済みコンテナを **確認**する（既定 read-only）:

```bash
# preview(dev) の期待コンテナが存在するか確認（read-only。値は触らない）。
# env は第 1 位置引数。project は --project フラグ（省略時は gcloud の既定 project）。
scripts/gcp/secret-bootstrap.sh preview --project "<DEV_PROJECT_ID>"

# Terraform を使わない運用で、コンテナを実際に作る場合のみ（IAM は別途自分で付与）:
# scripts/gcp/secret-bootstrap.sh preview --project "<DEV_PROJECT_ID>" --create
```

> per-PR の `preview-pr-<N>-database-url` は **Terraform ではなく preview workflow が作成 / 削除**する（PR ライフサイクルに追従）。

### 11-2. secret 値の投入（out-of-band）

```bash
# 1 つの secret に新しいバージョンを追加（値は stdin。argv / echo に出さない）
printf '%s' "<VALUE>" | gcloud secrets versions add staging-clerk-secret-key --data-file=-

# scripts のラッパでも可（冪等 upsert）。secret id は第 1 位置引数、値は stdin で渡す。
printf '%s' "<VALUE>" | scripts/gcp/secret-put.sh staging-database-url --project "<STAGING_PROJECT_ID>"
```

> 値は対話入力 / ファイル / stdin から渡し、**ターミナル履歴・ログ・argv に残さない**。

### 11-3. IAM モデル（per-secret 付与）

`infra/terraform/modules/secret-manager` が以下を付与する（SA 定義自体は `modules/iam` のまま）:

| principal | role | 対象 |
|---|---|---|
| **backend runtime SA**（`hernes-backend-run@<project>`） | `roles/secretmanager.secretAccessor` | 自環境の長期 backend secret（preview は `preview-clerk-secret-key` / `preview-clerk-webhook-secret` / `preview-app-secret`。**`preview-neon-api-key` は含めない**。staging/prod は `<env>-*` 全 5 種）。staging/prod では Cloud Run **service**（runtime）と Cloud Run **Job**（migration）の両方がこの SA で動き、`<env>-database-url` を読む |
| **github deploy SA（dev）**（`hernes-github-deploy@<dev-project>`） | `roles/secretmanager.admin`（dev プロジェクト） | `preview-neon-api-key` の読み取り + `preview-pr-*` の作成 / version / 削除 / per-PR accessor 付与（dev は低機微なのでプロジェクトレベル admin を許容） |
| **backend runtime SA**（per-PR） | `roles/secretmanager.secretAccessor` | `preview-pr-<N>-database-url`（**preview workflow** が作成直後に付与。secret 削除時に binding も消える） |

> runtime SA は **自環境の long-lived secret にだけ** accessor を持つ。
> **staging/prod の deploy SA は DB secret を読まない**: migration は backend runtime SA で動く
> Cloud Run Job が行い、`DATABASE_URL` を `--update-secrets` で受け取る（GitHub runner は DB secret を読まない）。
> deploy SA が値を読むのは dev の `preview-neon-api-key`（+ per-PR DB の作成）に限られる。
>
> **マルチプロジェクト運用**: staging/production を別 project に分ける場合、その project 側の backend runtime SA に
> `<env>-*` secret の accessor を付ける必要がある。Terraform 変数
> `backend_runtime_sa_email_staging` / `_production`（= GitHub Variables `BACKEND_RUNTIME_SA_STAGING` / `_PRODUCTION` と同じ email）
> を渡すと secret-manager モジュールがバインドする（単一 project なら空でよい）。

---

## 12. Required Secret Manager secrets（preview / staging / production）

secret **値**の source of truth は **GCP Secret Manager**。下記の secret id を環境ごとに用意する（id 名は固定）。
**非機密の設定値・公開鍵は Secret Manager ではなく GitHub Variables**（`vars.*`、[§13](#13-required-github-repository-variables)）に置く。

### 12-1. Secret Manager の secret id（環境別）

| 環境 | secret id | 作成主体 |
|---|---|---|
| Preview（dev / 長期） | `preview-clerk-secret-key`, `preview-clerk-webhook-secret`, `preview-neon-api-key`, `preview-app-secret` | Terraform（コンテナ）+ 手動投入（値） |
| Preview（PR ごと / 短命） | `preview-pr-<N>-database-url`（N = PR 番号） | **preview workflow**（Terraform ではない） |
| Staging | `staging-database-url`, `staging-clerk-secret-key`, `staging-clerk-webhook-secret`, `staging-redis-auth-string`, `staging-app-secret` | Terraform（コンテナ）+ 手動投入（値） |
| Production | `production-database-url`, `production-clerk-secret-key`, `production-clerk-webhook-secret`, `production-redis-auth-string`, `production-app-secret` | Terraform（コンテナ）+ 手動投入（値） |

### 12-2. Cloud Run ランタイム env → secret マッピング（`--update-secrets`）

Cloud Run は以下の参照を `--update-secrets` で受け取り、起動時に Secret Manager から直接読む（値は runner に出ない）。

| env | Preview `backend-pr-<N>` | Staging `backend-staging` | Production `backend-prod` |
|---|---|---|---|
| `DATABASE_URL` | `preview-pr-<N>-database-url:latest` | `staging-database-url:latest` | `production-database-url:latest` |
| `CLERK_SECRET_KEY` | `preview-clerk-secret-key:latest` | `staging-clerk-secret-key:latest` | `production-clerk-secret-key:latest` |
| `CLERK_WEBHOOK_SECRET` | `preview-clerk-webhook-secret:latest` | `staging-clerk-webhook-secret:latest` | `production-clerk-webhook-secret:latest` |
| `APP_SECRET` | `preview-app-secret:latest` | `staging-app-secret:latest` | `production-app-secret:latest` |
| `REDIS_AUTH_STRING` | （なし。`REDIS_ENABLED=false`） | `staging-redis-auth-string:latest` | `production-redis-auth-string:latest` |

> **Frontend は secret を一切受け取らない**（公開 `VITE_*` build-arg のみ）。
> `preview-neon-api-key` は Cloud Run に渡さない。preview workflow が Neon branch 操作のために
> `gcloud secrets versions access` で都度読む（[§15](#15-preview-workflow-の流れ) / 鍵は即マスク）。

### 12-3. GitHub Variables 側に置く値（公開 / 非機密 = secret ではない）

下記は Secret Manager ではなく **GitHub Variables**（[§13](#13-required-github-repository-variables)）で管理する:

- Clerk 公開値: `CLERK_JWKS_URL_<ENV>` / `CLERK_ISSUER_<ENV>` / `CLERK_AUTHORIZED_PARTIES_<ENV>` / `VITE_CLERK_PUBLISHABLE_KEY_<ENV>`
- Neon 非機密: `NEON_PROJECT_ID` / `NEON_PARENT_BRANCH`（API key だけが secret）
- インフラ参照: `CLOUDSQL_*_INSTANCE` / `VPC_NETWORK` / `VPC_SUBNET` / `REDIS_HOST_<ENV>` / `REDIS_PORT_<ENV>` / `ALLOWED_ORIGINS_<ENV>` / `BACKEND_RUNTIME_SA_<ENV>`
- 各種モード: `APP_ENV` / `REDIS_ENABLED` / `MAIL_MODE` / `PAYMENT_MODE` / `NOTIFICATION_MODE` 等（非機密の plain env）

### 12-4. Frontend build args（公開可。**機密を入れない**）

| key | 全環境 | 備考 |
|---|---|---|
| `VITE_APP_ENV` | `preview`/`staging`/`production` | |
| `VITE_API_BASE_URL` | backend URL | CI が deploy 後に解決して注入する場合あり |
| `VITE_CLERK_PUBLISHABLE_KEY` | publishable key（`vars.VITE_CLERK_PUBLISHABLE_KEY_<ENV>`） | **publishable のみ**。secret key は禁止 |

> `DATABASE_URL` / `CLERK_SECRET_KEY` / `CLERK_WEBHOOK_SECRET` / `APP_SECRET` / `REDIS_AUTH_STRING` は
> **絶対にログ・argv へ出さない**。Cloud Run へは `--update-secrets` の参照経由でのみ渡す。

---

## 13. Required GitHub repository variables

非機密の設定値は **GitHub Variables**（Secrets ではない）に置く。

| Variable | 例 / 用途 |
|---|---|
| `APP_NAME` | `hernes` |
| `GCP_REGION` | `asia-northeast1` |
| `GCP_PROJECT_ID_DEV` | preview 用 project |
| `GCP_PROJECT_ID_STAGING` | staging 用 project |
| `GCP_PROJECT_ID_PRODUCTION` | production 用 project |
| `GCP_WIF_PROVIDER_DEV` | preview WIF provider リソース名 |
| `GCP_WIF_PROVIDER_STAGING` | staging WIF provider |
| `GCP_WIF_PROVIDER_PRODUCTION` | production WIF provider |
| `GCP_DEPLOY_SERVICE_ACCOUNT_DEV` | preview deploy SA email |
| `GCP_DEPLOY_SERVICE_ACCOUNT_STAGING` | staging deploy SA |
| `GCP_DEPLOY_SERVICE_ACCOUNT_PRODUCTION` | production deploy SA |
| `ARTIFACT_REGISTRY_LOCATION` | `asia-northeast1` |
| `ARTIFACT_REGISTRY_REPOSITORY` | `hernes-frontend` / `hernes-backend`（用途で参照） |
| `GCS_PREVIEW_BUCKET` / `GCS_STAGING_BUCKET` / `GCS_PRODUCTION_BUCKET` | 各環境の GCS バケット名 |
| `NEON_PROJECT_ID` | Neon project 識別子（非機密。API key だけが secret） |
| `NEON_PARENT_BRANCH` | branch `pr-<N>` の親ブランチ |
| `CLERK_JWKS_URL_PREVIEW` / `_STAGING` / `_PRODUCTION` | Clerk JWKS URL（公開値） |
| `CLERK_ISSUER_PREVIEW` / `_STAGING` / `_PRODUCTION` | Clerk issuer（公開値） |
| `CLERK_AUTHORIZED_PARTIES_PREVIEW` / `_STAGING` / `_PRODUCTION` | 許可 azp 一覧（カンマ区切り / 公開値。azp 検証用） |
| `VITE_CLERK_PUBLISHABLE_KEY_PREVIEW` / `_STAGING` / `_PRODUCTION` | Clerk publishable key（公開鍵 / FE build arg） |
| `CLOUDSQL_STAGING_INSTANCE` / `CLOUDSQL_PRODUCTION_INSTANCE` | Cloud SQL インスタンス接続名 |
| `VPC_NETWORK` / `VPC_SUBNET` | Direct VPC egress 用ネットワーク / サブネット |
| `REDIS_HOST_STAGING` / `REDIS_PORT_STAGING` / `REDIS_HOST_PRODUCTION` / `REDIS_PORT_PRODUCTION` | Memorystore 接続先（auth string だけが secret） |
| `ALLOWED_ORIGINS_STAGING` / `ALLOWED_ORIGINS_PRODUCTION` | CORS allowlist（公開値） |
| `BACKEND_RUNTIME_SA_DEV` / `_STAGING` / `_PRODUCTION` | backend runtime SA email（`hernes-backend-run@<project>`。Terraform 出力でもある） |
| `RUN_DB_MIGRATIONS` | `true` のときだけ migration step を実行。drizzle 未配線の scaffold では未設定（=skip）のまま。drizzle-kit + `packages/db/drizzle.config.ts`（+ migrations）を配線してから `true` にする |

`gh` で一括登録する例:

```bash
gh variable set APP_NAME --body "hernes"
gh variable set GCP_REGION --body "asia-northeast1"
gh variable set ARTIFACT_REGISTRY_LOCATION --body "asia-northeast1"
gh variable set NEON_PROJECT_ID --body "<neon-project-id>"
gh variable set BACKEND_RUNTIME_SA_STAGING --body "hernes-backend-run@<staging-project>.iam.gserviceaccount.com"
# ... 以下同様
```

> **GitHub Secrets には長期 secret を置かない**。GCP 認証は WIF（短命 OIDC トークン）、
> secret 値は Secret Manager（Cloud Run の service / Job が `--update-secrets` で参照）。
> runner が値を読むのは dev の `preview-neon-api-key` のみ（`gcloud secrets versions access` 直後に即マスク）。

---

## 14. GitHub Environments（production approval）設定

`production` は **GitHub Environment の approval（required reviewers）必須**。

設定（UI: Settings → Environments）:

1. Environment `production` を作成。
2. **Required reviewers** を有効化し、承認者を指定。
3. 必要なら **Deployment branches** を `main`（or tag）に限定。
4. production の deploy job に `environment: production` を付ける。

```yaml
jobs:
  deploy-production:
    runs-on: ubuntu-latest
    environment: production      # ← ここで approval ゲートが効く
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v4
      # auth(WIF) → build → migration(明示step) → deploy
```

> `preview` / `staging` も Environment を作っておくと、OIDC の environment claim 制限と secrets スコープ管理がしやすい。

---

## 15. Preview workflow の流れ

PR 単位で **作成 → 更新 → close で削除** のライフサイクルを回す。frontend URL が動的なので注入順序に注意。

```text
PR open ──────────▶  ┌ WIF で GCP 認証 (project=DEV)
                     │ NEON_API_KEY を Secret Manager から都度取得 (gcloud secrets versions access / 即マスク)
                     │ Neon branch pr-<N> 作成 (parent=NEON_PARENT_BRANCH)
                     │ db_url を preview-pr-<N>-database-url に格納 + runtime SA へ accessor 付与
                     │ backend image build/push → backend-pr-<N> deploy
                     │   （Cloud Run が Secret Manager を参照: --update-secrets / --service-account=runtime SA）
                     │ frontend image build (VITE_API_BASE_URL=backend URL) → frontend-pr-<N> deploy
                     │ backend の ALLOWED_ORIGINS に frontend URL を注入して更新
                     │ Drizzle migration を Neon branch に適用
                     └ PR に Preview URL をコメント

PR synchronize ───▶  同じ job を再実行（image 再ビルド & リビジョン更新 & migration）

PR close/merge ───▶  ┌ Cloud Run frontend-pr-<N> / backend-pr-<N> 削除
                     │ Neon branch pr-<N> 削除
                     │ GCS prefix pr/<N>/ のオブジェクト削除（bucket 自体は消さない）
                     └ （GCS は lifecycle 14 日でも自動削除される保険あり）
```

要点:

- サービス名は `frontend-pr-<PR_NUMBER>` / `backend-pr-<PR_NUMBER>`。PR 番号 = `${{ github.event.number }}`。
- **frontend を先に deploy → URL 取得 → backend の `ALLOWED_ORIGINS` を更新**（CORS のため、[§6](#6-cors-方針)）。
- Preview は `REDIS_ENABLED=false`。Redis を作らない/参照しない。
- ラベル `pr=<PR_NUMBER>` を全 preview リソースに付け、cleanup の対象判定に使う。

deploy（backend）コマンド例:

```bash
PR="${{ github.event.number }}"
# DATABASE_URL は per-PR secret、その他は preview 長期 secret を参照（値は runner に出ない）。
# runtime SA を指定して、その SA に付与した accessor で Cloud Run が直接読む。
gcloud run deploy "backend-pr-${PR}" \
  --image "asia-northeast1-docker.pkg.dev/${PROJECT}/hernes-backend/backend:${SHA}" \
  --region asia-northeast1 --port 8080 --allow-unauthenticated \
  --service-account "${{ vars.BACKEND_RUNTIME_SA_DEV }}" \
  --labels "app=hernes,env=preview,pr=${PR},managed-by=github-actions,commit-sha=${SHA}" \
  --set-env-vars "APP_ENV=preview,REDIS_ENABLED=false,GCS_PREFIX=pr/${PR}/" \
  --update-secrets "DATABASE_URL=preview-pr-${PR}-database-url:latest,CLERK_SECRET_KEY=preview-clerk-secret-key:latest,CLERK_WEBHOOK_SECRET=preview-clerk-webhook-secret:latest,APP_SECRET=preview-app-secret:latest"
```

---

## 16. Staging 手順

`main` への push で自動デプロイ（常設環境）。

```text
push main ──▶ verify(再現) ─▶ WIF(STAGING) ─▶
             backend build/push → migrate image build/push (Dockerfile target=migrate)
             Drizzle migration を Cloud Run Job で実行
               （backend runtime SA / DATABASE_URL=staging-database-url を --update-secrets で注入。runner は DB secret を読まない）
             backend-staging deploy
               （Cloud Run が Secret Manager を参照: --update-secrets / --service-account=runtime SA）
             frontend build (VITE_API_BASE_URL=backend-staging URL) → frontend-staging deploy
             ALLOWED_ORIGINS = vars.ALLOWED_ORIGINS_STAGING（+ frontend-staging URL）
```

- DB は **Cloud SQL(staging)**、Redis は **Memorystore(staging)** に **Direct VPC egress** で接続（`REDIS_ENABLED=true`）。
- サービス名は `frontend-staging` / `backend-staging`（PR サフィックス無し）。
- migration は **Cloud Run Job**（`hernes-migrate-staging`）として実行する。backend runtime イメージは
  drizzle-kit を持たないため、専用の migrate イメージ（`Dockerfile` の `migrate` ステージ）を使う。
  `DATABASE_URL` は Job が Secret Manager から `--update-secrets` で読むため、**GitHub runner に DB secret を降ろさない**。
  Cloud SQL(private IP) へは Direct VPC egress + Cloud SQL Auth Proxy 接続で到達する。

```bash
gcloud run deploy backend-staging \
  --image "asia-northeast1-docker.pkg.dev/${PROJECT}/hernes-backend/backend:${SHA}" \
  --region asia-northeast1 --port 8080 \
  --service-account "${{ vars.BACKEND_RUNTIME_SA_STAGING }}" \
  --network "${{ vars.VPC_NETWORK }}" --subnet "${{ vars.VPC_SUBNET }}" --vpc-egress private-ranges-only \
  --labels "app=hernes,env=staging,managed-by=github-actions,commit-sha=${SHA}" \
  --set-env-vars "APP_ENV=staging,REDIS_ENABLED=true" \
  --update-secrets "DATABASE_URL=staging-database-url:latest,CLERK_SECRET_KEY=staging-clerk-secret-key:latest,CLERK_WEBHOOK_SECRET=staging-clerk-webhook-secret:latest,REDIS_AUTH_STRING=staging-redis-auth-string:latest,APP_SECRET=staging-app-secret:latest"
```

---

## 17. Production 手順（承認 / migration / rollback）

tag or 手動 dispatch でトリガし、**GitHub Environment `production` の approval を経て**デプロイ。

### 17-1. デプロイ順序

```text
trigger ─▶ [approval 待ち] ─▶ WIF(PRODUCTION) ─▶
  1) backend image build/push + migrate image build/push（Dockerfile target=migrate）
  2) DB migration（明示ステップ）: Cloud Run Job `hernes-migrate-prod` を backend runtime SA で実行。
     DATABASE_URL=production-database-url を --update-secrets で注入（runner に DB secret を降ろさない）→ Drizzle を Cloud SQL(prod) に適用
  3) backend-prod deploy（新リビジョン / Cloud Run が Secret Manager を --update-secrets で参照）
  4) frontend build → frontend-prod deploy
  5) ヘルスチェック /healthz 緑を確認
```

- migration は **Cloud Run Job** による**専用の明示ステップ**。アプリ deploy と分離してログに残す。
  DATABASE_URL は Job が Secret Manager 参照で受け取り、GitHub runner には降ろさない。
- DB / Redis は **Cloud SQL(prod) / Memorystore(prod)**。`REDIS_ENABLED=true`。

### 17-2. rollback（トラフィックを前リビジョンへ戻す）

新リビジョンに問題があれば、**直前の healthy リビジョンへトラフィックを切り戻す**:

```bash
# リビジョン一覧（新しい順）
gcloud run revisions list --service backend-prod --region asia-northeast1

# 直前の healthy リビジョンへ 100% 戻す
gcloud run services update-traffic backend-prod \
  --region asia-northeast1 \
  --to-revisions <PREVIOUS_REVISION>=100

# frontend 側も同様
gcloud run services update-traffic frontend-prod \
  --region asia-northeast1 \
  --to-revisions <PREVIOUS_FE_REVISION>=100
```

> Cloud Run はリビジョンを保持するため、コードの rollback は traffic 切替で即座に可能。
> 一方 **DB migration は自動では戻らない**。後方互換な migration（expand → contract）を基本とし、破壊的変更は段階適用する。

---

## 18. Cleanup（自動 / nightly orphan 掃除）

### 18-1. PR close 時（即時）

`pull_request: closed` で当該 PR のリソースだけを削除（[§15](#15-preview-workflow-の流れ)）。
**作用対象は `*-pr-*` / `pr=<N>` ラベルのものに限定**。staging/prod には絶対に触れない。

### 18-2. nightly orphan 掃除

閉じ忘れ / 失敗で残った preview リソースを毎晩掃除する（schedule workflow）。

```text
cron(nightly) ─▶ オープン PR 番号の集合を取得
              ─▶ Cloud Run で env=preview のサービスを列挙
              ─▶ サービス名 backend-pr-<N>/frontend-pr-<N> の <N> が
                 オープン PR 集合に無いものだけ削除
              ─▶ Neon の pr-<N> branch も同様に孤児を削除
              ─▶ GCS prefix pr/<N>/ も孤児を削除（lifecycle 14日が保険）
```

安全ガード（必須）:

- 削除対象セレクタは **必ず `--filter='labels.env=preview'` かつ名前が `*-pr-*`** に限定。
- ガードとして「名前に `-pr-` を含まない / `env` が preview でない」ものは **絶対にスキップ**。
- dry-run（ログ出力のみ）→ 本削除 の二段にし、`set -x` は使わない。

```bash
# 例: オープンしていない preview backend を削除（filter で env=preview に限定）
OPEN_PRS="$(gh pr list --state open --json number --jq '.[].number')"
gcloud run services list --region asia-northeast1 \
  --filter='metadata.labels.env=preview' \
  --format='value(metadata.name)' | while read -r svc; do
    case "$svc" in
      *-pr-*) n="${svc##*-pr-}";
        echo "$OPEN_PRS" | grep -qx "$n" || gcloud run services delete "$svc" \
          --region asia-northeast1 --quiet ;;
      *) : ;;   # -pr- を含まないものは触らない
    esac
done
```

---

## 19. Troubleshooting

| 症状 | 切り分け | 対処 |
|---|---|---|
| Cloud Run が起動しない | ログで listen ポート確認 | コンテナは **8080** を listen。`PORT` 環境変数に合わせる |
| startup probe 失敗 | `/healthz` を curl | `GET /healthz` が `ok` を返すか。BE は tsx 起動が成功しているか |
| 401 がずっと返る | token / JWKS | `CLERK_JWKS_URL` / `CLERK_ISSUER` が当該環境のものか。Bearer or `__session` が届いているか |
| 403 `azp not allowed` | azp 検証 | `CLERK_AUTHORIZED_PARTIES` に frontend origin が入っているか |
| CORS で fetch 失敗 | preflight | backend `ALLOWED_ORIGINS` に **frontend URL そのもの**が入っているか。`*`+credentials は不可 |
| Preview で frontend が API を叩けない | 注入順 | frontend deploy → URL 取得 → backend `ALLOWED_ORIGINS` 更新、の順になっているか |
| WIF 認証エラー | claim | provider の `attribute-condition`（repository / environment / ref）に合致するか。`id-token: write` があるか |
| Secret Manager access denied | IAM / secret 名 | runtime SA に `roles/secretmanager.secretAccessor` が当該 secret に付与されているか（`--service-account` 指定漏れに注意）。secret id / バージョン（`:latest`）が正しいか。`gcloud secrets versions access` する deploy SA の権限も確認 |
| migration が当たらない | DATABASE_URL | preview=Neon pooled / staging,prod=Cloud SQL。接続先環境を取り違えていないか |
| Redis 接続エラー（preview） | 想定通り | preview は `REDIS_ENABLED=false`。コードが Redis 必須になっていないか |
| image push 403 | Artifact Registry | deploy SA に `roles/artifactregistry.writer`。location=asia-northeast1, repo 名一致 |
| Java 系を探して失敗 | スタック誤認 | backend は **Hono(TS)**。Spring/Flyway/actuator は存在しない。`/healthz`・tsx・Drizzle を見る |

---

## 20. Cost 注意

- **Preview は使い捨て**。PR close で必ず Cloud Run / Neon branch / GCS prefix を削除。nightly で孤児掃除。
- GCS preview バケットは **lifecycle 14 日**で自動削除（消し忘れの保険）。
- **Redis(Memorystore) は Staging 以上のみ**。Preview に Redis を作らない（高コスト）。
- Cloud Run は **min-instances=0**（preview）でアイドル課金を避ける。staging/prod も必要に応じ最小限。
- Cloud SQL は **staging/prod のみ**。preview は Neon（ブランチは安価・短命）。
- Artifact Registry のイメージは古い世代を cleanup policy で削除（容量課金対策）。

---

## 21. Security 注意

- **`set -x` 禁止**。secret を `echo` しない。
- `DATABASE_URL` / `CLERK_SECRET_KEY` / `CLERK_WEBHOOK_SECRET` / `APP_SECRET` / `REDIS_AUTH_STRING` を **ログに出さない**。
- **GitHub Secrets に長期 secret を置かない**。GCP 認証は WIF の短命 OIDC トークンを使う。
- **secret は Secret Manager が source of truth**。Cloud Run へは `--update-secrets` の**参照**で渡し（値は runner に出ない）、
  値を runner で持ち回らない / ログに出さない。やむを得ず読むときは `gcloud secrets versions access` 直後に `echo "::add-mask::..."`。
- **SA JSON キー禁止**（WIF 一択）。WIF provider は repository / branch / environment claim で制限。
- **`CLERK_SECRET_KEY` を frontend build arg に渡さない**。`VITE_*` に機密を入れない（[§23](#23-vite_-に機密を入れてはいけない理由)）。
- CORS は `origin:'*'` + credentials を禁止。環境別 frontend URL のみ許可。
- **production は GitHub Environment approval 必須**。production migration は明示ステップ。
- **cleanup は `*-pr-*` / `env=preview` 以外に作用しない**ことをガードで保証。
- GCS は **uniform bucket-level access + public access prevention**。
- backend のトークン検証は JWKS 公開鍵のみ（secret 不要）。issuer / azp を必ず検証。

---

## 22. Clerk redirect URL / allowed origin / authorized domain 注意

Clerk は **redirect URL / allowed origin / authorized domain** を instance 側に登録しておく必要がある。
**Preview の URL は PR ごとに動的**なので、そのままだと毎回 Clerk 設定を更新できず認証が通らない。

対処（いずれか）:

1. **安定 preview ドメインを使う**: Cloud Run のサービス URL ではなく、`pr-<N>.preview.hernes.example.com` のような
   **ワイルドカード配下の安定ドメイン**にマップし、Clerk に `*.preview.hernes.example.com` を許可ドメインとして 1 回登録する。
2. **preview 専用 Clerk instance を使う**: development/preview 用の Clerk instance を分け、
   開発インスタンスのゆるい origin 許可（または広めの allowed origins）で運用する。

| 環境 | redirect/allowed origin/authorized domain |
|---|---|
| Preview | 安定 wildcard ドメイン or preview 専用 instance（動的 URL を直登録しない） |
| Staging | `frontend-staging` の固定 URL / ドメイン |
| Production | `frontend-prod` の本番ドメイン |

backend 側の `CLERK_AUTHORIZED_PARTIES`（azp）も、上記で決めた **安定オリジン**に合わせて設定する。
（動的 Cloud Run URL を azp に毎回入れる運用は破綻するため、安定ドメイン方式を推奨。）

---

## 23. VITE_* に機密を入れてはいけない理由

- Vite は `VITE_` プレフィックスの env を **ビルド時にバンドルへインライン展開**する。
  生成された JS は **ブラウザに配信され、誰でも閲覧できる**（難読化は防御にならない）。
- したがって `VITE_*` に入れてよいのは **公開して安全な値のみ**:
  `VITE_APP_ENV` / `VITE_API_BASE_URL` / `VITE_CLERK_PUBLISHABLE_KEY`（publishable は公開前提の鍵）。
- **入れてはいけない**: `CLERK_SECRET_KEY`、`DATABASE_URL`、`CLERK_WEBHOOK_SECRET`、`APP_SECRET`、`REDIS_AUTH_STRING`、その他 Secret Manager 管理のあらゆる secret。
- 特に **`CLERK_SECRET_KEY` を frontend build arg / `VITE_*` に渡さない**。これらは backend(Hono) の **サーバ側 env** にのみ置く。
- 機密が必要な処理（token 検証・webhook 検証・DB アクセス）は **すべて backend に寄せる**。frontend は publishable key で認証 UI を出し、JWT を backend に渡すだけにする。

---

> このドキュメントはテンプレート（scaffold）前提。実クラウド値はプレースホルダであり、各 `<...>` を実プロジェクトの値に置換し、
> Terraform / GitHub Actions / GCP Secret Manager / Clerk の実セットアップを行ったうえで運用すること。

> **NOTE（v2+ オプション / 任意）**: v1 では secret の source of truth は GCP Secret Manager 一本で、Infisical は使わない。
> 将来 v2 以降で、Infisical を **コントロールプレーン**（編集 UI / 監査 / 環境横断管理）として導入し、
> 値を Secret Manager に同期する構成を**任意で**採ることは可能。その場合も Cloud Run の参照先は Secret Manager のまま。
