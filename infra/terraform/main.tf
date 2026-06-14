# main.tf
# ルート構成。modules/ を呼び出して GCP 基盤を組み立てる。
#
# 重要な前提（CLAUDE.md / 規約より）:
#   - Cloud Run の "preview" サービス（frontend-pr-<N> / backend-pr-<N>）は
#     GitHub Actions が PR ごとに動的に gcloud run deploy する。Terraform では作らない。
#   - DB: preview は Neon（Terraform 管理外）。staging/prod は Cloud SQL（このコードで作る）。
#   - Redis: preview は無効。staging 以上のみ Memorystore を作る。
#   - GCS: preview / staging / production の 3 バケット。preview のみ lifecycle 14 日で自動削除。
#   - Secrets の source of truth は GCP Secret Manager。Terraform は Secret 値を扱わない
#     （Secret コンテナ + IAM のみ作る。値は gcloud secrets versions add で別途投入）。
#
# 各 module の I/F は modules/ 側担当エージェントの実装に合わせている
# （location/bucket_name/instance_name/authorized_network など）。

locals {
  # 複数 project 運用時の解決。未指定なら base project にフォールバック。
  project_id_staging    = var.project_id_staging != "" ? var.project_id_staging : var.project_id
  project_id_production = var.project_id_production != "" ? var.project_id_production : var.project_id

  # 共通ラベル。env 固有ラベルは呼び出し時に merge する。
  # （pr ラベルは GitHub Actions がデプロイ時に付与する想定。Terraform 管理リソースは managed-by=terraform）
  common_labels = {
    app        = var.app_name
    managed-by = "terraform"
  }

  # Secret Manager の IAM バインドに渡す SA principal（"serviceAccount:<email>" 形式）。
  backend_runtime_sa_member = "serviceAccount:${module.iam.backend_runtime_service_account_email}"
  github_deploy_sa_member   = "serviceAccount:${module.iam.github_deploy_service_account_email}"

  # マルチプロジェクト運用では staging/production の backend runtime SA は、その project
  # 側に存在する別 SA になる（iam モジュールは base/dev project にしか SA を作らない）。
  # その場合は var.backend_runtime_sa_email_staging / _production に実際の SA email を渡すと、
  # その SA に staging-* / production-* Secret の accessor が付く。
  # 単一 project 運用（project_id_staging/production 未指定）なら空のままで dev の SA を使う。
  staging_backend_runtime_sa_member    = var.backend_runtime_sa_email_staging != "" ? "serviceAccount:${var.backend_runtime_sa_email_staging}" : local.backend_runtime_sa_member
  production_backend_runtime_sa_member = var.backend_runtime_sa_email_production != "" ? "serviceAccount:${var.backend_runtime_sa_email_production}" : local.backend_runtime_sa_member
}

# ---------------------------------------------------------------------------
# Artifact Registry（Docker repos: hernes-frontend / hernes-backend）
# 規約: location asia-northeast1, repos hernes-frontend / hernes-backend。
# ---------------------------------------------------------------------------

module "artifact_registry_frontend" {
  source = "./modules/artifact-registry"

  project_id    = var.project_id
  location      = var.region
  repository_id = "${var.app_name}-frontend"
  description   = "${var.app_name} frontend container images"
  labels        = merge(local.common_labels, { component = "frontend" })
}

module "artifact_registry_backend" {
  source = "./modules/artifact-registry"

  project_id    = var.project_id
  location      = var.region
  repository_id = "${var.app_name}-backend"
  description   = "${var.app_name} backend container images"
  labels        = merge(local.common_labels, { component = "backend" })
}

# ---------------------------------------------------------------------------
# GCS バケット ×3
#   - preview:    object prefix pr/<N>/ を使う。lifecycle 14 日で自動削除。
#   - staging:    通常バケット（versioning 有効）。
#   - production: 通常バケット（versioning 有効）。
# uniform bucket-level access + public access prevention は modules/gcs が常に enforce する。
# ---------------------------------------------------------------------------

module "gcs_preview" {
  source = "./modules/gcs"

  project_id = var.project_id
  location   = var.region
  # 規約: gs://hernes-preview-<project>
  bucket_name = "${var.app_name}-preview-${var.project_id}"

  # preview だけ lifecycle 14 日。pr/<N>/ 配下のオブジェクトを自動削除する。
  lifecycle_age_days = 14
  # preview は使い捨て。バケットごと壊せるよう force_destroy を許可。
  force_destroy      = true
  versioning_enabled = false

  labels = merge(local.common_labels, { env = "preview" })
}

