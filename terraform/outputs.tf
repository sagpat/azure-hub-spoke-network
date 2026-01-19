
# Outputs
# Resource Groups
output "resource_groups" {
  description = "Resource group names"
  value = {
    hub        = azurerm_resource_group.hub.name
    spokes     = { for k, v in azurerm_resource_group.spokes : k => v.name }
    monitoring = azurerm_resource_group.monitoring.name
  }
}

# Hub Network
output "hub_vnet" {
  description = "Hub VNet details"
  value = {
    id            = module.hub_network.vnet_id
    name          = module.hub_network.vnet_name
    address_space = module.hub_network.address_space
    subnet_ids    = module.hub_network.subnet_ids
  }
}

# Spoke Networks
output "spoke_vnets" {
  description = "Spoke VNet details"
  value = {
    for k, v in module.spoke_networks : k => {
      id            = v.vnet_id
      name          = v.vnet_name
      address_space = v.address_space
      subnet_ids    = v.subnet_ids
    }
  }
}

# Azure Firewall
output "firewall" {
  description = "Azure Firewall details"
  value = var.enable_firewall ? {
    id                 = module.firewall[0].id
    name               = module.firewall[0].name
    private_ip_address = module.firewall[0].private_ip_address
    public_ip_address  = module.firewall[0].public_ip_address
  } : null
}

# Azure Bastion
output "bastion" {
  description = "Azure Bastion details"
  value = var.enable_bastion ? {
    id        = module.bastion[0].id
    name      = module.bastion[0].name
    dns_name  = module.bastion[0].dns_name
  } : null
}

# Log Analytics
output "log_analytics" {
  description = "Log Analytics Workspace details"
  value = {
    id           = module.monitoring.log_analytics_workspace_id
    name         = module.monitoring.log_analytics_workspace_name
    workspace_id = module.monitoring.log_analytics_workspace_workspace_id
  }
}

# Private DNS Zones
output "private_dns_zones" {
  description = "Private DNS Zone IDs"
  value       = module.private_dns.dns_zone_ids
}

# Test VMs
output "test_vms" {
  description = "Test VM details for connectivity testing"
  value = var.deploy_test_vms ? {
    for k, v in module.test_vms : k => {
      vm_name            = v.vm_name
      private_ip_address = v.private_ip_address
      vm_id              = v.vm_id
    }
  } : {}
}

# Connection Strings for Testing
output "connection_info" {
  description = "Useful connection information"
  value = {
    bastion_connect_command = var.enable_bastion ? "az network bastion ssh --name ${module.bastion[0].name} --resource-group ${azurerm_resource_group.hub.name} --target-resource-id <VM_RESOURCE_ID> --auth-type ssh-key --username azureuser --ssh-key <PATH_TO_KEY>" : "Bastion not deployed"
    firewall_private_ip     = var.enable_firewall ? module.firewall[0].private_ip_address : "Firewall not deployed"
  }
}
