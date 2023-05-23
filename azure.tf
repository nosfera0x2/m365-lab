provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "myResourceGroup"
  location = "eastus"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "mySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "client_nic" {
  name                = "client-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "client-ipconfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "dc_nic" {
  name                = "dc-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "dc-ipconfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "client_vm" {
  name                  = "client-vm"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.client_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "${azurerm_windows_virtual_machine.client_vm.name}-osdisk"
    create_option        = "FromImage"
    image_reference_id   = "/subscriptions/<subscription-id>/providers/Microsoft.Compute/images/Win2019Datacenter-Server-Core-2022.01.11-en.us-127GB.vhd"
    disk_size_gb         = 127
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter-Core-with-Containers-smalldisk"
    version   = "latest"
  }

  admin_username         = "<admin-username>"
  admin_password         = "<admin-password>"
}

resource "azurerm_windows_virtual_machine" "dc_vm" {
  name                  = "dc-vm"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.dc_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "${azurerm_windows_virtual_machine.dc_vm.name}-osdisk"
    create_option        = "FromImage"
    image_reference_id   = "/subscriptions/<subscription-id>/providers/Microsoft.Compute/images/Win2019Datacenter-Server-Core-2022.01.11-en.us-127GB.vhd"
    disk_size_gb         = 127
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "<windows-server-sku>"
    version   = "<windows-server-version>"
  }

  admin_username         = "<admin-username>"
  admin_password         = "<admin-password>"

}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "client_nic_association" {
    network_interface_id         	= azurerm_network_interface.client_nic.id
    application_gateway_id       	= "<application-gateway-id>"
    backend_address_pool_id      	= "<backend-address-pool-id>"
 }
 
 resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "dc_nic_association" {
    network_interface_id         	= azurerm_network_interface.dc_nic.id
    application_gateway_id       	= "<application-gateway-id>"
    backend_address_pool_id      	= "<backend-address-pool-id>"
 }
 
 resource "azurerm_virtual_machine_extension" "dc_extension" {
   name                 = "dc-extension"
   location             = azurerm_resource_group.rg.location
   resource_group_name  = azurerm_resource_group.rg.name
   virtual_machine_id   = azurerm_windows_virtual_machine.dc_vm.id
   publisher            = "Microsoft.Compute"
   type                 = "JsonADDomainExtension"
   type_handler_version = "1.3"
   auto_upgrade_minor_version = true
 
   settings = <<SETTINGS
     {
       "Name": "${var.domainName}",
       "User": "${var.domainAdminUsername}",
       "OUPath": "${var.ouPath}",
       "Restart": "${var.restart}"
     }
 SETTINGS
 
   protected_settings = <<PROTECTED_SETTINGS
     {
       "Password": "${var.domainAdminPassword}"
     }
 PROTECTED_SETTINGS
 }
 
 output "client_vm_ip_address" {
   value = azurerm_windows_virtual_machine.client_vm.private_ip_address
 }
 
 output "dc_vm_ip_address" {
   value = azurerm_windows_virtual_machine.dc_vm.private_ip_address
 }
 
