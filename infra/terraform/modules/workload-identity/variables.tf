variable "project_id" {
  description = "GCP project ID hosting the Workload Identity pool/provider."
  type        = string
}

variable "pool_id" {
  description = "Workload Identity Pool ID (4-32 chars), e.g. hernes-github-pool."
  type        = string
  default     = "hernes-github-pool"
}

variable "pool_display_name" {
  description = "Display name for the Workload Identity Pool."
  type        = string
  default     = "hernes GitHub Actions pool"
}

variable "provider_id" {
  description = "Workload Identity Pool Provider ID (4-32 chars), e.g. github."
  type        = string
  default     = "github"
}

variable "provider_display_name" {
  description = "Display name for the OIDC provider."
  type        = string
  default     = "GitHub Actions OIDC"
}

variable "github_repository" {
  description = <<-EOT
    GitHub repository allowed to authenticate, in "owner/repo" form
    (matches the OIDC `repository` claim). Used both in the provider
    attribute_condition and in the deploy SA principalSet binding.
  EOT
  type        = string
}

variable "allowed_refs" {
  description = <<-EOT
    Git refs allowed to mint credentials, matching the OIDC `ref` claim, e.g.
    ["refs/heads/main"]. Empty list = do not constrain by ref (rely on
    repository + environment instead). Preview deploys are typically gated by
    environment rather than ref.
  EOT
  type        = list(string)
  default     = []
}

variable "allowed_environments" {
  description = <<-EOT
    GitHub Environments allowed to mint credentials, matching the OIDC
    `environment` claim, e.g. ["preview"], ["staging"], ["production"]. Empty
    list = do not constrain by environment. For the production project, set
    this to ["production"] so only the approval-gated environment qualifies.
  EOT
  type        = list(string)
  default     = []
}

variable "allowed_audiences" {
  description = <<-EOT
    Allowed OIDC audiences. Leave empty to accept the provider's default
    audience (its full resource name), which google-github-actions/auth uses
    automatically. Override only for custom audience setups.
  EOT
  type        = list(string)
  default     = []
}

variable "deploy_service_account_id" {
  description = <<-EOT
    Fully-qualified resource ID of the deploy service account to bind for
    impersonation, e.g.
    projects/<project>/serviceAccounts/<sa-email>. Use the IAM module's
    github_deploy SA. Required for the workloadIdentityUser binding.
  EOT
  type        = string
}

variable "deploy_service_account_email" {
  description = <<-EOT
    Email of the deploy service account. Not used to create resources here; it
    is re-exported as an output for convenience so callers can wire the
    GitHub Actions `service_account` input alongside `provider_name`.
  EOT
  type        = string
}
