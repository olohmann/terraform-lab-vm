data "azurerm_resource_group" "rg" {
  count = length(var.resource_group_names)
  name  = element(var.resource_group_names, count.index)
}

resource "random_id" "rand" {
  count = length(var.resource_group_names)

  keepers = {
    rg_id = data.azurerm_resource_group.rg.*.id[count.index]
  }

  byte_length = 6
}


resource "azurerm_storage_account" "script_storage" {
  count = length(var.resource_group_names)

  name                     = "vm${format("%02d", count.index)}${random_id.rand.*.hex[count.index]}"
  resource_group_name      = data.azurerm_resource_group.rg.*.name[count.index]
  location                 = data.azurerm_resource_group.rg.*.location[count.index]
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


resource "azurerm_storage_container" "script_container" {
  count = length(var.resource_group_names)

  name                  = "scripts"
  resource_group_name   = data.azurerm_resource_group.rg.*.name[count.index]
  storage_account_name  = azurerm_storage_account.script_storage.*.name[count.index]
  container_access_type = "blob"
}

resource "azurerm_storage_blob" "win_script_blob" {
  count = length(var.resource_group_names)

  name                   = "installLabVM.ps1"
  resource_group_name    = data.azurerm_resource_group.rg.*.name[count.index]
  storage_account_name   = azurerm_storage_account.script_storage.*.name[count.index]
  storage_container_name = azurerm_storage_container.script_container.*.name[count.index]
  type                   = "block"
  source                 = "${path.module}/installLabVM.ps1"
}

resource "azurerm_virtual_network" "vnet" {
  count = length(var.resource_group_names)

  name                = "vnet"
  address_space       = ["10.0.0.0/24"]
  resource_group_name = data.azurerm_resource_group.rg.*.name[count.index]
  location            = data.azurerm_resource_group.rg.*.location[count.index]
}

resource "azurerm_subnet" "subnet" {
  count = length(var.resource_group_names)

  name                 = "default"
  resource_group_name  = data.azurerm_resource_group.rg.*.name[count.index]
  virtual_network_name = azurerm_virtual_network.vnet.*.name[count.index]
  address_prefix       = "10.0.0.0/24"
}


resource "azurerm_network_security_group" "nsg" {
  count = length(var.resource_group_names)

  name                = "nsg"
  resource_group_name = data.azurerm_resource_group.rg.*.name[count.index]
  location            = data.azurerm_resource_group.rg.*.location[count.index]

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


resource "azurerm_public_ip" "win_pip" {
  count = length(var.resource_group_names)

  name                = "pip"
  resource_group_name = data.azurerm_resource_group.rg.*.name[count.index]
  location            = data.azurerm_resource_group.rg.*.location[count.index]
  allocation_method   = "Dynamic"
  domain_name_label   = "vm-${random_id.rand.*.hex[count.index]}"
}


# ------------------- Windows VM ---------------------------------------------
resource "azurerm_network_interface" "win_nic" {
  count = length(var.resource_group_names)

  name                      = "nic"
  resource_group_name       = data.azurerm_resource_group.rg.*.name[count.index]
  location                  = data.azurerm_resource_group.rg.*.location[count.index]
  network_security_group_id = azurerm_network_security_group.nsg.*.id[count.index]

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.subnet.*.id[count.index]
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.win_pip.*.id[count.index]
  }
}


resource "azurerm_virtual_machine" "win_vm" {
  count = length(var.resource_group_names)

  name                  = "vm"
  resource_group_name   = data.azurerm_resource_group.rg.*.name[count.index]
  location              = data.azurerm_resource_group.rg.*.location[count.index]
  network_interface_ids = list(azurerm_network_interface.win_nic.*.id[count.index])
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
    name          = "osdisk"
    caching       = "ReadWrite"
    create_option = "FromImage"
    disk_size_gb  = 512
  }

  os_profile {
    computer_name  = "vm"
    admin_username = var.usernames[count.index]
    admin_password = var.passwords[count.index]
  }

  os_profile_windows_config {
    provision_vm_agent        = true
    enable_automatic_upgrades = false
  }
}

resource "azurerm_virtual_machine_extension" "win_ext" {
  count = length(var.resource_group_names)

  name                 = "vm-ext"
  resource_group_name  = data.azurerm_resource_group.rg.*.name[count.index]
  location             = data.azurerm_resource_group.rg.*.location[count.index]
  virtual_machine_name = azurerm_virtual_machine.win_vm.*.name[count.index]

  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  settings = <<SETTINGS
    {
        "fileUris": ["${azurerm_storage_account.script_storage.*.primary_blob_endpoint[count.index]}${azurerm_storage_container.script_container.*.name[count.index]}/${azurerm_storage_blob.win_script_blob.*.name[count.index]}"],
        "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File ./installLabVM.ps1"
    }
SETTINGS
}
