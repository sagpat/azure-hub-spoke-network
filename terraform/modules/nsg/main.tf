
# Network Security Group Module - Main Configuration
# Create NSG for each subnet
resource "azurerm_network_security_group" "subnets" {
  for_each = var.subnets

  name                = "nsg-${var.name_prefix}-${var.spoke_name}-${each.key}-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}


# NSG Rules - Web Spoke
resource "azurerm_network_security_rule" "web_allow_http" {
  count = var.spoke_name == "web" ? 1 : 0

  name                        = "Allow-HTTP-Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.subnets["WebSubnet"].name
}

resource "azurerm_network_security_rule" "web_allow_https" {
  count = var.spoke_name == "web" ? 1 : 0

  name                        = "Allow-HTTPS-Inbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.subnets["WebSubnet"].name
}


# NSG Rules - Data Spoke
resource "azurerm_network_security_rule" "data_allow_sql" {
  count = var.spoke_name == "data" ? 1 : 0

  name                        = "Allow-SQL-From-Web"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1433"
  source_address_prefix       = "10.1.0.0/16" # Web spoke
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.subnets["DataSubnet"].name
}

resource "azurerm_network_security_rule" "data_deny_internet" {
  count = var.spoke_name == "data" ? 1 : 0

  name                        = "Deny-Internet-Outbound"
  priority                    = 4000
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.subnets["DataSubnet"].name
}


# NSG Rules - Management Spoke
resource "azurerm_network_security_rule" "mgmt_allow_rdp" {
  count = var.spoke_name == "mgmt" ? 1 : 0

  name                        = "Allow-RDP-From-Bastion"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "10.0.2.0/26" # Bastion subnet
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.subnets["MgmtSubnet"].name
}

resource "azurerm_network_security_rule" "mgmt_allow_ssh" {
  count = var.spoke_name == "mgmt" ? 1 : 0

  name                        = "Allow-SSH-From-Bastion"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "10.0.2.0/26" # Bastion subnet
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.subnets["MgmtSubnet"].name
}


# Common NSG Rules - All Spokes
# Deny all inbound from internet (lowest priority)
resource "azurerm_network_security_rule" "deny_all_inbound" {
  for_each = var.subnets

  name                        = "Deny-All-Inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.subnets[each.key].name
}


# Associate NSGs with Subnets
resource "azurerm_subnet_network_security_group_association" "subnets" {
  for_each = var.subnet_ids

  subnet_id                 = each.value
  network_security_group_id = azurerm_network_security_group.subnets[each.key].id
}


# NSG Flow Logs (if Log Analytics is provided)
resource "azurerm_monitor_diagnostic_setting" "nsg" {
  for_each = var.enable_diagnostics ? var.subnets : {}

  name                       = "diag-nsg-${each.key}"
  target_resource_id         = azurerm_network_security_group.subnets[each.key].id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}
