
# Project Variables
variable "project_name" {
  description = "Name of the project (used in resource naming)"
  type        = string
  default     = "hubspoke"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "Week1-HubSpoke"
    Environment = "Development"
    ManagedBy   = "Terraform"
    Owner       = "LearningPath"
  }
}


# Hub Network Variables
variable "hub_vnet_address_space" {
  description = "Address space for the Hub VNet"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "hub_subnets" {
  description = "Subnets for the Hub VNet"
  type = map(object({
    address_prefixes = list(string)
  }))
  default = {
    AzureFirewallSubnet = {
      address_prefixes = ["10.0.1.0/24"]
    }
    AzureBastionSubnet = {
      address_prefixes = ["10.0.2.0/26"]
    }
    GatewaySubnet = {
      address_prefixes = ["10.0.3.0/27"]
    }
    ManagementSubnet = {
      address_prefixes = ["10.0.4.0/24"]
    }
  }
}


# Spoke Network Variables
variable "spoke_vnets" {
  description = "Configuration for spoke VNets"
  type = map(object({
    address_space = list(string)
    subnets = map(object({
      address_prefixes                  = list(string)
      private_endpoint_network_policies = optional(bool, false)
    }))
  }))
  default = {
    web = {
      address_space = ["10.1.0.0/16"]
      subnets = {
        WebSubnet = {
          address_prefixes = ["10.1.1.0/24"]
        }
        AppSubnet = {
          address_prefixes = ["10.1.2.0/24"]
        }
      }
    }
    data = {
      address_space = ["10.2.0.0/16"]
      subnets = {
        DataSubnet = {
          address_prefixes                  = ["10.2.1.0/24"]
          private_endpoint_network_policies = true
        }
        StorageSubnet = {
          address_prefixes                  = ["10.2.2.0/24"]
          private_endpoint_network_policies = true
        }
      }
    }
    mgmt = {
      address_space = ["10.3.0.0/16"]
      subnets = {
        MgmtSubnet = {
          address_prefixes = ["10.3.1.0/24"]
        }
        ToolingSubnet = {
          address_prefixes = ["10.3.2.0/24"]
        }
      }
    }
  }
}


# Azure Firewall Variables
variable "firewall_sku_tier" {
  description = "SKU tier for Azure Firewall (Standard or Premium)"
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Standard", "Premium", "Basic"], var.firewall_sku_tier)
    error_message = "Firewall SKU must be Standard, Premium, or Basic."
  }
}

variable "enable_firewall" {
  description = "Whether to deploy Azure Firewall (set to false to save costs during development)"
  type        = bool
  default     = true
}


# Bastion Variables
variable "bastion_sku" {
  description = "SKU for Azure Bastion (Basic or Standard)"
  type        = string
  default     = "Basic"
  validation {
    condition     = contains(["Basic", "Standard"], var.bastion_sku)
    error_message = "Bastion SKU must be Basic or Standard."
  }
}

variable "enable_bastion" {
  description = "Whether to deploy Azure Bastion"
  type        = bool
  default     = true
}


# Monitoring Variables
variable "log_retention_days" {
  description = "Number of days to retain logs in Log Analytics"
  type        = number
  default     = 30
}

variable "enable_network_watcher" {
  description = "Whether to enable Network Watcher"
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Whether to enable NSG flow logs"
  type        = bool
  default     = true
}


# Private DNS Variables
variable "private_dns_zones" {
  description = "Private DNS zones to create"
  type        = list(string)
  default = [
    "privatelink.database.windows.net",
    "privatelink.blob.core.windows.net",
    "privatelink.vaultcore.azure.net",
    "privatelink.azurewebsites.net"
  ]
}


# VM Variables (Optional - for testing)
variable "deploy_test_vms" {
  description = "Whether to deploy test VMs in spokes"
  type        = bool
  default     = false
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "SSH public key for Linux VMs"
  type        = string
  default     = ""
  sensitive   = true
}
