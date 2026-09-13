variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "firewall_subnet_ids" {
  type        = list(string)
  description = "Subnets for Network Firewall endpoints (one AZ for this lab)"
}

variable "enable_pass_rules" {
  type        = bool
  description = "false = Deny stage (default drop only). true = Allow stage (attach Suricata PASS groups from rules.tf)."
  default     = false
}

variable "log_retention_days" {
  type    = number
  default = 7
}

variable "tags" {
  type    = map(string)
  default = {}
}
