output "account_id" {
  value = data.aws_caller_identity.workload.account_id
}

output "vpc_id" {
  value = module.spoke_vpc.vpc_id
}

output "vpc_cidr" {
  value = module.spoke_vpc.vpc_cidr
}

output "private_subnet_id" {
  value = module.spoke_vpc.private_subnet_id
}

output "attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment_accepter.spoke.id
}

output "test_host_instance_id" {
  value = try(module.test_host[0].instance_id, null)
}

output "test_host_private_ip" {
  value = try(module.test_host[0].private_ip, null)
}
