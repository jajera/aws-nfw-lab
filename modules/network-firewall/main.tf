locals {
  tags = merge(var.tags, { Name = var.name })
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_log_group" "flow" {
  name              = "/aws/network-firewall/${var.name}/flow"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "alert" {
  name              = "/aws/network-firewall/${var.name}/alert"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

resource "aws_cloudwatch_log_resource_policy" "nfw" {
  policy_name = "${var.name}-nfw-logs"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "NetworkFirewallLogs"
      Effect = "Allow"
      Principal = {
        Service = "network-firewall.amazonaws.com"
      }
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
      ]
      Resource = [
        "${aws_cloudwatch_log_group.flow.arn}:*",
        "${aws_cloudwatch_log_group.alert.arn}:*",
      ]
      Condition = {
        ArnLike = {
          "aws:SourceArn" = "arn:aws:network-firewall:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
        }
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

resource "aws_networkfirewall_rule_group" "stateless_forward" {
  name        = "${var.name}-stateless-forward"
  description = "Forward all IP to stateful engine"
  type        = "STATELESS"
  capacity    = 10

  rule_group {
    rules_source {
      stateless_rules_and_custom_actions {
        stateless_rule {
          priority = 1
          rule_definition {
            actions = ["aws:forward_to_sfe"]
            match_attributes {
              protocols = [1, 6, 17]
              source {
                address_definition = "0.0.0.0/0"
              }
              destination {
                address_definition = "0.0.0.0/0"
              }
            }
          }
        }
      }
    }
  }

  tags = local.tags
}

resource "aws_networkfirewall_firewall_policy" "this" {
  name = "${var.name}-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]
    # drop_strict + explicit pass is the allow-list. CONTINUE keeps midstream
    # packets evaluable when a flow is first seen mid-handshake (e.g. after a
    # path change). Prefer this over drop_established, which dropped ICMP and
    # return traffic unexpectedly in lab testing.
    stateful_default_actions = ["aws:drop_strict", "aws:alert_strict"]

    stateful_engine_options {
      rule_order              = "STRICT_ORDER"
      stream_exception_policy = "CONTINUE"
    }

    stateless_rule_group_reference {
      priority     = 1
      resource_arn = aws_networkfirewall_rule_group.stateless_forward.arn
    }

    dynamic "stateful_rule_group_reference" {
      for_each = aws_networkfirewall_rule_group.pass
      content {
        priority     = local.pass_rule_groups[stateful_rule_group_reference.key].priority
        resource_arn = stateful_rule_group_reference.value.arn
      }
    }
  }

  tags = local.tags
}

resource "aws_networkfirewall_firewall" "this" {
  name                = var.name
  firewall_policy_arn = aws_networkfirewall_firewall_policy.this.arn
  vpc_id              = var.vpc_id

  dynamic "subnet_mapping" {
    for_each = var.firewall_subnet_ids
    content {
      subnet_id = subnet_mapping.value
    }
  }

  tags = local.tags
}

resource "aws_networkfirewall_logging_configuration" "this" {
  firewall_arn = aws_networkfirewall_firewall.this.arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.flow.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "FLOW"
    }
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.alert.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }
  }

  depends_on = [aws_cloudwatch_log_resource_policy.nfw]
}

locals {
  firewall_endpoints = {
    for state in aws_networkfirewall_firewall.this.firewall_status[0].sync_states :
    state.availability_zone => state.attachment[0].endpoint_id
  }
}
