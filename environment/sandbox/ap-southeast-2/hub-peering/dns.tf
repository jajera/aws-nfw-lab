# Private DNS for demo hosts. Zone lives in Syd *dev*; other spokes associate
# cross-account / cross-VPC. Hostnames: syd-dev, akl-dev, syd-prod, akl-prod.

provider "aws" {
  alias   = "syd_dev"
  region  = var.syd_region
  profile = var.syd_dev_profile

  default_tags {
    tags = local.tags
  }
}

provider "aws" {
  alias   = "akl_dev"
  region  = var.akl_region
  profile = var.akl_dev_profile

  default_tags {
    tags = local.tags
  }
}

provider "aws" {
  alias   = "syd_prod"
  region  = var.syd_region
  profile = var.syd_prod_profile != "" ? var.syd_prod_profile : var.syd_dev_profile

  default_tags {
    tags = local.tags
  }
}

provider "aws" {
  alias   = "akl_prod"
  region  = var.akl_region
  profile = var.akl_prod_profile != "" ? var.akl_prod_profile : var.akl_dev_profile

  default_tags {
    tags = local.tags
  }
}

locals {
  dns_enabled = (
    try(data.terraform_remote_state.syd_dev.outputs.test_host_private_ip, null) != null &&
    try(data.terraform_remote_state.akl_dev.outputs.test_host_private_ip, null) != null
  )

  prod_dns_enabled = (
    var.enable_prod_workloads &&
    local.dns_enabled &&
    try(data.terraform_remote_state.syd_prod[0].outputs.test_host_private_ip, null) != null &&
    try(data.terraform_remote_state.akl_prod[0].outputs.test_host_private_ip, null) != null
  )

  syd_dev_ip  = try(data.terraform_remote_state.syd_dev.outputs.test_host_private_ip, null)
  akl_dev_ip  = try(data.terraform_remote_state.akl_dev.outputs.test_host_private_ip, null)
  syd_prod_ip = try(data.terraform_remote_state.syd_prod[0].outputs.test_host_private_ip, null)
  akl_prod_ip = try(data.terraform_remote_state.akl_prod[0].outputs.test_host_private_ip, null)

  syd_dev_vpc_id  = try(data.terraform_remote_state.syd_dev.outputs.vpc_id, null)
  akl_dev_vpc_id  = try(data.terraform_remote_state.akl_dev.outputs.vpc_id, null)
  syd_prod_vpc_id = try(data.terraform_remote_state.syd_prod[0].outputs.vpc_id, null)
  akl_prod_vpc_id = try(data.terraform_remote_state.akl_prod[0].outputs.vpc_id, null)

  dns_zone_name = var.dns_zone_name
}

resource "aws_route53_zone" "lab" {
  count    = local.dns_enabled ? 1 : 0
  provider = aws.syd_dev

  name = local.dns_zone_name

  vpc {
    vpc_id     = local.syd_dev_vpc_id
    vpc_region = var.syd_region
  }

  tags = merge(local.tags, { Name = "nfw-lab-${local.dns_zone_name}" })

  lifecycle {
    ignore_changes = [vpc]
  }
}

resource "aws_route53_vpc_association_authorization" "akl_dev" {
  count    = local.dns_enabled ? 1 : 0
  provider = aws.syd_dev

  zone_id    = aws_route53_zone.lab[0].id
  vpc_id     = local.akl_dev_vpc_id
  vpc_region = var.akl_region
}

resource "aws_route53_zone_association" "akl_dev" {
  count    = local.dns_enabled ? 1 : 0
  provider = aws.akl_dev

  zone_id    = aws_route53_zone.lab[0].id
  vpc_id     = local.akl_dev_vpc_id
  vpc_region = var.akl_region

  depends_on = [aws_route53_vpc_association_authorization.akl_dev]
}

resource "aws_route53_vpc_association_authorization" "syd_prod" {
  count    = local.prod_dns_enabled ? 1 : 0
  provider = aws.syd_dev

  zone_id    = aws_route53_zone.lab[0].id
  vpc_id     = local.syd_prod_vpc_id
  vpc_region = var.syd_region
}

resource "aws_route53_zone_association" "syd_prod" {
  count    = local.prod_dns_enabled ? 1 : 0
  provider = aws.syd_prod

  zone_id    = aws_route53_zone.lab[0].id
  vpc_id     = local.syd_prod_vpc_id
  vpc_region = var.syd_region

  depends_on = [aws_route53_vpc_association_authorization.syd_prod]
}

