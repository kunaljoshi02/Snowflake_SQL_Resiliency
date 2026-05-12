output "container_app_url" {
  description = "FQDN of the Container App"
  value       = azurerm_container_app.this.ingress[0].fqdn
}

output "container_app_env_id" {
  description = "ID of the Container App Environment"
  value       = azurerm_container_app_environment.this.id
}

output "container_app_subnet_id" {
  description = "ID of the Container Apps subnet"
  value       = azurerm_subnet.container_apps.id
}
