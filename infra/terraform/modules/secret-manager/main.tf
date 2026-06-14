# ---------------------------------------------------------------------------
# Secret Manager module
#
# Manages secret CONTAINERS (google_secret_manager_secret) + IAM bindings for
# one environment. Invoked once per env (preview / staging / production).
#
# IMPORTANT: This module NEVER creates a google_secret_manager_secret_version
# with a real value. Terraform は Secret 値を扱わない。Secret VALUES are added
# out-of-band via `gcloud secrets versions add` (see scripts/gcp/secret-*.sh).
# Per-PR `preview-pr-<N>-database-url` secrets are created by GitHub Actions,
# NOT here.
# ---------------------------------------------------------------------------

# Secret containers, one per id. Automatic replication keeps the value close to
# the regions that need it without us managing replica placement.
resource "google_secret_manager_secret" "this" {
  for_each = toset(var.secret_ids)

  project   = var.project_id
  secret_id = each.value

  replication {
    auto {}
  }

  labels = var.labels
}

# accessor_members x secret_ids -> roles/secretmanager.secretAccessor.
# The runtime SA reads these directly from Cloud Run via --update-secrets.
resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = {
    for pair in setproduct(var.secret_ids, var.accessor_members) :
    "${pair[0]}::${pair[1]}" => {
      secret_id = pair[0]
      member    = pair[1]
    }
  }

  project   = var.project_id
  secret_id = google_secret_manager_secret.this[each.value.secret_id].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value.member
}

# deployer_member -> secretAccessor on each deployer_accessor_secret_ids.
# Used by the CI migration step (proxy-based) to read DATABASE_URL.
resource "google_secret_manager_secret_iam_member" "deployer_accessor" {
  for_each = var.deployer_member == "" ? toset([]) : toset(var.deployer_accessor_secret_ids)

  project   = var.project_id
  secret_id = google_secret_manager_secret.this[each.value].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = var.deployer_member
}

# Optional PROJECT-scoped roles/secretmanager.admin for the deploy SA.
# Used on the dev/preview project so the workflow can create/version/delete
# preview-pr-* secrets and read preview-neon-api-key.
resource "google_project_iam_member" "admin" {
  count = var.admin_project && var.admin_member != "" ? 1 : 0

  project = var.project_id
  role    = "roles/secretmanager.admin"
  member  = var.admin_member
}
