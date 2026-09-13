variable "name" {
  type        = string
  description = "Name prefix for peering resources"
}

variable "requester_transit_gateway_id" {
  type = string
}

variable "accepter_transit_gateway_id" {
  type = string
}

variable "accepter_account_id" {
  type = string
}

variable "accepter_region" {
  type = string
}

variable "requester_association_route_table_id" {
  type        = string
  description = "TGW RT associated with the peering attachment on the requester (inspection RT once NFW is attached, so peer arrival is inspected)"
}

variable "accepter_association_route_table_id" {
  type        = string
  description = "TGW RT associated with the peering attachment on the accepter"
}

variable "requester_static_route_table_id" {
  type        = string
  description = "TGW RT that gets static routes toward accepter CIDRs (usually no_inspection)"
}

variable "accepter_static_route_table_id" {
  type        = string
  description = "TGW RT that gets static routes toward requester CIDRs (usually no_inspection)"
}

variable "requester_static_cidrs" {
  type        = list(string)
  description = "CIDRs on the accepter side routed via peering"
  default     = []
}

variable "accepter_static_cidrs" {
  type        = list(string)
  description = "CIDRs on the requester side routed via peering"
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
