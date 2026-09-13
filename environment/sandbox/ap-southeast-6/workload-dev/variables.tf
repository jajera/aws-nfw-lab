variable "region" {
  type    = string
  default = "ap-southeast-6"
}

variable "workload_profile" {
  type        = string
  description = "AWS CLI profile for the Akl dev workload account"
}

variable "hub_profile" {
  type        = string
  description = "AWS CLI profile for akl-hub (attachment accept and RT wiring)"
}

variable "spoke_vpc_cidr" {
  type    = string
  default = "10.254.1.0/24"
}

variable "enable_test_host" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
