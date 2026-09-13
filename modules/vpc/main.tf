locals {
  tags = merge(var.tags, {
    Name = var.name
  })

  is_inspection = var.firewall_subnet_cidr != null
  tgw_cidr      = coalesce(var.tgw_subnet_cidr, var.private_subnet_cidr)
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, { Name = "${var.name}-vpc" })
}

# Spoke / general private subnet
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = var.az
  map_public_ip_on_launch = false

  tags = merge(local.tags, {
    Name = "${var.name}-private"
    Tier = "private"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, { Name = "${var.name}-private-rt" })
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Inspection: dedicated TGW subnet (may equal private when not inspection)
resource "aws_subnet" "tgw" {
  count = local.is_inspection ? 1 : 0

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.tgw_cidr
  availability_zone       = var.az
  map_public_ip_on_launch = false

  tags = merge(local.tags, {
    Name = "${var.name}-tgw"
    Tier = "tgw"
  })
}

resource "aws_route_table" "tgw" {
  count = local.is_inspection ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, { Name = "${var.name}-tgw-rt" })
}

resource "aws_route_table_association" "tgw" {
  count = local.is_inspection ? 1 : 0

  subnet_id      = aws_subnet.tgw[0].id
  route_table_id = aws_route_table.tgw[0].id
}

resource "aws_subnet" "firewall" {
  count = local.is_inspection ? 1 : 0

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.firewall_subnet_cidr
  availability_zone       = var.az
  map_public_ip_on_launch = false

  tags = merge(local.tags, {
    Name = "${var.name}-firewall"
    Tier = "firewall"
  })
}

resource "aws_route_table" "firewall" {
  count = local.is_inspection ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, { Name = "${var.name}-firewall-rt" })
}

resource "aws_route_table_association" "firewall" {
  count = local.is_inspection ? 1 : 0

  subnet_id      = aws_subnet.firewall[0].id
  route_table_id = aws_route_table.firewall[0].id
}

# SSM endpoints (private-only lab hosts)
data "aws_region" "current" {}

resource "aws_security_group" "ssm_endpoints" {
  count = var.enable_ssm_endpoints ? 1 : 0

  name_prefix = "${var.name}-ssm-vpce-"
  description = "SSM VPC interface endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.name}-ssm-vpce-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_endpoint" "ssm" {
  for_each = var.enable_ssm_endpoints ? var.ssm_endpoint_services : toset([])

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.ssm_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.tags, { Name = "${var.name}-vpce-${each.key}" })
}

# Optional NAT for demo bootstrap (dnf install)
resource "aws_internet_gateway" "this" {
  count = var.enable_nat ? 1 : 0

  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.name}-igw" })
}

resource "aws_subnet" "public" {
  count = var.enable_nat ? 1 : 0

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.az
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name = "${var.name}-public"
    Tier = "public"
  })
}

resource "aws_route_table" "public" {
  count = var.enable_nat ? 1 : 0

  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.name}-public-rt" })
}

resource "aws_route" "public_default" {
  count = var.enable_nat ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route_table_association" "public" {
  count = var.enable_nat ? 1 : 0

  subnet_id      = aws_subnet.public[0].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_eip" "nat" {
  count  = var.enable_nat ? 1 : 0
  domain = "vpc"
  tags   = merge(local.tags, { Name = "${var.name}-nat-eip" })
}

resource "aws_nat_gateway" "this" {
  count = var.enable_nat ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  tags          = merge(local.tags, { Name = "${var.name}-nat" })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route" "private_default_nat" {
  count = var.enable_nat ? 1 : 0

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}
