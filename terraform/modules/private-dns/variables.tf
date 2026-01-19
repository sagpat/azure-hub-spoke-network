
# Private DNS Module - Variables
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "dns_zones" {
  description = "List of Private DNS zone names to create"
  type        = list(string)
}

variable "hub_vnet_id" {
  description = "Resource ID of the Hub VNet"
  type        = string
}

variable "spoke_vnet_ids" {
  description = "Map of spoke names to VNet IDs"
  type        = map(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}
