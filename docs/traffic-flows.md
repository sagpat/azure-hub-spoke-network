# Traffic Flow Documentation

This document explains how traffic flows through the hub-spoke network topology in various scenarios.

## Traffic Flow Scenarios

### 1. Internet-Bound Traffic from Spoke

When a VM in a spoke network needs to access the internet:

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. VM in Spoke initiates connection to Internet                 │
│    Source: 10.1.1.5 (Spoke Prod VM)                            │
│    Destination: 8.8.8.8 (Internet)                             │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 2. Route Table lookup                                           │
│    Matches: 0.0.0.0/0 → Next Hop: Azure Firewall (10.0.1.4)   │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 3. NSG Check (Spoke Workload Subnet)                           │
│    Outbound rule: Allow                                         │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 4. Traffic routed to Azure Firewall (via VNet Peering)         │
│    Source: 10.1.1.5                                            │
│    Destination: 8.8.8.8                                         │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 5. Azure Firewall processes traffic                            │
│    - Checks network rules                                       │
│    - Checks application rules                                   │
│    - Performs SNAT to Firewall Public IP                       │
│    - Logs the connection                                        │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 6. Traffic forwarded to Internet                               │
│    Source: 20.x.x.x (Firewall Public IP)                       │
│    Destination: 8.8.8.8                                         │
└─────────────────────────────────────────────────────────────────┘
```

**Key Points:**
- All internet traffic is SNAT'd to the Firewall's public IP
- The original source IP (10.1.1.5) is hidden from the internet
- Firewall logs show the original source and destination
- Return traffic follows the reverse path

### 2. Spoke-to-Spoke Communication

When a VM in one spoke needs to communicate with a VM in another spoke:

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. VM in Prod Spoke initiates connection to Dev Spoke          │
│    Source: 10.1.1.5 (Prod VM)                                  │
│    Destination: 10.2.1.10 (Dev VM)                             │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 2. Route Table lookup (Prod Spoke)                             │
│    Matches: 10.2.0.0/16 → Next Hop: Azure Firewall (10.0.1.4) │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 3. NSG Check (Prod Workload Subnet)                            │
│    Outbound rule: Allow                                         │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 4. Traffic sent to Hub via VNet Peering                        │
│    Source: 10.1.1.5                                            │
│    Destination: 10.2.1.10                                       │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 5. Azure Firewall processes traffic                            │
│    - Checks network rules (Allow spoke-to-spoke)               │
│    - Logs the connection                                        │
│    - Does NOT perform SNAT (private-to-private)                │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 6. Traffic sent to Dev Spoke via VNet Peering                  │
│    Source: 10.1.1.5 (preserved)                                │
│    Destination: 10.2.1.10                                       │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 7. Route Table lookup (Dev Spoke)                              │
│    Matches: 10.1.0.0/16 → Next Hop: Azure Firewall            │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 8. NSG Check (Dev Workload Subnet)                             │
│    Inbound rule: Check if allowed from 10.1.0.0/16            │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 9. Traffic delivered to Dev VM                                 │
│    Destination VM: 10.2.1.10                                    │
└─────────────────────────────────────────────────────────────────┘
```

**Key Points:**
- Traffic goes through the firewall for inspection
- Original source IP is preserved (no SNAT for private traffic)
- Both outbound and inbound NSGs are checked
- Firewall rules control which spokes can communicate
- Return traffic follows the reverse path

### 3. Remote Access via Azure Bastion

When an administrator needs to access a VM:

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Administrator accesses Azure Portal                          │
│    Opens Bastion connection to VM                               │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 2. HTTPS connection to Azure Bastion Public IP                 │
│    Protocol: TLS 1.2+                                          │
│    Port: 443                                                    │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 3. Azure Bastion authenticates user via Azure AD               │
│    Checks: RBAC permissions, MFA                                │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 4. Bastion connects to target VM via VNet Peering              │
│    Source: Bastion Subnet (10.0.2.x)                           │
│    Destination: VM private IP (10.1.1.5)                        │
│    Protocol: RDP (3389) or SSH (22)                            │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 5. NSG Check (Spoke Workload Subnet)                           │
│    Inbound rule: Implicitly allows from Bastion                │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 6. RDP/SSH session established                                  │
│    Administrator can now manage the VM                          │
│    All traffic encrypted end-to-end                             │
└─────────────────────────────────────────────────────────────────┘
```

**Key Points:**
- No public IP required on target VM
- No RDP/SSH ports exposed to internet
- Authentication via Azure AD
- Session encrypted with TLS
- Audit trail in Azure Activity Log

### 4. On-Premises to Azure (via VPN Gateway)

When resources in on-premises network need to access Azure:

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. On-premises resource initiates connection                    │
│    Source: 192.168.1.10 (On-prem server)                       │
│    Destination: 10.1.1.5 (Azure VM)                            │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 2. Traffic encrypted by on-premises VPN device                 │
│    Protocol: IPSec                                             │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 3. Traffic sent over Internet to Azure VPN Gateway             │
│    Destination: VPN Gateway Public IP (20.x.x.x)               │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 4. VPN Gateway decrypts traffic                                 │
│    Source: 192.168.1.10                                        │
│    Destination: 10.1.1.5                                        │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 5. BGP/Static routing determines next hop                      │
│    May route through Azure Firewall (if configured)            │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 6. Traffic sent to spoke via VNet Peering                      │
│    Source: 192.168.1.10                                        │
│    Destination: 10.1.1.5                                        │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 7. NSG Check (Spoke Workload Subnet)                           │
│    Inbound rule: Check if on-prem network is allowed          │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 8. Traffic delivered to Azure VM                               │
│    Destination: 10.1.1.5                                        │
└─────────────────────────────────────────────────────────────────┘
```

