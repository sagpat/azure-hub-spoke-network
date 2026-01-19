
# Azure Bastion Module - Main Configuration
# Public IP for Azure Bastion
resource "azurerm_public_ip" "bastion" {
  name                = "pip-${var.name_prefix}-bastion-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

# Azure Bastion Host
resource "azurerm_bastion_host" "main" {
  name                = "bas-${var.name_prefix}-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku
  
  # Standard SKU features
  copy_paste_enabled     = true
  file_copy_enabled      = var.sku == "Standard" ? true : false
  ip_connect_enabled     = var.sku == "Standard" ? true : false
  shareable_link_enabled = var.sku == "Standard" ? true : false
  tunneling_enabled      = var.sku == "Standard" ? true : false

  ip_configuration {
    name                 = "bastion-ipconfig"
    subnet_id            = var.subnet_id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  tags = var.tags
}

# Diagnostic Settings for Bastion
resource "azurerm_monitor_diagnostic_setting" "bastion" {
  name                       = "diag-${azurerm_bastion_host.main.name}"
  target_resource_id         = azurerm_bastion_host.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "BastionAuditLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
