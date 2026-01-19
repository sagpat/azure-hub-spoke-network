#!/bin/bash
#
# Cleanup script for Azure Hub-Spoke Network Topology
#
# WARNING: This will destroy all resources created by Terraform
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=================================="
echo "Azure Hub-Spoke Network Cleanup"
echo "=================================="
echo ""
echo "WARNING: This will destroy all resources including:"
echo "  - Azure Firewall"
echo "  - Azure Bastion"
echo "  - VPN Gateway"
echo "  - All Virtual Networks"
echo "  - All Network Security Groups"
echo "  - Log Analytics Workspace"
echo ""

read -p "Are you sure you want to destroy all resources? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
read -p "Type 'DELETE' to confirm destruction: " CONFIRM_DELETE

if [[ "$CONFIRM_DELETE" != "DELETE" ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

cd "${SCRIPT_DIR}"

echo ""
echo "Destroying resources..."
terraform destroy

echo ""
echo "=================================="
echo "Cleanup Complete!"
echo "=================================="
