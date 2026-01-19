
# Azure Firewall Module - Outputs
output "id" {
  description = "Azure Firewall ID"
  value       = azurerm_firewall.main.id
}

output "name" {
  description = "Azure Firewall name"
  value       = azurerm_firewall.main.name
}

output "private_ip_address" {
  description = "Azure Firewall private IP address"
  value       = azurerm_firewall.main.ip_configuration[0].private_ip_address
}

output "public_ip_address" {
  description = "Azure Firewall public IP address"
  value       = azurerm_public_ip.firewall.ip_address
}

output "policy_id" {
  description = "Azure Firewall Policy ID"
  value       = azurerm_firewall_policy.main.id
}
