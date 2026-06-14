output "host" {
  description = "Private IP / hostname of the Redis primary endpoint."
  value       = google_redis_instance.this.host
}

output "port" {
  description = "Port the Redis endpoint listens on."
  value       = google_redis_instance.this.port
}

output "current_location_id" {
  description = "Zone currently hosting the (primary) instance."
  value       = google_redis_instance.this.current_location_id
}

output "auth_string" {
  description = "Redis AUTH password when auth_enabled=true (empty otherwise). Treat as a secret."
  value       = google_redis_instance.this.auth_string
  sensitive   = true
}

output "id" {
  description = "Fully-qualified Redis instance ID."
  value       = google_redis_instance.this.id
}
