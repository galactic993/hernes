output "network_id" {
  description = "Fully-qualified VPC network ID (projects/<p>/global/networks/<n>)."
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "VPC network name (used by cloud-sql / memorystore authorized_network)."
  value       = google_compute_network.this.name
}

output "network_self_link" {
  description = "VPC network self_link (used by Memorystore authorized_network)."
  value       = google_compute_network.this.self_link
}

output "subnet_id" {
  description = "Subnet ID for Cloud Run Direct VPC egress (network_interfaces.subnetwork)."
  value       = google_compute_subnetwork.this.id
}

output "subnet_name" {
  description = "Subnet name."
  value       = google_compute_subnetwork.this.name
}

output "subnet_self_link" {
  description = "Subnet self_link."
  value       = google_compute_subnetwork.this.self_link
}

# Empty string when PSA is disabled; otherwise the peering connection used to
# express dependency ordering for cloud-sql private IP instances.
output "private_service_access_connection" {
  description = "Service Networking peering connection (depend on this before creating private-IP Cloud SQL instances)."
  value       = var.enable_private_service_access ? google_service_networking_connection.private_service_access[0].id : ""
}
