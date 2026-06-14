# =============================================================================
# modules/cloud-sql
# -----------------------------------------------------------------------------
# Cloud SQL for PostgreSQL 16 instance + database + user.
#
# Used for Staging and Prod (completely separate from Neon, which is Preview-
# only). Private IP only: the instance is attached to the hernes VPC and is NOT
# reachable from the public internet. Requires the network's Private Services
# Access peering (see modules/network.enable_private_service_access) to exist
# first — express that with a depends_on in the root module.
#
# Prod hardening (backups / PITR / maintenance window / deletion protection)
# is toggled via variables so the same module serves staging and prod.
# =============================================================================

resource "google_sql_database_instance" "this" {
  project          = var.project_id
  name             = var.instance_name
  region           = var.region
  database_version = "POSTGRES_16"

  # Guard against accidental `terraform destroy`. Set true for prod.
  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    availability_type = var.availability_type # ZONAL (staging) | REGIONAL (prod HA)
    disk_type         = "PD_SSD"
    disk_size         = var.disk_size
    disk_autoresize   = true

    # ---- Private IP only -------------------------------------------------
    # No public IP. ipv4_enabled=false forces all access through the VPC via
    # private_network (the Service Networking peering created in modules/network).
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.network
      enable_private_path_for_google_cloud_services = true
    }

    # ---- Backups + Point-In-Time Recovery --------------------------------
    # Enabled for prod; can be disabled for staging to cut cost. PITR requires
    # binary logging style WAL retention (transaction_log_retention_days).
    backup_configuration {
      enabled                        = var.backup_enabled
      start_time                     = var.backup_start_time
      point_in_time_recovery_enabled = var.point_in_time_recovery_enabled
      transaction_log_retention_days = var.transaction_log_retention_days
      backup_retention_settings {
        retained_backups = var.retained_backups
        retention_unit   = "COUNT"
      }
    }

    # ---- Maintenance window ----------------------------------------------
    # Pin updates to a low-traffic window for prod. day: 1=Mon .. 7=Sun.
    maintenance_window {
      day          = var.maintenance_window_day
      hour         = var.maintenance_window_hour
      update_track = var.maintenance_update_track
    }

    # Useful default flags; extend via var.database_flags.
    dynamic "database_flags" {
      for_each = var.database_flags
      content {
        name  = database_flags.value.name
        value = database_flags.value.value
      }
    }

    user_labels = var.labels
  }
}

# Application database.
resource "google_sql_database" "this" {
  project  = var.project_id
  name     = var.database_name
  instance = google_sql_database_instance.this.name

  # PostgreSQL defaults; explicit for clarity.
  charset   = "UTF8"
  collation = "en_US.UTF8"
}

# Application user. Password is supplied as a (sensitive) variable, expected to
# originate from GCP Secret Manager — never hard-coded.
resource "google_sql_user" "this" {
  project  = var.project_id
  name     = var.user_name
  instance = google_sql_database_instance.this.name
  password = var.user_password
}
