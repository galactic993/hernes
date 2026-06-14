variable "project_id" {
  description = "GCP project ID that owns the Artifact Registry repository."
  type        = string
}

variable "location" {
  description = "Artifact Registry location. For hernes use asia-northeast1."
  type        = string
  default     = "asia-northeast1"
}

variable "repository_id" {
  description = "Repository ID, e.g. hernes-frontend or hernes-backend."
  type        = string
}

variable "description" {
  description = "Human-readable description of the repository."
  type        = string
  default     = "Docker repository managed by Terraform for hernes."
}

variable "labels" {
  description = "Resource labels (e.g. app=hernes, managed-by=github-actions)."
  type        = map(string)
  default     = {}
}
