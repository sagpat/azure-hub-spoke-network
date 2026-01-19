# Week 1 Learning Notes: Enterprise Hub-Spoke Network

> **Project:** Enterprise Hub-Spoke Network with Secure Access
> **Focus:** Azure Networking, Hub Spoke Architecture.

---

## Table of Contents

1. [Azure Firewall Policy & Rules](#1-azure-firewall-policy--rules)
2. [Azure's Magic IP: 168.63.129.16](#2-azures-magic-ip-16863129016)
3. [Azure Firewall Pricing](#3-azure-firewall-pricing)
4. [VNet Peering: Why Two-Way?](#4-vnet-peering-why-two-way)
5. [Diagnostic Settings](#5-diagnostic-settings)
6. [Route Tables (UDRs)](#6-route-tables-udrs)
7. [Incremental Deployment Strategies](#7-incremental-deployment-strategies)
8. [Test VM Module](#8-test-vm-module)
9. [Private DNS Zones](#9-private-dns-zones)
10. [Understanding Traceroute Through Azure Firewall](#10-understanding-traceroute-through-azure-firewall)
11. [Verifying Internet Traffic Through Firewall](#11-verifying-internet-traffic-through-firewall)
12. [Monitoring Architecture: How Logs Flow](#12-monitoring-architecture-how-logs-flow)

---

## 1. Azure Firewall Policy & Rules

### Hierarchy Overview

```
┌─────────────────────────────────────────────────────────┐
│                  Azure Firewall Policy                  │
│  (Container for all rules - can be shared across FWs)   │
└─────────────────────────┬───────────────────────────────┘
              │
    ┌─────────────────┼─────────────────┐
    ▼                 ▼                 ▼
┌───────────────┐ ┌───────────────┐ ┌───────────────────┐
│ Rule Collection│ │ Rule Collection│ │ Rule Collection │
│ Group (Pri:100)│ │ Group (Pri:200)│ │ Group (Pri:300) │
│   DNAT Rules   │ │ Network Rules  │ │ Application     │
└───────────────┘ └───────────────┘ └───────────────────┘
```

### Azure Firewall Policy

A **policy** is a top-level container that holds all your firewall rules.

| Feature | Description |
|---------|-------------|
| **Centralized Management** | One policy can be attached to multiple firewalls |
| **Inheritance** | Child policies can inherit from parent policies |
| **Global Settings** | DNS proxy, threat intelligence, TLS inspection |

```hcl
resource "azurerm_firewall_policy" "main" {
  name     = "fwpol-hubspoke"
  sku      = "Basic"  # Using Basic SKU for dev/test cost savings
  
  # Note: DNS proxy requires Standard or Premium tier
  # dns {
  #   proxy_enabled = true
  # }
  
  threat_intelligence_mode = "Alert"  # Alert on known malicious IPs
}
```

### Rule Types Explained

#### 1️⃣ DNAT Rules (Destination NAT) — Process First

**Purpose:** Translate inbound traffic from public IP to private resources

```
Internet → Firewall Public IP:80 → Translated to → Web Server 10.1.1.4:80
```

| Use Case | Example |
|----------|---------|
| Expose web server | Public:443 → Private:443 |
| Expose SSH jump box | Public:2222 → Private:22 |

```hcl
nat_rule_collection {
  name     = "dnat-web"
  priority = 100
  action   = "Dnat"
  
  rule {
  name                = "web-http"
  protocols           = ["TCP"]
  source_addresses    = ["*"]           # From anywhere
  destination_address = "20.1.2.3"      # Firewall public IP
  destination_ports   = ["80"]
  translated_address  = "10.1.1.4"      # Internal web server
  translated_port     = "80"
  }
}
```

#### 2️⃣ Network Rules — Process Second

**Purpose:** Filter traffic at **Layer 3/4** (IP addresses, ports, protocols)

| Field | What It Filters |
|-------|-----------------|
| `protocols` | TCP, UDP, ICMP, Any |
| `source_addresses` | Source IP/CIDR |
| `destination_addresses` | Destination IP/CIDR |
| `destination_ports` | Port numbers |

```hcl
network_rule_collection {
  name     = "allow-spoke-to-spoke"
  priority = 100
  action   = "Allow"
  
  rule {
  name                  = "spoke-communication"
  protocols             = ["Any"]
  source_addresses      = ["10.1.0.0/16"]  # Web spoke
  destination_addresses = ["10.2.0.0/16"]  # Data spoke
  destination_ports     = ["1433"]          # SQL port
  }
}
```

#### 3️⃣ Application Rules — Process Last

**Purpose:** Filter traffic at **Layer 7** (HTTP/HTTPS with FQDN matching)

| Feature | Description |
|---------|-------------|
| `destination_fqdns` | Filter by domain names (*.microsoft.com) |
| `protocols` | HTTP (80), HTTPS (443), MSSQL (1433) |
| `web_categories` | Block categories like "Gambling", "Social Media" |

```hcl
application_rule_collection {
  name     = "allow-azure-services"
  priority = 200
  action   = "Allow"
  
  rule {
  name = "azure-management"
  protocols {
    type = "Https"
    port = 443
  }
  source_addresses  = ["10.0.0.0/8"]
  destination_fqdns = [
    "management.azure.com",
    "*.management.azure.com"
  ]
  }
}
```

### Processing Order

```
Incoming Traffic
    │
    ▼
┌─────────────────┐
│ 1. DNAT Rules   │ ──→ Match? Translate & continue
│    (Inbound)    │
└────────┬────────┘
     ▼
┌─────────────────┐
│ 2. Network Rules│ ──→ Match Allow? Pass through
│    (L3/L4)      │ ──→ Match Deny? Drop
└────────┬────────┘
     ▼
┌─────────────────┐
│ 3. Application  │ ──→ Match Allow? Pass through
│    Rules (L7)   │ ──→ No match? Deny (default)
└────────┬────────┘
     ▼
  Traffic Allowed/Denied
```

### Quick Reference Table

| Rule Type | Layer | Filters By | Best For |
|-----------|-------|------------|----------|
| **DNAT** | L3/L4 | Port translation | Exposing services to internet |
| **Network** | L3/L4 | IP, Port, Protocol | Internal routing, non-HTTP traffic |
| **Application** | L7 | FQDN, URL, Category | Web traffic, SaaS apps |

---

## 2. Azure's Magic IP: 168.63.129.16

### What Is It?

A **special virtual public IP address** used by Azure to provide critical platform services to all VMs.

### Services Provided

| Service | Purpose |
|---------|---------|
| **Azure DNS** | DNS resolution for Azure resources (port 53) |
| **DHCP** | IP address assignment to VMs |
| **Health Probes** | Load balancer health checks |
| **VM Agent** | Communication for Azure VM extensions |
| **Metadata Service** | Instance metadata (IMDS) |
| **KMS Activation** | Windows activation |

### Why We Allow DNS to This IP

```hcl
rule {
  name                  = "allow-dns"
  protocols             = ["UDP"]
  source_addresses      = ["*"]
  destination_addresses = ["168.63.129.16"]  # Azure DNS
  destination_ports     = ["53"]
}
```

This rule ensures VMs can:
- Resolve Azure resource names
- Resolve private DNS zones (privatelink.*)
- Resolve public DNS names through Azure

### Key Facts

| Property | Value |
|----------|-------|
| IP Address | `168.63.129.16` |
| Scope | Same in **all** Azure regions |
| Routable | Only within Azure VNets |
| Not a real server | Virtual IP handled by Azure fabric |

### What Happens If You Block It?

❌ VMs can't get IP addresses (DHCP fails)  
❌ DNS resolution breaks  
❌ Load balancer health probes fail  
❌ VM extensions stop working  
❌ Windows activation fails  

**Key Takeaway:** This is a critical Azure infrastructure IP that should always be allowed.

---

## 3. Azure Firewall Pricing

### Firewall Policy Pricing

| Item | Cost |
|------|------|
| **Azure Firewall Policy** | **$100 per policy per region** |
| Policy Analytics (optional) | $250 per policy per month |

### Important Exception

> **No charge if the policy is associated with only a single firewall**

```
┌─────────────────────────────────────────────────────────────────┐
│  Policy → 1 Firewall = FREE                                     │
│  Policy → 2+ Firewalls (same region) = $100/month               │
│  Policy → 4 Firewalls (4 regions) = $400/month ($100 × 4)       │
└─────────────────────────────────────────────────────────────────┘
```

### Azure Firewall Cost

| SKU | Deployment (per hour) | Data Processing (per GB) | Est. Monthly |
|-----|----------------------|-------------------------|--------------|
| **Basic** | $0.395/hr | $0.065/GB | ~$288 |
| **Standard** | $1.25/hr | $0.016/GB | ~$912 |
| **Premium** | $1.75/hr | $0.016/GB | ~$1,277 |

### This Project's Cost (Single Firewall with Basic SKU)

| Resource | Cost |
|----------|------|
| Firewall Policy | **$0** (single firewall association) |
| Azure Firewall (Basic) | ~$288/month |
| Public IP (Firewall) | ~$4/month |
| Public IP (Management - Basic SKU requirement) | ~$4/month |
| **Total** | **~$296/month** |

> **Note:** This project uses Basic SKU to save ~$620/month compared to Standard SKU.
> Basic SKU requires an additional Management Public IP and Management Subnet.

### Cost-Saving Tips

1. **We're already using Basic SKU** — saving ~$620/month vs Standard
2. **Deallocate when not in use** — saves ~$10/day
3. **Set `enable_firewall = false`** during initial learning

---


## 4. VNet Peering: Why Two-Way?

Azure VNet peering is **non-transitive and one-directional by design**. Each peering only allows traffic in the direction it's configured.

### The Two Peerings

```
┌─────────────────┐                      ┌─────────────────┐
│                 │   spoke_to_hub       │                 │
│   Spoke VNet    │ ──────────────────▶  │    Hub VNet     │
│   (10.1.0.0/16) │                      │   (10.0.0.0/16) │
│                 │   hub_to_spoke       │                 │
│                 │ ◀──────────────────  │                 │
└─────────────────┘                      └─────────────────┘
```

| Peering | Created In | Allows Traffic |
|---------|-----------|----------------|
| `spoke_to_hub` | Spoke VNet | Spoke → Hub |
| `hub_to_spoke` | Hub VNet | Hub → Spoke |

### Without Both Peerings

| Scenario | Result |
|----------|--------|
| Only `spoke_to_hub` | Spoke can reach Hub ✅, Hub can't reach Spoke ❌ |
| Only `hub_to_spoke` | Hub can reach Spoke ✅, Spoke can't reach Hub ❌ |
| **Both peerings** | **Bidirectional communication ✅** |

### Real-World Example

```
Web VM (Spoke)              Firewall (Hub)              Response
   10.1.1.4                   10.0.1.4
    │                          │
    │── HTTP Request ─────────▶│   (needs spoke_to_hub)
    │                          │
    │◀─── HTTP Response ───────│   (needs hub_to_spoke)
    │                          │
```

### Peering Settings Explained

```hcl
# Spoke → Hub peering
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  allow_virtual_network_access = true   # Allow basic connectivity
  allow_forwarded_traffic      = true   # Accept traffic forwarded BY hub
  allow_gateway_transit        = false  # Spoke doesn't have a gateway
  use_remote_gateways          = false  # Not using hub's VPN gateway
}

# Hub → Spoke peering
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  allow_virtual_network_access = true   # Allow basic connectivity
  allow_forwarded_traffic      = true   # Accept traffic forwarded TO spoke
  allow_gateway_transit        = true   # Hub CAN share its gateway
  use_remote_gateways          = false  # Hub doesn't use remote gateways
}
```

### Key Settings

| Setting | Purpose |
|---------|---------|
| `allow_virtual_network_access` | Enable basic IP connectivity |
| `allow_forwarded_traffic` | Accept non-direct traffic (e.g., from firewall) |
| `allow_gateway_transit` | Share VPN/ExpressRoute gateway with peer |
| `use_remote_gateways` | Use the peer's gateway for on-prem connectivity |

### Why `allow_forwarded_traffic = true`?

Critical for hub-spoke! Without it, spoke-to-spoke via firewall fails:

```
Spoke-Web                  Hub Firewall                 Spoke-Data
 10.1.1.4                    10.0.1.4                    10.2.1.4
  │                           │                           │
  │── Packet to 10.2.1.4 ────▶│                           │
  │                           │── Forward to 10.2.1.4 ───▶│
  │                           │      (forwarded traffic)  │
```

**Key Takeaway:** Azure requires a peering resource on **both sides** to enable bidirectional communication. It's a security feature—each VNet owner must explicitly consent.

---

## 5. Diagnostic Settings

### What It Does

Sends firewall logs and metrics to **Log Analytics** for monitoring, troubleshooting, and compliance.

### Configuration

```hcl
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                       = "diag-${azurerm_firewall.main.name}"
  target_resource_id         = azurerm_firewall.main.id          # What to monitor
  log_analytics_workspace_id = var.log_analytics_workspace_id    # Where to send
```

### Log Categories

| Category | What It Captures |
|----------|------------------|
| `AzureFirewallApplicationRule` | Layer 7 rule hits - legacy format |
| `AzureFirewallNetworkRule` | Layer 3/4 rule hits - legacy format |
| `AzureFirewallDnsProxy` | DNS queries when DNS proxy is enabled |
| `AZFWApplicationRule` | Layer 7 rule hits - **new structured format** |
| `AZFWNetworkRule` | Layer 3/4 rule hits - **new structured format** |

### Legacy vs New Format

```
┌─────────────────────────────────────────────────────────────────┐
│  Legacy (AzureFirewall*)         │  New (AZFW*)                 │
├──────────────────────────────────┼──────────────────────────────┤
│  Single msg_s string field       │  Structured JSON fields      │
│  Harder to query                 │  Easy to filter/aggregate    │
│  "HTTPS request from 10.1.1.4    │  { "SourceIp": "10.1.1.4",  │
│   to github.com:443. Action:     │    "Fqdn": "github.com",     │
│   Allow"                         │    "Action": "Allow" }       │
└──────────────────────────────────┴──────────────────────────────┘
```

### Where Logs Go

```
Azure Firewall ──▶ Diagnostic Setting ──▶ Log Analytics Workspace
                          │
                          ▼
                      ┌─────────────────┐
                      │  Query with KQL │
                      │  Create Alerts  │
                      │  Build Dashboards│
                      └─────────────────┘
```

### Example KQL Queries

**See blocked traffic:**
```kusto
AZFWNetworkRule
| where Action == "Deny"
| project TimeGenerated, SourceIp, DestinationIp, DestinationPort
| take 100
```

**Top accessed FQDNs:**
```kusto
AZFWApplicationRule
| summarize count() by Fqdn
| top 10 by count_
```

### Cost Impact

| Item | Cost |
|------|------|
| Log ingestion | ~$2.76/GB |
| Log retention (first 31 days) | Free |
| Log retention (beyond 31 days) | ~$0.12/GB/month |

---

## 6. Route Tables (UDRs)

### What Are UDRs?

User Defined Routes override Azure's default routing, giving you control over traffic flow.

### Route 1: Default Route (Internet Traffic)

```hcl
resource "azurerm_route" "to_firewall" {
  name                   = "route-to-firewall"
  address_prefix         = "0.0.0.0/0"           # ALL destinations
  next_hop_type          = "VirtualAppliance"    # Send to firewall
  next_hop_in_ip_address = var.firewall_private_ip  # e.g., 10.0.1.4
}
```

| Field | Meaning |
|-------|---------|
| `0.0.0.0/0` | Matches **any destination** (default route) |
| `VirtualAppliance` | Route to a network virtual appliance |
| `next_hop_in_ip_address` | Firewall's private IP |

**Effect:** Any traffic going to the internet goes through firewall first.

```
VM (10.1.1.4) ──▶ Firewall (10.0.1.4) ──▶ Internet
            │
         Inspect/Log/Filter
```

### Route 2: Spoke-to-Spoke Traffic

```hcl
resource "azurerm_route" "to_spokes" {
  name                   = "route-to-spokes"
  address_prefix         = "10.0.0.0/8"          # All 10.x.x.x addresses
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip
}
```

**Effect:** Traffic between spokes goes through firewall.

```
Spoke-Web (10.1.1.4) ──▶ Firewall (10.0.1.4) ──▶ Spoke-Data (10.2.1.4)
                │
          Inspect/Log/Allow or Deny
```

### Why Both Routes?

| Scenario | Without UDR | With UDR |
|----------|-------------|----------|
| Spoke → Internet | Direct via Azure | Via Firewall ✅ |
| Spoke → Spoke | Direct via peering | Via Firewall ✅ |

### Route Table Association

```hcl
resource "azurerm_subnet_route_table_association" "spoke_subnets" {
  for_each = var.subnet_ids

  subnet_id      = each.value
  route_table_id = azurerm_route_table.spoke.id
}
```

### Visual Traffic Flow

```
            ┌─────────────────────────────┐
            │      Azure Firewall         │
            │        10.0.1.4             │
            └──────────┬──────────────────┘
                   │
    ┌──────────────────────────┼──────────────────────────┐
    │                          │                          │
    ▼                          ▼                          ▼
┌───────────────┐          ┌───────────────┐          ┌───────────────┐
│  Spoke-Web    │          │  Spoke-Data   │          │  Spoke-Mgmt   │
│  10.1.0.0/16  │          │  10.2.0.0/16  │          │  10.3.0.0/16  │
│               │          │               │          │               │
│ Route Table:  │          │ Route Table:  │          │ Route Table:  │
│ 0.0.0.0/0→FW  │          │ 0.0.0.0/0→FW  │          │ 0.0.0.0/0→FW  │
│ 10.0.0.0/8→FW │          │ 10.0.0.0/8→FW │          │ 10.0.0.0/8→FW │
└───────────────┘          └───────────────┘          └───────────────┘
```

---

## 7. Incremental Deployment Strategies

### Option 1: Use `-target` Flag

Deploy specific modules one at a time:

```bash
# Day 1: Foundation
terraform apply -target=azurerm_resource_group.hub \
        -target=azurerm_resource_group.spokes \
        -target=module.monitoring \
        -target=module.hub_network

# Day 2: Spoke Networks
terraform apply -target=module.spoke_networks

# Day 3: Azure Firewall
terraform apply -target=module.firewall

# Day 4: Route Tables
terraform apply -target=module.route_tables

# Day 5: NSGs + Bastion
terraform apply -target=module.nsgs \
        -target=module.bastion

# Day 6: Private DNS
terraform apply -target=module.private_dns
```

### Option 2: Use Feature Flags

Modify `terraform.tfvars`:

```hcl
# Start with expensive resources disabled
enable_firewall        = false   # ~$288/month saved (Basic SKU)
enable_bastion         = false   # ~$139/month saved
enable_network_watcher = false

# Enable incrementally as you learn
enable_firewall = true   # Day 3
enable_bastion  = true   # Day 5
deploy_test_vms = true   # Day 7 (requires SSH key)
```

### Recommended Day-by-Day Plan

| Day | What to Deploy | Est. Cost |
|-----|----------------|-----------|
| **Day 1** | RGs + Monitoring + Hub VNet | ~$2/day |
| **Day 2** | Study firewall rules (no deploy) | $0 |
| **Day 3** | Spoke VNets + Peering | ~$0.10/day |
| **Day 4** | Azure Firewall | ~$30/day ⚠️ |
| **Day 5** | Route Tables + NSGs | $0 |
| **Day 6** | Bastion + Private DNS | ~$5/day |
| **Day 7** | Test VMs + Connectivity Testing | ~$1/day |
| **Day 8** | Test everything, then **destroy** | $0 |

### Cost-Saving Commands

```bash
# Check what's deployed
terraform state list

# Destroy everything when done
terraform destroy

# Destroy specific expensive resource
terraform destroy -target=module.firewall
```

---

## 📝 Key Takeaways

1. **Terraform modules** are reusable templates; `for_each` creates multiple instances
2. **Azure Firewall Policy** is free for single firewall; $100/region for multiple
3. **VNet peering** requires resources on both sides for bidirectional traffic
4. **168.63.129.16** is Azure's internal DNS/DHCP IP — never block it!
5. **UDRs** override default routing to force traffic through firewall
6. **Diagnostic settings** send logs to Log Analytics for monitoring
7. **Incremental deployment** helps with learning and cost management
8. **Test VMs** are essential to validate hub-spoke connectivity via Bastion

---

## 8. Test VM Module

### Why Test VMs?

Without actual VMs in the spoke networks, you can't validate:
- Traffic flowing through the firewall
- Spoke-to-spoke connectivity
- Bastion access working correctly
- DNS resolution via private DNS zones
- Route tables forcing traffic correctly

### Architecture

```
┌───────────────────────────────────────────────────────┐
│                    HUB NETWORK                          │
│  ┌─────────────┐  ┌─────────────┐                         │
│  │  Firewall   │  │   Bastion   │───SSH via browser───▶  │
│  └─────────────┘  └─────────────┘                         │
└──────────┬──────────────┬───────────────┬────────────┘
       │              │               │
  ┌──────▼──────┐  ┌───▼───────┐  ┌─▼───────────┐
  │ SPOKE: web  │  │ SPOKE: data│  │ SPOKE: mgmt │
  │ ┌────────┐ │  │ ┌───────┐ │  │ ┌────────┐ │
  │ │ VM-web │ │  │ │VM-data│ │  │ │ VM-mgmt│ │
  │ └10.1.1.4┘ │  │ └10.2.1.4┘ │  │ └10.3.1.4┘ │
  └─────────────┘  └───────────┘  └────────────┘
```

### How the VM Module Works

```hcl
# In main.tf - deploys one VM per spoke when enabled
module "test_vms" {
  source   = "./modules/vm"
  for_each = var.deploy_test_vms ? var.spoke_vnets : {}

  spoke_name           = each.key            # "web", "data", "mgmt"
  subnet_id            = module.spoke_networks[each.key].subnet_ids[...]
  admin_ssh_public_key = var.admin_ssh_public_key
}
```

### Key Terraform Concepts Used

| Concept | Usage |
|---------|-------|
| `for_each` | Creates VM in each spoke network |
| Conditional | `var.deploy_test_vms ? ... : {}` skips if false |
| `custom_data` | Bootstraps VM with networking tools |
| SSH key auth | More secure than password, works with Bastion |

### Connectivity Tests to Run

```bash
# 1. Test spoke-to-spoke (from web VM)
ping 10.2.1.4           # Should go via firewall
traceroute 10.2.1.4     # Should show firewall hop

# 2. Test internet access
curl https://ifconfig.me  # Should show firewall's public IP

# 3. Test private DNS
nslookup privatelink.blob.core.windows.net

# 4. Test what's blocked
curl -I https://gambling-site.com  # Should be blocked by firewall
```

### Pre-installed Tools

The VM `custom_data` script installs:
- `curl`, `wget` - HTTP testing
- `traceroute` - Route path analysis
- `nslookup`, `dig` - DNS testing
- `tcpdump` - Packet capture
- `nmap` - Port scanning

---

## 9. Private DNS Zones

### What are Azure Private DNS Zones?

Azure **Private DNS Zones** provide name resolution within virtual networks without needing custom DNS servers. They are essential for **Private Endpoints**—the feature that allows you to access Azure PaaS services (like SQL Database, Storage, Key Vault) over a private IP address instead of their public endpoints.

### Why Private DNS Zones Matter

When you create a **Private Endpoint** for an Azure service (e.g., Azure SQL Database), Azure assigns it a private IP from your VNet. But here's the problem:

- The service's public FQDN (e.g., `mydb.database.windows.net`) still resolves to a **public IP** by default
- Your VMs would try to connect to the public IP, bypassing your private network security

**Private DNS Zones solve this** by:
1. Overriding the public DNS resolution within your VNet
2. Resolving the service FQDN to the **private IP** of the Private Endpoint

### How It Works in This Project

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Private DNS Zone                                 │
│            privatelink.database.windows.net                          │
│                                                                      │
│  A Record: mydb → 10.1.1.5 (Private Endpoint IP)                    │
└───────────────────────────┬─────────────────────────────────────────┘
              │
      ┌───────────────┼───────────────────────┐
      │ VNet Links    │                       │
      ▼               ▼                       ▼
  ┌───────────────┐ ┌───────────────┐     ┌───────────────┐
  │   Hub VNet    │ │  Spoke VNets  │ ... │  All VNets    │
  │  10.0.0.0/16  │ │   10.1-3.x    │     │   Linked!     │
  └───────────────┘ └───────────────┘     └───────────────┘
      │               │                       │
      ▼               ▼                       ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  VMs in any linked VNet can resolve:                            │
  │  mydb.database.windows.net → 10.1.1.5 (Private IP)             │
  │  NOT the public IP!                                             │
  └─────────────────────────────────────────────────────────────────┘
```

### DNS Zones in This Project

| Zone Name | Azure Service | Purpose |
|-----------|---------------|---------|
| `privatelink.database.windows.net` | Azure SQL Database | Private access to SQL DBs |
| `privatelink.blob.core.windows.net` | Azure Blob Storage | Private access to Storage Accounts |
| `privatelink.vaultcore.azure.net` | Azure Key Vault | Private access to secrets/keys |
| `privatelink.azurewebsites.net` | Azure App Service | Private access to web apps |

### Terraform Implementation

The project creates DNS zones and links them to all VNets:

```hcl
# Create the Private DNS Zone
resource "azurerm_private_dns_zone" "zones" {
  for_each = toset(var.dns_zones)
  name                = each.value  # e.g., "privatelink.database.windows.net"
  resource_group_name = var.resource_group_name
}

# Link to Hub VNet
resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  for_each = toset(var.dns_zones)
  name                  = "link-hub"
  private_dns_zone_name = azurerm_private_dns_zone.zones[each.key].name
  virtual_network_id    = var.hub_vnet_id
  registration_enabled  = false  # Manual record management
}

# Link to ALL Spoke VNets
resource "azurerm_private_dns_zone_virtual_network_link" "spokes" {
  for_each = {
  for pair in setproduct(var.dns_zones, keys(var.spoke_vnet_ids)) :
  "${pair[0]}-${pair[1]}" => {
    zone    = pair[0]
    spoke   = pair[1]
    vnet_id = var.spoke_vnet_ids[pair[1]]
  }
  }
  name                  = "link-spoke-${each.value.spoke}"
  private_dns_zone_name = azurerm_private_dns_zone.zones[each.value.zone].name
  virtual_network_id    = each.value.vnet_id
}
```

### Key Concept: `setproduct` for Many-to-Many Links

The `setproduct` function creates the **Cartesian product** of two lists:

```hcl
# DNS Zones: ["privatelink.database.windows.net", "privatelink.blob.core.windows.net"]
# Spokes:    ["web", "data", "mgmt"]

# setproduct produces:
# [
#   ["privatelink.database.windows.net", "web"],
#   ["privatelink.database.windows.net", "data"],
#   ["privatelink.database.windows.net", "mgmt"],
#   ["privatelink.blob.core.windows.net", "web"],
#   ["privatelink.blob.core.windows.net", "data"],
#   ["privatelink.blob.core.windows.net", "mgmt"],
#   ... (4 zones × 3 spokes = 12 links)
# ]
```

This ensures **every DNS zone is linked to every VNet**.

### Registration Enabled vs Disabled

| Setting | Behavior |
|---------|----------|
| `registration_enabled = true` | VMs automatically register their hostnames in the DNS zone |
| `registration_enabled = false` | Records must be created manually (or by Private Endpoints) |

In this project, we use `false` because:
- DNS records are created automatically when you deploy Private Endpoints
- We don't need VM hostnames registered in these zones

### Testing Private DNS Resolution

From a VM in any spoke network:

```bash
# Test DNS resolution (should return private IP, not public)
nslookup privatelink.blob.core.windows.net

# If you have a real private endpoint:
nslookup mystorageaccount.blob.core.windows.net
# Should resolve to 10.x.x.x (private IP), not a public IP
```

### Complete Traffic Flow with Private Endpoint

```
┌─────────────────────────────────────────────────────────────────────┐
│  1. VM in Web Spoke wants to access Azure SQL Database              │
│     App calls: "mydb.database.windows.net"                          │
└───────────────────────────────┬─────────────────────────────────────┘
                ▼
┌─────────────────────────────────────────────────────────────────────┐
│  2. DNS Query sent to Azure DNS (168.63.129.16)                     │
│     Azure checks: Is there a Private DNS Zone linked to this VNet?  │
│     YES → privatelink.database.windows.net is linked                │
└───────────────────────────────┬─────────────────────────────────────┘
                ▼
┌─────────────────────────────────────────────────────────────────────┐
│  3. Private DNS Zone returns: 10.1.1.5 (Private Endpoint IP)        │
│     NOT the public IP!                                              │
└───────────────────────────────┬─────────────────────────────────────┘
                ▼
┌─────────────────────────────────────────────────────────────────────┐
│  4. Traffic flows PRIVATELY:                                        │
│     Web Spoke (10.1.x.x) → Hub VNet → Private Endpoint (10.1.1.5)  │
│     Never leaves Azure backbone, never touches public internet      │
└─────────────────────────────────────────────────────────────────────┘
```

### Benefits of This Architecture

| Benefit | Description |
|---------|-------------|
| **Security** | Traffic to PaaS services stays within Azure network |
| **Compliance** | No data exposure to public internet |
| **Centralized DNS** | All DNS zones in Hub RG, linked to all VNets |
| **Scalability** | Add new spokes and they automatically get DNS resolution |
| **No Custom DNS** | Uses Azure's built-in DNS (168.63.129.16) |

### Common Private Link DNS Zones

| Service | Zone Name |
|---------|-----------|
| Azure SQL | `privatelink.database.windows.net` |
| Blob Storage | `privatelink.blob.core.windows.net` |
| Key Vault | `privatelink.vaultcore.azure.net` |
| App Service | `privatelink.azurewebsites.net` |
| Cosmos DB | `privatelink.documents.azure.com` |
| Azure Container Registry | `privatelink.azurecr.io` |
| Azure Kubernetes Service | `privatelink.<region>.azmk8s.io` |
| Event Hubs | `privatelink.servicebus.windows.net` |

---

## 10. Understanding Traceroute Through Azure Firewall

### The Scenario

When running traceroute from a spoke VM to another spoke VM, you might see unexpected IPs:

```bash
azureuser@vm-hubspoke-dev-web:~$ traceroute 10.2.1.4
traceroute to 10.2.1.4 (10.2.1.4), 30 hops max, 60 byte packets
 1  10.0.5.6 (10.0.5.6)  3.925 ms  3.894 ms 10.0.5.5 (10.0.5.5)  2.821 ms
 2  * 10.2.1.4 (10.2.1.4)  4.332 ms *
```

### The Question

The firewall's configured IP is **10.0.1.4** (in AzureFirewallSubnet), but traceroute shows **10.0.5.5/10.0.5.6**. What's happening?

### Hub Network Subnet Layout

| Subnet | Address Range | Purpose |
|--------|--------------|--------|
| AzureFirewallSubnet | 10.0.1.0/24 | Firewall's main IP (**10.0.1.4**) |
| AzureFirewallManagementSubnet | **10.0.5.0/24** | Firewall management (Basic SKU) |
| AzureBastionSubnet | 10.0.2.0/26 | Bastion |
| GatewaySubnet | 10.0.3.0/27 | VPN/ExpressRoute Gateway |
| ManagementSubnet | 10.0.4.0/24 | Management VMs |

### Explanation

With **Basic SKU Azure Firewall**, Azure requires two subnets:

1. **AzureFirewallSubnet** (10.0.1.0/24)
   - The firewall's public-facing private IP: **10.0.1.4**
   - This is what your route tables point to
   - Used for traffic ingress/egress

2. **AzureFirewallManagementSubnet** (10.0.5.0/24)
   - Used for internal Azure management and packet processing
   - Required only for Basic SKU (forced tunneling scenario)
   - IPs like 10.0.5.5/10.0.5.6 are used internally

### Why Traceroute Shows Management IPs

When packets traverse the firewall:
1. Traffic enters via **10.0.1.4** (AzureFirewallSubnet)
2. Internal processing uses **10.0.5.x** IPs (AzureFirewallManagementSubnet)
3. Traceroute ICMP responses come from the processing plane, revealing management subnet IPs

### Visual Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│  Web Spoke VM (10.1.x.x)                                            │
│  traceroute 10.2.1.4                                                │
└──────────────────────────┬──────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Route Table: 0.0.0.0/0 → 10.0.1.4 (Firewall)                       │
└──────────────────────────┬──────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Azure Firewall (Hub Network)                                       │
│  ├── AzureFirewallSubnet: 10.0.1.4 (traffic entry point)           │
│  └── AzureFirewallManagementSubnet: 10.0.5.5/10.0.5.6 (processing) │
│                                                                     │
│  Hop 1 in traceroute: 10.0.5.5 / 10.0.5.6 ← Response from here     │
└──────────────────────────┬──────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Data Spoke VM: 10.2.1.4                                            │
│                                                                     │
│  Hop 2 in traceroute: 10.2.1.4 ← Final destination                 │
└─────────────────────────────────────────────────────────────────────┘
```

### The `*` Asterisks in Traceroute

The `*` symbols indicate ICMP packets that timed out:
```
 2  * 10.2.1.4 (10.2.1.4)  4.332 ms *
```

This is **normal behavior** - Azure Firewall and many network devices intentionally don't respond to all traceroute probes for security reasons.

### Key Takeaways

| Observation | Meaning |
|-------------|--------|
| Hop 1 shows 10.0.5.x | Traffic is going through Azure Firewall ✅ |
| Multiple IPs at Hop 1 | Firewall has multiple processing instances (HA) |
| Hop 2 reaches destination | Spoke-to-spoke routing works correctly ✅ |
| `*` asterisks | Normal - probes timed out (security feature) |
| 2 hops total | Direct path: Source → Firewall → Destination |

### Verification Commands

```bash
# Get firewall's configured private IP
az network firewall ip-config list \
  --firewall-name fw-hubspoke-dev-q1qb \
  --resource-group rg-hubspoke-dev-hub-q1qb \
  --query "[].privateIpAddress" -o tsv
# Returns: 10.0.1.4

# List all hub subnets
az network vnet subnet list \
  --resource-group rg-hubspoke-dev-hub-q1qb \
  --vnet-name vnet-hubspoke-dev-hub-q1qb \
  --output table
```

### Bottom Line

✅ Your hub-spoke network is working correctly!  
✅ Spoke-to-spoke traffic flows through the Azure Firewall as designed  
✅ Route tables (UDRs) are forcing traffic to the firewall  
✅ VNet peering is connected and functional

---

## 11. Verifying Internet Traffic Through Firewall

### The Test: What IP Does the Internet See?

When you run `curl https://ifconfig.me` from a spoke VM, it tells you which public IP the internet sees your traffic coming from.

```bash
azureuser@vm-hubspoke-dev-web:~$ curl https://ifconfig.me
20.x.x.x
```

If your network is configured correctly, this should be the **Azure Firewall's public IP**, not the VM's own IP.

### Finding Firewall's Public IP

#### Method 1: Azure Portal - Via Firewall Resource
1. Go to **Azure Portal** → Search for "Firewalls"
2. Click on **fw-hubspoke-dev-q1qb**
3. On the **Overview** page, look for **Firewall public IP** in the right panel

#### Method 2: Azure Portal - Via Public IP Resource
1. Go to **Azure Portal** → Search for "Public IP addresses"
2. Find **pip-hubspoke-dev-fw-q1qb**
3. The **IP address** field shows the public IP

#### Method 3: Azure CLI
```bash
az network public-ip show \
  --name pip-hubspoke-dev-fw-q1qb \
  --resource-group rg-hubspoke-dev-hub-q1qb \
  --query ipAddress -o tsv
```

### How It Works: SNAT (Source NAT)

When spoke VMs access the internet, Azure Firewall performs **SNAT** - it replaces the VM's private IP with the Firewall's public IP.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Spoke VM (10.1.1.4)                                                    │
│  curl https://ifconfig.me                                               │
│  Source IP: 10.1.1.4 (private)                                          │
└──────────────────────────────────┬──────────────────────────────────────┘
                   │
                   ▼ Route Table: 0.0.0.0/0 → 10.0.1.4
┌─────────────────────────────────────────────────────────────────────────┐
│  Azure Firewall                                                         │
│  Private IP: 10.0.1.4                                                   │
│  Public IP: 20.x.x.x                                                    │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  SNAT (Source NAT)                                               │   │
│  │  Before: Source IP = 10.1.1.4 (VM private IP)                   │   │
│  │  After:  Source IP = 20.x.x.x (Firewall public IP)              │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Internet (ifconfig.me)                                                 │
│                                                                         │
│  "I see your IP as: 20.x.x.x"                                          │
│                                                                         │
│  ifconfig.me only sees the Firewall's public IP,                       │
│  NOT the original VM's private IP (10.1.1.4)                           │
└─────────────────────────────────────────────────────────────────────────┘
```

### Step-by-Step Flow

| Step | What Happens | IP Addresses |
|------|-------------|-------------|
| 1 | Spoke VM sends HTTPS request to ifconfig.me | Source: 10.1.1.4, Dest: ifconfig.me |
| 2 | Route table redirects to Firewall | Traffic goes to 10.0.1.4 |
| 3 | Firewall inspects & applies rules | Checks if traffic is allowed |
| 4 | **SNAT occurs** | Source IP changed: 10.1.1.4 → 20.x.x.x |
| 5 | Request goes to internet | Source: 20.x.x.x (Firewall's public IP) |
| 6 | ifconfig.me responds | "Your IP is 20.x.x.x" |
| 7 | Response returns through Firewall | Reverse NAT back to 10.1.1.4 |
| 8 | VM receives response | Shows Firewall's public IP |

### Why This Matters

| Scenario | What ifconfig.me Returns | Meaning |
|----------|-------------------------|--------|
| ✅ Traffic through Firewall | Firewall's public IP (20.x.x.x) | Route tables working correctly |
| ❌ Traffic bypasses Firewall | VM's own public IP | Route table misconfigured |
| ❌ Traffic bypasses Firewall | Random Azure NAT IP | No routes to firewall |

### Verification Commands

```bash
# Step 1: Get Firewall's public IP
FW_PUBLIC_IP=$(az network public-ip show \
  --name pip-hubspoke-dev-fw-q1qb \
  --resource-group rg-hubspoke-dev-hub-q1qb \
  --query ipAddress -o tsv)

echo "Firewall Public IP: $FW_PUBLIC_IP"

# Step 2: From spoke VM, check what IP internet sees
# (Run this command while SSH'd into the spoke VM via Bastion)
curl https://ifconfig.me

# Step 3: Compare - they should match!
```

### What If They Don't Match?

If `curl https://ifconfig.me` returns a different IP than the Firewall's public IP:

1. **Check Route Table Association**
   ```bash
   az network vnet subnet show \
   --resource-group rg-hubspoke-dev-spoke-web-q1qb \
   --vnet-name vnet-hubspoke-dev-spoke-web-q1qb \
   --name WebSubnet \
   --query routeTable.id -o tsv
   ```

2. **Check Route Table Has Default Route**
   ```bash
   az network route-table route list \
   --resource-group rg-hubspoke-dev-spoke-web-q1qb \
   --route-table-name rt-hubspoke-dev-spoke-web-q1qb \
   --output table
   ```
   Should show: `0.0.0.0/0 → 10.0.1.4` (Firewall IP)

3. **Check Firewall Rules Allow Traffic**
   - Ensure outbound rules permit HTTPS to ifconfig.me

### Key Takeaways

| Concept | Description |
|---------|-------------|
| **SNAT** | Source Network Address Translation - Firewall replaces VM's private IP with its public IP |
| **ifconfig.me** | Service that returns your public IP as seen from the internet |
| **Verification** | If ifconfig.me returns Firewall's IP, your routing is correct |
| **Centralized Egress** | All internet traffic from all spokes exits through one IP (Firewall) |
| **Security Benefit** | Single point of control for all outbound traffic |

---

## 12. Monitoring Architecture: How Logs Flow

### The Question

How does the Log Analytics Workspace receive logs from all resources (Firewall, Bastion, NSGs)?

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    LOG ANALYTICS WORKSPACE                       │
│                  (log-hubspoke-dev-q1qb)                        │
│                                                                  │
│   Collects:  AzureDiagnostics, Metrics, Activity Logs           │
└─────────────────────────────────────────────────────────────────┘
                ▲
                │
    ┌─────────────────────┼─────────────────────┐
    │                     │                     │
    │                     │                     │
┌───────┴───────┐    ┌───────┴───────┐    ┌───────┴───────┐
│   FIREWALL    │    │    BASTION    │    │     NSGs      │
│               │    │               │    │               │
│ Diagnostic    │    │ Diagnostic    │    │ Diagnostic    │
│ Setting       │    │ Setting       │    │ Setting       │
└───────────────┘    └───────────────┘    └───────────────┘
```

### The Connection Mechanism: Diagnostic Settings

Each Azure resource has an `azurerm_monitor_diagnostic_setting` resource that creates a "pipe" to send logs to Log Analytics.

### Example: Firewall → Log Analytics

```hcl
# From modules/firewall/main.tf
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                       = "diag-${azurerm_firewall.main.name}"
  target_resource_id         = azurerm_firewall.main.id           # ← Source resource
  log_analytics_workspace_id = var.log_analytics_workspace_id     # ← Destination

  enabled_log {
  category = "AzureFirewallApplicationRule"   # HTTP/HTTPS traffic logs
  }
  enabled_log {
  category = "AzureFirewallNetworkRule"       # TCP/UDP/ICMP logs
  }
  metric {
  category = "AllMetrics"                     # Performance metrics
  }
}
```

### How the Workspace ID Flows Through Terraform

```
main.tf (root)
   │
   ├── module "monitoring" 
   │      └── Creates: azurerm_log_analytics_workspace.main
   │      └── Outputs: workspace_id
   │
   ├── module "firewall"
   │      └── Input: log_analytics_workspace_id = module.monitoring.workspace_id
   │      └── Creates: azurerm_monitor_diagnostic_setting
   │
   ├── module "bastion"
   │      └── Input: log_analytics_workspace_id = module.monitoring.workspace_id
   │      └── Creates: azurerm_monitor_diagnostic_setting
   │
   └── module "nsgs"
     └── Input: log_analytics_workspace_id = module.monitoring.workspace_id
     └── Creates: azurerm_monitor_diagnostic_setting (for each NSG)
```

### Key Components

| Component | Purpose |
|-----------|--------|
| **Log Analytics Workspace** | Central data store for all logs and metrics |
| **Diagnostic Setting** | The "pipe" connecting each resource to the workspace |
| **Log Categories** | What types of logs to send (ApplicationRule, NetworkRule, etc.) |
| **Metrics** | Performance data (throughput, latency, connections, etc.) |

### Log Categories by Resource

| Resource | Log Categories |
|----------|---------------|
| **Azure Firewall** | AzureFirewallApplicationRule, AzureFirewallNetworkRule, AZFWApplicationRule, AZFWNetworkRule |
| **Azure Bastion** | BastionAuditLogs |
| **NSGs** | NetworkSecurityGroupEvent, NetworkSecurityGroupRuleCounter |

### Useful KQL Queries

**All Firewall Activity:**
```kql
AzureDiagnostics
| where Category contains "AzureFirewall"
| project TimeGenerated, Category, msg_s
| order by TimeGenerated desc
```

**Blocked Traffic Only:**
```kql
AzureDiagnostics
| where Category contains "AzureFirewall"
| where msg_s contains "Deny"
| project TimeGenerated, msg_s
| order by TimeGenerated desc
```

**Traffic by Spoke:**
```kql
AzureDiagnostics
| where Category contains "AzureFirewall"
| parse msg_s with * "from " SourceIP ":" *
| extend Spoke = case(
  SourceIP startswith "10.1.", "Web Spoke",
  SourceIP startswith "10.2.", "Data Spoke",
  SourceIP startswith "10.3.", "Mgmt Spoke",
  "Other"
)
| summarize Count = count() by Spoke
```

### Key Takeaways

| Concept | Description |
|---------|-------------|
| **Diagnostic Settings** | The bridge between Azure resources and Log Analytics |
| **Centralized Logging** | All resources send logs to one workspace for unified analysis |
| **Log Categories** | Each resource type has specific log types you can enable |
| **Terraform Pattern** | Monitoring module outputs workspace_id, other modules consume it |
| **KQL** | Kusto Query Language used to query logs in Log Analytics |

---

### Azure Firewall Basic SKU

This project uses **Azure Firewall Basic** SKU for cost optimization in dev/test environments:

| Feature | Basic | Standard | Premium |
|---------|-------|----------|----------|
| Throughput | Up to 250 Mbps | Up to 30 Gbps | Up to 100 Gbps |
| Threat Intelligence | Alert only | Alert & Deny | Alert & Deny |
| IDPS | ❌ | ❌ | ✅ |
| TLS Inspection | ❌ | ❌ | ✅ |
| Web Categories | ❌ | ✅ | ✅ |
| Est. Cost/month | ~$300 | ~$912 | ~$1,825 |

**Basic SKU Requirements:**
- Requires a **Management Subnet** (`AzureFirewallManagementSubnet`) with minimum /26 CIDR
- Requires a **Management Public IP** for Azure infrastructure communication
- Management traffic is separated from data plane traffic
- Recommended for dev/test or small workloads with <250 Mbps throughput

## Additional Resources

- [Azure Hub-Spoke Reference Architecture](https://learn.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- [Azure Firewall Documentation](https://learn.microsoft.com/azure/firewall/)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Networking Best Practices](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/plan-for-ip-addressing)

---

