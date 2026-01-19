
# Azure Firewall Module - Variables
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "name_suffix" {
  description = "Suffix for resource names"
  type        = string
}

variable "sku_tier" {
  description = "SKU tier for Azure Firewall"
  type        = string
  default     = "Standard"
}

variable "subnet_id" {
  description = "Subnet ID for Azure Firewall (AzureFirewallSubnet)"
  type        = string
}

variable "management_subnet_id" {
  description = "Subnet ID for Azure Firewall Management (AzureFirewallManagementSubnet) - required for Basic tier"
  type        = string
  default     = null
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for diagnostics"
  type        = string
}

variable "spoke_address_prefixes" {
  description = "List of spoke address prefixes for firewall rules"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}
