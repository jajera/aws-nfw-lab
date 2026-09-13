output "peering_attachment_id" {
  value = module.peering.peering_attachment_id
}

output "peer_association_route_table_id_syd" {
  value = local.peer_assoc_syd
}

output "peer_association_route_table_id_akl" {
  value = local.peer_assoc_akl
}

output "syd_spoke_cidrs" {
  value = local.syd_spoke_cidrs
}

output "akl_spoke_cidrs" {
  value = local.akl_spoke_cidrs
}

output "dns_zone_name" {
  value = local.dns_enabled ? local.dns_zone_name : null
}

output "syd_dev_hostname" {
  value = local.dns_enabled ? "syd-dev.${local.dns_zone_name}" : null
}

output "akl_dev_hostname" {
  value = local.dns_enabled ? "akl-dev.${local.dns_zone_name}" : null
}

output "syd_prod_hostname" {
  value = local.prod_dns_enabled ? "syd-prod.${local.dns_zone_name}" : null
}

output "akl_prod_hostname" {
  value = local.prod_dns_enabled ? "akl-prod.${local.dns_zone_name}" : null
}
