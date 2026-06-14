# ---------------------------------------------------------------------------
# IAM module
#
# Creates the three service accounts hernes needs and grants each the minimum
# set of roles required (least privilege). NO service account JSON keys are
# created here - runtime identity comes from Cloud Run's attached SA, and
# GitHub Actions authenticates via Workload Identity Federation (see
# modules/workload-identity). Issuing long-lived keys is intentionally
# avoided.
#
# Service accounts:
#   1. frontend runtime - attached to Cloud Run frontend service. The frontend
#      is a static nginx container and needs essentially no GCP permissions, so
#      it gets an identity with an (optional, default-empty) role list.
#   2. backend runtime  - attached to Cloud Run backend service. Needs:
#        - roles/cloudsql.client            (connect to Cloud SQL: staging/prod)
#        - storage objectAdmin on its bucket (read/write app objects)
#        - roles/redis.viewer               (discover Memorystore: staging+)
#      Note: actual Redis data-plane traffic flows over Direct VPC egress and
#      needs no IAM role; redis.viewer is for instance metadata lookups only.
#   3. github deploy   - impersonated by GitHub Actions via WIF to deploy:
#        - roles/run.admin
#        - roles/artifactregistry.writer
#        - roles/iam.serviceAccountUser     (to deploy Cloud Run "as" the
#                                            runtime SAs above)
#
# Project-level role bindings use google_project_iam_member (additive,
# per-(role, member) bindings) so this module never clobbers bindings owned by
# other configs. Every role list is variable-driven for least-privilege tuning.
# ---------------------------------------------------------------------------

# === Service accounts ======================================================

resource "google_service_account" "frontend_runtime" {
  project      = var.project_id
  account_id   = var.frontend_runtime_account_id
  display_name = "hernes frontend Cloud Run runtime"
  description  = "Runtime identity for the frontend Cloud Run service. Minimal permissions; the frontend is a static nginx container."
}

resource "google_service_account" "backend_runtime" {
  project      = var.project_id
  account_id   = var.backend_runtime_account_id
  display_name = "hernes backend Cloud Run runtime"
  description  = "Runtime identity for the backend Cloud Run service. Cloud SQL client + GCS objectAdmin (own bucket) + Redis metadata."
}

resource "google_service_account" "github_deploy" {
  project      = var.project_id
  account_id   = var.github_deploy_account_id
  display_name = "hernes GitHub Actions deployer"
  description  = "Impersonated by GitHub Actions via Workload Identity Federation to deploy Cloud Run and push images. No JSON key."
}

# === Frontend runtime role bindings ========================================
# Defaults to empty: the static frontend needs no project roles. Exposed as a
# variable so a caller can add narrowly-scoped roles if ever required.
resource "google_project_iam_member" "frontend_runtime" {
  for_each = toset(var.frontend_runtime_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.frontend_runtime.email}"
}

# === Backend runtime role bindings =========================================

# Project-level roles for the backend runtime SA (e.g. roles/cloudsql.client,
# roles/redis.viewer). Variable-driven so preview (no Redis) vs staging/prod
# can pass different sets.
resource "google_project_iam_member" "backend_runtime" {
  for_each = toset(var.backend_runtime_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.backend_runtime.email}"
}

# Bucket-scoped objectAdmin for the backend runtime SA. Granted on the SPECIFIC
# environment bucket only (not project-wide storage admin) to keep blast radius
# minimal. Skipped when var.backend_gcs_bucket is null (e.g. wiring not ready).
resource "google_storage_bucket_iam_member" "backend_object_admin" {
  count = var.backend_gcs_bucket == null ? 0 : 1

  bucket = var.backend_gcs_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.backend_runtime.email}"
}

# === GitHub deploy role bindings ===========================================
# Default set is the deploy minimum: run.admin + artifactregistry.writer +
# iam.serviceAccountUser. Variable-driven so it can be tightened/extended.
resource "google_project_iam_member" "github_deploy" {
  for_each = toset(var.github_deploy_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_deploy.email}"
}
