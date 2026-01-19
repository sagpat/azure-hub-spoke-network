
# Monitoring Module - Outputs
output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace resource ID"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Log Analytics Workspace name"
  value       = azurerm_log_analytics_workspace.main.name
}

output "log_analytics_workspace_workspace_id" {
  description = "Log Analytics Workspace ID (GUID)"
  value       = azurerm_log_analytics_workspace.main.workspace_id
}

output "storage_account_id" {
  description = "Storage Account ID for flow logs"
  value       = azurerm_storage_account.flow_logs.id
}

output "storage_account_name" {
  description = "Storage Account name for flow logs"
  value       = azurerm_storage_account.flow_logs.name
}
