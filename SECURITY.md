# Security Best Practices

This document outlines security best practices for deploying and maintaining the Azure hub-spoke network topology.

## Overview

This hub-spoke network implementation includes multiple layers of security controls to protect your Azure infrastructure. This document helps you understand and maximize these security features.

## Network Security

### 1. Network Segmentation

**Implemented:**
- Separate VNets for hub and spokes
- Separate subnets for workload and data tiers
- Isolated management subnet in hub

**Best Practices:**
```
✅ DO: Keep production and development in separate spokes
✅ DO: Use additional spokes for different applications
✅ DO: Implement micro-segmentation where needed
❌ DON'T: Mix production and development resources
❌ DON'T: Use same subnet for different security zones
```

### 2. Azure Firewall Configuration

**Implemented:**
- Network rules for spoke-to-spoke communication
- Application rules for internet access
- Centralized logging

**Best Practices:**
```hcl
# Follow principle of least privilege
✅ DO: Start with deny-all and add specific allow rules
✅ DO: Use FQDN filtering instead of IP addresses when possible
✅ DO: Group rules logically by application or purpose
✅ DO: Document each rule with description
❌ DON'T: Use wildcard (*) allow rules
❌ DON'T: Allow all traffic between spokes
```

**Review Firewall Rules Regularly:**
```bash
# Query firewall logs to see denied traffic
az monitor log-analytics query \
  --workspace $WORKSPACE_ID \
  --analytics-query "AzureDiagnostics | where Category == 'AzureFirewallNetworkRule' and msg_s contains 'Deny'"
```

### 3. Network Security Groups (NSGs)

**Implemented:**
- NSGs on all spoke subnets
- Default deny-all rules
- Specific allow rules for required traffic

**Best Practices:**
```
✅ DO: Use application security groups (ASGs) for complex scenarios
✅ DO: Apply NSGs at subnet level
✅ DO: Use service tags instead of IP addresses
✅ DO: Enable NSG flow logs
❌ DON'T: Allow 0.0.0.0/0 inbound on any port
❌ DON'T: Use wide port ranges (e.g., 1-65535)
```

**NSG Rule Example:**
```hcl
# Good - Specific and documented
security_rule {
  name                       = "AllowHttpsFromAppSubnet"
  priority                   = 100
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "443"
  source_address_prefix      = "10.1.1.0/24"  # App subnet
  destination_address_prefix = "10.1.2.0/24"  # Data subnet
}

# Bad - Too permissive
security_rule {
  name                       = "AllowAll"
  priority                   = 100
  access                     = "Allow"
  protocol                   = "*"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
}
```

### 4. Private Endpoints

**Recommendation:**
Use private endpoints for Azure PaaS services to keep traffic on the private network.

```hcl
# Example: Private endpoint for Azure SQL
resource "azurerm_private_endpoint" "sql" {
  name                = "pe-sql-database"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub_spoke.name
  subnet_id           = azurerm_subnet.spoke_prod_data.id

  private_service_connection {
    name                           = "sql-connection"
    private_connection_resource_id = azurerm_sql_server.example.id
    is_manual_connection           = false
    subresource_names              = ["sqlServer"]
  }
}
```

## Identity and Access Management

### 1. Azure RBAC

**Best Practices:**
```
✅ DO: Use Azure AD groups for access management
✅ DO: Follow principle of least privilege
✅ DO: Use built-in roles when possible
✅ DO: Regularly audit role assignments
❌ DON'T: Grant Owner role unless absolutely necessary
❌ DON'T: Use service principals for human access
```

**Key Roles:**
- **Network Contributor**: For network operations team
- **Reader**: For read-only access
- **Custom Roles**: For specific permissions

### 2. Azure Bastion Access

**Best Practices:**
```
✅ DO: Use Azure AD authentication
✅ DO: Enable MFA for all users
✅ DO: Use conditional access policies
✅ DO: Audit Bastion access logs
❌ DON'T: Share credentials
❌ DON'T: Use local accounts (prefer Azure AD)
```

### 3. Service Principals and Managed Identities

**Best Practices:**
```
✅ DO: Use managed identities for Azure resources
✅ DO: Rotate service principal credentials regularly
✅ DO: Limit service principal scope
❌ DON'T: Store credentials in code
❌ DON'T: Share service principal credentials
```

## Monitoring and Logging

### 1. Azure Monitor

**Implemented:**
- Log Analytics workspace
- Diagnostic settings on firewall
- NSG flow logs

**Best Practices:**
```
✅ DO: Enable diagnostic settings on all resources
✅ DO: Set appropriate log retention (30-90 days)
✅ DO: Create alerts for security events
✅ DO: Review logs regularly
```

**Key Metrics to Monitor:**
```kql
// Denied firewall connections
AzureDiagnostics
| where Category == "AzureFirewallNetworkRule"
| where msg_s contains "Deny"
| summarize count() by bin(TimeGenerated, 1h), msg_s

// Suspicious authentication attempts
AzureActivity
| where OperationNameValue contains "microsoft.compute/virtualmachines/login/action"
| where ActivityStatusValue != "Success"
| summarize count() by CallerIpAddress, bin(TimeGenerated, 1h)

// NSG rule changes
AzureActivity
| where OperationNameValue contains "microsoft.network/networksecuritygroups"
| where ActivityStatusValue == "Success"
| project TimeGenerated, Caller, OperationNameValue, ResourceId
```

