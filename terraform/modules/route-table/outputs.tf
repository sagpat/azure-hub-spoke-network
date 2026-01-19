
# Route Table Module - Outputs
output "id" {
  description = "Route Table ID"
  value       = azurerm_route_table.spoke.id
}

output "name" {
  description = "Route Table name"
  value       = azurerm_route_table.spoke.name
}

output "routes" {
  description = "List of routes in the route table"
  value = [
    azurerm_route.to_firewall.name,
    azurerm_route.to_spokes.name
  ]
}
