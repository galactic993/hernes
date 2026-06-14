# outputs.tf
# GitHub Actions の GitHub Variables 設定や運用で必要になる値を出力する。
# 機密値（DB パスワード等）は出力しない。Secret 値の source of truth は
# GCP Secret Manager（Secret ID は出すが、値は決して出力しない）。

# ---------------------------------------------------------------------------
# Workload Identity Federation / Deploy SA
# GitHub Variables: GCP_WIF_PROVIDER_* / GCP_DEPLOY_SERVICE_ACCOUNT_* に対応。
# ---------------------------------------------------------------------------

output "wif_provider_name" {
  description = "WIF provider のフルネーム（GitHub Variables GCP_WIF_PROVIDER_* に設定する値）。"
  value       = module.workload_identity.provider_name
}

output "wif_pool_name" {
  description = "WIF pool のフルネーム。"
  value       = module.workload_identity.pool_name
}

output "deploy_service_account_email" {
  description = "デプロイ用 SA のメール（GitHub Variables GCP_DEPLOY_SERVICE_ACCOUNT_* に設定する値）。"
  value       = module.iam.github_deploy_service_account_email
}

output "backend_runtime_service_account_email" {
  description = "backend Cloud Run runtime SA のメール（gcloud run deploy --service-account に渡す）。"
  value       = module.iam.backend_runtime_service_account_email
}

output "frontend_runtime_service_account_email" {
  description = "frontend Cloud Run runtime SA のメール。"
  value       = module.iam.frontend_runtime_service_account_email
}

# ---------------------------------------------------------------------------
# Artifact Registry
# GitHub Variables: ARTIFACT_REGISTRY_LOCATION / ARTIFACT_REGISTRY_REPOSITORY に対応。
# ---------------------------------------------------------------------------

output "artifact_registry_location" {
  description = "Artifact Registry のロケーション。"
  value       = var.region
}

output "artifact_registry_frontend_repository" {
  description = "frontend イメージ用 Artifact Registry repo ID。"
  value       = module.artifact_registry_frontend.repository_id
}

output "artifact_registry_backend_repository" {
  description = "backend イメージ用 Artifact Registry repo ID。"
  value       = module.artifact_registry_backend.repository_id
}

output "artifact_registry_frontend_url" {
  description = "frontend イメージの完全な Docker registry URL（イメージ prefix）。"
  value       = module.artifact_registry_frontend.registry_url
}

output "artifact_registry_backend_url" {
  description = "backend イメージの完全な Docker registry URL（イメージ prefix）。"
  value       = module.artifact_registry_backend.registry_url
}

# ---------------------------------------------------------------------------
# GCS バケット
# ---------------------------------------------------------------------------

output "gcs_preview_bucket" {
  description = "preview 用 GCS バケット名（object prefix pr/<PR_NUMBER>/ を使う）。"
  value       = module.gcs_preview.bucket_name
}

output "gcs_staging_bucket" {
  description = "staging 用 GCS バケット名（enable_staging=false の場合は null）。"
  value       = one(module.gcs_staging[*].bucket_name)
}

output "gcs_production_bucket" {
  description = "production 用 GCS バケット名（enable_production=false の場合は null）。"
  value       = one(module.gcs_production[*].bucket_name)
}

# ---------------------------------------------------------------------------
# Secret Manager（Secret ID のみ。値は出力しない）
# Terraform は Secret コンテナ + IAM だけを管理し、値は gcloud secrets versions add
# で別途投入する。下記は CI / 運用が参照する Secret ID の一覧。
# ---------------------------------------------------------------------------

output "secret_ids_preview" {
  description = "preview（dev project）で作る長期 Secret の ID 一覧。per-PR の preview-pr-* は含まない（GitHub Actions が作る）。"
  value       = concat(module.secret_manager_preview_backend.secret_ids, module.secret_manager_preview_neon.secret_ids)
}

output "secret_ids_staging" {
  description = "staging で作る Secret の ID 一覧（enable_staging=false なら空）。"
  value       = try(module.secret_manager_staging[0].secret_ids, [])
}

output "secret_ids_production" {
  description = "production で作る Secret の ID 一覧（enable_production=false なら空）。"
  value       = try(module.secret_manager_production[0].secret_ids, [])
}

# CI が BACKEND_RUNTIME_SA_* GitHub Variables にマップするための SA メール（環境別）。
# 単一 project では 3 つとも dev の SA に一致する。マルチプロジェクトでは staging/production を
# var.backend_runtime_sa_email_staging / _production で上書きすると、その値（= Secret accessor を
# 付与した実 SA）が出力され、GitHub Variables と Terraform バインドが一致する。
output "backend_runtime_sa_dev" {
  description = "GitHub Variables BACKEND_RUNTIME_SA_DEV に設定する backend runtime SA メール（dev/preview）。"
  value       = module.iam.backend_runtime_service_account_email
}

output "backend_runtime_sa_staging" {
  description = "GitHub Variables BACKEND_RUNTIME_SA_STAGING に設定する SA メール（単一 project なら dev SA、マルチプロジェクトなら override 値）。"
  value       = var.backend_runtime_sa_email_staging != "" ? var.backend_runtime_sa_email_staging : module.iam.backend_runtime_service_account_email
}

output "backend_runtime_sa_production" {
  description = "GitHub Variables BACKEND_RUNTIME_SA_PRODUCTION に設定する SA メール（単一 project なら dev SA、マルチプロジェクトなら override 値）。"
  value       = var.backend_runtime_sa_email_production != "" ? var.backend_runtime_sa_email_production : module.iam.backend_runtime_service_account_email
}

output "github_deploy_sa" {
  description = "GitHub Actions デプロイ SA のメール（preview-pr-* 管理 / migration で Secret Manager を読む）。"
  value       = module.iam.github_deploy_service_account_email
}

# ---------------------------------------------------------------------------
# Cloud SQL
# ---------------------------------------------------------------------------

output "cloud_sql_staging_connection_name" {
  description = "Cloud SQL staging の connection name（PROJECT:REGION:INSTANCE）。enable_staging=false なら null。"
  value       = one(module.cloud_sql_staging[*].connection_name)
}

output "cloud_sql_production_connection_name" {
  description = "Cloud SQL production の connection name（PROJECT:REGION:INSTANCE）。enable_production=false なら null。"
  value       = one(module.cloud_sql_production[*].connection_name)
}

output "cloud_sql_staging_private_ip" {
  description = "Cloud SQL staging の private IP。enable_staging=false なら null。"
  value       = one(module.cloud_sql_staging[*].private_ip_address)
}

output "cloud_sql_production_private_ip" {
  description = "Cloud SQL production の private IP。enable_production=false なら null。"
  value       = one(module.cloud_sql_production[*].private_ip_address)
}

# ---------------------------------------------------------------------------
# Memorystore (Redis)
# ---------------------------------------------------------------------------

output "redis_staging_host" {
  description = "Memorystore staging のホスト。enable_staging=false なら null。"
  value       = one(module.memorystore_staging[*].host)
}

output "redis_production_host" {
  description = "Memorystore production のホスト。enable_production=false なら null。"
  value       = one(module.memorystore_production[*].host)
}

# ---------------------------------------------------------------------------
# ネットワーク
# ---------------------------------------------------------------------------

output "network_id" {
  description = "Direct VPC egress 用 VPC の ID。staging/prod どちらも無効なら null。"
  value       = one(module.network[*].network_id)
}

output "network_subnet_id" {
  description = "Direct VPC egress 用サブネットの ID。"
  value       = one(module.network[*].subnet_id)
}
