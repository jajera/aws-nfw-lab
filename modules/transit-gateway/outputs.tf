output "transit_gateway_id" {
  value = aws_ec2_transit_gateway.this.id
}

output "transit_gateway_arn" {
  value = aws_ec2_transit_gateway.this.arn
}

output "inspection_route_table_id" {
  value = aws_ec2_transit_gateway_route_table.inspection.id
}

output "no_inspection_route_table_id" {
  value = aws_ec2_transit_gateway_route_table.no_inspection.id
}

output "ram_resource_share_arn" {
  value = aws_ram_resource_share.tgw.arn
}
