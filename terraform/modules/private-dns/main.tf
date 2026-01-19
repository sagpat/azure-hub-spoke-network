
# Private DNS Module - Main Configuration
# Create Private DNS Zones
resource "azurerm_private_dns_zone" "zones" {
  for_each = toset(var.dns_zones)

  name                = each.value
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Link DNS Zones to Hub VNet
resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  for_each = toset(var.dns_zones)

  name                  = "link-hub"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.zones[each.key].name
  virtual_network_id    = var.hub_vnet_id
  registration_enabled  = false

  tags = var.tags
}

# Link DNS Zones to Spoke VNets
resource "azurerm_private_dns_zone_virtual_network_link" "spokes" {
  for_each = {
    for pair in setproduct(var.dns_zones, keys(var.spoke_vnet_ids)) :
    "${pair[0]}-${pair[1]}" => {
      zone      = pair[0]
      spoke     = pair[1]
      vnet_id   = var.spoke_vnet_ids[pair[1]]
    }
  }

  name                  = "link-spoke-${each.value.spoke}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.zones[each.value.zone].name
  virtual_network_id    = each.value.vnet_id
  registration_enabled  = false

  tags = var.tags
}
