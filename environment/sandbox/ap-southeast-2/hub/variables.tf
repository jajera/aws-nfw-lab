variable "region" {
  type    = string
  default = "ap-southeast-2"
}

variable "hub_profile" {
  type        = string
  description = "AWS CLI profile for syd-hub"
}

variable "workload_account_ids" {
  type        = list(string)
  description = "Account IDs for Syd workload accounts (dev, prod, …) shared the TGW via RAM"
}

variable "amazon_side_asn" {
  type    = number
  default = 65001
}

variable "inspection_vpc_cidr" {
  type    = string
  default = "10.255.0.0/24"
}

variable "local_spoke_cidrs" {
  type        = list(string)
  description = "Sydney spoke CIDRs (dev + prod) for NFW allow rules / HOME_NET"
  default     = ["10.255.1.0/24", "10.255.2.0/24"]
}

variable "remote_spoke_cidrs" {
  type        = list(string)
  description = "Auckland spoke CIDRs (dev + prod) for NFW allow rules / HOME_NET"
  default     = ["10.254.1.0/24", "10.254.2.0/24"]
}

variable "enable_network_firewall" {
  type        = bool
  description = "When true, create NFW and hairpin inspection VPC through it. Leave false until after hub peering (teaching path)."
  default     = false
}

variable "firewall_rules_enabled" {
  type        = bool
  description = "When true (and enable_network_firewall), attach Suricata PASS rules. When false, stateful default drop (deny stage)."
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
