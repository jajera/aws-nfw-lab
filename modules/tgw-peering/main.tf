terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.requester, aws.accepter]
    }
  }
}

locals {
  tags = merge(var.tags, { Name = var.name })
}

resource "aws_ec2_transit_gateway_peering_attachment" "requester" {
  provider = aws.requester

  transit_gateway_id      = var.requester_transit_gateway_id
  peer_transit_gateway_id = var.accepter_transit_gateway_id
  peer_account_id         = var.accepter_account_id
  peer_region             = var.accepter_region

  tags = merge(local.tags, { Name = "${var.name}-requester" })
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "accepter" {
  provider = aws.accepter

  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.requester.id

  tags = merge(local.tags, { Name = "${var.name}-accepter" })
}

resource "aws_ec2_transit_gateway_route_table_association" "requester" {
  provider = aws.requester

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.requester.id
  transit_gateway_route_table_id = var.requester_association_route_table_id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.accepter]
}

resource "aws_ec2_transit_gateway_route_table_association" "accepter" {
  provider = aws.accepter

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.accepter.id
  transit_gateway_route_table_id = var.accepter_association_route_table_id
}

resource "aws_ec2_transit_gateway_route" "requester" {
  for_each = toset(var.requester_static_cidrs)
  provider = aws.requester

  destination_cidr_block         = each.value
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.requester.id
  transit_gateway_route_table_id = var.requester_static_route_table_id

  depends_on = [
    aws_ec2_transit_gateway_route_table_association.requester,
    aws_ec2_transit_gateway_peering_attachment_accepter.accepter,
  ]
}

resource "aws_ec2_transit_gateway_route" "accepter" {
  for_each = toset(var.accepter_static_cidrs)
  provider = aws.accepter

  destination_cidr_block         = each.value
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.accepter.id
  transit_gateway_route_table_id = var.accepter_static_route_table_id

  depends_on = [aws_ec2_transit_gateway_route_table_association.accepter]
}
