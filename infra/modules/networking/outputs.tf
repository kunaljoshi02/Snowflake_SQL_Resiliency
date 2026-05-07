output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.this.name
}

output "sql_subnet_id" {
  description = "ID of the SQL VM subnet"
  value       = azurerm_subnet.sql.id
}

output "pls_subnet_id" {
  description = "ID of the PLS NAT subnet"
  value       = azurerm_subnet.pls_nat.id
}

output "sql_nsg_id" {
  description = "ID of the SQL subnet NSG"
  value       = azurerm_network_security_group.sql.id
}

output "pls_nsg_id" {
  description = "ID of the PLS NAT subnet NSG"
  value       = azurerm_network_security_group.pls_nat.id
}
