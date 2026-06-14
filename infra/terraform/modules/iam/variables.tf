variable "project_id" {
  description = "GCP project ID in which the service accounts and bindings live."
  type        = string
}

# --- Service account IDs ---------------------------------------------------

variable "frontend_runtime_account_id" {
  description = "account_id for the frontend Cloud Run runtime SA (6-30 chars)."
  type        = string
  default     = "hernes-frontend-run"
}

variable "backend_runtime_account_id" {
  description = "account_id for the backend Cloud Run runtime SA (6-30 chars)."
  type        = string
  default     = "hernes-backend-run"
}

variable "github_deploy_account_id" {
  description = "account_id for the GitHub Actions deploy SA (6-30 chars)."
  type        = string
  default     = "hernes-github-deploy"
}

# --- Role lists (least privilege; tune per environment) --------------------

variable "frontend_runtime_roles" {
  description = <<-EOT
    Project roles for the frontend runtime SA. Empty by default - the static
    nginx frontend needs no GCP permissions. Add narrowly only if required.
  EOT
  type        = list(string)
  default     = []
}

variable "backend_runtime_roles" {
  description = <<-EOT
    Project roles for the backend runtime SA. Bucket access is granted
    separately (see backend_gcs_bucket). Defaults cover Cloud SQL connectivity
    and Memorystore (Redis) instance discovery.
      - roles/cloudsql.client : connect to Cloud SQL (staging/production)
      - roles/redis.viewer    : read Memorystore instance metadata (staging+)
    For PREVIEW (Neon DB, REDIS_ENABLED=false) pass [] or only the roles needed.
  EOT
  type        = list(string)
  default = [
    "roles/cloudsql.client",
    "roles/redis.viewer",
  ]
}

variable "backend_gcs_bucket" {
  description = <<-EOT
    Name of the GCS bucket on which the backend runtime SA receives
    roles/storage.objectAdmin (bucket-scoped, not project-wide). Set to null to
    skip the binding.
  EOT
  type        = string
  default     = null
}

variable "github_deploy_roles" {
  description = <<-EOT
    Project roles for the GitHub Actions deploy SA. Defaults are the deploy
    minimum:
      - roles/run.admin                : deploy/manage Cloud Run services
      - roles/artifactregistry.writer  : push container images
      - roles/iam.serviceAccountUser   : act as the runtime SAs during deploy
    NOTE: roles/iam.serviceAccountUser is granted at project scope here for
    simplicity. To further restrict, replace with per-SA serviceAccountUser
    bindings on only the frontend/backend runtime SAs.
  EOT
  type        = list(string)
  default = [
    "roles/run.admin",
    "roles/artifactregistry.writer",
    "roles/iam.serviceAccountUser",
  ]
}
