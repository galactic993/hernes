output "connection_name" {
  description = "Cloud SQL connection name (project:region:instance), e.g. for the Cloud SQL Auth Proxy."
  value       = google_sql_database_instance.this.connection_name
}

output "instance_name" {
  description = "Cloud SQL instance name."
  value       = google_sql_database_instance.this.name
}

output "private_ip_address" {
  description = "Private IP address of the instance (reachable from the VPC)."
  value       = google_sql_database_instance.this.private_ip_address
}

output "database_name" {
  description = "Application database name."
  value       = google_sql_database.this.name
}

output "user_name" {
  description = "Application database user name."
  value       = google_sql_user.this.name
}
