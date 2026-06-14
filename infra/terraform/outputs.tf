# outputs.tf
# GitHub Actions の GitHub Variables 設定や運用で必要になる値を出力する。
# 機密値（DB パスワード等）は出力しない。Secrets は Infisical が source of truth。

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
