variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "name" {
  description = "Cloud Run service name (e.g. backend-staging, frontend-prod, backend-pr-123)."
  type        = string
}

variable "region" {
  description = "Region for the Cloud Run service (e.g. asia-northeast1)."
  type        = string
  default     = "asia-northeast1"
}

variable "image" {
  description = "Fully-qualified container image (Artifact Registry), e.g. asia-northeast1-docker.pkg.dev/<project>/hernes-backend/backend:<sha>."
  type        = string
}

variable "service_account" {
  description = "Runtime service account email the revision runs as."
  type        = string
}

variable "port" {
  description = "Container listen port. hernes services listen on 8080."
  type        = number
  default     = 8080
}

variable "env" {
  description = "Non-secret environment variables (map of name => value). Do NOT put secrets here."
  type        = map(string)
  default     = {}
}

variable "secret_env" {
  description = "Secret-backed env vars sourced from Secret Manager: { ENV_NAME = { secret = \"<secret-id>\", version = \"latest\" } }."
  type = map(object({
    secret  = string
    version = optional(string, "latest")
  }))
  default = {}
}

variable "ingress" {
  description = "Ingress setting: INGRESS_TRAFFIC_ALL | INGRESS_TRAFFIC_INTERNAL_ONLY | INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER."
  type        = string
  default     = "INGRESS_TRAFFIC_ALL"
}

variable "min_instances" {
  description = "Minimum number of instances. 0 for PR/preview (scale to zero); >=1 for prod to avoid cold starts."
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of instances."
  type        = number
  default     = 10
}

variable "cpu" {
  description = "CPU limit per instance (e.g. \"1\", \"2\")."
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory limit per instance (e.g. \"512Mi\", \"1Gi\")."
  type        = string
  default     = "512Mi"
}

variable "labels" {
  description = "Resource labels (app/env/pr/managed-by/commit-sha)."
  type        = map(string)
  default     = {}
}

# ---- VPC / Direct VPC egress -------------------------------------------------
variable "network" {
  description = "VPC network name or ID for Direct VPC egress. Required together with var.subnet to enable VPC access."
  type        = string
  default     = null
}

variable "subnet" {
  description = "Subnet name or ID for Direct VPC egress. When null, no VPC access is configured (suitable for preview where Redis/private DB are not used)."
  type        = string
  default     = null
}

variable "vpc_egress" {
  description = "Direct VPC egress mode: PRIVATE_RANGES_ONLY (only RFC1918 via VPC) or ALL_TRAFFIC."
  type        = string
  default     = "PRIVATE_RANGES_ONLY"
}

variable "vpc_network_tags" {
  description = "Optional network tags applied to the revision's VPC interface (for firewall targeting)."
  type        = list(string)
  default     = []
}

# ---- Cloud SQL ---------------------------------------------------------------
variable "cloud_sql_connection_name" {
  description = "Optional Cloud SQL connection name (project:region:instance) to mount via the Cloud SQL Auth Proxy. Null to skip."
  type        = string
  default     = null
}

# ---- Health check ------------------------------------------------------------
variable "enable_health_check" {
  description = "Whether to configure an HTTP startup probe."
  type        = bool
  default     = true
}

variable "health_check_path" {
  description = "HTTP path for the startup probe. backend uses /healthz."
  type        = string
  default     = "/healthz"
}

# ---- IAM ---------------------------------------------------------------------
variable "allow_unauthenticated" {
  description = "Grant roles/run.invoker to allUsers (public access). True for public frontend/backend."
  type        = bool
  default     = true
}
