# Architecture Documentation

## Overview

This document provides detailed information about the hub-spoke network architecture implementation in Azure.

## Network Architecture Diagram

```
                              Internet
                                 |
                    ┌────────────┴─────────────┐
                    |                          |
              Azure Firewall              Azure Bastion
               (10.0.1.0/26)              (10.0.2.0/26)
                    |                          |
              ┌─────┴──────────────────────────┴─────┐
              |        Hub Virtual Network           |
              |           (10.0.0.0/16)              |
              |                                      |
              |  ┌────────────────┐                 |
              |  | VPN Gateway    |                 |
              |  | (10.0.3.0/26)  |                 |
              |  └────────┬───────┘                 |
              └───────────┼──────────────────────────┘
                         |
                    VNet Peering
                         |
         ┌───────────────┼───────────────┐
         |               |               |
    ┌────┴─────┐    ┌────┴─────┐   ┌────┴─────┐
    | Prod     |    | Dev      |   | Future   |
    | Spoke    |    | Spoke    |   | Spokes   |
    └──────────┘    └──────────┘   └──────────┘
```

## Hub Virtual Network

The hub VNet serves as the central connectivity point and contains shared services.

### Subnets

#### 1. Azure Firewall Subnet (10.0.1.0/26)
- **Purpose**: Network security appliance for traffic filtering
- **Naming**: Must be named "AzureFirewallSubnet" (Azure requirement)
- **Size**: /26 (64 IPs) - minimum required by Azure
- **Features**:
  - Layer 3-7 filtering
  - Threat intelligence
  - Network and application rules
  - Centralized logging

#### 2. Azure Bastion Subnet (10.0.2.0/26)
- **Purpose**: Secure RDP/SSH access to VMs
- **Naming**: Must be named "AzureBastionSubnet" (Azure requirement)
- **Size**: /26 (64 IPs) - minimum required by Azure
- **Features**:
  - Browser-based VM access
  - No public IPs needed on VMs
  - Protected against port scanning
  - TLS encrypted connections

#### 3. Gateway Subnet (10.0.3.0/26)
- **Purpose**: VPN Gateway for hybrid connectivity
- **Naming**: Must be named "GatewaySubnet" (Azure requirement)
- **Size**: /26 (64 IPs) - recommended for production
- **Features**:
  - Site-to-site VPN
  - Point-to-site VPN
  - ExpressRoute (future expansion)

#### 4. Management Subnet (10.0.4.0/24)
- **Purpose**: Management and jump box resources
- **Size**: /24 (256 IPs)
- **Use cases**:
  - Jump boxes
  - Monitoring tools
  - Configuration management

## Spoke Virtual Networks

### Production Spoke (10.1.0.0/16)

#### Workload Subnet (10.1.1.0/24)
- **Purpose**: Application tier
- **Services**: Web servers, application servers, APIs
- **NSG Rules**:
  - Allow HTTP/HTTPS from private networks
  - Allow required application ports
  - Deny all other inbound traffic

#### Data Subnet (10.1.2.0/24)
- **Purpose**: Database tier
- **Services**: SQL databases, data stores
- **NSG Rules**:
  - Allow SQL (1433) from workload subnet only
  - Deny all other inbound traffic

### Development Spoke (10.2.0.0/16)

#### Workload Subnet (10.2.1.0/24)
- **Purpose**: Development application tier
- **Services**: Dev web servers, testing environments
- **NSG Rules**:
  - Allow HTTP/HTTPS from private networks
  - Allow SSH from hub network
  - Allow required application ports

#### Data Subnet (10.2.2.0/24)
- **Purpose**: Development database tier
- **Services**: Dev databases, test data stores
- **NSG Rules**:
  - Allow SQL (1433) from dev workload subnet only
  - Deny all other inbound traffic

## VNet Peering

### Configuration
- **Type**: Azure VNet Peering (Microsoft backbone network)
- **Latency**: Low (same as intra-VNet)
- **Bandwidth**: No limits
- **Cost**: Pay per GB transferred

### Hub-to-Spoke Peering Settings
- `allow_virtual_network_access`: true
- `allow_forwarded_traffic`: true
- `allow_gateway_transit`: true (allows spokes to use hub gateway)

### Spoke-to-Hub Peering Settings
- `allow_virtual_network_access`: true
- `allow_forwarded_traffic`: true
- `use_remote_gateways`: false (set to true after gateway is ready)

**Note**: Spoke-to-spoke traffic is not directly allowed. All spoke-to-spoke communication must go through the Azure Firewall in the hub.

## Azure Firewall

### Purpose
Central security appliance for:
- Network traffic filtering
- Application traffic filtering
- Threat intelligence
- Logging and monitoring

### IP Configuration
- **Public IP**: For internet-bound traffic
- **Private IP**: For spoke-to-spoke traffic (dynamically assigned)

### Rule Collections

