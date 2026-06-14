output "repository_id" {
  description = "The repository ID (short name), e.g. hernes-frontend."
  value       = google_artifact_registry_repository.this.repository_id
}

output "registry_url" {
  description = <<-EOT
    Fully-qualified Docker registry URL for this repository, usable as an
    image prefix, e.g.:
      asia-northeast1-docker.pkg.dev/<project>/hernes-backend
  EOT
  value = format(
    "%s-docker.pkg.dev/%s/%s",
    google_artifact_registry_repository.this.location,
    google_artifact_registry_repository.this.project,
    google_artifact_registry_repository.this.repository_id,
  )
}
