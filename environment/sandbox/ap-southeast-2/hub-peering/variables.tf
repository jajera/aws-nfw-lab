variable "syd_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "akl_region" {
  type    = string
  default = "ap-southeast-6"
}

variable "syd_hub_profile" {
  type        = string
  description = "AWS CLI profile for syd-hub"
}

variable "akl_hub_profile" {
  type        = string
  description = "AWS CLI profile for akl-hub"
}

variable "syd_dev_profile" {
  type        = string
  description = "AWS CLI profile for Syd/Akl *dev* workloads"
}

variable "akl_dev_profile" {
  type        = string
  description = "AWS CLI profile for Akl *dev* workload (often same as syd_dev_profile)"
}

variable "syd_prod_profile" {
  type        = string
  description = "AWS CLI profile for Syd *prod* workload"
  default     = ""
}

variable "akl_prod_profile" {
  type        = string
  description = "AWS CLI profile for Akl *prod* workload (often same as syd_prod_profile)"
  default     = ""
}

variable "enable_prod_workloads" {
  type        = bool
  description = "Set true after Syd/Akl workload-prod stacks are applied (adds peer routes + DNS for prod)"
  default     = false
}

variable "dns_zone_name" {
  type        = string
  description = "Private hosted zone name for demo hosts"
  default     = "lab.demo"
}

variable "tags" {
  type    = map(string)
  default = {}
}
