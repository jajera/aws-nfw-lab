variable "name" {
  type        = string
  description = "Name prefix for VPC resources"
}

variable "cidr_block" {
  type        = string
  description = "VPC IPv4 CIDR"
}

variable "az" {
  type        = string
  description = "Single availability zone"
}

variable "private_subnet_cidr" {
  type        = string
  description = "Private subnet CIDR (workloads / TGW attachment for spokes)"
}

variable "firewall_subnet_cidr" {
  type        = string
  default     = null
  description = "Firewall endpoint subnet CIDR (inspection VPCs only)"
}

variable "tgw_subnet_cidr" {
  type        = string
  default     = null
  description = "TGW attachment subnet CIDR (inspection VPCs only). Defaults to private_subnet_cidr when unset."
}

variable "enable_ssm_endpoints" {
  type        = bool
  default     = true
  description = "Create interface endpoints for SSM (no NAT required)"
}

variable "ssm_endpoint_services" {
  type        = set(string)
  default     = ["ssm", "ssmmessages", "ec2messages"]
  description = "Interface endpoint short names when enable_ssm_endpoints is true. Omit services not offered in-region (post-2024 Regions such as ap-southeast-6 have no ec2messages; use ssmmessages only)."
}

variable "enable_nat" {
  type        = bool
  default     = false
  description = "NAT gateway for package installs (demo workload bootstrap)"

  validation {
    condition     = !var.enable_nat || var.public_subnet_cidr != null
    error_message = "public_subnet_cidr is required when enable_nat is true."
  }
}

variable "public_subnet_cidr" {
  type        = string
  default     = null
  description = "Public subnet CIDR when enable_nat is true"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags"
}
