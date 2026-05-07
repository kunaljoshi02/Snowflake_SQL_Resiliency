output "vm_id" {
  description = "Resource ID of the SQL Server VM."
  value       = azurerm_windows_virtual_machine.this.id
}

output "vm_name" {
  description = "Name of the SQL Server VM."
  value       = azurerm_windows_virtual_machine.this.name
}

output "nic_id" {
  description = "Resource ID of the VM network interface."
  value       = azurerm_network_interface.this.id
}

output "nic_private_ip" {
  description = "Private IP address of the VM network interface."
  value       = azurerm_network_interface.this.private_ip_address
}
