
# Spoke Network Module - Variables
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

variable "address_space" {
  description = "Address space for the Spoke VNet"
  type        = list(string)
}

variable "subnets" {
  description = "Subnets configuration"
  type = map(object({
    address_prefixes                  = list(string)
    private_endpoint_network_policies = optional(bool, false)
  }))
}

variable "hub_vnet_id" {
  description = "Resource ID of the Hub VNet"
  type        = string
}

variable "hub_vnet_name" {
  description = "Name of the Hub VNet"
  type        = string
}

variable "hub_resource_group_name" {
  description = "Resource group name of the Hub VNet"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}
