# infra/terraform — hernes GCP 基盤

設計駆動 × TDD のテンプレートに付随する **GCP 基盤の scaffold**。
実クラウドは無い前提で、プレースホルダ値 + 手動セットアップ前提だが、構文と参照は正しい。

## 何を作るか

| リソース | 環境 | 備考 |
|---|---|---|
| Artifact Registry (`hernes-frontend` / `hernes-backend`) | 共通 | Docker、`asia-northeast1` |
| GCS バケット ×3 | preview / staging / production | uniform access + public access prevention。**preview のみ lifecycle 14 日** |
| IAM デプロイ SA | 共通 | WIF から impersonate される |
| Workload Identity Federation | 共通 | GitHub Actions OIDC。SA JSON キー禁止 |
| VPC + サブネット | staging/prod | Cloud Run の **Direct VPC egress** 用 |
| Cloud SQL for PostgreSQL | staging / production | 完全分離。**Preview は Neon を使うので作らない** |
| Memorystore (Redis) | staging / production | **Preview は無効**（`REDIS_ENABLED=false`） |
| Secret Manager の Secret コンテナ + IAM | preview / staging / production | **箱と IAM のみ**。値は別途投入（下記） |

### Secret Manager（値ではなくコンテナだけ作る）

Secret 値の source of truth は **GCP Secret Manager**。ただし Terraform は
**Secret コンテナ（`google_secret_manager_secret`）と IAM だけ**を管理し、
**Secret 値（`*_version`）は一切作らない**。値は apply 後に手動 / CI で投入する:

```bash
printf '%s' "<value>" | gcloud secrets versions add <secret-id> --data-file=-
```

env ごとに作る長期 Secret:

- **preview**（dev project）: `preview-clerk-secret-key`, `preview-clerk-webhook-secret`,
  `preview-neon-api-key`, `preview-app-secret`
- **staging**: `staging-database-url`, `staging-clerk-secret-key`, `staging-clerk-webhook-secret`,
  `staging-redis-auth-string`, `staging-app-secret`
- **production**: `production-database-url`, `production-clerk-secret-key`,
  `production-clerk-webhook-secret`, `production-redis-auth-string`, `production-app-secret`

IAM の付与:

- backend runtime SA は env の長期 backend Secret に `roles/secretmanager.secretAccessor`
  （preview では `preview-neon-api-key` を**除く** 3 Secret のみ。neon-api-key は deploy SA が読む）。
  staging/prod では Cloud Run **service**（runtime）と Cloud Run **Job**（migration）の両方がこの SA で動き、
  `<env>-database-url` を含む全 Secret を読む。
- deploy SA は dev project に `roles/secretmanager.admin`（preview-pr-* の作成/削除 + neon-api-key 読取）。
  **staging/prod の deploy SA には DB secret accessor を付けない**（migration は backend runtime SA の
  Cloud Run Job が行い、DATABASE_URL を `--update-secrets` で受け取る。GitHub runner は DB secret を読まない）。
- マルチプロジェクト運用（staging/production を別 project）では、その project 側の backend runtime SA に
  accessor を付けるため、`backend_runtime_sa_email_staging` / `_production` 変数に実 SA email を渡す
  （単一 project なら空でよい）。

### Terraform が作らないもの（意図的）

- **Cloud Run の preview サービス**（`frontend-pr-<N>` / `backend-pr-<N>`）。
  PR ごとに GitHub Actions が `gcloud run deploy` で動的作成する。
- **Neon の preview ブランチ**。CI が Neon API で `pr-<N>` ブランチを切る。
- **Secret 値**。source of truth は GCP Secret Manager だが、**値は Terraform で扱わない**
  （コンテナ + IAM のみ。値は `gcloud secrets versions add` で投入）。
- **per-PR の preview Secret**（`preview-pr-<N>-database-url`）。PR ごとに GitHub Actions が
  作成し、cleanup で削除する（Terraform 管理外）。
- staging/prod の Cloud Run ベースサービスは **任意**。`main.tf` の末尾コメント参照
  （初回はイメージが無いので CI のデプロイに任せる運用が安全）。

## 前提

1. GCP プロジェクト（単一 or 環境別）が存在し、課金が有効。
2. 以下の API が有効化されていること（手動 or 別途 Terraform / `gcloud services enable`）:
   `artifactregistry`, `run`, `sqladmin`, `redis`, `compute`, `servicenetworking`,
   `secretmanager`, `iam`, `iamcredentials`, `sts`, `cloudresourcemanager`。
3. **state 用 GCS バケットが先に存在すること** → `../bootstrap` を先に apply する
   （chicken-and-egg 回避。`backend.tf` 参照）。
4. apply する人間/CI に該当 project の Owner 相当権限。

## 運用モデル: 単一 project / 複数 project

- **単一 project**: `project_id` だけ指定。preview/staging/prod が同じ project に同居する
  （dev 段階や小規模向け）。
