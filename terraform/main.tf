
# Main Terraform Configuration - Hub-Spoke Network
# Random suffix for unique naming
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

locals {
  # Resource naming convention
  name_prefix = "${var.project_name}-${var.environment}"
  name_suffix = random_string.suffix.result

  # Common tags for all resources
  common_tags = merge(var.tags, {
    Environment = var.environment
    Timestamp   = timestamp()
  })
}


# Resource Groups
resource "azurerm_resource_group" "hub" {
  name     = "rg-${local.name_prefix}-hub-${local.name_suffix}"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_resource_group" "spokes" {
  for_each = var.spoke_vnets

  name     = "rg-${local.name_prefix}-spoke-${each.key}-${local.name_suffix}"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_resource_group" "monitoring" {
  name     = "rg-${local.name_prefix}-monitoring-${local.name_suffix}"
  location = var.location
  tags     = local.common_tags
}


# Monitoring - Log Analytics Workspace
module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name = azurerm_resource_group.monitoring.name
  location            = var.location
  name_prefix         = local.name_prefix
  name_suffix         = local.name_suffix
  log_retention_days  = var.log_retention_days
  tags                = local.common_tags
}


# Hub Network
module "hub_network" {
  source = "./modules/hub-network"

  resource_group_name = azurerm_resource_group.hub.name
  location            = var.location
  name_prefix         = local.name_prefix
  name_suffix         = local.name_suffix
  address_space       = var.hub_vnet_address_space
  subnets             = var.hub_subnets
  tags                = local.common_tags
}


# Azure Firewall
module "firewall" {
  source = "./modules/firewall"
  count  = var.enable_firewall ? 1 : 0

  resource_group_name           = azurerm_resource_group.hub.name
  location                      = var.location
  name_prefix                   = local.name_prefix
  name_suffix                   = local.name_suffix
  sku_tier                      = var.firewall_sku_tier
  subnet_id                     = module.hub_network.subnet_ids["AzureFirewallSubnet"]
  management_subnet_id          = var.firewall_sku_tier == "Basic" ? module.hub_network.subnet_ids["AzureFirewallManagementSubnet"] : null
  log_analytics_workspace_id    = module.monitoring.log_analytics_workspace_id
  spoke_address_prefixes        = [for spoke in var.spoke_vnets : spoke.address_space[0]]
  tags                          = local.common_tags
}


# Azure Bastion
module "bastion" {
  source = "./modules/bastion"
  count  = var.enable_bastion ? 1 : 0

  resource_group_name        = azurerm_resource_group.hub.name
  location                   = var.location
  name_prefix                = local.name_prefix
  name_suffix                = local.name_suffix
  sku                        = var.bastion_sku
  subnet_id                  = module.hub_network.subnet_ids["AzureBastionSubnet"]
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = local.common_tags
}


# Spoke Networks
module "spoke_networks" {
  source   = "./modules/spoke-network"
  for_each = var.spoke_vnets

  resource_group_name = azurerm_resource_group.spokes[each.key].name
  location            = var.location
  name_prefix         = local.name_prefix
  name_suffix         = local.name_suffix
  spoke_name          = each.key
  address_space       = each.value.address_space
  subnets             = each.value.subnets
  tags                = local.common_tags

  # Hub connectivity
  hub_vnet_id   = module.hub_network.vnet_id
  hub_vnet_name = module.hub_network.vnet_name
  hub_resource_group_name = azurerm_resource_group.hub.name
}


# Route Tables (UDRs) - Force traffic through Firewall
module "route_tables" {
  source   = "./modules/route-table"
  for_each = var.enable_firewall ? var.spoke_vnets : {}

  resource_group_name   = azurerm_resource_group.spokes[each.key].name
  location              = var.location
  name_prefix           = local.name_prefix
  name_suffix           = local.name_suffix
  spoke_name            = each.key
  firewall_private_ip   = var.enable_firewall ? module.firewall[0].private_ip_address : null
  subnet_ids            = module.spoke_networks[each.key].subnet_ids
  tags                  = local.common_tags
}


# Network Security Groups
module "nsgs" {
  source   = "./modules/nsg"
  for_each = var.spoke_vnets

  resource_group_name        = azurerm_resource_group.spokes[each.key].name
  location                   = var.location
  name_prefix                = local.name_prefix
  name_suffix                = local.name_suffix
  spoke_name                 = each.key
  subnets                    = each.value.subnets
  subnet_ids                 = module.spoke_networks[each.key].subnet_ids
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  enable_diagnostics         = true
  tags                       = local.common_tags
}


# Private DNS Zones
module "private_dns" {
  source = "./modules/private-dns"

  resource_group_name = azurerm_resource_group.hub.name
  dns_zones           = var.private_dns_zones
  hub_vnet_id         = module.hub_network.vnet_id
  spoke_vnet_ids      = { for k, v in module.spoke_networks : k => v.vnet_id }
  tags                = local.common_tags
}


# Network Watcher (if not already exists in region)
resource "azurerm_network_watcher" "main" {
  count = var.enable_network_watcher ? 1 : 0

  name                = "nw-${local.name_prefix}-${var.location}"
  location            = var.location
  resource_group_name = azurerm_resource_group.monitoring.name
  tags                = local.common_tags
}


# Test VMs in Spoke Networks

# These VMs are used to test connectivity:
# - Between spokes (via hub firewall)
# - From spokes to internet (via hub firewall)
# - Bastion access to VMs
module "test_vms" {
  source   = "./modules/vm"
  for_each = var.deploy_test_vms ? var.spoke_vnets : {}

  resource_group_name  = azurerm_resource_group.spokes[each.key].name
  location             = var.location
  name_prefix          = local.name_prefix
  name_suffix          = local.name_suffix
  spoke_name           = each.key
  subnet_id            = module.spoke_networks[each.key].subnet_ids[keys(each.value.subnets)[0]]
  vm_size              = "Standard_B1s"
  admin_username       = var.admin_username
  admin_ssh_public_key = var.admin_ssh_public_key
  tags                 = local.common_tags
}
