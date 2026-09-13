# aws-nfw-lab

AWS Network Firewall multi account inspection demo.

Disposable Terraform lab: dual-hub TGW, RAM-shared **dev** and **prod** spokes,
hub-to-hub peering, then staged Network Firewall attach (deny → allow).

Teaching path uses **full `terraform apply` + variables**, not
`terraform apply -target`.

## Demo roles

| Role | Region | What it owns |
| ------ | -------- | -------------- |
| `syd-hub` / `akl-hub` | `ap-southeast-2` / `ap-southeast-6` | TGW, inspection VPC (NFW optional), RAM share |
| `syd-dev` / `akl-dev` | same | Dev spoke + demo host |
| `syd-prod` / `akl-prod` | same | Prod spoke + demo host |

Hub-to-hub connectivity is **TGW peering**. Workloads attach only to their regional hub via **RAM**.

Provider profile names are set in each stack `terraform.tfvars` (see `*.tfvars.example`).

## CIDRs and ASNs

| Item | Value |
| ------ | -------- |
| Sydney inspection VPC | `10.255.0.0/24` |
| Sydney **dev** spoke | `10.255.1.0/24` |
| Sydney **prod** spoke | `10.255.2.0/24` |
| Auckland inspection VPC | `10.254.0.0/24` |
| Auckland **dev** spoke | `10.254.1.0/24` |
| Auckland **prod** spoke | `10.254.2.0/24` |
| Sydney TGW ASN | `65001` |
| Auckland TGW ASN | `65002` |

DNS (after hub-peering): `syd-dev` / `akl-dev` / `syd-prod` / `akl-prod` under `lab.demo`.

## Prerequisites

- Terraform `>= 1.16`
- Hub profile + **dev** and **prod** workload profiles
- Org RAM sharing enabled
- Copy each `terraform.tfvars.example` → `terraform.tfvars`

## Apply order (mesh first, NFW later)

Defaults: `enable_network_firewall = false`, `firewall_rules_enabled = false`.

```bash
# 1–2 Hubs (include both workload account IDs in workload_account_ids)
cd environment/sandbox/ap-southeast-2/hub && terraform init && terraform apply
cd ../../ap-southeast-6/hub && terraform init && terraform apply

# 3–4 Dev workloads
cd ../../ap-southeast-2/workload-dev && terraform init && terraform apply
cd ../../ap-southeast-6/workload-dev && terraform init && terraform apply

# 5 Hub peering (dev DNS; enable_prod_workloads=false)
cd ../../ap-southeast-2/hub-peering && terraform init && terraform apply

# 6 Prod workloads (after your prod workload profile is logged in)
cd ../workload-prod && terraform init && terraform apply
cd ../../ap-southeast-6/workload-prod && terraform init && terraform apply

# 7 Re-apply hubs if you added the prod account ID to RAM, then peering with prod
cd ../../ap-southeast-2/hub && terraform apply   # workload_account_ids includes prod
cd ../../ap-southeast-6/hub && terraform apply
cd ../../ap-southeast-2/hub-peering
terraform apply -var='enable_prod_workloads=true'
# Persist enable_prod_workloads=true in terraform.tfvars

# Prove mesh (dev↔dev, then Syd-dev↔Syd-prod intra-Region, etc.)

# NFW attach deny → allow (same as before; re-apply all workload-* + peering)
```

Cross-stack wiring uses `terraform_remote_state` against sibling `terraform.tfstate` files.

### Inspection model

**Double-inspect** for cross-Region:

| Flow | Inspected by |
| ------ | -------------- |
| Same Region (e.g. Syd dev ↔ Syd prod, different accounts) | Local hub NFW — **one firewall sees both directions** |
| Cross Region | **Both** hub NFWs (source and destination) |

`hub-peering` puts the peer on each hub's **inspection** RT when NFW is on.
Egress on the inspection RT follows `0.0.0.0/0` through the local firewall
before the peer. While `enable_network_firewall` is false, peering and spokes
stay on **no_inspection** and nothing is inspected.

## Destroy order

Reverse of apply (~30–60+ min). If a spoke `aws_vpc` hangs on destroy, delete
any leftover SSM endpoint security group in that VPC, then re-run destroy
(`terraform state rm` the VPC if AWS already deleted it and Terraform reports
`InvalidVpcID.NotFound`).

```bash
cd environment/sandbox/ap-southeast-2/hub-peering && terraform destroy
cd ../workload-prod && terraform destroy
cd ../../ap-southeast-6/workload-prod && terraform destroy
cd ../../ap-southeast-2/workload-dev && terraform destroy
cd ../../ap-southeast-6/workload-dev && terraform destroy
cd ../hub && terraform destroy
cd ../../ap-southeast-2/hub && terraform destroy
```

## Layout

```
environment/sandbox/
  ap-southeast-2/hub
  ap-southeast-2/workload-dev
  ap-southeast-2/workload-prod
  ap-southeast-2/hub-peering
  ap-southeast-6/hub
  ap-southeast-6/workload-dev
  ap-southeast-6/workload-prod
```

## Cost note

TGW attachments and Network Firewall endpoints bill hourly while running. Use **1 AZ**, tear down when idle.
