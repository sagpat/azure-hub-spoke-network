
# VM Module - Main Configuration

# This module creates test VMs in spoke networks to validate connectivity
# Network Interface for the VM
resource "azurerm_network_interface" "vm" {
  name                = "nic-${var.name_prefix}-${var.spoke_name}-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

# Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-${var.name_prefix}-${var.spoke_name}-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.vm.id
  ]

  # Use SSH key authentication (more secure, works with Bastion)
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  # Disable password authentication for security
  disable_password_authentication = true

  os_disk {
    name                 = "osdisk-${var.name_prefix}-${var.spoke_name}-${var.name_suffix}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Ubuntu 22.04 LTS - lightweight and good for testing
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Custom data script to install networking tools
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y curl wget traceroute dnsutils net-tools tcpdump nmap
    echo "VM provisioned at $(date)" > /tmp/provision.log
    echo "Hostname: $(hostname)" >> /tmp/provision.log
    echo "Private IP: $(hostname -I)" >> /tmp/provision.log
  EOF
  )

  tags = var.tags
}