module "gcs_staging" {
  source = "./modules/gcs"
  count  = var.enable_staging ? 1 : 0

  project_id = local.project_id_staging
  location   = var.region
  # 規約: gs://hernes-staging-<project>
  bucket_name        = "${var.app_name}-staging-${local.project_id_staging}"
  lifecycle_age_days = null # lifecycle delete なし
  force_destroy      = false
  versioning_enabled = true

  labels = merge(local.common_labels, { env = "staging" })
}

module "gcs_production" {
  source = "./modules/gcs"
  count  = var.enable_production ? 1 : 0

  project_id = local.project_id_production
  location   = var.region
  # 規約: gs://hernes-production-<project>
  bucket_name        = "${var.app_name}-production-${local.project_id_production}"
  lifecycle_age_days = null
  force_destroy      = false
  versioning_enabled = true

  labels = merge(local.common_labels, { env = "production" })
}

# ---------------------------------------------------------------------------
# IAM（runtime SA ×2 + デプロイ用 SA）
# デプロイ SA は WIF から impersonate されて GitHub Actions がデプロイする。
# backend runtime SA には preview バケットへの object 権限を付与しておく。
# ---------------------------------------------------------------------------

module "iam" {
  source = "./modules/iam"

  project_id = var.project_id

  # backend runtime SA に preview バケットの object 権限を付与（bucket-scoped）。
  backend_gcs_bucket = module.gcs_preview.bucket_name

  # SA account_id / role はモジュール側のデフォルト（最小権限）を採用。
  # 必要なら *_account_id / *_roles を上書きする。
}

# ---------------------------------------------------------------------------
# Secret Manager（Secret コンテナ + IAM。値は扱わない）
#
# Terraform は長期 Secret の「箱」と IAM だけを管理する。値は gcloud secrets
# versions add で別途投入する（Terraform は Secret 値を扱わない）。
# per-PR の preview-pr-<N>-database-url は GitHub Actions が作る（Terraform 管理外）。
#
# preview-neon-api-key の accessor 除外について:
#   backend runtime SA には clerk/app の 3 Secret だけ accessor を付ける。
#   neon-api-key は deploy SA（project admin）が workflow 内で読むだけなので、
#   backend には付けない。accessor_members は secret_ids の「各」Secret に効くため、
#   accessor を付ける 3 Secret と、付けない neon-api-key を別 module インスタンスに分割している。
#   project-scoped の admin は backend 側インスタンスで 1 回だけ付与する。
# ---------------------------------------------------------------------------

# preview（dev project）: backend が読む 3 Secret。deploy SA に project admin を付与。
module "secret_manager_preview_backend" {
  source = "./modules/secret-manager"

  project_id  = var.project_id
  environment = "preview"
  region      = var.region

  secret_ids = [
    "preview-clerk-secret-key",
    "preview-clerk-webhook-secret",
    "preview-app-secret",
  ]

  # backend runtime SA は上記 3 Secret を Cloud Run の --update-secrets で直接読む。
  accessor_members = [local.backend_runtime_sa_member]

  # dev project は低機微。deploy SA に project-level admin を付けて、workflow が
  # preview-pr-* の作成/版追加/削除 + per-PR accessor 付与を行えるようにする。
  admin_member  = local.github_deploy_sa_member
  admin_project = true

  labels = merge(local.common_labels, { env = "preview" })
}

# preview（dev project）: neon-api-key。backend には accessor を付けない
# （deploy SA が project admin 経由で workflow 内で読むだけ）。
module "secret_manager_preview_neon" {
  source = "./modules/secret-manager"

  project_id  = var.project_id
  environment = "preview"
  region      = var.region

  secret_ids = [
    "preview-neon-api-key",
  ]

  # accessor は付けない。admin も backend インスタンス側で付与済みなので付けない。

  labels = merge(local.common_labels, { env = "preview" })
}

# staging: 5 Secret。backend runtime SA が Cloud Run service（runtime）と
# Cloud Run Job（migration）の両方で読む。deploy SA に DB secret accessor は付けない
# （migration は backend runtime SA で動く Cloud Run Job が行い、DATABASE_URL を
#  Secret Manager 参照で受け取る。GitHub runner は DB secret を読まない）。
module "secret_manager_staging" {
  source = "./modules/secret-manager"
  count  = var.enable_staging ? 1 : 0

  project_id  = local.project_id_staging
  environment = "staging"
  region      = var.region

  secret_ids = [
    "staging-database-url",
    "staging-clerk-secret-key",
    "staging-clerk-webhook-secret",
    "staging-redis-auth-string",
    "staging-app-secret",
  ]

