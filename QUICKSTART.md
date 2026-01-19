# Quick Start Guide

This guide will help you deploy the Azure hub-spoke network topology in under 10 minutes (excluding Azure resource provisioning time).

## Prerequisites

Before you begin, ensure you have:

- An Azure subscription with Contributor or Owner access
- Azure CLI installed and configured
- Terraform >= 1.0 installed
- Bash shell (Linux, macOS, or WSL on Windows)

## Quick Deployment

### 1. Clone and Navigate
```bash
git clone https://github.com/sagpat/azure-hub-spoke-network.git
cd azure-hub-spoke-network
```

### 2. Login to Azure
```bash
az login
az account set --subscription "<your-subscription-id>"
```

### 3. Deploy
```bash
./deploy.sh
```

The script will:
- Validate prerequisites
- Initialize Terraform
- Create a deployment plan
- Ask for confirmation
- Deploy all resources

**Time:** ~30-45 minutes (VPN Gateway and Azure Firewall take time to provision)

### 4. Validate Deployment
```bash
./validate.sh
```

## What Gets Deployed?

### Hub Network (10.0.0.0/16)
- **Azure Firewall** - Centralized security appliance
- **Azure Bastion** - Secure VM access
- **VPN Gateway** - Hybrid connectivity
- **Management Subnet** - Jump boxes and tools

### Spoke Networks
- **Production (10.1.0.0/16)** - Production workloads
- **Development (10.2.0.0/16)** - Development/test workloads

### Security Features
- Network Security Groups (NSGs) on all subnets
- User-Defined Routes (UDRs) forcing traffic through firewall
- Azure Firewall with network and application rules
- Log Analytics for centralized monitoring

## Configuration

### Customize Variables (Optional)

1. Copy the example variables file:
```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Edit `terraform.tfvars` with your values:
```hcl
location     = "eastus"
environment  = "prod"

hub_vnet_address_space         = ["10.0.0.0/16"]
spoke_prod_vnet_address_space  = ["10.1.0.0/16"]
spoke_dev_vnet_address_space   = ["10.2.0.0/16"]

tags = {
  Project     = "HubSpokeNetwork"
  ManagedBy   = "Terraform"
  CostCenter  = "IT"
}
```

3. Deploy with custom configuration:
```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## Verify Deployment

### Check Resource Group
```bash
az group show --name rg-prod-hubspoke
```

### Check Virtual Networks
```bash
az network vnet list --resource-group rg-prod-hubspoke --output table
```

### Check Firewall
```bash
az network firewall show --resource-group rg-prod-hubspoke --name afw-prod-hub
```

### Check Bastion
```bash
az network bastion show --resource-group rg-prod-hubspoke --name bas-prod-hub
```

## Access Your VMs

1. Navigate to Azure Portal
2. Go to the VM you want to access
3. Click "Connect" → "Bastion"
4. Enter credentials
5. Connect securely without exposing RDP/SSH to internet

## Test Connectivity

### Deploy a Test VM (Optional)

Create a test VM in the production spoke:

```bash
az vm create \
  --resource-group rg-prod-hubspoke \
  --name vm-test-prod \
  --vnet-name vnet-prod-spoke-prod \
  --subnet WorkloadSubnet \
  --image UbuntuLTS \
  --admin-username azureadmin \
  --generate-ssh-keys \
  --public-ip-address "" \
  --nsg ""
```

### Test Internet Connectivity

1. Connect to the VM via Azure Bastion
2. Run: `curl ifconfig.me`
3. Verify the IP returned matches your Azure Firewall public IP

### Test Spoke-to-Spoke Connectivity

1. Deploy VMs in both production and development spokes
2. From one VM, ping the other
3. Check Azure Firewall logs to see the traffic being inspected

## View Logs

### Firewall Logs
```bash
# Get workspace ID
WORKSPACE_ID=$(terraform output -raw log_analytics_workspace_id)

# Query firewall logs
az monitor log-analytics query \
  --workspace $WORKSPACE_ID \
  --analytics-query "AzureDiagnostics | where Category == 'AzureFirewallNetworkRule' | take 100"
```

