# Resource Group
resource "azurerm_resource_group" "hub_spoke" {
  name     = "rg-${var.environment}-hubspoke"
  location = var.location
  tags     = var.tags
}

# Log Analytics Workspace for monitoring
resource "azurerm_log_analytics_workspace" "hub" {
  name                = "law-${var.environment}-hubspoke"
  location            = azurerm_resource_group.hub_spoke.location
  resource_group_name = azurerm_resource_group.hub_spoke.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

###############################
# Hub Virtual Network
###############################

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.environment}-hub"
  location            = azurerm_resource_group.hub_spoke.location
  resource_group_name = azurerm_resource_group.hub_spoke.name
  address_space       = var.hub_vnet_address_space
  tags                = var.tags
}

# Hub Subnets
resource "azurerm_subnet" "hub_firewall" {
  name                 = "AzureFirewallSubnet" # Must be named exactly this
  resource_group_name  = azurerm_resource_group.hub_spoke.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/26"]
}

resource "azurerm_subnet" "hub_bastion" {
  name                 = "AzureBastionSubnet" # Must be named exactly this
  resource_group_name  = azurerm_resource_group.hub_spoke.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.2.0/26"]
}

resource "azurerm_subnet" "hub_gateway" {
  name                 = "GatewaySubnet" # Must be named exactly this
  resource_group_name  = azurerm_resource_group.hub_spoke.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.3.0/26"]
}

resource "azurerm_subnet" "hub_mgmt" {
  name                 = "ManagementSubnet"
  resource_group_name  = azurerm_resource_group.hub_spoke.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.4.0/24"]
}

###############################
# Azure Firewall
###############################

