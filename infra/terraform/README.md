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

### Terraform が作らないもの（意図的）

- **Cloud Run の preview サービス**（`frontend-pr-<N>` / `backend-pr-<N>`）。
  PR ごとに GitHub Actions が `gcloud run deploy` で動的作成する。
- **Neon の preview ブランチ**。CI が Neon API で `pr-<N>` ブランチを切る。
- **Secret 値**。source of truth は Infisical。Terraform は Secret を一切扱わない。
- staging/prod の Cloud Run ベースサービスは **任意**。`main.tf` の末尾コメント参照
  （初回はイメージが無いので CI のデプロイに任せる運用が安全）。

## 前提

1. GCP プロジェクト（単一 or 環境別）が存在し、課金が有効。
2. 以下の API が有効化されていること（手動 or 別途 Terraform / `gcloud services enable`）:
   `artifactregistry`, `run`, `sqladmin`, `redis`, `compute`, `servicenetworking`,
   `iam`, `iamcredentials`, `sts`, `cloudresourcemanager`。
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

# Cloud SQL のアプリ DB パスワードは機密。tfvars に書かず環境変数で注入する:
export TF_VAR_db_app_password_staging="<from Infisical>"
export TF_VAR_db_app_password_production="<from Infisical>"

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

`DATABASE_URL` / `CLERK_SECRET_KEY` 等の **機密は Infisical に入れる**（GitHub Secrets/Variables に置かない）。

## セキュリティ注意

- SA JSON キーは作らない（WIF のみ）。
- production リソースは `enable_production=true` のときだけ作成。実運用では
  GitHub Environment approval / 明示 migration ステップを CI 側で設ける。
- 機密値を output / ログに出さない。
