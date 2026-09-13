terraform {
  required_version = ">= 1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.64"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.hub_profile

  default_tags {
    tags = local.tags
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  tags = merge(var.tags, {
    Project     = "aws-nfw-lab"
    Environment = "lab"
    Hub         = "akl"
    DemoRole    = "akl-hub"
  })

  az = data.aws_availability_zones.available.names[0]

  tgw_subnet_cidr      = cidrsubnet(var.inspection_vpc_cidr, 4, 0)
  firewall_subnet_cidr = cidrsubnet(var.inspection_vpc_cidr, 4, 1)
  private_subnet_cidr  = cidrsubnet(var.inspection_vpc_cidr, 4, 2)
}

module "tgw" {
  source = "../../../../modules/transit-gateway"

  name            = "nfw-lab-akl-tgw"
  amazon_side_asn = var.amazon_side_asn
  ram_principals  = var.workload_account_ids
  tags            = local.tags
}

module "inspection_vpc" {
  source = "../../../../modules/vpc"

  name                 = "nfw-lab-akl-insp"
  cidr_block           = var.inspection_vpc_cidr
  az                   = local.az
  private_subnet_cidr  = local.private_subnet_cidr
  tgw_subnet_cidr      = local.tgw_subnet_cidr
  firewall_subnet_cidr = local.firewall_subnet_cidr
  enable_ssm_endpoints = false
  tags                 = local.tags
}

module "network_firewall" {
  count  = var.enable_network_firewall ? 1 : 0
  source = "../../../../modules/network-firewall"

  name                = "nfw-lab-akl"
  vpc_id              = module.inspection_vpc.vpc_id
  firewall_subnet_ids = [module.inspection_vpc.firewall_subnet_id]
  enable_pass_rules   = var.firewall_rules_enabled
  tags                = local.tags
}

resource "aws_ec2_transit_gateway_vpc_attachment" "inspection" {
  subnet_ids             = [module.inspection_vpc.tgw_subnet_id]
  transit_gateway_id     = module.tgw.transit_gateway_id
  vpc_id                 = module.inspection_vpc.vpc_id
  appliance_mode_support = "enable"
  dns_support            = "enable"

  tags = merge(local.tags, { Name = "nfw-lab-akl-insp-attach" })
}

resource "aws_ec2_transit_gateway_route_table_association" "inspection" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.inspection.id
  transit_gateway_route_table_id = module.tgw.no_inspection_route_table_id
}

resource "aws_route" "tgw_to_firewall" {
  count = var.enable_network_firewall ? 1 : 0

  route_table_id         = module.inspection_vpc.tgw_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = module.network_firewall[0].firewall_endpoint_ids[local.az]
}

resource "aws_route" "firewall_to_tgw" {
  count = var.enable_network_firewall ? 1 : 0

  route_table_id         = module.inspection_vpc.firewall_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = module.tgw.transit_gateway_id
}

resource "aws_ec2_transit_gateway_route" "inspection_default" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.inspection.id
  transit_gateway_route_table_id = module.tgw.inspection_route_table_id
}
