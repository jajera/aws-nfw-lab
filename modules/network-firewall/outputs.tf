output "firewall_arn" {
  value = aws_networkfirewall_firewall.this.arn
}

output "firewall_id" {
  value = aws_networkfirewall_firewall.this.id
}

output "firewall_policy_arn" {
  value = aws_networkfirewall_firewall_policy.this.arn
}

output "firewall_endpoint_ids" {
  value       = local.firewall_endpoints
  description = "Map of AZ name to NFW VPC endpoint ID"
}

output "flow_log_group_name" {
  value = aws_cloudwatch_log_group.flow.name
}

output "alert_log_group_name" {
  value = aws_cloudwatch_log_group.alert.name
}
