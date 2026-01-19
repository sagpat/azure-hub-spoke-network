
# Azure Bastion Module - Outputs
output "id" {
  description = "Azure Bastion ID"
  value       = azurerm_bastion_host.main.id
}

output "name" {
  description = "Azure Bastion name"
  value       = azurerm_bastion_host.main.name
}

output "dns_name" {
  description = "Azure Bastion DNS name"
  value       = azurerm_bastion_host.main.dns_name
}

output "public_ip_address" {
  description = "Azure Bastion public IP address"
  value       = azurerm_public_ip.bastion.ip_address
}