### 2. Azure Sentinel (Recommended)

For production environments, consider Azure Sentinel for:
- Advanced threat detection
- Security orchestration and automation
- Incident response

### 3. Alerting

**Create Alerts For:**
1. Firewall health status changes
2. High number of denied connections
3. NSG rule modifications
4. VPN gateway disconnections
5. Unusual traffic patterns

## Data Protection

### 1. Encryption in Transit

**Implemented:**
- TLS for Azure Bastion connections
- IPSec for VPN connections
- HTTPS enforcement in firewall rules

**Best Practices:**
```
✅ DO: Use TLS 1.2 or higher
✅ DO: Enforce HTTPS for web applications
✅ DO: Use VPN for on-premises connectivity
❌ DON'T: Allow unencrypted protocols (HTTP, FTP, Telnet)
```

### 2. Encryption at Rest

**Best Practices:**
```
✅ DO: Enable encryption on VM disks
✅ DO: Use Azure Key Vault for secrets
✅ DO: Enable encryption on storage accounts
✅ DO: Use customer-managed keys (CMK) for sensitive data
```

## Compliance and Governance

### 1. Azure Policy

**Recommended Policies:**
```hcl
# Require NSGs on subnets
# Require diagnostic settings
# Require tags on resources
# Restrict allowed locations
# Require TLS version
```

### 2. Resource Tagging

**Best Practices:**
```hcl
tags = {
  Environment  = "Production"
  CostCenter   = "IT-Security"
  Owner        = "network-team@company.com"
  Compliance   = "PCI-DSS"
  DataClass    = "Confidential"
}
```

### 3. Change Management

**Best Practices:**
```
✅ DO: Use Infrastructure as Code (Terraform)
✅ DO: Version control all changes
✅ DO: Peer review all changes
✅ DO: Test in non-production first
✅ DO: Document all changes
```

## Incident Response

### 1. Preparation

**Runbooks to Create:**
1. Security incident response
2. Network outage response
3. Firewall rule emergency change
4. VPN connection troubleshooting

### 2. Detection

**Monitor For:**
- Failed authentication attempts
- Unusual network traffic
- Configuration changes
- Resource deletions
- Privilege escalations

### 3. Response

**Immediate Actions:**
1. Isolate affected resources
2. Review firewall and NSG logs
3. Check Azure Activity Log
4. Preserve evidence for forensics
5. Notify stakeholders

## Regular Security Tasks

### Daily
- [ ] Review security alerts
- [ ] Monitor Azure Security Center recommendations

### Weekly
- [ ] Review firewall deny logs
- [ ] Check for unusual traffic patterns
- [ ] Review Azure Advisor recommendations

### Monthly
- [ ] Audit RBAC assignments
- [ ] Review and update firewall rules
- [ ] Test disaster recovery procedures
- [ ] Review security policies

### Quarterly
- [ ] Security assessment
- [ ] Penetration testing (if required)
- [ ] Update documentation
- [ ] Review and update runbooks
- [ ] Compliance audit

## Hardening Checklist

### Network Layer
- [x] Azure Firewall deployed and configured
- [x] NSGs applied to all subnets
- [x] No public IPs on workload VMs
- [ ] Private endpoints for PaaS services
- [ ] DDoS Protection Standard (optional, for production)

### Access Control
- [x] Azure Bastion for remote access
- [ ] Azure AD authentication enabled
- [ ] MFA enforced for all users
- [ ] Conditional access policies configured
- [ ] JIT access for VMs (optional)

### Monitoring
- [x] Log Analytics workspace configured
- [x] Diagnostic settings enabled
- [x] NSG flow logs enabled
- [ ] Azure Sentinel deployed (recommended)
- [ ] Security alerts configured

### Governance
- [ ] Azure Policy assigned
- [ ] Resource tags applied
- [ ] Change management process
- [ ] Security runbooks documented

## Security Contacts

Maintain a list of security contacts:
- Security team email
- Incident response team
- Azure support contact
- Management escalation contact

## Additional Resources

- [Azure Security Best Practices](https://docs.microsoft.com/en-us/azure/security/fundamentals/best-practices-and-patterns)
- [Azure Network Security](https://docs.microsoft.com/en-us/azure/security/fundamentals/network-best-practices)
- [Azure Firewall Best Practices](https://docs.microsoft.com/en-us/azure/firewall/firewall-best-practices)
- [CIS Azure Foundations Benchmark](https://www.cisecurity.org/benchmark/azure)

## Report Security Issues

If you discover a security vulnerability:
1. Do NOT create a public issue
2. Email: [security contact]
3. Include detailed description and steps to reproduce

---

**Remember:** Security is a continuous process, not a one-time configuration. Regular review and updates are essential.
