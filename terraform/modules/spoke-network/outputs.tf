
# Spoke Network Module - Outputs
output "vnet_id" {
  description = "Spoke VNet ID"
  value       = azurerm_virtual_network.spoke.id
}

output "vnet_name" {
  description = "Spoke VNet name"
  value       = azurerm_virtual_network.spoke.name
}

output "address_space" {
  description = "Spoke VNet address space"
  value       = azurerm_virtual_network.spoke.address_space
}

output "subnet_ids" {
  description = "Map of subnet names to IDs"
  value       = { for k, v in azurerm_subnet.spoke_subnets : k => v.id }
}

output "subnet_address_prefixes" {
  description = "Map of subnet names to address prefixes"
  value       = { for k, v in azurerm_subnet.spoke_subnets : k => v.address_prefixes }
}

output "peering_spoke_to_hub_id" {
  description = "Spoke to Hub peering ID"
  value       = azurerm_virtual_network_peering.spoke_to_hub.id
}
