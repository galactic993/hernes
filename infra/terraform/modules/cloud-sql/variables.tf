variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Region (e.g. asia-northeast1)."
  type        = string
  default     = "asia-northeast1"
}

variable "instance_name" {
  description = "Cloud SQL instance name (e.g. hernes-staging, hernes-prod)."
  type        = string
}

variable "network" {
  description = "VPC network self_link/ID the private-IP instance attaches to (from modules/network)."
  type        = string
}

variable "database_name" {
  description = "Application database name."
  type        = string
  default     = "hernes"
}

variable "user_name" {
  description = "Application database user name."
  type        = string
  default     = "hernes_app"
}

variable "user_password" {
  description = "Application database user password. Source from GCP Secret Manager, never commit a real value."
  type        = string
  sensitive   = true
}

variable "tier" {
  description = "Machine tier (e.g. db-custom-1-3840 for staging, db-custom-2-7680 for prod)."
  type        = string
  default     = "db-custom-1-3840"
}

variable "availability_type" {
  description = "ZONAL (single zone, staging) or REGIONAL (HA, prod)."
  type        = string
  default     = "ZONAL"
}

variable "disk_size" {
  description = "Initial disk size in GB (autoresize is enabled)."
  type        = number
  default     = 10
}

# ---- Backups / PITR ----------------------------------------------------------
variable "backup_enabled" {
  description = "Enable automated backups. True for prod; optional for staging."
  type        = bool
  default     = false
}

variable "backup_start_time" {
  description = "Daily backup start time, HH:MM UTC."
  type        = string
  default     = "18:00" # 03:00 JST
}

variable "point_in_time_recovery_enabled" {
  description = "Enable Point-In-Time Recovery (WAL archiving). Requires backups enabled. True for prod."
  type        = bool
  default     = false
}

variable "transaction_log_retention_days" {
  description = "Days of transaction logs retained for PITR (1-7)."
  type        = number
  default     = 7
}

variable "retained_backups" {
  description = "Number of automated backups to retain."
  type        = number
  default     = 7
}

# ---- Maintenance window ------------------------------------------------------
variable "maintenance_window_day" {
  description = "Maintenance day of week (1=Mon .. 7=Sun)."
  type        = number
  default     = 7 # Sunday
}

variable "maintenance_window_hour" {
  description = "Maintenance hour (0-23, UTC)."
  type        = number
  default     = 18 # 03:00 JST
}

variable "maintenance_update_track" {
  description = "Maintenance update track: \"stable\" (prod) or \"canary\"."
  type        = string
  default     = "stable"
}

# ---- Flags / labels / protection --------------------------------------------
variable "database_flags" {
  description = "Extra Postgres flags as a list of { name, value }."
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "deletion_protection" {
  description = "Prevent terraform from destroying the instance. Set true for prod."
  type        = bool
  default     = false
}

variable "labels" {
  description = "User labels (app/env/managed-by)."
  type        = map(string)
  default     = {}
}
