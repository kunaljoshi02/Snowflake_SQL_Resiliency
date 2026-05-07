###############################################################################
# Network Interface
###############################################################################
resource "azurerm_network_interface" "this" {
  name                          = "${var.vm_name}-nic"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  accelerated_networking_enabled = true
  tags                          = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

###############################################################################
# SQL Server Virtual Machine
###############################################################################
resource "azurerm_windows_virtual_machine" "this" {
  name                = var.vm_name
  computer_name       = substr(replace(var.vm_name, "-", ""), 0, 15)
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  zone                = var.zone
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  tags                = var.tags

  network_interface_ids = [azurerm_network_interface.this.id]

  source_image_reference {
    publisher = "MicrosoftSQLServer"
    offer     = "sql2022-ws2022"
    sku       = "enterprise-gen2"
    version   = "latest"
  }

  os_disk {
    name                 = "${var.vm_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }
}

###############################################################################
# Data Disk (SQL Data) – LUN 0, ReadOnly caching
###############################################################################
resource "azurerm_managed_disk" "data" {
  name                 = "${var.vm_name}-data"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb
  zone                 = var.zone
  tags                 = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  managed_disk_id    = azurerm_managed_disk.data.id
  virtual_machine_id = azurerm_windows_virtual_machine.this.id
  lun                = 0
  caching            = "ReadOnly"
}

###############################################################################
# Log Disk (SQL Logs) – LUN 1, no caching
###############################################################################
resource "azurerm_managed_disk" "log" {
  name                 = "${var.vm_name}-log"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.log_disk_size_gb
  zone                 = var.zone
  tags                 = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "log" {
  managed_disk_id    = azurerm_managed_disk.log.id
  virtual_machine_id = azurerm_windows_virtual_machine.this.id
  lun                = 1
  caching            = "None"
}

###############################################################################
# AdventureWorks Database Setup via Custom Script Extension
###############################################################################
resource "azurerm_virtual_machine_extension" "adventureworks" {
  count = var.install_adventureworks ? 1 : 0

  name                 = "${var.vm_name}-adventureworks"
  virtual_machine_id   = azurerm_windows_virtual_machine.this.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  tags                 = var.tags

  protected_settings = <<SETTINGS
    {
      "fileUris": ["https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2022.bak"],
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted -Command \"New-Item -ItemType Directory -Path 'C:\\SQLData' -Force; Copy-Item -Path 'AdventureWorks2022.bak' -Destination 'C:\\SQLData\\AdventureWorks2022.bak' -Force; $sqlCmd = \\\"RESTORE DATABASE [AdventureWorks2022] FROM DISK = N'C:\\SQLData\\AdventureWorks2022.bak' WITH MOVE N'AdventureWorks2022' TO N'C:\\SQLData\\AdventureWorks2022.mdf', MOVE N'AdventureWorks2022_log' TO N'C:\\SQLData\\AdventureWorks2022_log.ldf', REPLACE, STATS = 10\\\"; Invoke-Sqlcmd -Query $sqlCmd -ServerInstance 'localhost' -TrustServerCertificate\""
    }
  SETTINGS

  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.data,
    azurerm_virtual_machine_data_disk_attachment.log
  ]
}
