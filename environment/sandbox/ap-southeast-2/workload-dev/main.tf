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
  alias   = "workload"
  region  = var.region
  profile = var.workload_profile

  default_tags {
    tags = local.tags
  }
}

provider "aws" {
  alias   = "hub"
  region  = var.region
  profile = var.hub_profile

  default_tags {
    tags = local.tags
  }
}

data "aws_availability_zones" "available" {
  provider = aws.workload
  state    = "available"
}

data "aws_caller_identity" "workload" {
  provider = aws.workload
}

data "terraform_remote_state" "syd_hub" {
  backend = "local"
  config = {
    path = "${path.module}/../hub/terraform.tfstate"
  }
}

locals {
  tags = merge(var.tags, {
    Project     = "aws-nfw-lab"
    Environment = "lab"
    Hub         = "syd"
    DemoRole    = "syd-dev"
  })

  az = data.aws_availability_zones.available.names[0]
}

module "spoke_vpc" {
  source = "../../../../modules/vpc"
  providers = {
    aws = aws.workload
  }

  name                 = "nfw-lab-syd-dev"
  cidr_block           = var.spoke_vpc_cidr
  az                   = local.az
  private_subnet_cidr  = cidrsubnet(var.spoke_vpc_cidr, 1, 0)
  public_subnet_cidr   = cidrsubnet(var.spoke_vpc_cidr, 1, 1)
  enable_ssm_endpoints = true
  enable_nat           = var.enable_test_host
  tags                 = local.tags
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke" {
  provider = aws.workload

  subnet_ids         = [module.spoke_vpc.tgw_subnet_id]
  transit_gateway_id = data.terraform_remote_state.syd_hub.outputs.transit_gateway_id
  vpc_id             = module.spoke_vpc.vpc_id
  dns_support        = "enable"

  tags = merge(local.tags, { Name = "nfw-lab-syd-dev-attach" })
}

resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "spoke" {
  provider = aws.hub

  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.spoke.id

  tags = merge(local.tags, { Name = "nfw-lab-syd-dev-attach-accept" })
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke" {
  provider = aws.hub

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment_accepter.spoke.id
  transit_gateway_route_table_id = data.terraform_remote_state.syd_hub.outputs.spoke_association_route_table_id
}

resource "aws_ec2_transit_gateway_route" "to_spoke" {
  provider = aws.hub

  destination_cidr_block         = var.spoke_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment_accepter.spoke.id
  transit_gateway_route_table_id = data.terraform_remote_state.syd_hub.outputs.no_inspection_route_table_id
}

resource "aws_route" "spoke_lab_via_tgw" {
  for_each = toset(["10.254.0.0/16", "10.255.0.0/16"])
  provider = aws.workload

  route_table_id         = module.spoke_vpc.private_route_table_id
  destination_cidr_block = each.value
  transit_gateway_id     = data.terraform_remote_state.syd_hub.outputs.transit_gateway_id
}

resource "aws_route" "spoke_default_via_tgw" {
  count    = var.enable_test_host ? 0 : 1
  provider = aws.workload

  route_table_id         = module.spoke_vpc.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = data.terraform_remote_state.syd_hub.outputs.transit_gateway_id
}

module "test_host" {
  count  = var.enable_test_host ? 1 : 0
  source = "../../../../modules/test-host"
  providers = {
    aws = aws.workload
  }

  name      = "nfw-lab-syd-dev-host"
  subnet_id = module.spoke_vpc.private_subnet_id
  vpc_id    = module.spoke_vpc.vpc_id
  tags      = local.tags
}
