output "provider_name" {
  description = <<-EOT
    Fully-qualified provider resource name, used as the
    `workload_identity_provider` input for google-github-actions/auth, e.g.:
      projects/<num>/locations/global/workloadIdentityPools/<pool>/providers/github
  EOT
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "pool_name" {
  description = <<-EOT
    Fully-qualified Workload Identity Pool resource name, e.g.:
      projects/<num>/locations/global/workloadIdentityPools/<pool>
  EOT
  value       = google_iam_workload_identity_pool.this.name
}

output "deploy_service_account_email" {
  description = "Email of the deploy SA to pass as `service_account` to google-github-actions/auth."
  value       = var.deploy_service_account_email
}
