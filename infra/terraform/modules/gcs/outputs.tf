output "bucket_name" {
  description = "The name of the created bucket."
  value       = google_storage_bucket.this.name
}

output "bucket_url" {
  description = "The gs:// URL of the bucket, e.g. gs://hernes-preview-<project>."
  value       = google_storage_bucket.this.url
}
