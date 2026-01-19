
# Network Security Group Module - Outputs
output "nsg_ids" {
  description = "Map of NSG names to IDs"
  value       = { for k, v in azurerm_network_security_group.subnets : k => v.id }
}

output "nsg_names" {
  description = "Map of subnet names to NSG names"
  value       = { for k, v in azurerm_network_security_group.subnets : k => v.name }
}
