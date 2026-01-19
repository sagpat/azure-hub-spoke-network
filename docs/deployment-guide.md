# Deployment Guide - Enterprise Hub-Spoke Network

This guide walks through deploying the Hub-Spoke network infrastructure step by step.

## Prerequisites

### Required Tools
```bash
# Check Azure CLI
az --version  # Should be 2.50.0 or higher

# Check Terraform
terraform --version  # Should be 1.5.0 or higher

# Check Git
git --version
```

### Azure Account Setup
```bash
# Login to Azure
az login

# List subscriptions
az account list --output table

# Set the subscription you want to use
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify current subscription
az account show --output table
```

### Register Required Providers
```bash
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.OperationsManagement
az provider register --namespace Microsoft.Storage
```

---

## Step-by-Step Deployment

### 1. Project Setup and Hub Network

#### Step 1.1: Initialize the Project
```bash
cd week1-hub-spoke-network/terraform

# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit variables with your preferences
# Especially update: location, tags, enable_firewall (false to save costs initially)
```

#### Step 1.2: Initialize Terraform
```bash
terraform init
```

Expected output:
```
Terraform has been successfully initialized!
```

#### Step 1.3: Validate Configuration
```bash
terraform validate
```

#### Step 1.4: Plan the Deployment
```bash
# For development (lower cost)
terraform plan -var-file=environments/dev.tfvars -out=tfplan

# Or use default variables
terraform plan -out=tfplan
```

Review the plan carefully. You should see resources for:
- Resource Groups (hub, spokes, monitoring)
- Hub VNet with subnets
- Spoke VNets with subnets
- VNet Peerings
- Azure Firewall (if enabled)
- Azure Bastion (if enabled)
- Route Tables
- NSGs
- Private DNS Zones
- Log Analytics Workspace

#### Step 1.5: Apply the Configuration
```bash
terraform apply tfplan
```

⏱️ **Expected Time:** 15-30 minutes (Azure Firewall takes ~10 minutes to deploy)

---

### 2: Verify Firewall Deployment

#### Step 2.1: Verify Firewall is Running
```bash
# Get firewall details from Terraform output
terraform output firewall

# Or check via Azure CLI
az network firewall list --output table
```

#### Step 2.2: Review Firewall Rules
```bash
# List firewall policies
az network firewall policy list --output table

# View specific policy rules
az network firewall policy rule-collection-group list \
  --policy-name "fwpol-hubspoke-dev-XXXX" \
  --resource-group "rg-hubspoke-dev-hub-XXXX" \
  --output table
```

#### Step 2.3: Test Firewall Logs
```bash
# Query firewall logs (after some traffic)
az monitor log-analytics query \
  --workspace "log-hubspoke-dev-XXXX" \
  --analytics-query "AzureDiagnostics | where Category == 'AzureFirewallNetworkRule' | take 10"
```

---

### 3: Verify Spoke Networks and Peering

#### Step 3.1: Verify VNet Peerings
```bash
# List all VNet peerings for Hub
az network vnet peering list \
  --resource-group "rg-hubspoke-dev-hub-XXXX" \
  --vnet-name "vnet-hubspoke-dev-hub-XXXX" \
  --output table
```

#### Step 3.2: Check Peering Status
All peerings should show:
- `peeringState`: Connected
- `peeringSyncLevel`: FullyInSync

---

### 4: Verify Route Tables

#### Step 4.1: List Route Tables
```bash
az network route-table list --output table
```

#### Step 4.2: Verify Routes
```bash
az network route-table route list \
  --resource-group "rg-hubspoke-dev-spoke-web-XXXX" \
  --route-table-name "rt-hubspoke-dev-spoke-web-XXXX" \
  --output table
```

You should see:
- `route-to-firewall`: 0.0.0.0/0 → Firewall IP
- `route-to-spokes`: 10.0.0.0/8 → Firewall IP

---

### 5: Verify Bastion and NSGs

#### Step 5.1: Verify Bastion
```bash
az network bastion list --output table
```

#### Step 5.2: Test Bastion Connection
```bash
# First, deploy test VMs (see  7) or get VM ID
terraform output test_vms

# Connect to web spoke VM via Bastion
az network bastion ssh \
  --name "bas-hubspoke-dev-XXXX" \
  --resource-group "rg-hubspoke-dev-hub-XXXX" \
  --target-resource-id "$(terraform output -json test_vms | jq -r '.web.vm_id')" \
  --auth-type "ssh-key" \
  --username "azureuser" \
  --ssh-key "~/.ssh/id_rsa"
```

#### Step 5.3: Review NSGs
```bash
az network nsg list --output table

# View specific NSG rules
az network nsg rule list \
  --resource-group "rg-hubspoke-dev-spoke-web-XXXX" \
  --nsg-name "nsg-hubspoke-dev-web-WebSubnet-XXXX" \
  --output table
```

