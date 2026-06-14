# variables.tf
# ルート構成の入力変数。
#
# 運用モデル:
#   - 単一 project 運用: project_id だけ指定すれば全環境が同じ project に乗る。
#   - 複数 project 運用: project_id_staging / project_id_production を上書きすると分離できる。
#     （指定なしの場合は project_id にフォールバックする。main.tf の local で解決する。）

# ---------------------------------------------------------------------------
# 共通
# ---------------------------------------------------------------------------

variable "app_name" {
  description = "アプリ名。リソース名・ラベルの接頭辞に使う。"
  type        = string
  default     = "hernes"
}

variable "region" {
  description = "GCP リージョン（Artifact Registry / Cloud Run / Cloud SQL / Memorystore）。"
  type        = string
  default     = "asia-northeast1"
}

# ---------------------------------------------------------------------------
# プロジェクト（単一でも複数でも動く）
# ---------------------------------------------------------------------------

variable "project_id" {
  description = "ベースとなる GCP project ID。staging/prod を上書きしなければ全環境がこれを使う（= dev/共通 project）。"
  type        = string
}

variable "project_id_staging" {
  description = "staging を別 project に分けたい場合に指定。空なら project_id にフォールバック。"
  type        = string
  default     = ""
}

variable "project_id_production" {
  description = "production を別 project に分けたい場合に指定。空なら project_id にフォールバック。"
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# マルチプロジェクト運用時の backend runtime SA（Secret Manager accessor 用）
#
# iam モジュールは base/dev project にしか SA を作らない。staging/production を別
# project に分ける場合、その project 側の backend runtime SA に staging-* /
# production-* Secret の secretAccessor を付ける必要がある。下記にその SA の email を
# 渡すと secret-manager モジュールがバインドする。単一 project 運用なら空でよい。
# 値は GitHub Variables の BACKEND_RUNTIME_SA_STAGING / _PRODUCTION と一致させること。
# ---------------------------------------------------------------------------

variable "backend_runtime_sa_email_staging" {
  description = "staging を別 project に分ける場合の staging backend runtime SA email。空なら dev の SA を使う（単一 project）。"
  type        = string
  default     = ""
}

variable "backend_runtime_sa_email_production" {
  description = "production を別 project に分ける場合の production backend runtime SA email。空なら dev の SA を使う（単一 project）。"
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# GitHub / Workload Identity Federation
# ---------------------------------------------------------------------------

variable "github_repository" {
  description = "GitHub リポジトリ \"owner/repo\"。WIF の attribute condition / principalSet 制限に使う。"
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "github_repository は \"owner/repo\" 形式で指定してください。"
  }
}

# ---------------------------------------------------------------------------
# 環境フラグ（preview は GitHub Actions が動的に作るので Terraform 管理対象外）
# ---------------------------------------------------------------------------

variable "enable_staging" {
  description = "staging 用リソース（Cloud SQL / Memorystore / staging bucket 等）を作るか。"
  type        = bool
  default     = true
}

variable "enable_production" {
  description = "production 用リソース（Cloud SQL / Memorystore / production bucket 等）を作るか。"
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Cloud SQL (PostgreSQL) — staging / prod のみ。Preview は Neon を使うので作らない。
# ---------------------------------------------------------------------------

variable "db_tier_staging" {
  description = "Cloud SQL staging の machine tier。"
  type        = string
  default     = "db-custom-1-3840"
}

variable "db_tier_production" {
  description = "Cloud SQL production の machine tier。"
  type        = string
  default     = "db-custom-2-7680"
}

# NOTE: PostgreSQL バージョンは modules/cloud-sql 側で固定（POSTGRES_16）。
# ルートからは渡さない（モジュール I/F に database_version 入力が無いため）。

variable "db_name" {
  description = "アプリ用データベース名。"
  type        = string
  default     = "hernes"
}

# アプリ DB ユーザのパスワード。機密。
# 実運用では GCP Secret Manager 由来の値を TF_VAR_db_app_password_* で渡す。
# terraform.tfvars に実値を書かない。プレースホルダ default は scaffold 用。
variable "db_app_password_staging" {
  description = "Cloud SQL staging のアプリユーザパスワード（機密）。TF_VAR_ で注入する。"
  type        = string
  sensitive   = true
  default     = "CHANGE_ME_staging" # scaffold 用プレースホルダ。実運用で必ず上書き。
}

variable "db_app_password_production" {
  description = "Cloud SQL production のアプリユーザパスワード（機密）。TF_VAR_ で注入する。"
  type        = string
  sensitive   = true
  default     = "CHANGE_ME_production" # scaffold 用プレースホルダ。実運用で必ず上書き。
}

# ---------------------------------------------------------------------------
# Memorystore (Redis) — staging 以上のみ。Preview は REDIS_ENABLED=false。
# ---------------------------------------------------------------------------

variable "redis_tier" {
  description = "Memorystore Redis の tier（BASIC / STANDARD_HA）。"
  type        = string
  default     = "BASIC"
}

variable "redis_memory_size_gb" {
  description = "Memorystore Redis の容量(GB)。"
  type        = number
  default     = 1
}

# ---------------------------------------------------------------------------
# ネットワーク（Cloud Run -> Cloud SQL / Memorystore を Direct VPC egress で接続）
# ---------------------------------------------------------------------------

variable "network_subnet_cidr" {
  description = "Direct VPC egress 用サブネットの CIDR。"
  type        = string
  default     = "10.8.0.0/24"
}
