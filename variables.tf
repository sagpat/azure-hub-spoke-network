variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "hub_vnet_address_space" {
  description = "Address space for hub VNet"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "spoke_prod_vnet_address_space" {
  description = "Address space for production spoke VNet"
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "spoke_dev_vnet_address_space" {
  description = "Address space for development spoke VNet"
  type        = list(string)
  default     = ["10.2.0.0/16"]
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureadmin"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "HubSpokeNetwork"
    ManagedBy = "Terraform"
  }
}
