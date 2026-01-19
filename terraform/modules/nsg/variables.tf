
# Network Security Group Module - Variables
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

variable "spoke_name" {
  description = "Name of the spoke (web, data, mgmt)"
  type        = string
}

variable "subnets" {
  description = "Subnets configuration"
  type = map(object({
    address_prefixes                  = list(string)
    private_endpoint_network_policies = optional(bool, false)
  }))
}

variable "subnet_ids" {
  description = "Map of subnet names to IDs"
  type        = map(string)
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for diagnostics"
  type        = string
  default     = null
}

variable "enable_diagnostics" {
  description = "Enable diagnostic settings for NSGs"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}
