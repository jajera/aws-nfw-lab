output "peering_attachment_id" {
  value = aws_ec2_transit_gateway_peering_attachment.requester.id
}

output "peering_attachment_accepter_id" {
  value = aws_ec2_transit_gateway_peering_attachment_accepter.accepter.id
}