  # マルチプロジェクト運用では staging project 側の backend runtime SA を渡す
  # （未指定なら単一 project とみなし dev の SA を使う）。
  accessor_members = [local.staging_backend_runtime_sa_member]

  labels = merge(local.common_labels, { env = "staging" })
}

# production: 5 Secret。backend runtime SA が runtime と migration（Cloud Run Job）で読む。
# deploy SA に DB secret accessor は付けない（staging と同様）。
module "secret_manager_production" {
  source = "./modules/secret-manager"
  count  = var.enable_production ? 1 : 0

  project_id  = local.project_id_production
  environment = "production"
  region      = var.region

  secret_ids = [
    "production-database-url",
    "production-clerk-secret-key",
    "production-clerk-webhook-secret",
    "production-redis-auth-string",
    "production-app-secret",
  ]

  accessor_members = [local.production_backend_runtime_sa_member]

  labels = merge(local.common_labels, { env = "production" })
}

# ---------------------------------------------------------------------------
# Workload Identity Federation（GitHub Actions OIDC -> GCP）
# SA JSON キー禁止。repository claim で制限する（必要なら ref / environment も）。
# ---------------------------------------------------------------------------

module "workload_identity" {
  source = "./modules/workload-identity"

  project_id        = var.project_id
  github_repository = var.github_repository

  # デプロイ SA を impersonation 用に bind する。
  deploy_service_account_id    = "projects/${var.project_id}/serviceAccounts/${module.iam.github_deploy_service_account_email}"
  deploy_service_account_email = module.iam.github_deploy_service_account_email

  # production を別 project で運用する場合は、その project 側で
  # allowed_environments=["production"] を指定した WIF を別途用意する想定。
  # 単一 project ではここで environment を絞らず、GitHub Environment approval で制御する。
}

# ---------------------------------------------------------------------------
# ネットワーク（VPC + サブネット + Private Service Access）。
# Cloud Run の Direct VPC egress と Cloud SQL private IP / Memorystore に使う。
# staging 以上で必要。
# ---------------------------------------------------------------------------

module "network" {
  source = "./modules/network"
  count  = (var.enable_staging || var.enable_production) ? 1 : 0

  project_id   = var.project_id
  region       = var.region
  network_name = "${var.app_name}-vpc"
  subnet_name  = "${var.app_name}-subnet"
  subnet_cidr  = var.network_subnet_cidr

  # Cloud SQL private IP を使うため Private Service Access を有効化。
  enable_private_service_access = true
}

# ---------------------------------------------------------------------------
# Cloud SQL for PostgreSQL（staging / production を完全分離）
# Preview は Neon を使うのでここでは作らない。
# user_password は機密。実運用では GCP Secret Manager の値を渡す
# （ここではプレースホルダ変数経由。tfvars に実値を書かないこと）。
# ---------------------------------------------------------------------------

module "cloud_sql_staging" {
  source = "./modules/cloud-sql"
  count  = var.enable_staging ? 1 : 0

  project_id    = local.project_id_staging
  region        = var.region
  instance_name = "${var.app_name}-staging"
  tier          = var.db_tier_staging
  database_name = var.db_name
  user_password = var.db_app_password_staging

  # private IP で VPC に閉じる。network モジュールの network_name を渡す。
  network = one(module.network[*].network_name)

  availability_type   = "ZONAL"
  deletion_protection = false

  labels = merge(local.common_labels, { env = "staging" })

  # PSA peering が出来てから instance を作る（private IP 依存）。
  depends_on = [module.network]
}

module "cloud_sql_production" {
  source = "./modules/cloud-sql"
  count  = var.enable_production ? 1 : 0

  project_id    = local.project_id_production
  region        = var.region
  instance_name = "${var.app_name}-prod"
  tier          = var.db_tier_production
  database_name = var.db_name
  user_password = var.db_app_password_production

  network = one(module.network[*].network_name)

  # prod は HA + バックアップ + PITR + 削除保護。
  availability_type              = "REGIONAL"
  backup_enabled                 = true
  point_in_time_recovery_enabled = true
  deletion_protection            = true

  labels = merge(local.common_labels, { env = "production" })

  depends_on = [module.network]
}

# ---------------------------------------------------------------------------
# Memorystore (Redis) — staging 以上のみ。Preview は REDIS_ENABLED=false。
# Cloud Run からは Direct VPC egress で接続する。
# ---------------------------------------------------------------------------

module "memorystore_staging" {
  source = "./modules/memorystore"
  count  = var.enable_staging ? 1 : 0

