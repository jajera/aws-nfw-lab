# Lab PASS policy (Rule design exercise). Attached only when enable_pass_rules
# (walkthrough Allow stage). Deny stage keeps the firewall with default drop.
# Unmatched traffic still hits stateful default drop — PASS only for these IP sets.
#
# Cross-Region traffic is double-inspected (both hubs) once NFW is attached.
# Same-Region traffic hairpins through one local firewall that sees both
# directions. Pass rules still list both directions so either hub can allow
# the flow, and use flow:stateless plus reverse port rules so midstream /
# return packets match under stream_exception_policy = CONTINUE.

locals {
  # Private subnet is cidrsubnet(spoke/24, 1, 0) → .0–.127. Cover the usable
  # DHCP pool (.4–.126) so demo hosts always match after rebuilds.
  # Dummy sets live in the public half (.128–.255) or inspection VPC — never
  # assigned to demo hosts.
  private_host_octets = range(4, 127)

  # Peering / same-Region sides: full private pool per spoke
  dev_syd = [for i in local.private_host_octets : "${cidrhost("10.255.1.0/24", i)}/32"]
  dev_akl = [for i in local.private_host_octets : "${cidrhost("10.254.1.0/24", i)}/32"]

  # Fictional jump hosts — public half only (demo hosts are not here)
  dev_syd_jumps = [for i in range(180, 200) : "${cidrhost("10.255.1.0/24", i)}/32"]
  dev_akl_jumps = [for i in range(180, 200) : "${cidrhost("10.254.1.0/24", i)}/32"]

  prod_syd_apps = [for i in local.private_host_octets : "${cidrhost("10.255.2.0/24", i)}/32"]
  prod_akl_apps = [for i in local.private_host_octets : "${cidrhost("10.254.2.0/24", i)}/32"]
  prod_syd_dbs  = [for i in range(20, 30) : "${cidrhost("10.255.2.0/24", i)}/32"]
  prod_akl_dbs  = [for i in range(20, 30) : "${cidrhost("10.254.2.0/24", i)}/32"]
  prod_monitors = concat(
    [for i in range(200, 220) : "${cidrhost("10.255.2.0/24", i)}/32"],
    [for i in range(200, 220) : "${cidrhost("10.254.2.0/24", i)}/32"],
  )
  prod_dns     = ["10.255.2.53/32", "10.254.2.53/32"]
  prod_apps    = concat(local.prod_syd_apps, local.prod_akl_apps)
  prod_clients = concat(local.prod_apps, local.prod_monitors)

  # Dummy sets — public half / insp VPC; probes from real hosts to these still drop
  dummy_syd_batch = [for i in range(150, 180) : "${cidrhost("10.255.2.0/24", i)}/32"]
  dummy_akl_batch = [for i in range(150, 180) : "${cidrhost("10.254.2.0/24", i)}/32"]
  dummy_ldap      = ["10.255.2.140/32", "10.254.2.140/32"]
  dummy_ntp       = ["10.255.0.123/32", "10.254.0.123/32"] # inspection VPC — not spokes

  pass_rule_groups = var.enable_pass_rules ? {
    peer_dev = {
      priority    = 10
      capacity    = 30
      description = "Dev Syd-Akl peering (both ways, asymmetric-safe)"
      ip_sets = {
        DEV_SYD = local.dev_syd
        DEV_AKL = local.dev_akl
      }
      rules = join("\n", [
        "pass icmp $DEV_SYD any -> $DEV_AKL any (msg:\"lab peer-dev icmp syd>akl\"; flow:stateless; sid:1001; rev:2;)",
        "pass icmp $DEV_AKL any -> $DEV_SYD any (msg:\"lab peer-dev icmp akl>syd\"; flow:stateless; sid:1002; rev:2;)",
        "pass tcp $DEV_SYD any -> $DEV_AKL [80,53] (msg:\"lab peer-dev tcp syd>akl\"; flow:stateless; sid:1003; rev:2;)",
        "pass tcp $DEV_AKL any -> $DEV_SYD [80,53] (msg:\"lab peer-dev tcp akl>syd\"; flow:stateless; sid:1004; rev:2;)",
        "pass tcp $DEV_AKL [80,53] -> $DEV_SYD any (msg:\"lab peer-dev tcp return akl>syd\"; flow:stateless; sid:1007; rev:1;)",
        "pass tcp $DEV_SYD [80,53] -> $DEV_AKL any (msg:\"lab peer-dev tcp return syd>akl\"; flow:stateless; sid:1008; rev:1;)",
        "pass udp $DEV_SYD any -> $DEV_AKL 53 (msg:\"lab peer-dev udp syd>akl\"; flow:stateless; sid:1005; rev:2;)",
        "pass udp $DEV_AKL any -> $DEV_SYD 53 (msg:\"lab peer-dev udp akl>syd\"; flow:stateless; sid:1006; rev:2;)",
        "pass udp $DEV_AKL 53 -> $DEV_SYD any (msg:\"lab peer-dev udp return akl>syd\"; flow:stateless; sid:1009; rev:1;)",
        "pass udp $DEV_SYD 53 -> $DEV_AKL any (msg:\"lab peer-dev udp return syd>akl\"; flow:stateless; sid:1010; rev:1;)",
      ])
    }
    peer_dev_ssh = {
      priority    = 11
      capacity    = 10
      description = "Dev jump hosts SSH Syd-Akl (dummy /.180–.199; demo hosts use private /.4–.126)"
      ip_sets = {
        DEV_SYD_JUMPS = local.dev_syd_jumps
        DEV_AKL_JUMPS = local.dev_akl_jumps
      }
      rules = join("\n", [
        "pass tcp $DEV_SYD_JUMPS any -> $DEV_AKL_JUMPS 22 (msg:\"lab peer-dev-ssh syd>akl\"; sid:1101; rev:1;)",
        "pass tcp $DEV_AKL_JUMPS any -> $DEV_SYD_JUMPS 22 (msg:\"lab peer-dev-ssh akl>syd\"; sid:1102; rev:1;)",
      ])
    }
    same_region_demo = {
      priority    = 15
      capacity    = 20
      description = "Same-Region inter-account demo (dev↔prod hairpin through local NFW)"
      ip_sets = {
        DEV_SYD       = local.dev_syd
        DEV_AKL       = local.dev_akl
        PROD_SYD_APPS = local.prod_syd_apps
        PROD_AKL_APPS = local.prod_akl_apps
      }
      rules = join("\n", [
        "pass icmp $DEV_SYD any -> $PROD_SYD_APPS any (msg:\"lab same-region icmp syd-dev>syd-prod\"; flow:stateless; sid:1501; rev:1;)",
        "pass icmp $PROD_SYD_APPS any -> $DEV_SYD any (msg:\"lab same-region icmp syd-prod>syd-dev\"; flow:stateless; sid:1502; rev:1;)",
        "pass tcp $DEV_SYD any -> $PROD_SYD_APPS 80 (msg:\"lab same-region http syd-dev>syd-prod\"; flow:stateless; sid:1503; rev:1;)",
        "pass tcp $PROD_SYD_APPS any -> $DEV_SYD 80 (msg:\"lab same-region http syd-prod>syd-dev\"; flow:stateless; sid:1504; rev:1;)",
        "pass tcp $PROD_SYD_APPS 80 -> $DEV_SYD any (msg:\"lab same-region http return syd-prod>syd-dev\"; flow:stateless; sid:1505; rev:1;)",
        "pass tcp $DEV_SYD 80 -> $PROD_SYD_APPS any (msg:\"lab same-region http return syd-dev>syd-prod\"; flow:stateless; sid:1506; rev:1;)",
        "pass icmp $DEV_AKL any -> $PROD_AKL_APPS any (msg:\"lab same-region icmp akl-dev>akl-prod\"; flow:stateless; sid:1511; rev:1;)",
        "pass icmp $PROD_AKL_APPS any -> $DEV_AKL any (msg:\"lab same-region icmp akl-prod>akl-dev\"; flow:stateless; sid:1512; rev:1;)",
        "pass tcp $DEV_AKL any -> $PROD_AKL_APPS 80 (msg:\"lab same-region http akl-dev>akl-prod\"; flow:stateless; sid:1513; rev:1;)",
        "pass tcp $PROD_AKL_APPS any -> $DEV_AKL 80 (msg:\"lab same-region http akl-prod>akl-dev\"; flow:stateless; sid:1514; rev:1;)",
        "pass tcp $PROD_AKL_APPS 80 -> $DEV_AKL any (msg:\"lab same-region http return akl-prod>akl-dev\"; flow:stateless; sid:1515; rev:1;)",
        "pass tcp $DEV_AKL 80 -> $PROD_AKL_APPS any (msg:\"lab same-region http return akl-dev>akl-prod\"; flow:stateless; sid:1516; rev:1;)",
      ])
    }
    svc_prod_http = {
      priority    = 20
      capacity    = 10
      description = "Prod HTTP/HTTPS between app /32 sets"
      ip_sets = {
        PROD_SYD_APPS = local.prod_syd_apps
        PROD_AKL_APPS = local.prod_akl_apps
      }
      rules = join("\n", [
        "pass tcp $PROD_SYD_APPS any -> $PROD_AKL_APPS [80,443] (msg:\"lab prod-http syd>akl\"; flow:stateless; sid:2001; rev:2;)",
        "pass tcp $PROD_AKL_APPS any -> $PROD_SYD_APPS [80,443] (msg:\"lab prod-http akl>syd\"; flow:stateless; sid:2002; rev:2;)",
        "pass tcp $PROD_AKL_APPS [80,443] -> $PROD_SYD_APPS any (msg:\"lab prod-http return akl>syd\"; flow:stateless; sid:2003; rev:1;)",
        "pass tcp $PROD_SYD_APPS [80,443] -> $PROD_AKL_APPS any (msg:\"lab prod-http return syd>akl\"; flow:stateless; sid:2004; rev:1;)",
      ])
    }
    svc_prod_db = {
      priority    = 21
      capacity    = 10
      description = "Prod app to same-Region DB :5432"
      ip_sets = {
        PROD_SYD_APPS = local.prod_syd_apps
        PROD_AKL_APPS = local.prod_akl_apps
        PROD_SYD_DBS  = local.prod_syd_dbs
        PROD_AKL_DBS  = local.prod_akl_dbs
      }
      rules = join("\n", [
        "pass tcp $PROD_SYD_APPS any -> $PROD_SYD_DBS 5432 (msg:\"lab prod-db syd\"; sid:2101; rev:1;)",
        "pass tcp $PROD_AKL_APPS any -> $PROD_AKL_DBS 5432 (msg:\"lab prod-db akl\"; sid:2102; rev:1;)",
      ])
    }
    svc_prod_dns = {
      priority    = 22
      capacity    = 10
      description = "Prod apps/monitors to DNS /32s"
      ip_sets = {
        PROD_CLIENTS = local.prod_clients
        PROD_DNS     = local.prod_dns
      }
      rules = join("\n", [
        "pass tcp $PROD_CLIENTS any -> $PROD_DNS 53 (msg:\"lab prod-dns tcp\"; sid:2201; rev:1;)",
        "pass udp $PROD_CLIENTS any -> $PROD_DNS 53 (msg:\"lab prod-dns udp\"; sid:2202; rev:1;)",
      ])
    }
    svc_prod_metrics = {
      priority    = 23
      capacity    = 10
      description = "Prod monitors to apps :9100"
      ip_sets = {
        PROD_MONITORS = local.prod_monitors
        PROD_APPS     = local.prod_apps
      }
      rules = join("\n", [
        "pass tcp $PROD_MONITORS any -> $PROD_APPS 9100 (msg:\"lab prod-metrics\"; sid:2301; rev:1;)",
      ])
    }
    svc_prod_ldap = {
      priority    = 24
      capacity    = 10
      description = "Prod apps to dummy LDAP /32s (hosts do not exist)"
      ip_sets = {
        PROD_APPS = local.prod_apps
        PROD_LDAP = local.dummy_ldap
      }
      rules = join("\n", [
        "pass tcp $PROD_APPS any -> $PROD_LDAP 389 (msg:\"lab prod-ldap\"; sid:2401; rev:1;)",
        "pass tcp $PROD_APPS any -> $PROD_LDAP 636 (msg:\"lab prod-ldaps\"; sid:2402; rev:1;)",
      ])
    }
    svc_prod_ntp = {
      priority    = 25
      capacity    = 10
      description = "Prod apps UDP NTP to dummy insp-VPC /32s"
      ip_sets = {
        PROD_APPS = local.prod_apps
        PROD_NTP  = local.dummy_ntp
      }
      rules = join("\n", [
        "pass udp $PROD_APPS any -> $PROD_NTP 123 (msg:\"lab prod-ntp\"; sid:2501; rev:1;)",
      ])
    }
    svc_dummy_batch = {
      priority    = 30
      capacity    = 10
      description = "Dummy batch Syd-Akl :8443 - IP sets exclude demo hosts so real probes still drop"
      ip_sets = {
        DUMMY_SYD = local.dummy_syd_batch
        DUMMY_AKL = local.dummy_akl_batch
      }
      rules = join("\n", [
        "pass tcp $DUMMY_SYD any -> $DUMMY_AKL 8443 (msg:\"lab dummy-batch syd>akl\"; sid:3001; rev:1;)",
        "pass tcp $DUMMY_AKL any -> $DUMMY_SYD 8443 (msg:\"lab dummy-batch akl>syd\"; sid:3002; rev:1;)",
      ])
    }
  } : {}
}

resource "aws_networkfirewall_rule_group" "pass" {
  for_each = local.pass_rule_groups

  name        = "${var.name}-${replace(each.key, "_", "-")}"
  description = each.value.description
  type        = "STATEFUL"
  capacity    = each.value.capacity

  rule_group {
    rule_variables {
      dynamic "ip_sets" {
        for_each = each.value.ip_sets
        content {
          key = ip_sets.key
          ip_set {
            definition = ip_sets.value
          }
        }
      }
    }

    rules_source {
      rules_string = each.value.rules
    }

    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
  }

  tags = local.tags
}
