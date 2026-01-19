
# Azure Firewall Module - Main Configuration
# Public IP for Azure Firewall
resource "azurerm_public_ip" "firewall" {
  name                = "pip-${var.name_prefix}-fw-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

# Management Public IP for Azure Firewall (required for Basic tier)
resource "azurerm_public_ip" "firewall_management" {
  count               = var.sku_tier == "Basic" ? 1 : 0
  name                = "pip-${var.name_prefix}-fw-mgmt-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

# Azure Firewall Policy
resource "azurerm_firewall_policy" "main" {
  name                = "fwpol-${var.name_prefix}-${var.name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku_tier

  # Note: DNS Proxy requires Premium tier - disabled for Standard tier
  # dns {
  #   proxy_enabled = true
  # }

  threat_intelligence_mode = "Alert"

  tags = var.tags
}

# Firewall Policy Rule Collection Group - Network Rules
resource "azurerm_firewall_policy_rule_collection_group" "network_rules" {
  name               = "rcg-network-rules"
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = 100

  network_rule_collection {
    name     = "allow-spoke-to-spoke"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "spoke-to-spoke-all"
      protocols             = ["Any"]
      source_addresses      = var.spoke_address_prefixes
      destination_addresses = var.spoke_address_prefixes
      destination_ports     = ["*"]
    }
  }

  network_rule_collection {
    name     = "allow-azure-services"
    priority = 200
    action   = "Allow"

    rule {
      name                  = "allow-dns"
      protocols             = ["UDP"]
      source_addresses      = ["*"]
      destination_addresses = ["168.63.129.16"]
      destination_ports     = ["53"]
    }

    rule {
      name                  = "allow-ntp"
      protocols             = ["UDP"]
      source_addresses      = var.spoke_address_prefixes
      destination_addresses = ["*"]
      destination_ports     = ["123"]
    }

    # Note: Using Azure KMS service tag instead of FQDN (Basic tier doesn't support FQDNs in network rules)
    rule {
      name                  = "allow-kms"
      protocols             = ["TCP"]
      source_addresses      = var.spoke_address_prefixes
      destination_addresses = ["AzureCloud"]
      destination_ports     = ["1688"]
    }
  }
}

# Firewall Policy Rule Collection Group - Application Rules
resource "azurerm_firewall_policy_rule_collection_group" "application_rules" {
  name               = "rcg-application-rules"
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = 200

  application_rule_collection {
    name     = "allow-windows-updates"
    priority = 100
    action   = "Allow"

    rule {
      name = "windows-update"
      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
      source_addresses  = var.spoke_address_prefixes
      destination_fqdns = [
        "*.windowsupdate.microsoft.com",
        "*.update.microsoft.com",
        "*.windowsupdate.com",
        "download.microsoft.com",
        "wustat.windows.com",
        "ntservicepack.microsoft.com"
      ]
    }
  }

  application_rule_collection {
    name     = "allow-azure-services"
    priority = 200
    action   = "Allow"

    rule {
      name = "azure-management"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = var.spoke_address_prefixes
      destination_fqdns = [
        "management.azure.com",
        "*.management.azure.com",
        "login.microsoftonline.com",
        "*.login.microsoftonline.com"
      ]
    }

    rule {
      name = "azure-monitor"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = var.spoke_address_prefixes
      destination_fqdns = [
        "*.ods.opinsights.azure.com",
        "*.oms.opinsights.azure.com",
        "*.monitoring.azure.com"
      ]
    }
  }

  application_rule_collection {
    name     = "allow-web-categories"
    priority = 300
    action   = "Allow"

    rule {
      name = "github-access"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = var.spoke_address_prefixes
      destination_fqdns = [
        "github.com",
        "*.github.com",
        "raw.githubusercontent.com"
      ]
    }

    rule {
      name = "ip-check-services"
      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
      source_addresses  = var.spoke_address_prefixes
      destination_fqdns = [
        "ifconfig.me",
        "checkip.amazonaws.com",
        "ipinfo.io",
        "icanhazip.com",
        "api.ipify.org"
      ]
    }

    rule {
      name = "common-test-sites"
      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
      source_addresses  = var.spoke_address_prefixes
      destination_fqdns = [
        "www.microsoft.com",
        "*.microsoft.com",
        "ubuntu.com",
        "*.ubuntu.com"
      ]
    }
  }
}

# Firewall Policy Rule Collection Group - DNAT Rules
resource "azurerm_firewall_policy_rule_collection_group" "dnat_rules" {
  name               = "rcg-dnat-rules"
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = 300

  # Example DNAT rule (commented out - uncomment when needed)
  # nat_rule_collection {
  #   name     = "dnat-web-traffic"
  #   priority = 100
  #   action   = "Dnat"
  #
  #   rule {
  #     name                = "web-server-http"
  #     protocols           = ["TCP"]
  #     source_addresses    = ["*"]
  #     destination_address = azurerm_public_ip.firewall.ip_address
  #     destination_ports   = ["80"]
  #     translated_address  = "10.1.1.4"  # Web server private IP
  #     translated_port     = "80"
  #   }
  # }
}

# Azure Firewall
resource "azurerm_firewall" "main" {
  name                = "fw-${var.name_prefix}-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.sku_tier
  firewall_policy_id  = azurerm_firewall_policy.main.id
  zones               = ["1", "2", "3"]

  ip_configuration {
    name                 = "fw-ipconfig"
    subnet_id            = var.subnet_id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  # Management IP configuration is required for Basic tier
  dynamic "management_ip_configuration" {
    for_each = var.sku_tier == "Basic" ? [1] : []
    content {
      name                 = "fw-mgmt-ipconfig"
      subnet_id            = var.management_subnet_id
      public_ip_address_id = azurerm_public_ip.firewall_management[0].id
    }
  }

  tags = var.tags
}

# Diagnostic Settings for Firewall
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                       = "diag-${azurerm_firewall.main.name}"
  target_resource_id         = azurerm_firewall.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AzureFirewallApplicationRule"
  }

  enabled_log {
    category = "AzureFirewallNetworkRule"
  }

  # Note: AzureFirewallDnsProxy requires Premium tier - removed for Basic/Standard

  enabled_log {
    category = "AZFWApplicationRule"
  }

  enabled_log {
    category = "AZFWNetworkRule"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
