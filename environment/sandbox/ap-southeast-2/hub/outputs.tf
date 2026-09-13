output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "region" {
  value = var.region
}

output "az" {
  value = local.az
}

output "transit_gateway_id" {
  value = module.tgw.transit_gateway_id
}

output "transit_gateway_arn" {
  value = module.tgw.transit_gateway_arn
}

output "inspection_route_table_id" {
  value = module.tgw.inspection_route_table_id
}

output "no_inspection_route_table_id" {
  value = module.tgw.no_inspection_route_table_id
}

# Spoke assoc: passthrough (no_inspection) until NFW is attached, then inspection.
output "spoke_association_route_table_id" {
  value = var.enable_network_firewall ? module.tgw.inspection_route_table_id : module.tgw.no_inspection_route_table_id
}

output "enable_network_firewall" {
  value = var.enable_network_firewall
}

output "firewall_rules_enabled" {
  value = var.firewall_rules_enabled
}

output "ram_resource_share_arn" {
  value = module.tgw.ram_resource_share_arn
}

output "inspection_vpc_id" {
  value = module.inspection_vpc.vpc_id
}

output "inspection_vpc_cidr" {
  value = module.inspection_vpc.vpc_cidr
}

output "inspection_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.inspection.id
}

output "firewall_arn" {
  value = try(module.network_firewall[0].firewall_arn, null)
}

output "firewall_endpoint_ids" {
  value = try(module.network_firewall[0].firewall_endpoint_ids, {})
}

output "flow_log_group_name" {
  value = try(module.network_firewall[0].flow_log_group_name, null)
}

output "alert_log_group_name" {
  value = try(module.network_firewall[0].alert_log_group_name, null)
}

output "local_spoke_cidrs" {
  value = var.local_spoke_cidrs
}

output "remote_spoke_cidrs" {
  value = var.remote_spoke_cidrs
}

# First local/remote CIDR kept for simple docs / legacy consumers (dev spokes)
output "local_spoke_cidr" {
  value = var.local_spoke_cidrs[0]
}

output "remote_spoke_cidr" {
  value = var.remote_spoke_cidrs[0]
}
