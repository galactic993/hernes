output "secret_ids" {
  description = "The list of secret CONTAINER ids created by this module."
  value       = var.secret_ids
}

output "secret_names" {
  description = "Map of secret_id -> full resource name (projects/<p>/secrets/<id>). NEVER contains values."
  value       = { for id, s in google_secret_manager_secret.this : id => s.name }
}
