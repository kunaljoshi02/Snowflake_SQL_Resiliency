output "function_app_url" {
  description = "Function App default hostname"
  value       = azurerm_linux_function_app.failover.default_hostname
}

output "function_app_id" {
  description = "Function App resource ID"
  value       = azurerm_linux_function_app.failover.id
}

output "function_app_identity_principal_id" {
  description = "Function App managed identity principal ID"
  value       = azurerm_linux_function_app.failover.identity[0].principal_id
}

output "key_vault_id" {
  description = "Key Vault resource ID"
  value       = azurerm_key_vault.failover.id
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.failover.vault_uri
}

output "action_group_id" {
  description = "Action Group resource ID"
  value       = azurerm_monitor_action_group.failover.id
}