resource "aws_route53_vpc_association_authorization" "akl_prod" {
  count    = local.prod_dns_enabled ? 1 : 0
  provider = aws.syd_dev

  zone_id    = aws_route53_zone.lab[0].id
  vpc_id     = local.akl_prod_vpc_id
  vpc_region = var.akl_region
}

resource "aws_route53_zone_association" "akl_prod" {
  count    = local.prod_dns_enabled ? 1 : 0
  provider = aws.akl_prod

  zone_id    = aws_route53_zone.lab[0].id
  vpc_id     = local.akl_prod_vpc_id
  vpc_region = var.akl_region

  depends_on = [aws_route53_vpc_association_authorization.akl_prod]
}

resource "aws_route53_record" "syd_dev" {
  count    = local.dns_enabled ? 1 : 0
  provider = aws.syd_dev

  zone_id = aws_route53_zone.lab[0].zone_id
  name    = "syd-dev"
  type    = "A"
  ttl     = 60
  records = [local.syd_dev_ip]
}

resource "aws_route53_record" "akl_dev" {
  count    = local.dns_enabled ? 1 : 0
  provider = aws.syd_dev

  zone_id = aws_route53_zone.lab[0].zone_id
  name    = "akl-dev"
  type    = "A"
  ttl     = 60
  records = [local.akl_dev_ip]
}

resource "aws_route53_record" "syd_prod" {
  count    = local.prod_dns_enabled ? 1 : 0
  provider = aws.syd_dev

  zone_id = aws_route53_zone.lab[0].zone_id
  name    = "syd-prod"
  type    = "A"
  ttl     = 60
  records = [local.syd_prod_ip]
}

resource "aws_route53_record" "akl_prod" {
  count    = local.prod_dns_enabled ? 1 : 0
  provider = aws.syd_dev

  zone_id = aws_route53_zone.lab[0].zone_id
  name    = "akl-prod"
  type    = "A"
  ttl     = 60
  records = [local.akl_prod_ip]
}

resource "aws_vpc_dhcp_options" "syd_dev" {
  count    = local.dns_enabled ? 1 : 0
  provider = aws.syd_dev

  domain_name         = local.dns_zone_name
  domain_name_servers = ["AmazonProvidedDNS"]

  tags = merge(local.tags, { Name = "nfw-lab-syd-dev-dhcp" })
}

resource "aws_vpc_dhcp_options_association" "syd_dev" {
  count    = local.dns_enabled ? 1 : 0
  provider = aws.syd_dev

  vpc_id          = local.syd_dev_vpc_id
  dhcp_options_id = aws_vpc_dhcp_options.syd_dev[0].id
}

resource "aws_vpc_dhcp_options" "akl_dev" {
  count    = local.dns_enabled ? 1 : 0
  provider = aws.akl_dev

  domain_name         = local.dns_zone_name
  domain_name_servers = ["AmazonProvidedDNS"]

  tags = merge(local.tags, { Name = "nfw-lab-akl-dev-dhcp" })
}

resource "aws_vpc_dhcp_options_association" "akl_dev" {
  count    = local.dns_enabled ? 1 : 0
  provider = aws.akl_dev

  vpc_id          = local.akl_dev_vpc_id
  dhcp_options_id = aws_vpc_dhcp_options.akl_dev[0].id
}

resource "aws_vpc_dhcp_options" "syd_prod" {
  count    = local.prod_dns_enabled ? 1 : 0
  provider = aws.syd_prod

  domain_name         = local.dns_zone_name
  domain_name_servers = ["AmazonProvidedDNS"]

  tags = merge(local.tags, { Name = "nfw-lab-syd-prod-dhcp" })
}

resource "aws_vpc_dhcp_options_association" "syd_prod" {
  count    = local.prod_dns_enabled ? 1 : 0
  provider = aws.syd_prod

  vpc_id          = local.syd_prod_vpc_id
  dhcp_options_id = aws_vpc_dhcp_options.syd_prod[0].id
}

resource "aws_vpc_dhcp_options" "akl_prod" {
  count    = local.prod_dns_enabled ? 1 : 0
  provider = aws.akl_prod

  domain_name         = local.dns_zone_name
  domain_name_servers = ["AmazonProvidedDNS"]

  tags = merge(local.tags, { Name = "nfw-lab-akl-prod-dhcp" })
}

resource "aws_vpc_dhcp_options_association" "akl_prod" {
  count    = local.prod_dns_enabled ? 1 : 0
  provider = aws.akl_prod

  vpc_id          = local.akl_prod_vpc_id
  dhcp_options_id = aws_vpc_dhcp_options.akl_prod[0].id
}