  project_id     = local.project_id_staging
  region         = var.region
  name           = "${var.app_name}-staging"
  tier           = var.redis_tier
  memory_size_gb = var.redis_memory_size_gb
  # network モジュールの self_link を authorized_network に渡す。
  authorized_network = one(module.network[*].network_self_link)

  labels = merge(local.common_labels, { env = "staging" })

  depends_on = [module.network]
}

module "memorystore_production" {
  source = "./modules/memorystore"
  count  = var.enable_production ? 1 : 0

  project_id         = local.project_id_production
  region             = var.region
  name               = "${var.app_name}-prod"
  tier               = "STANDARD_HA"
  memory_size_gb     = var.redis_memory_size_gb
  authorized_network = one(module.network[*].network_self_link)

  labels = merge(local.common_labels, { env = "production" })

  depends_on = [module.network]
}

# ---------------------------------------------------------------------------
# Cloud Run のベースサービス（任意）
# ---------------------------------------------------------------------------
# preview の Cloud Run サービスは GitHub Actions が PR 単位で動的に作る（Terraform 管理外）。
# staging/prod の frontend-staging / backend-staging / frontend-prod / backend-prod を
# Terraform でブートストラップしたい場合は、ここに modules/cloud-run の呼び出しを追加する。
# 初回はイメージが無いため、CI の deploy に任せる運用（Terraform では作らない）でも問題ない。
# 例:
#   module "cloud_run_backend_staging" {
#     source     = "./modules/cloud-run"
#     count      = var.enable_staging ? 1 : 0
#     project_id = local.project_id_staging
#     region     = var.region
#     name       = "${var.app_name}-backend-staging"  # = backend-staging 命名規約に合わせる
#     ...
#   }

# ---------------------------------------------------------------------------
# 監視（Cloud Monitoring / Logging / Billing budget）
#   modules/monitoring が「ログ / バグ・不具合 / SLA・SLO / 料金」をまとめて作る。
#
#   - 監視対象は有効な env の長寿命 Cloud Run サービス（backend-staging /
#     frontend-staging / backend-prod / frontend-prod）。preview の *-pr-<N> は
#     scale-to-zero で寿命が短いため対象外（var.services に渡さない）。
#   - 単一 project 運用で重複させないよう、**distinct な project_id ごとに 1
#     インスタンス**だけ作る（staging と production が同じ project なら 1 つ）。
# ---------------------------------------------------------------------------

locals {
  # 有効な env => その project_id。
  monitored_env_projects = merge(
    var.enable_staging ? { staging = local.project_id_staging } : {},
    var.enable_production ? { production = local.project_id_production } : {},
  )

  # project_id => { env(ラベル用), service_names }。
  # 同じ project に複数 env が乗る場合は env をまとめ、サービス名も連結する。
  monitoring_instances = {
    for proj in distinct(values(local.monitored_env_projects)) :
    proj => {
      env = join("-", sort([for e, p in local.monitored_env_projects : e if p == proj]))
      service_names = flatten([
        for e, p in local.monitored_env_projects : (
          e == "staging" ? ["backend-staging", "frontend-staging"] :
          e == "production" ? ["backend-prod", "frontend-prod"] : []
        ) if p == proj
      ])
    }
  }
}

module "monitoring" {
  source   = "./modules/monitoring"
  for_each = var.enable_monitoring ? local.monitoring_instances : {}

  project_id = each.key
  env        = each.value.env
  region     = var.region
  labels     = merge(local.common_labels, { env = each.value.env })

  # API 有効化はリポジトリ慣習に合わせ既定 OFF（別管理）。
  enable_apis               = var.enable_monitoring_apis
  notification_emails       = var.notification_emails
  pubsub_notification_topic = var.monitoring_pubsub_topic

  # SLO / アラート / ダッシュボード / ログフィルタの単一ドライバ。
  services = {
    for n in each.value.service_names : n => { service_name = n }
  }

  # 予算は production を含む instance だけ ON。請求アカウント未指定なら OFF（通知のみ）。
  budget_enable        = var.billing_account != "" && strcontains(each.value.env, "production")
  billing_account      = var.billing_account
  budget_currency_code = "JPY"
  budget_amount_units  = var.monitoring_budget_amount_units

  # uptime は安定ドメインがある env のみ（既定は空 = 何も作らない）。
  # env が "production-staging" のように複合でも各 env キーのターゲットを拾えるよう、
  # budget_enable と同じく strcontains で部分一致マージする（exact-match lookup だと
  # 単一 project × 両 env 運用で複合ラベルにヒットせず無言で何も作られないため）。
  uptime_targets = merge([
    for e, t in var.uptime_targets : t if strcontains(each.value.env, e)
  ]...)
}
