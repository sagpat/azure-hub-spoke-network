# Azure Hub-Spoke Network Topology

A production-ready implementation of Azure hub-spoke network topology with centralized security controls, private connectivity, and secure remote access.

## 🏗️ Architecture Overview

This project implements a hub-spoke network topology in Azure with the following components:

### Hub Virtual Network (10.0.0.0/16)
The hub VNet acts as the central point of connectivity and contains:

- **Azure Firewall** (10.0.1.0/26) - Centralized network security appliance for filtering and logging traffic
- **Azure Bastion** (10.0.2.0/26) - Secure RDP/SSH connectivity without exposing VMs to the internet
- **VPN Gateway** (10.0.3.0/26) - Hybrid connectivity to on-premises networks
- **Management Subnet** (10.0.4.0/24) - For jump boxes and management tools

### Spoke Virtual Networks
Two spoke networks connected to the hub via VNet peering:

1. **Production Spoke** (10.1.0.0/16)
   - Workload Subnet (10.1.1.0/24) - Application tier
   - Data Subnet (10.1.2.0/24) - Database tier

2. **Development Spoke** (10.2.0.0/16)
   - Workload Subnet (10.2.1.0/24) - Application tier
   - Data Subnet (10.2.2.0/24) - Database tier

## 🔒 Security Features

### 1. Centralized Traffic Control
- All spoke-to-spoke and internet-bound traffic routes through Azure Firewall
- User-defined routes (UDRs) force traffic inspection
- Network and application rules control allowed traffic

### 2. Network Security Groups (NSGs)
- Layer 4 security at subnet level
- Separate NSGs for workload and data subnets
- Default deny-all rules with explicit allow rules
- NSG flow logs enabled for monitoring

### 3. Secure Remote Access
- Azure Bastion for secure VM access without public IPs
- No RDP/SSH ports exposed to the internet
- All management traffic goes through Bastion

### 4. Private Connectivity
- VNet peering for low-latency spoke-to-hub communication
- VPN Gateway for hybrid connectivity to on-premises
- No public endpoints on spoke resources

### 5. Monitoring and Logging
- Log Analytics workspace for centralized logging
- Azure Firewall diagnostics enabled
- NSG flow logs for traffic analysis
- All security events logged and queryable

## 🌐 Traffic Flow Patterns

### Internet-bound Traffic
```
Spoke VM → Route Table → Azure Firewall → Internet
```

### Spoke-to-Spoke Communication
```
Spoke 1 VM → Route Table → Azure Firewall → Route Table → Spoke 2 VM
```

### Management Access
```
Administrator → Azure Bastion → Spoke VM (via private IP)
```

### Hybrid Connectivity
```
On-premises → VPN Gateway → Hub VNet → Azure Firewall → Spoke VNets
```

## 📋 Prerequisites

- Azure subscription with appropriate permissions
- Terraform >= 1.0
- Azure CLI (for authentication)

## 🚀 Deployment Instructions

### 1. Clone the Repository
```bash
git clone https://github.com/sagpat/azure-hub-spoke-network.git
cd azure-hub-spoke-network
```

### 2. Authenticate to Azure
```bash
az login
az account set --subscription "<subscription-id>"
```

### 3. Initialize Terraform
```bash
terraform init
```

