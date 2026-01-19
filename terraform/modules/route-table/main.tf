
# Route Table Module - Main Configuration
# Route Table for Spoke
resource "azurerm_route_table" "spoke" {
  name                          = "rt-${var.name_prefix}-spoke-${var.spoke_name}-${var.name_suffix}"
  location                      = var.location
  resource_group_name           = var.resource_group_name

  tags = var.tags
}

# Default route to Azure Firewall
resource "azurerm_route" "to_firewall" {
  name                   = "route-to-firewall"
  resource_group_name    = var.resource_group_name
  route_table_name       = azurerm_route_table.spoke.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip
}

# Route to other spokes through firewall (spoke-to-spoke inspection)
resource "azurerm_route" "to_spokes" {
  name                   = "route-to-spokes"
  resource_group_name    = var.resource_group_name
  route_table_name       = azurerm_route_table.spoke.name
  address_prefix         = "10.0.0.0/8"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip
}

# Associate Route Table with Subnets
resource "azurerm_subnet_route_table_association" "spoke_subnets" {
  for_each = var.subnet_ids

  subnet_id      = each.value
  route_table_id = azurerm_route_table.spoke.id
}
