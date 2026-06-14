output "frontend_runtime_service_account_email" {
  description = "Email of the frontend Cloud Run runtime service account."
  value       = google_service_account.frontend_runtime.email
}

output "backend_runtime_service_account_email" {
  description = "Email of the backend Cloud Run runtime service account."
  value       = google_service_account.backend_runtime.email
}

output "github_deploy_service_account_email" {
  description = "Email of the GitHub Actions deploy service account (impersonated via WIF)."
  value       = google_service_account.github_deploy.email
}
