# ---------------------------------------------------------------------------
# GCS bucket module
#
# Creates ONE Cloud Storage bucket. Invoked once per environment bucket:
#   - preview:    hernes-preview-<project>    (lifecycle 14d auto-delete)
#   - staging:    hernes-staging-<project>
#   - production: hernes-production-<project>
#
# Security baseline enforced for every bucket:
#   - uniform_bucket_level_access = true  (no per-object ACLs; IAM only)
#   - public_access_prevention    = "enforced" (never publicly accessible)
# ---------------------------------------------------------------------------

resource "google_storage_bucket" "this" {
  project = var.project_id
  name    = var.bucket_name

  # Region for the bucket. hernes uses asia-northeast1.
  location = var.location

  # Standard storage class is appropriate for app object storage.
  storage_class = var.storage_class

  # --- Security: IAM-only access, no public exposure ---------------------
  # Uniform bucket-level access disables object ACLs and forces all access
  # to be granted via IAM (see modules/iam objectAdmin binding for backend).
  uniform_bucket_level_access = true

  # Block any configuration that would make objects publicly readable.
  public_access_prevention = "enforced"

  # Versioning is opt-in per environment (typically off for preview, on for
  # staging/production to protect against accidental overwrite/delete).
  versioning {
    enabled = var.versioning_enabled
  }

  # Optional age-based deletion. Used by the preview bucket (14 days) so PR
  # artifacts are auto-reclaimed. When var.lifecycle_age_days is null the
  # dynamic block emits nothing and no lifecycle rule is created.
  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_age_days == null ? [] : [var.lifecycle_age_days]
    content {
      action {
        type = "Delete"
      }
      condition {
        age = lifecycle_rule.value
      }
    }
  }

  # Common hernes labels: app / env / managed-by, plus caller-provided.
  labels = var.labels

  # For preview buckets that are torn down with PRs, allow Terraform to
  # delete the bucket even if it still holds objects (gated by a variable so
  # staging/production keep the safe default of false).
  force_destroy = var.force_destroy
}