---

### 6: Private DNS Zones

#### Step 6.1: Verify DNS Zones
```bash
az network private-dns zone list --output table
```

#### Step 6.2: Verify VNet Links
```bash
az network private-dns link vnet list \
  --resource-group "rg-hubspoke-dev-hub-XXXX" \
  --zone-name "privatelink.database.windows.net" \
  --output table
```

---

### 7: Deploy Test VMs (Optional)

Deploy test VMs in each spoke network to validate connectivity.

#### Step 7.1: Get Your SSH Public Key
```bash
# View your existing SSH public key
cat ~/.ssh/id_rsa.pub

# If you don't have one, generate it
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

#### Step 7.2: Enable VM Deployment
Edit `terraform.tfvars`:
```hcl
# Test VMs
deploy_test_vms      = true
admin_username       = "azureuser"
admin_ssh_public_key = "ssh-rsa AAAA... your-public-key-here"
```

#### Step 7.3: Deploy the VMs
```bash
# Plan and apply
terraform plan -out=tfplan
terraform apply tfplan
```

⏱️ **Expected Time:** 3-5 minutes

#### Step 7.4: Get VM Details
```bash
# List all test VMs
terraform output test_vms

# Get specific VM info
az vm list --query "[?contains(name, 'hubspoke')]" --output table
```

#### Step 7.5: Connect to VMs via Bastion
```bash
# Get VM resource ID
VM_ID=$(az vm show --name "vm-hubspoke-dev-web-XXXX" \
  --resource-group "rg-hubspoke-dev-spoke-web-XXXX" \
  --query id -o tsv)

# Connect via Bastion
az network bastion ssh \
  --name "bas-hubspoke-dev-XXXX" \
  --resource-group "rg-hubspoke-dev-hub-XXXX" \
  --target-resource-id "$VM_ID" \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa
```

---

### 8: Connectivity Testing

Use the test VMs to validate the hub-spoke network.

#### Step 8.1: Test Spoke-to-Spoke Connectivity
From the web spoke VM, ping the data spoke VM:
```bash
# Get IP of data spoke VM (from terraform output)
ping 10.2.1.4  # Data spoke VM private IP

# Trace the route (should go through firewall)
traceroute 10.2.1.4
```

#### Step 8.2: Test Internet Access via Firewall
```bash
# Check external IP (should be Firewall's public IP)
curl https://ifconfig.me

# Validate the IP using firewall's public IP
az network public-ip show \  --name pip-hubspoke-dev-fw-XXX \  --resource-group rg-hubspoke-dev-hub-XXX \  --query ipAddress -o tsv              

# Test allowed URLs
curl -I https://www.microsoft.com
curl -I https://ubuntu.com
```

#### Step 8.3: Test DNS Resolution
```bash
# Test private DNS resolution
nslookup privatelink.blob.core.windows.net
nslookup privatelink.database.windows.net
```

#### Step 8.4: Test Blocked Traffic
```bash
# This should be blocked by firewall (if not in allowed rules)
curl -I https://some-random-site.com
```

---

### 9: Monitoring and Documentation

#### Step 9.1: Access Log Analytics
```bash
# Get workspace ID
terraform output log_analytics

# Open in Azure Portal
echo "https://portal.azure.com/#@/resource/$(terraform output -raw log_analytics.id)/logs"
```

#### Step 7.2: Useful Kusto Queries

**Network Traffic Analysis:**
```kusto
AzureDiagnostics
| where Category == "AzureFirewallNetworkRule"
| project TimeGenerated, msg_s
| order by TimeGenerated desc
| take 100
```

**Blocked Traffic:**
```kusto
AzureDiagnostics
| where Category == "AzureFirewallNetworkRule"
| where msg_s contains "Deny"
| project TimeGenerated, msg_s
| order by TimeGenerated desc
```

**Application Rules:**
```kusto
AzureDiagnostics
| where Category == "AzureFirewallApplicationRule"
| project TimeGenerated, msg_s
| order by TimeGenerated desc
| take 100
```

---

## Cost Management

### Check Current Costs
```bash
# List all resources and their costs (requires Cost Management access)
az consumption usage list \
  --start-date "2026-01-01" \
  --end-date "2026-01-31" \
  --output table
```

### Deallocate Resources When Not In Use
```bash
# Stop Azure Firewall (saves ~$30/)
az network firewall update \
  --name "fw-hubspoke-dev-XXXX" \
  --resource-group "rg-hubspoke-dev-hub-XXXX" \
  --sku AZFW_VNet \
  --tier Standard \
  --no-wait
```

### Destroy Resources When Done Learning
```bash
# WARNING: This destroys all resources!
terraform destroy
```

---
