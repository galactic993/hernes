# ---------------------------------------------------------------------------
# Artifact Registry module
#
# Creates a single Docker-format Artifact Registry repository.
# Invoked once per image repo (e.g. hernes-frontend, hernes-backend) by
# parameterizing `repository_id`.
#
# Manual setup prerequisite (not managed here, do it once per project):
#   gcloud services enable artifactregistry.googleapis.com
# ---------------------------------------------------------------------------

resource "google_artifact_registry_repository" "this" {
  project = var.project_id

  # Region for the repo. For hernes this is asia-northeast1 (same region as
  # Cloud Run / Cloud SQL / Memorystore to avoid cross-region pull latency).
  location = var.location

  # Repository name, e.g. "hernes-frontend" or "hernes-backend".
  repository_id = var.repository_id

  # Docker images only for this template.
  format = "DOCKER"

  description = var.description

  # Common hernes labels: app / managed-by, plus any caller-provided labels.
  labels = var.labels
}
