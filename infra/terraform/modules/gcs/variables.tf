variable "project_id" {
  description = "GCP project ID that owns the bucket."
  type        = string
}

variable "bucket_name" {
  description = "Globally-unique bucket name, e.g. hernes-preview-<project>."
  type        = string
}

variable "location" {
  description = "Bucket location. For hernes use asia-northeast1."
  type        = string
  default     = "asia-northeast1"
}

variable "storage_class" {
  description = "Default storage class for the bucket."
  type        = string
  default     = "STANDARD"
}

variable "versioning_enabled" {
  description = "Enable object versioning (recommended for staging/production)."
  type        = bool
  default     = false
}

variable "lifecycle_age_days" {
  description = <<-EOT
    Optional age (in days) after which objects are deleted. Set to 14 for the
    preview bucket so PR artifacts auto-expire. Leave null to disable the
    lifecycle delete rule entirely (staging/production).
  EOT
  type        = number
  default     = null
}

variable "force_destroy" {
  description = <<-EOT
    Allow Terraform to delete the bucket even when it still contains objects.
    Only enable for ephemeral preview buckets; keep false for staging/prod.
  EOT
  type        = bool
  default     = false
}

variable "labels" {
  description = "Resource labels (e.g. app=hernes, env=<env>, managed-by=github-actions)."
  type        = map(string)
  default     = {}
}
