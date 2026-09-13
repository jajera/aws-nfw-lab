data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  # Stand-in for a small on-prem DNS/HTTP service: nginx (:80) + dnsmasq (:53).
  # Validation is dig/curl against the host; nothing fancy beyond answering lab.demo.
  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
    dnf install -y nginx dnsmasq

    cat >/usr/share/nginx/html/index.html <<'HTML'
    <html><body><h1>aws-nfw-lab</h1><p>demo http</p></body></html>
    HTML
    systemctl enable --now nginx

    # AL2023: systemd-resolved stub holds :53; free it so dnsmasq can listen
    mkdir -p /etc/systemd/resolved.conf.d
    cat >/etc/systemd/resolved.conf.d/no-stub.conf <<'EOF'
    [Resolve]
    DNSStubListener=no
    EOF
    systemctl restart systemd-resolved

    PRIV_IP=$(hostname -I | awk '{print $1}')
    IFACE=$(ip -o -4 route show to default | awk '{print $5}' | head -1)

    # Minimal authoritative-style answers for lab.demo (on-prem DNS stand-in)
    cat >/etc/dnsmasq.d/lab.conf <<EOF
    interface=$${IFACE}
    bind-interfaces
    listen-address=$${PRIV_IP}
    domain-needed
    bogus-priv
    no-resolv
    address=/lab.demo/$${PRIV_IP}
    EOF
    systemctl enable --now dnsmasq
  EOT
}

resource "aws_security_group" "host" {
  name_prefix = "${var.name}-"
  description = "Lab demo host (http + dns)"
  vpc_id      = var.vpc_id

  ingress {
    description = "ICMP from lab"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.254.0.0/15"]
  }

  ingress {
    description = "HTTP from lab"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.254.0.0/15"]
  }

  ingress {
    description = "DNS TCP from lab"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["10.254.0.0/15"]
  }

  ingress {
    description = "DNS UDP from lab"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["10.254.0.0/15"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-sg" })

  # Name prefix changes (e.g. syd-host → syd-dev-host) replace the SG; create
  # the new one and reattach before destroying the old, or delete hangs.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "ssm" {
  name_prefix = "${var.name}-ssm-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name_prefix = "${var.name}-ssm-"
  role        = aws_iam_role.ssm.name
  tags        = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "this" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.host.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  user_data              = local.user_data

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(var.tags, { Name = var.name })
}