### 4. Review and Customize Variables
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your desired values
```

### 5. Plan Deployment
```bash
terraform plan -out=tfplan
```

### 6. Deploy Infrastructure
```bash
terraform apply tfplan
```

**Note:** The deployment takes approximately 30-45 minutes due to VPN Gateway and Azure Firewall provisioning times.

### 7. Verify Deployment
```bash
terraform output
```

## 🔧 Configuration Options

### Variables
Edit `terraform.tfvars` to customize:

| Variable | Description | Default |
|----------|-------------|---------|
| `location` | Azure region | eastus |
| `environment` | Environment name | prod |
| `hub_vnet_address_space` | Hub VNet CIDR | 10.0.0.0/16 |
| `spoke_prod_vnet_address_space` | Production spoke CIDR | 10.1.0.0/16 |
| `spoke_dev_vnet_address_space` | Development spoke CIDR | 10.2.0.0/16 |
| `admin_username` | VM admin username | azureadmin |
| `tags` | Resource tags | See variables.tf |

### Azure Firewall Rules
The firewall is configured with:

**Network Rules:**
- Allow spoke-to-spoke communication
- Allow DNS queries
- Block all other network traffic by default

**Application Rules:**
- Allow Azure services (*.microsoft.com, *.azure.com)
- Allow OS updates (Ubuntu repositories)
- Block all other application traffic by default

To modify rules, edit the `azurerm_firewall_network_rule_collection` and `azurerm_firewall_application_rule_collection` resources in `main.tf`.

### VPN Gateway Remote Access (Optional)

By default, spoke networks have `use_remote_gateways = false` in their VNet peering configuration. To allow spoke VMs to use the hub's VPN gateway for on-premises connectivity:

1. Ensure the VPN Gateway is fully provisioned (check Azure Portal)
2. Edit `main.tf` and set `use_remote_gateways = true` in the spoke-to-hub peering resources
3. Apply the change:
   ```bash
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

**Note:** `use_remote_gateways` cannot be enabled until the VPN gateway is ready, and cannot be used simultaneously with `allow_gateway_transit` in the same peering direction.

## 📊 Monitoring

### View Firewall Logs
```bash
# Query firewall application rule logs
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "AzureDiagnostics | where Category == 'AzureFirewallApplicationRule' | take 100"

# Query firewall network rule logs
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "AzureDiagnostics | where Category == 'AzureFirewallNetworkRule' | take 100"
```

### NSG Flow Logs
NSG flow logs are enabled and sent to Log Analytics workspace for analysis.

## 🧹 Cleanup

To remove all deployed resources:

```bash
terraform destroy
```

**Warning:** This will delete all resources including the VPN Gateway, Azure Firewall, and all VNets.

## 📁 Project Structure

```
.
├── main.tf                    # Main infrastructure resources
├── variables.tf               # Variable definitions
├── outputs.tf                 # Output values
├── providers.tf               # Provider configuration
├── backend.tf                 # Backend configuration (commented)
├── terraform.tfvars.example   # Example variables file
├── README.md                  # This file
└── docs/
    ├── architecture.md        # Detailed architecture documentation
    └── traffic-flows.md       # Traffic flow diagrams and explanations
```

## 🔐 Security Best Practices Implemented

1. **Defense in Depth**: Multiple layers of security (Firewall, NSGs, private endpoints)
2. **Least Privilege**: Default deny with explicit allow rules
3. **Segmentation**: Separate VNets for different environments
4. **Centralized Control**: All traffic inspected by Azure Firewall
5. **Zero Trust**: No direct internet access for VMs, Bastion for management
6. **Monitoring**: Comprehensive logging for audit and compliance
7. **Private Connectivity**: VNet peering and VPN Gateway, no public IPs on workloads

## 📚 Additional Resources

- [Azure Hub-Spoke Network Topology](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- [Azure Firewall Documentation](https://docs.microsoft.com/en-us/azure/firewall/)
- [Azure Bastion Documentation](https://docs.microsoft.com/en-us/azure/bastion/)
- [Azure VPN Gateway Documentation](https://docs.microsoft.com/en-us/azure/vpn-gateway/)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## ⚠️ Cost Considerations

This infrastructure includes several premium Azure services:
- Azure Firewall: ~$1.25/hour + data processing
- Azure Bastion: ~$0.19/hour
- VPN Gateway (VpnGw1): ~$0.19/hour

Estimated monthly cost: **$500-800** depending on data transfer and region.

For development/testing, consider:
- Using lower SKUs where available
- Deallocating resources when not in use
- Using Azure Cost Management for monitoring