#### Network Rules (Priority 100)
1. **Allow Spoke-to-Spoke**: Permits communication between spoke networks
2. **Allow DNS**: Permits DNS queries from all private networks

#### Application Rules (Priority 100)
1. **Allow Azure Services**: *.microsoft.com, *.windows.net, *.azure.com
2. **Allow Updates**: Ubuntu and other OS update repositories

### Logging
All allowed and denied traffic is logged to Log Analytics workspace for:
- Security auditing
- Compliance reporting
- Troubleshooting
- Traffic analysis

## User-Defined Routes (UDRs)

Routes are configured to force traffic through the Azure Firewall:

### Spoke Route Table
Applied to all spoke subnets:
1. **Default Route (0.0.0.0/0)**: Next hop = Azure Firewall
2. **Spoke Production (10.1.0.0/16)**: Next hop = Azure Firewall
3. **Spoke Development (10.2.0.0/16)**: Next hop = Azure Firewall

This ensures all traffic is inspected by the firewall.

## Network Security Groups (NSGs)

### Defense in Depth Strategy
NSGs provide Layer 4 (transport layer) security in addition to the Azure Firewall's Layer 3-7 filtering.

### NSG Rules Structure
1. **Allow Rules**: Specific permitted traffic (priority 100-4000)
2. **Deny All Rule**: Explicit deny at priority 4096

### Production Environment NSGs
- Stricter rules
- Only essential ports allowed
- No SSH access from external networks

### Development Environment NSGs
- More permissive for development needs
- SSH allowed from hub network
- Additional debugging ports available

## Monitoring and Logging

### Log Analytics Workspace
Central repository for all logs:
- Azure Firewall logs
- NSG flow logs
- Diagnostic logs
- Metrics

### Diagnostic Settings
Enabled for:
- Azure Firewall (application and network rules)
- Network Security Groups (events and rule counters)

### Key Metrics
- Firewall throughput
- Firewall health
- NSG rule hits
- Traffic patterns

## Security Considerations

### 1. Zero Trust Network Access
- No public IPs on workload VMs
- All access through Azure Bastion
- All traffic inspected by firewall

### 2. Network Segmentation
- Separate VNets for different environments
- Separate subnets for different tiers
- NSGs at subnet boundaries

### 3. Centralized Security
- Single point for security policies (firewall)
- Centralized logging
- Consistent rule enforcement

### 4. Defense in Depth
- Multiple security layers:
  - Azure Firewall (L3-L7)
  - NSGs (L4)
  - Application security (L7)

### 5. Monitoring and Alerting
- All security events logged
- Queryable with KQL (Kusto Query Language)
- Can integrate with Azure Sentinel for SIEM

## Scalability

### Adding New Spokes
To add a new spoke network:
1. Create new VNet with appropriate address space
2. Create VNet peering to hub
3. Configure route table to use firewall
4. Apply appropriate NSGs
5. Update firewall rules if needed

### Scaling Existing Resources
- **Azure Firewall**: Can scale to handle up to 30 Gbps
- **VPN Gateway**: Can upgrade SKU for more throughput
- **VNet Peering**: No bandwidth limits

## High Availability

### Current Implementation
- Azure Firewall: Single instance (99.95% SLA)
- VPN Gateway: Single instance (99.95% SLA)
- Azure Bastion: Single instance (99.95% SLA)

### Production Recommendations
1. **Active-Active VPN Gateway**: For higher availability
2. **Firewall Availability Zones**: Deploy across multiple zones
3. **Multiple Bastion Hosts**: For redundancy
4. **Azure DDoS Protection**: For DDoS mitigation

## Cost Optimization

### Current Cost Drivers
1. Azure Firewall: ~$1.25/hour + $0.016/GB processed
2. Azure Bastion: ~$0.19/hour
3. VPN Gateway: ~$0.19/hour (VpnGw1)
4. VNet Peering: ~$0.01/GB transferred

### Optimization Tips
1. Use appropriate SKUs for your needs
2. Monitor data transfer costs
3. Deallocate non-production resources when not in use
4. Use Azure Firewall Policy inheritance for multiple firewalls
5. Consider Azure Firewall Basic for dev/test (when available)

## Compliance and Governance

### Built-in Compliance Features
- All traffic logged for audit trail
- Centralized policy enforcement
- Network segmentation for data isolation
- Secure remote access (no exposed RDP/SSH)

### Azure Policy Integration
Can enforce:
- Required tags
- Allowed regions
- Required diagnostic settings
- NSG rules requirements

## Future Enhancements

1. **Azure Application Gateway**: For application layer load balancing
2. **Azure Front Door**: For global load balancing and CDN
3. **Private Endpoints**: For Azure PaaS services
4. **ExpressRoute**: For dedicated private connectivity
5. **Azure Sentinel**: For advanced SIEM capabilities
6. **Network Watcher**: For network monitoring and diagnostics
