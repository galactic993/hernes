# =============================================================================
# modules/network
# -----------------------------------------------------------------------------
# VPC + subnet for the hernes platform.
#
# Purpose:
#   - Provide a private VPC so Cloud Run can reach Cloud SQL (private IP) and
#     Memorystore (Redis) over private addressing only.
#   - Cloud Run egress is wired via *Direct VPC egress* (recommended over the
#     legacy Serverless VPC Access connector). Direct VPC egress attaches the
#     Cloud Run revision directly to the subnet below — no connector resource
#     is required. See the (optional) connector block at the bottom if your
#     org still mandates a Serverless VPC Access connector instead.
# =============================================================================

# Custom-mode VPC: we manage subnets explicitly (no auto-created subnets) so
# the address ranges are deterministic and auditable.
resource "google_compute_network" "this" {
  project                         = var.project_id
  name                            = var.network_name
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = false
}

# Primary subnet used by Cloud Run Direct VPC egress and as the network from
# which Cloud SQL private service access / Redis private IPs are reachable.
# Private Google Access is enabled so workloads can reach Google APIs
# (Artifact Registry, Secret Manager, GCS, etc.) without external IPs.
resource "google_compute_subnetwork" "this" {
  project                  = var.project_id
  name                     = var.subnet_name
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true

  # Optional secondary ranges (kept empty by default). Useful if the subnet is
  # ever reused for GKE pods/services; harmless for Cloud Run Direct VPC egress.
  dynamic "secondary_ip_range" {
    for_each = var.secondary_ip_ranges
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }
}

# -----------------------------------------------------------------------------
# Private Services Access (PSA) for Cloud SQL.
# Cloud SQL private IP instances live in a Google-managed VPC that is peered to
# this VPC. PSA requires (1) a reserved IP range and (2) a VPC peering using
# that range. The cloud-sql module attaches instances to var.network.
# -----------------------------------------------------------------------------
resource "google_compute_global_address" "private_service_access" {
  count         = var.enable_private_service_access ? 1 : 0
  project       = var.project_id
  name          = "${var.network_name}-psa-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.private_service_access_prefix_length
  network       = google_compute_network.this.id
}

resource "google_service_networking_connection" "private_service_access" {
  count                   = var.enable_private_service_access ? 1 : 0
  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_access[0].name]
}

# -----------------------------------------------------------------------------
# OPTION B (commented): Serverless VPC Access connector.
# Direct VPC egress (attaching the subnet directly to the Cloud Run service —
# see modules/cloud-run) is preferred. Uncomment only if your org policy still
# requires a connector. A connector needs its own /28 range, distinct from the
# subnet above.
# -----------------------------------------------------------------------------
# resource "google_vpc_access_connector" "this" {
#   project       = var.project_id
#   name          = "${var.network_name}-conn"
#   region        = var.region
#   ip_cidr_range = "10.8.0.0/28" # must NOT overlap var.subnet_cidr
#   network       = google_compute_network.this.name
#   min_instances = 2
#   max_instances = 3
# }
