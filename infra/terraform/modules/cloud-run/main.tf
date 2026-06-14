# =============================================================================
# modules/cloud-run
# -----------------------------------------------------------------------------
# A single Cloud Run service (google_cloud_run_v2_service).
#
# General-purpose: used to create the long-lived base services
# (frontend-staging / backend-staging / frontend-prod / backend-prod) and can
# equally back ephemeral PR services if desired.
#
# Notes for hernes:
#   - backend listens on 8080, serves GET /healthz, runs via tsx.
#   - frontend is served by nginx on 8080.
#   - Connectivity to Cloud SQL / Redis uses Direct VPC egress: attach the
#     revision to a VPC subnet (var.subnet) rather than a Serverless VPC
#     connector. Set var.cloud_sql_connection_name to additionally mount the
#     Cloud SQL Auth Proxy unix socket.
# =============================================================================

resource "google_cloud_run_v2_service" "this" {
  project  = var.project_id
  name     = var.name
  location = var.region

  # Ingress controls who can reach the service:
  #   INGRESS_TRAFFIC_ALL                   -> public internet
  #   INGRESS_TRAFFIC_INTERNAL_ONLY         -> VPC / same-project only
  #   INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER
  ingress = var.ingress

  labels = var.labels

  template {
    # Runtime service account (deploy-time identity is separate, via WIF).
    service_account = var.service_account

    # Autoscaling bounds. min=0 for PR/preview to save cost; raise for prod.
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    # ---- Direct VPC egress -------------------------------------------------
    # Attaching network_interfaces makes the revision live inside the VPC so it
    # can reach Cloud SQL private IP and Memorystore Redis. egress controls
    # whether ALL traffic or only private-range (RFC1918) traffic is routed
    # through the VPC.
    dynamic "vpc_access" {
      for_each = var.subnet == null ? [] : [1]
      content {
        egress = var.vpc_egress
        network_interfaces {
          network    = var.network
          subnetwork = var.subnet
          tags       = var.vpc_network_tags
        }
      }
    }

    containers {
      image = var.image

      # Cloud Run requires the container to listen on this port; hernes uses 8080.
      ports {
        container_port = var.port
      }

      # Plain (non-secret) environment variables. Secrets must be injected from
      # Secret Manager / Infisical at deploy time, NOT placed here.
      dynamic "env" {
        for_each = var.env
        content {
          name  = env.key
          value = env.value
        }
      }

      # Secret-backed environment variables sourced from Secret Manager.
      # Pass var.secret_env as { ENV_NAME = { secret = "<secret-id>", version = "latest" } }.
      dynamic "env" {
        for_each = var.secret_env
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value.secret
              version = env.value.version
            }
          }
        }
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        # Avoid billing for idle CPU between requests (request-based billing).
        cpu_idle = var.min_instances == 0
      }

      # HTTP startup/liveness probe. hernes backend exposes GET /healthz.
      # For the nginx frontend this path should also return 200 (or override
      # var.health_check_path). Set var.enable_health_check=false to skip.
      dynamic "startup_probe" {
        for_each = var.enable_health_check ? [1] : []
        content {
          http_get {
            path = var.health_check_path
            port = var.port
          }
          initial_delay_seconds = 5
          period_seconds        = 10
          failure_threshold     = 6
          timeout_seconds       = 3
        }
      }
    }

    # ---- Cloud SQL Auth Proxy (optional) -----------------------------------
    # When a connection name is supplied, mount the built-in Cloud SQL proxy so
    # the app can connect over /cloudsql/<connection_name>. With private IP +
    # Direct VPC egress this is usually unnecessary, but kept for flexibility.
    dynamic "volumes" {
      for_each = var.cloud_sql_connection_name == null ? [] : [1]
      content {
        name = "cloudsql"
        cloud_sql_instance {
          instances = [var.cloud_sql_connection_name]
        }
      }
    }
  }

  # Route 100% of traffic to the latest ready revision.
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# Optionally allow unauthenticated (public) invocations. For public-facing
# frontend/backend this is typically true; lock down with false + IAM bindings
# managed elsewhere for internal services.
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  count    = var.allow_unauthenticated ? 1 : 0
  project  = google_cloud_run_v2_service.this.project
  location = google_cloud_run_v2_service.this.location
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
