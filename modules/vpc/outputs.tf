output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}

output "tgw_subnet_id" {
  value       = try(aws_subnet.tgw[0].id, aws_subnet.private.id)
  description = "Subnet for TGW attachment (inspection TGW subnet or spoke private subnet)"
}

output "tgw_route_table_id" {
  value       = try(aws_route_table.tgw[0].id, null)
  description = "Inspection VPC TGW subnet route table (null for spokes)"
}

output "firewall_subnet_id" {
  value = try(aws_subnet.firewall[0].id, null)
}

output "firewall_route_table_id" {
  value = try(aws_route_table.firewall[0].id, null)
}

output "az" {
  value = var.az
}
