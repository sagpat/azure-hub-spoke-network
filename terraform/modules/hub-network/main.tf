
# Hub Network Module - Main Configuration
# Hub Virtual Network
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.name_prefix}-hub-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
  tags                = var.tags
}

# Hub Subnets
resource "azurerm_subnet" "hub_subnets" {
  for_each = var.subnets

  name                 = each.key
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = each.value.address_prefixes

  # # Special handling for specific subnets
  # dynamic "delegation" {
  #   for_each = each.key == "ManagementSubnet" ? [] : [] # No delegations for now; placeholder for future use
  #   content {
  #     name = delegation.value.name
  #     service_delegation {
  #       name    = delegation.value.service_name
  #       actions = delegation.value.actions
  #     }
  #   }
  # }
}
