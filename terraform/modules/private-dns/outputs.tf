
# Private DNS Module - Outputs
output "dns_zone_ids" {
  description = "Map of DNS zone names to IDs"
  value       = { for k, v in azurerm_private_dns_zone.zones : k => v.id }
}

output "dns_zone_names" {
  description = "List of DNS zone names"
  value       = [for v in azurerm_private_dns_zone.zones : v.name]
}
