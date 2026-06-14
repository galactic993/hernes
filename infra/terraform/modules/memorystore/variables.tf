variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Region (e.g. asia-northeast1)."
  type        = string
  default     = "asia-northeast1"
}

variable "name" {
  description = "Redis instance name (e.g. hernes-staging-redis, hernes-prod-redis)."
  type        = string
}

variable "tier" {
  description = "Service tier: BASIC (single node, staging) or STANDARD_HA (replicated, prod)."
  type        = string
  default     = "BASIC"
}

variable "memory_size_gb" {
  description = "Redis memory size in GB."
  type        = number
  default     = 1
}

variable "redis_version" {
  description = "Redis version (e.g. REDIS_7_2)."
  type        = string
  default     = "REDIS_7_2"
}

variable "authorized_network" {
  description = "VPC network self_link/ID authorized to access the instance (from modules/network)."
  type        = string
}

variable "connect_mode" {
  description = "Connectivity mode: DIRECT_PEERING (default) or PRIVATE_SERVICE_ACCESS."
  type        = string
  default     = "DIRECT_PEERING"
}

variable "location_id" {
  description = "Primary zone (e.g. asia-northeast1-a). Null lets Google choose."
  type        = string
  default     = null
}

variable "alternative_location_id" {
  description = "Replica zone for STANDARD_HA (e.g. asia-northeast1-b). Ignored for BASIC."
  type        = string
  default     = null
}

variable "auth_enabled" {
  description = "Enable Redis AUTH (per-instance password)."
  type        = bool
  default     = true
}

variable "transit_encryption_mode" {
  description = "In-transit encryption: SERVER_AUTHENTICATION (TLS) or DISABLED."
  type        = string
  default     = "SERVER_AUTHENTICATION"
}

variable "display_name" {
  description = "Human-friendly display name."
  type        = string
  default     = null
}

variable "maintenance_window_day" {
  description = "Maintenance day (MONDAY..SUNDAY). Null disables the maintenance policy."
  type        = string
  default     = "SUNDAY"
}

variable "maintenance_window_hour" {
  description = "Maintenance start hour (0-23, UTC)."
  type        = number
  default     = 18 # 03:00 JST
}

variable "labels" {
  description = "Resource labels (app/env/managed-by)."
  type        = map(string)
  default     = {}
}
