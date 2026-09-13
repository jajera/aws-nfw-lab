variable "name" {
  type        = string
  description = "Name prefix"
}

variable "amazon_side_asn" {
  type        = number
  description = "TGW BGP ASN (unique per hub)"
}

variable "ram_principals" {
  type        = list(string)
  description = "Account IDs (or OU ARNs) to share the TGW with via RAM"
}

variable "tags" {
  type    = map(string)
  default = {}
}
