# hub-peering (`ap-southeast-2`)

Inter-Region TGW peering plus private DNS (`lab.demo`).

Once NFW is on both hubs, this stack associates the peer to each hub's
**inspection** RT so cross-Region traffic is **double-inspected**. Same-Region
traffic (e.g. Syd-dev ↔ Syd-prod) hairpins through the local NFW only.

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply
terraform destroy
```

Requires both regional `hub` and workload stacks (dev; prod when enabled).
