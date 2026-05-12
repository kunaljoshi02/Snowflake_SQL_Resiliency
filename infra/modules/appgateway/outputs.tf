output "appgw_id" {
  description = "Resource ID of the Application Gateway"
  value       = azurerm_application_gateway.this.id
}

output "appgw_private_ip" {
  description = "Private frontend IP address of the Application Gateway"
  value       = cidrhost(var.appgw_subnet_prefix, 10)
}

output "appgw_public_ip" {
  description = "Public IP address of the Application Gateway"
  value       = azurerm_public_ip.appgw.ip_address
}

output "pe_primary_ip" {
  description = "Private IP of the Private Endpoint to primary PLS"
  value       = azurerm_private_endpoint.primary_sql.private_service_connection[0].private_ip_address
}

output "pe_secondary_ip" {
  description = "Private IP of the Private Endpoint to secondary PLS"
  value       = azurerm_private_endpoint.secondary_sql.private_service_connection[0].private_ip_address
}

output "appgw_subnet_id" {
  description = "Resource ID of the Application Gateway subnet"
  value       = azurerm_subnet.appgw.id
}

output "pe_subnet_id" {
  description = "Resource ID of the Private Endpoints subnet"
  value       = azurerm_subnet.pe.id
}