resource "azurerm_public_ip" "firewall" {
  name                = "pip-${var.environment}-firewall"
  location            = azurerm_resource_group.hub_spoke.location
  resource_group_name = azurerm_resource_group.hub_spoke.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall" "hub" {
  name                = "afw-${var.environment}-hub"
  location            = azurerm_resource_group.hub_spoke.location
  resource_group_name = azurerm_resource_group.hub_spoke.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  tags                = var.tags

  ip_configuration {
    name                 = "firewall-ipconfig"
    subnet_id            = azurerm_subnet.hub_firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

# Firewall Network Rules
resource "azurerm_firewall_network_rule_collection" "hub" {
  name                = "network-rules"
  azure_firewall_name = azurerm_firewall.hub.name
  resource_group_name = azurerm_resource_group.hub_spoke.name
  priority            = 100
  action              = "Allow"

  rule {
    name                  = "allow-spoke-to-spoke"
    source_addresses      = ["10.1.0.0/16", "10.2.0.0/16"]
    destination_ports     = ["*"]
    destination_addresses = ["10.1.0.0/16", "10.2.0.0/16"]
    protocols             = ["Any"]
  }

  rule {
    name                  = "allow-dns"
    source_addresses      = ["10.0.0.0/8"]
    destination_ports     = ["53"]
    destination_addresses = ["*"]
    protocols             = ["UDP", "TCP"]
  }
}

# Firewall Application Rules
resource "azurerm_firewall_application_rule_collection" "hub" {
  name                = "app-rules"
  azure_firewall_name = azurerm_firewall.hub.name
  resource_group_name = azurerm_resource_group.hub_spoke.name
  priority            = 100
  action              = "Allow"

  rule {
    name             = "allow-azure-services"
    source_addresses = ["10.0.0.0/8"]

    target_fqdns = [
      "*.microsoft.com",
      "*.windows.net",
      "*.azure.com",
    ]

    protocol {
      port = "443"
      type = "Https"
    }

    protocol {
      port = "80"
      type = "Http"
    }
  }

  rule {
    name             = "allow-updates"
    source_addresses = ["10.0.0.0/8"]

    target_fqdns = [
      "*.ubuntu.com",
      "security.ubuntu.com",
    ]

    protocol {
      port = "443"
      type = "Https"
    }

    protocol {
      port = "80"
      type = "Http"
    }
  }
}

# Firewall Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                       = "firewall-diagnostics"
  target_resource_id         = azurerm_firewall.hub.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.hub.id

  enabled_log {
    category = "AzureFirewallApplicationRule"
  }

  enabled_log {
    category = "AzureFirewallNetworkRule"
  }

  enabled_log {
    category = "AzureFirewallDnsProxy"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

###############################
# Azure Bastion
###############################

resource "azurerm_public_ip" "bastion" {
  name                = "pip-${var.environment}-bastion"
  location            = azurerm_resource_group.hub_spoke.location
  resource_group_name = azurerm_resource_group.hub_spoke.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "hub" {
  name                = "bas-${var.environment}-hub"
  location            = azurerm_resource_group.hub_spoke.location
  resource_group_name = azurerm_resource_group.hub_spoke.name
  tags                = var.tags

  ip_configuration {
    name                 = "bastion-ipconfig"
    subnet_id            = azurerm_subnet.hub_bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

###############################
# VPN Gateway
###############################

resource "azurerm_public_ip" "vpn_gateway" {
  name                = "pip-${var.environment}-vpngateway"
  location            = azurerm_resource_group.hub_spoke.location
  resource_group_name = azurerm_resource_group.hub_spoke.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway" "hub" {
  name                = "vgw-${var.environment}-hub"
  location            = azurerm_resource_group.hub_spoke.location
  resource_group_name = azurerm_resource_group.hub_spoke.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  tags                = var.tags

  ip_configuration {
    name                          = "vpngateway-ipconfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.hub_gateway.id
  }
}

###############################
# Spoke Virtual Networks
###############################

# Production Spoke VNet
resource "azurerm_virtual_network" "spoke_prod" {
  name                = "vnet-${var.environment}-spoke-prod"
  location            = azurerm_resource_group.hub_spoke.location
  resource_group_name = azurerm_resource_group.hub_spoke.name
  address_space       = var.spoke_prod_vnet_address_space
  tags                = merge(var.tags, { Environment = "Production" })
}

resource "azurerm_subnet" "spoke_prod_workload" {
  name                 = "WorkloadSubnet"
  resource_group_name  = azurerm_resource_group.hub_spoke.name
  virtual_network_name = azurerm_virtual_network.spoke_prod.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "spoke_prod_data" {
  name                 = "DataSubnet"
  resource_group_name  = azurerm_resource_group.hub_spoke.name
  virtual_network_name = azurerm_virtual_network.spoke_prod.name
  address_prefixes     = ["10.1.2.0/24"]
}

# Development Spoke VNet
resource "azurerm_virtual_network" "spoke_dev" {
  name                = "vnet-${var.environment}-spoke-dev"
  location            = azurerm_resource_group.hub_spoke.location
  resource_group_name = azurerm_resource_group.hub_spoke.name
  address_space       = var.spoke_dev_vnet_address_space
  tags                = merge(var.tags, { Environment = "Development" })
}

resource "azurerm_subnet" "spoke_dev_workload" {
  name                 = "WorkloadSubnet"
  resource_group_name  = azurerm_resource_group.hub_spoke.name
  virtual_network_name = azurerm_virtual_network.spoke_dev.name
  address_prefixes     = ["10.2.1.0/24"]
}

resource "azurerm_subnet" "spoke_dev_data" {
  name                 = "DataSubnet"
  resource_group_name  = azurerm_resource_group.hub_spoke.name
  virtual_network_name = azurerm_virtual_network.spoke_dev.name
  address_prefixes     = ["10.2.2.0/24"]
}

###############################
# VNet Peering
###############################

# Hub to Production Spoke Peering
resource "azurerm_virtual_network_peering" "hub_to_prod" {
  name                         = "peer-hub-to-prod"
  resource_group_name          = azurerm_resource_group.hub_spoke.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke_prod.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
}

resource "azurerm_virtual_network_peering" "prod_to_hub" {
  name                         = "peer-prod-to-hub"
  resource_group_name          = azurerm_resource_group.hub_spoke.name
  virtual_network_name         = azurerm_virtual_network.spoke_prod.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false # Set to true after VPN gateway is ready
}

# Hub to Development Spoke Peering
resource "azurerm_virtual_network_peering" "hub_to_dev" {
  name                         = "peer-hub-to-dev"
  resource_group_name          = azurerm_resource_group.hub_spoke.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke_dev.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
}

resource "azurerm_virtual_network_peering" "dev_to_hub" {
  name                         = "peer-dev-to-hub"
  resource_group_name          = azurerm_resource_group.hub_spoke.name
  virtual_network_name         = azurerm_virtual_network.spoke_dev.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false # Set to true after VPN gateway is ready
}

###############################
# Route Tables
###############################

# Route table for production spoke
resource "azurerm_route_table" "spoke_prod" {
  name                          = "rt-${var.environment}-spoke-prod"
  location                      = azurerm_resource_group.hub_spoke.location
  resource_group_name           = azurerm_resource_group.hub_spoke.name
  bgp_route_propagation_enabled = true
  tags                          = var.tags
}

resource "azurerm_route" "spoke_prod_to_internet" {
  name                   = "route-to-internet"
  resource_group_name    = azurerm_resource_group.hub_spoke.name
  route_table_name       = azurerm_route_table.spoke_prod.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

resource "azurerm_route" "spoke_prod_to_spoke_dev" {
  name                   = "route-to-spoke-dev"
  resource_group_name    = azurerm_resource_group.hub_spoke.name
  route_table_name       = azurerm_route_table.spoke_prod.name
  address_prefix         = "10.2.0.0/16"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

# Route table for development spoke
resource "azurerm_route_table" "spoke_dev" {
  name                          = "rt-${var.environment}-spoke-dev"
  location                      = azurerm_resource_group.hub_spoke.location
  resource_group_name           = azurerm_resource_group.hub_spoke.name
  bgp_route_propagation_enabled = true
  tags                          = var.tags
}

resource "azurerm_route" "spoke_dev_to_internet" {
  name                   = "route-to-internet"
  resource_group_name    = azurerm_resource_group.hub_spoke.name
  route_table_name       = azurerm_route_table.spoke_dev.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

resource "azurerm_route" "spoke_dev_to_spoke_prod" {
  name                   = "route-to-spoke-prod"
  resource_group_name    = azurerm_resource_group.hub_spoke.name
  route_table_name       = azurerm_route_table.spoke_dev.name
  address_prefix         = "10.1.0.0/16"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

# Associate route tables with subnets
resource "azurerm_subnet_route_table_association" "spoke_prod_workload" {
  subnet_id      = azurerm_subnet.spoke_prod_workload.id
  route_table_id = azurerm_route_table.spoke_prod.id
}

resource "azurerm_subnet_route_table_association" "spoke_prod_data" {
  subnet_id      = azurerm_subnet.spoke_prod_data.id
  route_table_id = azurerm_route_table.spoke_prod.id
}

resource "azurerm_subnet_route_table_association" "spoke_dev_workload" {
  subnet_id      = azurerm_subnet.spoke_dev_workload.id
  route_table_id = azurerm_route_table.spoke_dev.id
}

resource "azurerm_subnet_route_table_association" "spoke_dev_data" {
  subnet_id      = azurerm_subnet.spoke_dev_data.id
  route_table_id = azurerm_route_table.spoke_dev.id
}

###############################
# Network Security Groups
###############################

# NSG for Production Workload Subnet
resource "azurerm_network_security_group" "spoke_prod_workload" {
  name                = "nsg-${var.environment}-spoke-prod-workload"
  location            = azurerm_resource_group.hub_spoke.location
  resource_group_name = azurerm_resource_group.hub_spoke.name
  tags                = var.tags

  security_rule {
    name                       = "AllowHttpsInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHttpInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "spoke_prod_workload" {
  subnet_id                 = azurerm_subnet.spoke_prod_workload.id
  network_security_group_id = azurerm_network_security_group.spoke_prod_workload.id
}

# NSG for Production Data Subnet
resource "azurerm_network_security_group" "spoke_prod_data" {
  name                = "nsg-${var.environment}-spoke-prod-data"
  location            = azurerm_resource_group.hub_spoke.location
  resource_group_name = azurerm_resource_group.hub_spoke.name
  tags                = var.tags

  security_rule {
    name                       = "AllowSqlFromWorkload"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "10.1.1.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "spoke_prod_data" {
  subnet_id                 = azurerm_subnet.spoke_prod_data.id
  network_security_group_id = azurerm_network_security_group.spoke_prod_data.id
}

# NSG for Development Workload Subnet
resource "azurerm_network_security_group" "spoke_dev_workload" {
  name                = "nsg-${var.environment}-spoke-dev-workload"
  location            = azurerm_resource_group.hub_spoke.location
  resource_group_name = azurerm_resource_group.hub_spoke.name
  tags                = var.tags

  security_rule {
    name                       = "AllowHttpsInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHttpInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSshFromHub"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "spoke_dev_workload" {
  subnet_id                 = azurerm_subnet.spoke_dev_workload.id
  network_security_group_id = azurerm_network_security_group.spoke_dev_workload.id
}

# NSG for Development Data Subnet
resource "azurerm_network_security_group" "spoke_dev_data" {
  name                = "nsg-${var.environment}-spoke-dev-data"
  location            = azurerm_resource_group.hub_spoke.location
  resource_group_name = azurerm_resource_group.hub_spoke.name
  tags                = var.tags

  security_rule {
    name                       = "AllowSqlFromWorkload"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "10.2.1.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "spoke_dev_data" {
  subnet_id                 = azurerm_subnet.spoke_dev_data.id
  network_security_group_id = azurerm_network_security_group.spoke_dev_data.id
}

# NSG Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "nsg_prod_workload" {
  name                       = "nsg-prod-workload-diagnostics"
  target_resource_id         = azurerm_network_security_group.spoke_prod_workload.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.hub.id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

resource "azurerm_monitor_diagnostic_setting" "nsg_prod_data" {
  name                       = "nsg-prod-data-diagnostics"
  target_resource_id         = azurerm_network_security_group.spoke_prod_data.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.hub.id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}
