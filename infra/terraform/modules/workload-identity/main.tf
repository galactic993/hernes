# ---------------------------------------------------------------------------
# Workload Identity Federation (WIF) module
#
# Lets GitHub Actions authenticate to GCP WITHOUT any service account JSON key.
# GitHub's OIDC token is exchanged for short-lived GCP credentials that
# impersonate the deploy SA (var.deploy_service_account_email, produced by
# modules/iam.github_deploy).
#
# Trust is locked down at two layers:
#   1. attribute_condition on the provider - a CEL expression that REJECTS any
#      OIDC token whose claims don't match the allowed repository / refs /
#      environments. This is the primary security gate.
#   2. workloadIdentityUser IAM binding - only principals from this pool that
#      match the configured principalSet may impersonate the deploy SA.
#
# Manual setup prerequisite (once per project):
#   gcloud services enable iamcredentials.googleapis.com sts.googleapis.com
#
# GitHub Actions usage (google-github-actions/auth):
#   workload_identity_provider: <output provider_name>
#   service_account:            <var.deploy_service_account_email>
# ---------------------------------------------------------------------------

# === Workload Identity Pool ================================================
resource "google_iam_workload_identity_pool" "this" {
  project = var.project_id

  workload_identity_pool_id = var.pool_id
  display_name              = var.pool_display_name
  description               = "WIF pool for hernes GitHub Actions OIDC. No SA keys."
  disabled                  = false
}

# === OIDC Provider (GitHub Actions) ========================================
resource "google_iam_workload_identity_pool_provider" "github" {
  project = var.project_id

  workload_identity_pool_id          = google_iam_workload_identity_pool.this.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = var.provider_display_name
  description                        = "GitHub Actions OIDC provider, restricted by repository/ref/environment claims."

  # Map GitHub OIDC claims to Google STS attributes. Only mapped attributes can
  # be referenced in attribute_condition and in the SA principalSet binding.
  attribute_mapping = {
    "google.subject"        = "assertion.sub"
    "attribute.repository"  = "assertion.repository"
    "attribute.ref"         = "assertion.ref"
    "attribute.environment" = "assertion.environment"
  }

  # PRIMARY SECURITY GATE.
  # Reject any token not coming from the allowed repository, and additionally
  # require the ref OR the environment to be in the allow-lists. This blocks
  # forks/other repos from minting credentials for this project.
  #
  # Production hardening: tighten these allow-lists per environment. For the
  # production project, prefer environment-claim pinning (e.g.
  # attribute.environment == 'production') combined with GitHub Environment
  # approval, rather than broad ref matching.
  attribute_condition = join(" && ", compact([
    "attribute.repository == \"${var.github_repository}\"",
    length(var.allowed_refs) == 0 ? "" : "attribute.ref in [${join(", ", formatlist("\"%s\"", var.allowed_refs))}]",
    length(var.allowed_environments) == 0 ? "" : "attribute.environment in [${join(", ", formatlist("\"%s\"", var.allowed_environments))}]",
  ]))

  oidc {
    # GitHub Actions OIDC issuer. Fixed value.
    issuer_uri = "https://token.actions.githubusercontent.com"
    # Restrict the audience to this provider's full resource name so tokens
    # minted for other audiences are not accepted.
    allowed_audiences = var.allowed_audiences
  }
}

# === Allow the deploy SA to be impersonated from this pool =================
# Binds roles/iam.workloadIdentityUser so federated GitHub identities can
# impersonate the deploy SA. The principalSet is scoped to the configured
# repository attribute, so even within the pool only the right repo qualifies.
resource "google_service_account_iam_member" "deploy_sa_wif" {
  service_account_id = var.deploy_service_account_id
  role               = "roles/iam.workloadIdentityUser"
  member = format(
    "principalSet://iam.googleapis.com/%s/attribute.repository/%s",
    google_iam_workload_identity_pool.this.name,
    var.github_repository,
  )
}
