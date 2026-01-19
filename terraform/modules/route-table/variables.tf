
# Route Table Module - Variables
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
  description = "Name of the spoke"
  type        = string
}

variable "firewall_private_ip" {
  description = "Private IP address of Azure Firewall"
  type        = string
}

variable "subnet_ids" {
  description = "Map of subnet names to IDs to associate with route table"
  type        = map(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}
