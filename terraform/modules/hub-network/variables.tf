
# Hub Network Module - Variables
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

variable "address_space" {
  description = "Address space for the Hub VNet"
  type        = list(string)
}

variable "subnets" {
  description = "Subnets configuration"
  type = map(object({
    address_prefixes = list(string)
  }))
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}
