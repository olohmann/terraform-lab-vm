data "azurerm_resource_group" "rg" {
  name = "${var.resource_group_name}"
}

locals {
  unique = "${substr(sha256(data.azurerm_resource_group.rg.id), 0, 8)}"
}

resource "azurerm_storage_account" "script_storage" {
  name                     = "vm${local.unique}"
  resource_group_name      = "${data.azurerm_resource_group.rg.name}"
  location                 = "${data.azurerm_resource_group.rg.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "script_container" {
  name                  = "scripts"
  resource_group_name   = "${data.azurerm_resource_group.rg.name}"
  storage_account_name  = "${azurerm_storage_account.script_storage.name}"
  container_access_type = "blob"
}

resource "azurerm_storage_blob" "win_script_blob" {
  name = "installLabVM.ps1"

  resource_group_name    = "${data.azurerm_resource_group.rg.name}"
  storage_account_name   = "${azurerm_storage_account.script_storage.name}"
  storage_container_name = "${azurerm_storage_container.script_container.name}"
  type                   = "block"
  source                 = "${path.module}/installLabVM.ps1"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${local.unique}"
  address_space       = ["10.0.0.0/24"]
  location            = "${data.azurerm_resource_group.rg.location}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"
}

resource "azurerm_subnet" "subnet" {
  name                 = "default"
  resource_group_name  = "${data.azurerm_resource_group.rg.name}"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  address_prefix       = "10.0.0.0/24"
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${local.unique}"
  location            = "${data.azurerm_resource_group.rg.location}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"

  security_rule {
    name                       = "RDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ------------------- Windows VM ---------------------------------------------
resource "azurerm_public_ip" "win_pip" {
  name                = "pip-${local.unique}"
  location            = "${data.azurerm_resource_group.rg.location}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"

  allocation_method = "Dynamic"
  domain_name_label = "vm-${local.unique}"
}

resource "azurerm_network_interface" "win_nic" {
  name                      = "nic-${local.unique}"
  location                  = "${data.azurerm_resource_group.rg.location}"
  resource_group_name       = "${data.azurerm_resource_group.rg.name}"
  network_security_group_id = "${azurerm_network_security_group.nsg.id}"

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = "${azurerm_subnet.subnet.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.win_pip.id}"
  }
}

resource "azurerm_virtual_machine" "win_vm" {
  name                  = "vm${local.unique}"
  location              = "${data.azurerm_resource_group.rg.location}"
  resource_group_name   = "${data.azurerm_resource_group.rg.name}"
  network_interface_ids = ["${azurerm_network_interface.win_nic.id}"]
  vm_size               = "${var.vm_size}"

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftVisualStudio"
    offer     = "VisualStudio"
    sku       = "VS-2017-Comm-Latest-WS2016"
    version   = "latest"
  }

  storage_os_disk {
    name          = "osdisk-${local.unique}"
    caching       = "ReadWrite"
    create_option = "FromImage"
    disk_size_gb  = 512
  }

  os_profile {
    computer_name  = "vm${local.unique}"
    admin_username = "${var.username}"
    admin_password = "${var.password}"
  }

  os_profile_windows_config {
    provision_vm_agent        = true
    enable_automatic_upgrades = false
  }
}

resource "azurerm_virtual_machine_extension" "win_ext" {
  name                = "vm-ext-${local.unique}"
  location            = "${data.azurerm_resource_group.rg.location}"
  resource_group_name = "${data.azurerm_resource_group.rg.name}"

  virtual_machine_name = "${azurerm_virtual_machine.win_vm.name}"

  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  settings = <<SETTINGS
    {
        "fileUris": ["${azurerm_storage_account.script_storage.primary_blob_endpoint}${azurerm_storage_container.script_container.name}/${azurerm_storage_blob.win_script_blob.name}"],
        "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File ./installLabVM.ps1"
    }
SETTINGS

  depends_on = ["azurerm_storage_blob.win_script_blob"]
}

