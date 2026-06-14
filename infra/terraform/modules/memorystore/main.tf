# =============================================================================
# modules/memorystore
# -----------------------------------------------------------------------------
# Memorystore for Redis instance (google_redis_instance).
#
# Used for Staging and Prod only. Preview/PR environments run with
# REDIS_ENABLED=false and do NOT instantiate this module.
#
# Connectivity: the instance is attached to the hernes VPC via
# authorized_network; Cloud Run reaches it over Direct VPC egress using the
# private host/port emitted by this module.
# =============================================================================

resource "google_redis_instance" "this" {
  project        = var.project_id
  name           = var.name
  region         = var.region
  tier           = var.tier # BASIC (single node) | STANDARD_HA (replicated, prod)
  memory_size_gb = var.memory_size_gb
  redis_version  = var.redis_version

  # Private connectivity: bind the instance to the VPC. With DIRECT_PEERING the
  # instance gets a private IP reachable from Cloud Run Direct VPC egress.
  authorized_network = var.authorized_network
  connect_mode       = var.connect_mode

  # Pin location(s). For STANDARD_HA set both an alternative zone for the read
  # replica; for BASIC only the primary is used.
  location_id             = var.location_id
  alternative_location_id = var.tier == "STANDARD_HA" ? var.alternative_location_id : null

  # Encrypt in transit. AUTH adds a per-instance password (read via auth_string).
  auth_enabled            = var.auth_enabled
  transit_encryption_mode = var.transit_encryption_mode

  display_name = var.display_name
  labels       = var.labels

  # Maintenance window (low-traffic). day: MONDAY..SUNDAY.
  dynamic "maintenance_policy" {
    for_each = var.maintenance_window_day == null ? [] : [1]
    content {
      weekly_maintenance_window {
        day = var.maintenance_window_day
        start_time {
          hours   = var.maintenance_window_hour
          minutes = 0
          seconds = 0
          nanos   = 0
        }
      }
    }
  }
}
