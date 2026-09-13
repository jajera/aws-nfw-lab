locals {
  tags = merge(var.tags, { Name = var.name })
}

resource "aws_ec2_transit_gateway" "this" {
  description                     = var.name
  amazon_side_asn                 = var.amazon_side_asn
  auto_accept_shared_attachments  = "disable"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = merge(local.tags, { Name = var.name })
}

resource "aws_ec2_transit_gateway_route_table" "inspection" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(local.tags, { Name = "${var.name}-inspection" })
}

resource "aws_ec2_transit_gateway_route_table" "no_inspection" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(local.tags, { Name = "${var.name}-no-inspection" })
}

resource "aws_ram_resource_share" "tgw" {
  name                      = "${var.name}-share"
  allow_external_principals = false

  tags = merge(local.tags, { Name = "${var.name}-share" })
}

resource "aws_ram_resource_association" "tgw" {
  resource_arn       = aws_ec2_transit_gateway.this.arn
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

resource "aws_ram_principal_association" "workload" {
  for_each = toset(var.ram_principals)

  principal          = each.value
  resource_share_arn = aws_ram_resource_share.tgw.arn
}
