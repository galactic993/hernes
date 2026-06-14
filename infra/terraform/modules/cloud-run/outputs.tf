output "service_uri" {
  description = "Public HTTPS URL of the Cloud Run service."
  value       = google_cloud_run_v2_service.this.uri
}

output "service_name" {
  description = "Cloud Run service name."
  value       = google_cloud_run_v2_service.this.name
}

output "latest_ready_revision" {
  description = "Name of the latest ready revision."
  value       = google_cloud_run_v2_service.this.latest_ready_revision
}

output "location" {
  description = "Region the service is deployed in."
  value       = google_cloud_run_v2_service.this.location
}
