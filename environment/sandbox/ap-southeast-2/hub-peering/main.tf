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
  alias   = "syd_hub"
  region  = var.syd_region
  profile = var.syd_hub_profile

  default_tags {
    tags = local.tags
  }
}

provider "aws" {
  alias   = "akl_hub"
  region  = var.akl_region
  profile = var.akl_hub_profile

  default_tags {
    tags = local.tags
  }
}

data "terraform_remote_state" "syd_hub" {
  backend = "local"
  config = {
    path = "${path.module}/../hub/terraform.tfstate"
  }
}

data "terraform_remote_state" "akl_hub" {
  backend = "local"
  config = {
    path = "${path.module}/../../ap-southeast-6/hub/terraform.tfstate"
  }
}

data "terraform_remote_state" "syd_dev" {
  backend = "local"
  config = {
    path = "${path.module}/../workload-dev/terraform.tfstate"
  }
}

data "terraform_remote_state" "akl_dev" {
  backend = "local"
  config = {
    path = "${path.module}/../../ap-southeast-6/workload-dev/terraform.tfstate"
  }
}

data "terraform_remote_state" "syd_prod" {
  count = var.enable_prod_workloads ? 1 : 0

  backend = "local"
  config = {
    path = "${path.module}/../workload-prod/terraform.tfstate"
  }
}

data "terraform_remote_state" "akl_prod" {
  count = var.enable_prod_workloads ? 1 : 0

  backend = "local"
  config = {
    path = "${path.module}/../../ap-southeast-6/workload-prod/terraform.tfstate"
  }
}

locals {
  tags = merge(var.tags, {
    Project     = "aws-nfw-lab"
    Environment = "lab"
    DemoRole    = "hub-peering"
  })

  nfw_in_path = (
    try(data.terraform_remote_state.syd_hub.outputs.enable_network_firewall, false) &&
    try(data.terraform_remote_state.akl_hub.outputs.enable_network_firewall, false)
  )

  # When NFW is on, associate the peer with the inspection RT so arriving
  # cross-Region traffic is inspected. Before NFW exists, keep the peer on
  # no_inspection for a plain TGW mesh.
  #
  # Cross-Region is double-inspect (both hubs) once NFW is on. Same-Region
  # stays single-inspect at the local hub (no peer hop).
  peer_assoc_syd = (
    local.nfw_in_path
    ? data.terraform_remote_state.syd_hub.outputs.inspection_route_table_id
    : data.terraform_remote_state.syd_hub.outputs.no_inspection_route_table_id
  )
  peer_assoc_akl = (
    local.nfw_in_path
    ? data.terraform_remote_state.akl_hub.outputs.inspection_route_table_id
    : data.terraform_remote_state.akl_hub.outputs.no_inspection_route_table_id
  )

  syd_spoke_cidrs = compact(concat(
    [try(data.terraform_remote_state.syd_dev.outputs.vpc_cidr, null)],
    var.enable_prod_workloads ? [try(data.terraform_remote_state.syd_prod[0].outputs.vpc_cidr, null)] : [],
  ))
  akl_spoke_cidrs = compact(concat(
    [try(data.terraform_remote_state.akl_dev.outputs.vpc_cidr, null)],
    var.enable_prod_workloads ? [try(data.terraform_remote_state.akl_prod[0].outputs.vpc_cidr, null)] : [],
  ))
}

module "peering" {
  source = "../../../../modules/tgw-peering"

  providers = {
    aws.requester = aws.syd_hub
    aws.accepter  = aws.akl_hub
  }

  name                                 = "nfw-lab-syd-akl-peer"
  requester_transit_gateway_id         = data.terraform_remote_state.syd_hub.outputs.transit_gateway_id
  accepter_transit_gateway_id          = data.terraform_remote_state.akl_hub.outputs.transit_gateway_id
  accepter_account_id                  = data.terraform_remote_state.akl_hub.outputs.account_id
  accepter_region                      = data.terraform_remote_state.akl_hub.outputs.region
  requester_association_route_table_id = local.peer_assoc_syd
  accepter_association_route_table_id  = local.peer_assoc_akl
  requester_static_route_table_id      = data.terraform_remote_state.syd_hub.outputs.no_inspection_route_table_id
  accepter_static_route_table_id       = data.terraform_remote_state.akl_hub.outputs.no_inspection_route_table_id
  requester_static_cidrs               = local.akl_spoke_cidrs
  accepter_static_cidrs                = local.syd_spoke_cidrs
  tags                                 = local.tags
}
