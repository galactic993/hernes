# bootstrap/variables.tf

variable "app_name" {
  description = "アプリ名（ラベル用）。"
  type        = string
  default     = "hernes"
}

variable "project_id" {
  description = "state バケットを作る GCP project ID。"
  type        = string
}

variable "region" {
  description = "state バケットのロケーション。"
  type        = string
  default     = "asia-northeast1"
}

variable "state_bucket_name" {
  description = "Terraform state 用 GCS バケット名（グローバル一意）。例: hernes-tfstate-<PROJECT_ID>"
  type        = string
}

output "state_bucket_name" {
  description = "作成した state バケット名。infra/terraform の -backend-config=bucket=... に渡す。"
  value       = google_storage_bucket.tfstate.name
}
