output "pls_id" {
  description = "Resource ID of the Private Link Service."
  value       = azurerm_private_link_service.this.id
}

output "pls_alias" {
  description = "Alias of the Private Link Service (used by Snowflake to provision a Private Endpoint)."
  value       = azurerm_private_link_service.this.alias
}
