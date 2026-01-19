
# Azure Bastion Module - Variables
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

variable "sku" {
  description = "SKU for Azure Bastion (Basic or Standard)"
  type        = string
  default     = "Basic"
}

variable "subnet_id" {
  description = "Subnet ID for Azure Bastion (AzureBastionSubnet)"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for diagnostics"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}
