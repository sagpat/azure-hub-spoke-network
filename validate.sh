#!/bin/bash
#
# Validation script for Azure Hub-Spoke Network Topology
#
# This script validates the deployment and tests connectivity
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=================================="
echo "Azure Hub-Spoke Network Validation"
echo "=================================="

# Get outputs from Terraform
cd "${SCRIPT_DIR}"

echo ""
echo "Getting deployment outputs..."

RG_NAME=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
HUB_VNET_NAME=$(terraform output -raw hub_vnet_name 2>/dev/null || echo "")
FIREWALL_PRIVATE_IP=$(terraform output -raw firewall_private_ip 2>/dev/null || echo "")

if [ -z "$RG_NAME" ]; then
    echo "Error: Could not get resource group name. Is the deployment complete?"
    exit 1
fi

echo "Resource Group: ${RG_NAME}"
echo "Hub VNet: ${HUB_VNET_NAME}"
echo "Firewall Private IP: ${FIREWALL_PRIVATE_IP}"

# Validate Azure Firewall
echo ""
echo "Validating Azure Firewall..."
FIREWALL_STATE=$(az network firewall show \
    --resource-group "${RG_NAME}" \
    --name "afw-prod-hub" \
    --query "provisioningState" \
    -o tsv 2>/dev/null || echo "NotFound")

if [ "$FIREWALL_STATE" = "Succeeded" ]; then
    echo "✓ Azure Firewall is running"
else
    echo "✗ Azure Firewall state: ${FIREWALL_STATE}"
fi

# Validate Azure Bastion
echo ""
echo "Validating Azure Bastion..."
BASTION_STATE=$(az network bastion show \
    --resource-group "${RG_NAME}" \
    --name "bas-prod-hub" \
    --query "provisioningState" \
    -o tsv 2>/dev/null || echo "NotFound")

if [ "$BASTION_STATE" = "Succeeded" ]; then
    echo "✓ Azure Bastion is running"
else
    echo "✗ Azure Bastion state: ${BASTION_STATE}"
fi

# Validate VPN Gateway
echo ""
echo "Validating VPN Gateway..."
VPN_STATE=$(az network vnet-gateway show \
    --resource-group "${RG_NAME}" \
    --name "vgw-prod-hub" \
    --query "provisioningState" \
    -o tsv 2>/dev/null || echo "NotFound")

if [ "$VPN_STATE" = "Succeeded" ]; then
    echo "✓ VPN Gateway is running"
else
    echo "✗ VPN Gateway state: ${VPN_STATE}"
fi

# Validate VNet Peerings
echo ""
echo "Validating VNet Peerings..."

PEERING_HUB_TO_PROD=$(az network vnet peering show \
    --resource-group "${RG_NAME}" \
    --vnet-name "${HUB_VNET_NAME}" \
    --name "peer-hub-to-prod" \
    --query "peeringState" \
    -o tsv 2>/dev/null || echo "NotFound")

if [ "$PEERING_HUB_TO_PROD" = "Connected" ]; then
    echo "✓ Hub to Production peering is connected"
else
    echo "✗ Hub to Production peering state: ${PEERING_HUB_TO_PROD}"
fi

PEERING_HUB_TO_DEV=$(az network vnet peering show \
    --resource-group "${RG_NAME}" \
    --vnet-name "${HUB_VNET_NAME}" \
    --name "peer-hub-to-dev" \
    --query "peeringState" \
    -o tsv 2>/dev/null || echo "NotFound")

if [ "$PEERING_HUB_TO_DEV" = "Connected" ]; then
    echo "✓ Hub to Development peering is connected"
else
    echo "✗ Hub to Development peering state: ${PEERING_HUB_TO_DEV}"
fi

# Validate Route Tables
echo ""
echo "Validating Route Tables..."

ROUTE_COUNT=$(az network route-table route list \
    --resource-group "${RG_NAME}" \
    --route-table-name "rt-prod-spoke" \
    --query "length(@)" \
    -o tsv 2>/dev/null || echo "0")

if [ "$ROUTE_COUNT" -ge 3 ]; then
    echo "✓ Route table has ${ROUTE_COUNT} routes configured"
else
    echo "✗ Route table has only ${ROUTE_COUNT} routes (expected at least 3)"
fi

# Validate NSGs
echo ""
echo "Validating Network Security Groups..."

NSG_COUNT=$(az network nsg list \
    --resource-group "${RG_NAME}" \
    --query "length(@)" \
    -o tsv 2>/dev/null || echo "0")

if [ "$NSG_COUNT" -ge 4 ]; then
    echo "✓ ${NSG_COUNT} Network Security Groups configured"
else
    echo "✗ Only ${NSG_COUNT} NSGs found (expected at least 4)"
fi

# Summary
echo ""
echo "=================================="
echo "Validation Summary"
echo "=================================="
echo ""
echo "Core Components:"
echo "  - Azure Firewall: ${FIREWALL_STATE}"
echo "  - Azure Bastion: ${BASTION_STATE}"
echo "  - VPN Gateway: ${VPN_STATE}"
echo ""
echo "Network Connectivity:"
echo "  - Hub to Prod Peering: ${PEERING_HUB_TO_PROD}"
echo "  - Hub to Dev Peering: ${PEERING_HUB_TO_DEV}"
echo "  - Route Tables: ${ROUTE_COUNT} routes"
echo "  - NSGs: ${NSG_COUNT} groups"
echo ""
echo "For detailed architecture information, see:"
echo "  - docs/architecture.md"
echo "  - docs/traffic-flows.md"