- **複数 project**: `project_id_staging` / `project_id_production` を指定して分離。
  未指定なら `project_id` にフォールバックする（`main.tf` の `locals` で解決）。

## apply 手順

```bash
# 0) 先に state バケットを用意（初回だけ）
#    ../bootstrap/README.md を参照して bootstrap を apply する。

cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars を編集（project_id, github_repository など）

# Cloud SQL のアプリ DB「ユーザパスワード」は Terraform の provisioning 入力（機密）。
# google_sql_user 作成に必要なため Terraform がこの値を受け取るのは避けられない。これは
# 「Terraform は Secret Manager の runtime secret 値を扱わない」という規約とは別レイヤの話。
# 注意: これは DB ユーザのパスワードであり、runtime の DATABASE_URL とは別物。
#   DATABASE_URL（接続文字列）は instance 作成後に private IP + このパスワードから組み立てて
#   <env>-database-url secret に格納する（下記「apply 後」参照）。database-url を流用しない。
# 値は運用者が安全に生成・管理するパスワードを out-of-band に渡す（tfvars には書かない）:
read -rs -p "staging DB password: " TF_VAR_db_app_password_staging && export TF_VAR_db_app_password_staging
read -rs -p "production DB password: " TF_VAR_db_app_password_production && export TF_VAR_db_app_password_production
# （パスワードマネージャ CLI から渡してもよい。例: TF_VAR_db_app_password_staging="$(op read 'op://…')"）

# 1) backend は partial config。env 別に prefix を分ける。
terraform init \
  -backend-config="bucket=hernes-tfstate-<PROJECT_ID>" \
  -backend-config="prefix=terraform/state/staging"

# 2) 計画と適用
terraform plan
terraform apply
```

> 環境ごとに state を分けたい場合は、`-backend-config="prefix=terraform/state/<env>"`
> を切り替えて `terraform init -reconfigure` する。あるいは `backend-<env>.hcl` を用意する。

## apply 後にやること

`terraform output` の値を **GitHub Variables（非機密）** に登録する:

| output | GitHub Variable |
|---|---|
| `wif_provider_name` | `GCP_WIF_PROVIDER_DEV` / `_STAGING` / `_PRODUCTION` |
| `deploy_service_account_email` | `GCP_DEPLOY_SERVICE_ACCOUNT_DEV` / `_STAGING` / `_PRODUCTION` |
| `artifact_registry_location` | `ARTIFACT_REGISTRY_LOCATION` |
| `artifact_registry_*_repository` | `ARTIFACT_REGISTRY_REPOSITORY`（frontend/backend で分ける） |
| `gcs_*_bucket` | backend env の `GCS_BUCKET` |
| `cloud_sql_*_connection_name` | backend の Cloud SQL 接続設定 |
| `redis_*_host` | backend の `REDIS_*`（staging 以上のみ） |
| `backend_runtime_sa_dev` / `_staging` / `_production` | `BACKEND_RUNTIME_SA_DEV` / `_STAGING` / `_PRODUCTION`（単一 project なら 3 つとも同じ。マルチプロジェクトは override 値） |
| `secret_ids_*` | 投入対象の Secret ID 一覧（値は別途 `gcloud secrets versions add`） |

`DATABASE_URL` / `CLERK_SECRET_KEY` 等の **機密値は GCP Secret Manager に入れる**
（`gcloud secrets versions add <secret-id> --data-file=-`。GitHub Secrets/Variables には置かない）。
Cloud Run は runtime SA の `secretAccessor` を使い `--update-secrets` で直接参照する
（値は runner にもログにも出さない）。

### `<env>-database-url` の組み立て（apply 後）

`TF_VAR_db_app_password_*` に渡した **DB ユーザパスワード**と、`terraform output` の
**Cloud SQL private IP / connection name** から runtime の `DATABASE_URL` を組み立て、
`<env>-database-url` secret に格納する（DB ユーザパスワードそのものとは別の値）:

```bash
# 例: staging。private IP は terraform output / Cloud SQL から取得。
# DB ユーザは Terraform の既定 hernes_app、パスワードは apply 時に渡した TF_VAR_db_app_password_staging。
# DB 名は var.db_name（既定 hernes）。
PRIVATE_IP="$(terraform output -raw cloud_sql_staging_private_ip)"
URL="postgres://hernes_app:${TF_VAR_db_app_password_staging}@${PRIVATE_IP}:5432/hernes"
printf '%s' "${URL}" | scripts/gcp/secret-put.sh staging-database-url --project "<STAGING_PROJECT_ID>"
```

> backend runtime SA がこの secret を読む（Cloud Run service の runtime と Cloud Run Job の
> migration の両方）。GitHub runner には DATABASE_URL を一切降ろさない。

## セキュリティ注意

- SA JSON キーは作らない（WIF のみ）。
- production リソースは `enable_production=true` のときだけ作成。実運用では
  GitHub Environment approval / 明示 migration ステップを CI 側で設ける。
- 機密値を output / ログに出さない。