**Key Points:**
- Traffic encrypted over internet
- VPN Gateway performs decryption
- Can route through firewall for inspection
- NSGs control access to spoke resources
- BGP can be used for dynamic routing

### 5. Hub Management Access

When administrators access management resources in the hub:

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Administrator connects via Azure Bastion                     │
│    Target: Management VM in Hub (10.0.4.5)                     │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 2. Direct connection within Hub VNet                           │
│    Source: Bastion Subnet (10.0.2.x)                           │
│    Destination: Management Subnet (10.0.4.5)                    │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────────────────────────────┐
│ 3. Access granted to management VM                             │
│    No firewall traversal needed (same VNet)                    │
└─────────────────────────────────────────────────────────────────┘
```

**Key Points:**
- Intra-VNet traffic is more direct
- No firewall hop for hub-to-hub traffic
- Still protected by NSGs

## Traffic Flow Analysis

### Network Security Layers

Traffic must pass through multiple security layers:

1. **Source NSG (Outbound)**: First layer of filtering
2. **Azure Firewall**: Central inspection point
3. **Destination NSG (Inbound)**: Final layer of filtering

### Asymmetric Routing Prevention

The architecture prevents asymmetric routing by:
- Using UDRs to force traffic through the firewall
- Applying routes to all spoke subnets consistently
- Ensuring return traffic follows the same path

### Traffic Inspection Points

| Traffic Type | Firewall Inspection | NSG Inspection | Logged |
|-------------|---------------------|----------------|--------|
| Spoke → Internet | Yes | Yes | Yes |
| Spoke → Spoke | Yes | Yes | Yes |
| Hub → Spoke | Optional | Yes | Optional |
| On-prem → Azure | Optional | Yes | Optional |
| Bastion → VM | No | Yes | Yes (activity log) |

## Performance Considerations

### Latency

| Path | Typical Latency |
|------|----------------|
| Spoke → Internet (via Firewall) | +1-2ms |
| Spoke → Spoke (via Firewall) | +1-2ms |
| Hub → Spoke (peering) | <1ms |
| On-prem → Azure (VPN) | Varies by distance |

### Throughput

| Component | Maximum Throughput |
|-----------|-------------------|
| Azure Firewall Standard | Up to 30 Gbps |
| VNet Peering | No limit |
| VPN Gateway (VpnGw1) | Up to 650 Mbps |
| Azure Bastion | Varies by SKU |

## Troubleshooting Traffic Issues

### 1. Check Route Tables
```bash
az network route-table show \
  --resource-group rg-prod-hubspoke \
  --name rt-prod-spoke
```

### 2. Check NSG Rules
```bash
az network nsg show \
  --resource-group rg-prod-hubspoke \
  --name nsg-prod-spoke-prod-workload
```

### 3. Check Firewall Logs
```kql
AzureDiagnostics
| where Category == "AzureFirewallNetworkRule"
| where msg_s contains "10.1.1.5"
| project TimeGenerated, msg_s
```

### 4. Check NSG Flow Logs
```kql
AzureDiagnostics
| where Category == "NetworkSecurityGroupFlowEvent"
| project TimeGenerated, FlowDirection_s, SourceIP_s, DestinationIP_s
```

### 5. Use Network Watcher
- Connection Monitor for connectivity testing
- Next Hop for route verification
- IP Flow Verify for NSG rule testing
- Packet Capture for deep inspection

## Security Monitoring

### Key Metrics to Monitor

1. **Firewall Metrics**:
   - Application rule hit count
   - Network rule hit count
   - Throughput
   - Health status

2. **NSG Metrics**:
   - Inbound/outbound flows
   - Denied flows
   - Rule hits

3. **Peering Metrics**:
   - Bytes transferred
   - Packets dropped

### Alert Recommendations

1. Alert on denied firewall connections
2. Alert on unusual traffic patterns
3. Alert on high firewall latency
4. Alert on VPN gateway disconnection
5. Alert on NSG rule changes

## Best Practices

1. **Log Everything**: Enable diagnostic settings on all network resources
2. **Use Consistent Naming**: Follow Azure naming conventions
3. **Document Changes**: Keep firewall rules documented
4. **Regular Audits**: Review NSG and firewall rules regularly
5. **Test Changes**: Use Network Watcher to test before deploying
6. **Monitor Performance**: Track latency and throughput metrics
7. **Plan for Scale**: Consider ExpressRoute for high-bandwidth needs
