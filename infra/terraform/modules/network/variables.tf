variable "project_id" {
  description = "GCP project ID where the VPC is created."
  type        = string
}

variable "region" {
  description = "Region for the subnet (e.g. asia-northeast1)."
  type        = string
  default     = "asia-northeast1"
}

variable "network_name" {
  description = "Name of the VPC network."
  type        = string
  default     = "hernes-vpc"
}

variable "subnet_name" {
  description = "Name of the primary subnet used for Direct VPC egress / private connectivity."
  type        = string
  default     = "hernes-subnet"
}

variable "subnet_cidr" {
  description = "Primary CIDR range for the subnet. Must not overlap other ranges (PSA, connector)."
  type        = string
  default     = "10.20.0.0/24"
}

variable "secondary_ip_ranges" {
  description = "Optional secondary ranges on the subnet (range_name + ip_cidr_range)."
  type = list(object({
    range_name    = string
    ip_cidr_range = string
  }))
  default = []
}

variable "enable_private_service_access" {
  description = "Reserve a range and create the Service Networking peering so Cloud SQL private IP works. Required when using cloud-sql with private IP."
  type        = bool
  default     = true
}

variable "private_service_access_prefix_length" {
  description = "Prefix length for the reserved Private Services Access range (Google recommends /16, but /20 is sufficient for small footprints)."
  type        = number
  default     = 20
}