### NSG Flow Logs
NSG diagnostics are enabled and sent to Log Analytics. Query them using Azure Portal or Azure CLI.

## Common Operations

### Update Firewall Rules

1. Edit `main.tf` - find the firewall rule collections
2. Add/modify/remove rules
3. Apply changes:
```bash
terraform plan -out=tfplan
terraform apply tfplan
```

### Add a New Spoke

1. Add new spoke VNet resources in `main.tf`
2. Add peering resources
3. Add to route table
4. Apply changes:
```bash
terraform plan -out=tfplan
terraform apply tfplan
```

### Scale Resources

Most resources can be scaled by updating the SKU in `main.tf`:
- Azure Firewall: Change `sku_tier`
- VPN Gateway: Change `sku`
- Bastion: Change SKU in resource

## Cleanup

When you're done testing or want to remove all resources:

```bash
./cleanup.sh
```

**Warning:** This will destroy ALL resources. Make sure you have backups if needed.

## Costs

Approximate monthly costs (US East):
- Azure Firewall: ~$900/month
- Azure Bastion: ~$140/month  
- VPN Gateway (VpnGw1): ~$140/month
- VNet Peering: ~$30/month (varies by traffic)

**Total: ~$1,200-1,500/month**

### Cost Optimization Tips

1. **Development/Testing:**
   - Deallocate VPN Gateway when not needed
   - Use lower SKUs
   - Delete dev environments overnight

2. **Production:**
   - Use Azure Reservations for predictable costs
   - Monitor with Azure Cost Management
   - Right-size resources based on actual usage

3. **Alternative for Testing:**
   - Consider Azure Firewall Basic (when available)
   - Use Network Virtual Appliances (NVAs) for non-production

## Troubleshooting

### Terraform Errors

**Issue:** Provider authentication errors
```bash
# Re-authenticate
az login
az account set --subscription "<subscription-id>"
```

**Issue:** Resource already exists
```bash
# Import existing resource
terraform import azurerm_resource_group.hub_spoke /subscriptions/{sub-id}/resourceGroups/{rg-name}
```

### Connectivity Issues

**Issue:** Can't reach internet from spoke VM
1. Check route table is associated with subnet
2. Verify firewall rules allow traffic
3. Check NSG rules
4. Use Network Watcher to diagnose

**Issue:** Can't access VM via Bastion
1. Ensure Bastion is fully provisioned (can take 10-15 minutes)
2. Check NSG rules on target subnet
3. Verify VM is running

### Firewall Issues

**Issue:** Traffic not allowed through firewall
1. Check application rules (for FQDN-based filtering)
2. Check network rules (for IP-based filtering)
3. Review firewall logs
4. Ensure route tables are correct

## Next Steps

1. **Deploy Workloads**
   - Deploy your applications to spoke networks
   - Use private endpoints for Azure PaaS services

2. **Configure VPN**
   - Set up site-to-site VPN to on-premises
   - Configure BGP if needed

3. **Enhance Security**
   - Enable Azure DDoS Protection
   - Integrate with Azure Sentinel
   - Enable JIT access for VMs

4. **Optimize**
   - Review firewall logs for allowed/denied traffic
   - Adjust NSG rules based on actual needs
   - Monitor performance and costs

## Additional Resources

- [Full Architecture Documentation](docs/architecture.md)
- [Traffic Flow Details](docs/traffic-flows.md)
- [Azure Hub-Spoke Reference](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)

## Support

For issues or questions:
1. Check the [documentation](docs/)
2. Review [Azure documentation](https://docs.microsoft.com/azure/)
3. Open an issue on GitHub

## Security Note

This deployment includes:
- ✅ Centralized firewall for traffic inspection
- ✅ No public IPs on workload VMs
- ✅ Secure remote access via Bastion
- ✅ Network segmentation
- ✅ Comprehensive logging
- ✅ NSG rules for defense in depth

For production use, consider additional security measures like:
- Azure Sentinel for SIEM
- Azure Security Center
- Azure Policy for compliance
- Azure DDoS Protection
- Private endpoints for PaaS services
