#!/bin/bash
#
# Deployment script for Azure Hub-Spoke Network Topology
#
# Usage: ./deploy.sh [environment]
# Example: ./deploy.sh prod
#

set -e

ENVIRONMENT=${1:-prod}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=================================="
echo "Azure Hub-Spoke Network Deployment"
echo "Environment: ${ENVIRONMENT}"
echo "=================================="

# Check prerequisites
echo ""
echo "Checking prerequisites..."

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "Error: Azure CLI is not installed. Please install it first."
    echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "Error: Terraform is not installed. Please install it first."
    echo "Visit: https://www.terraform.io/downloads"
    exit 1
fi

# Check Azure CLI login status
echo "Checking Azure login status..."
if ! az account show &> /dev/null; then
    echo "Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)

echo "Using Azure Subscription:"
echo "  Name: ${SUBSCRIPTION_NAME}"
echo "  ID: ${SUBSCRIPTION_ID}"

# Confirm deployment
echo ""
read -p "Do you want to proceed with the deployment? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Initialize Terraform
echo ""
echo "Initializing Terraform..."
cd "${SCRIPT_DIR}"
terraform init

# Validate configuration
echo ""
echo "Validating Terraform configuration..."
terraform validate

if [ $? -ne 0 ]; then
    echo "Error: Terraform validation failed."
    exit 1
fi

# Create plan
echo ""
echo "Creating deployment plan..."
terraform plan -out=tfplan

# Review plan
echo ""
echo "Review the deployment plan above."
read -p "Do you want to apply this plan? (yes/no): " APPLY_CONFIRM

if [[ "$APPLY_CONFIRM" != "yes" ]]; then
    echo "Deployment cancelled."
    rm -f tfplan
    exit 0
fi

# Apply plan
echo ""
echo "Applying deployment plan..."
echo "Note: This will take approximately 30-45 minutes due to VPN Gateway and Firewall provisioning."
terraform apply tfplan

# Clean up plan file
rm -f tfplan

# Display outputs
echo ""
echo "=================================="
echo "Deployment Complete!"
echo "=================================="
echo ""
terraform output

echo ""
echo "Next Steps:"
echo "1. Review the outputs above"
echo "2. Configure VPN connection if needed"
echo "3. Deploy workloads to spoke networks"
echo "4. Test connectivity using Azure Bastion"
echo ""
echo "Documentation: docs/architecture.md"
echo "Traffic Flows: docs/traffic-flows.md"
