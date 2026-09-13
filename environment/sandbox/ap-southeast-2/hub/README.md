# syd-hub

Transit Gateway, inspection VPC, RAM share. Network Firewall is **optional** and
staged for teaching:

| Stage | Vars |
| ----- | ---- |
| Mesh prereq | `enable_network_firewall=false` |
| Attach deny | `enable_network_firewall=true`, `firewall_rules_enabled=false` |
| Allow PASS | both `true` |

Prefer full `terraform apply -var=…` over `-target`. After flipping NFW flags,
re-apply the regional **workload** and **hub-peering** stacks so spoke/peer
associations follow `spoke_association_route_table_id`.
