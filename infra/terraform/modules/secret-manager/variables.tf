variable "project_id" {
  description = "GCP project ID that owns the secrets and IAM bindings."
  type        = string
}

variable "environment" {
  description = "Environment name for this module instance (e.g. preview / staging / production). Used in labels."
  type        = string
}

variable "region" {
  description = "GCP region. Secrets use automatic replication, so this is informational only. hernes uses asia-northeast1."
  type        = string
  default     = "asia-northeast1"
}

variable "secret_ids" {
  description = <<-EOT
    Secret CONTAINERS (google_secret_manager_secret) to create for this env.
    Only the containers are managed here; secret VALUES are added out-of-band
    via `gcloud secrets versions add` (Terraform never handles secret values).
  EOT
  type        = list(string)
}

variable "accessor_members" {
  description = <<-EOT
    SA principals (e.g. "serviceAccount:hernes-backend-run@<project>.iam.gserviceaccount.com")
    that get roles/secretmanager.secretAccessor on EACH secret in secret_ids.
  EOT
  type        = list(string)
  default     = []
}

variable "deployer_accessor_secret_ids" {
  description = <<-EOT
    Subset of secret_ids that deployer_member can read (secretAccessor), used by
    the CI migration step to read DATABASE_URL.
  EOT
  type        = list(string)
  default     = []
}

variable "deployer_member" {
  description = "Deploy SA principal granted secretAccessor on each deployer_accessor_secret_ids. Empty to skip."
  type        = string
  default     = ""
}

variable "admin_member" {
  description = "Deploy SA principal granted roles/secretmanager.admin at PROJECT scope when admin_project=true. Empty to skip."
  type        = string
  default     = ""
}

variable "admin_project" {
  description = <<-EOT
    When true (and admin_member is set), grant admin_member roles/secretmanager.admin
    at PROJECT scope. Used for the dev/preview env so the workflow can create/version/
    delete per-PR preview-pr-* secrets and read preview-neon-api-key.
  EOT
  type        = bool
  default     = false
}

variable "labels" {
  description = "Resource labels applied to every secret (e.g. app=hernes, env=<env>, managed-by=terraform)."
  type        = map(string)
  default     = {}
}
