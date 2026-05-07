# =============================================================================
# Primary Region Outputs
# =============================================================================

output "primary_resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.main.name
}

output "primary_vnet_id" {
  description = "Primary region VNet ID"
  value       = module.networking_primary.vnet_id
}

output "primary_lb_frontend_ip" {
  description = "Primary region ILB frontend private IP (AG listener)"
  value       = "10.1.1.10"
}

output "primary_pls_id" {
  description = "Primary region Private Link Service ID"
  value       = module.pls_primary.pls_id
}

output "primary_pls_alias" {
  description = "Primary region PLS alias — use in Snowflake SYSTEM$PROVISION_PRIVATELINK_ENDPOINT"
  value       = module.pls_primary.pls_alias
}

output "primary_sql_vm_ips" {
  description = "Primary region SQL VM private IPs"
  value = [
    module.sql_vm_primary_1.nic_private_ip,
    module.sql_vm_primary_2.nic_private_ip
  ]
}

# =============================================================================
# Secondary Region Outputs
# =============================================================================

output "secondary_resource_group_name" {
  description = "Resource group name (same as primary — single RG)"
  value       = azurerm_resource_group.main.name
}

output "secondary_vnet_id" {
  description = "Secondary region VNet ID"
  value       = module.networking_secondary.vnet_id
}

output "secondary_lb_frontend_ip" {
  description = "Secondary region ILB frontend private IP (AG listener)"
  value       = "10.2.1.10"
}

output "secondary_pls_id" {
  description = "Secondary region Private Link Service ID"
  value       = module.pls_secondary.pls_id
}

output "secondary_pls_alias" {
  description = "Secondary region PLS alias — use in Snowflake SYSTEM$PROVISION_PRIVATELINK_ENDPOINT"
  value       = module.pls_secondary.pls_alias
}

output "secondary_sql_vm_ips" {
  description = "Secondary region SQL VM private IPs"
  value = [
    module.sql_vm_secondary_1.nic_private_ip,
    module.sql_vm_secondary_2.nic_private_ip
  ]
}

# =============================================================================
# Shared / Cross-Region Outputs
# =============================================================================

output "cloud_witness_storage_account" {
  description = "Cloud Witness storage account name for WSFC quorum configuration"
  value       = module.cloud_witness.storage_account_name
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID"
  value       = module.monitoring.workspace_id
}

# =============================================================================
# Snowflake Integration Instructions
# =============================================================================

output "snowflake_integration_guide" {
  description = "Instructions for Snowflake PE provisioning"
  value       = <<-EOT
    ========================================================================
    SNOWFLAKE PRIVATE ENDPOINT PROVISIONING GUIDE
    ========================================================================

    After Terraform deployment, provision 4 Private Endpoints from Snowflake:

    1. Snowflake Primary (East US 2) → SQL Primary (East US 2):
       SELECT SYSTEM$PROVISION_PRIVATELINK_ENDPOINT(
         '<primary_pls_resource_id>',
         '<sql_fqdn>',
         'sqlServer'
       );

    2. Snowflake Secondary (Central US) → SQL Primary (East US 2) [cross-region]:
       SELECT SYSTEM$PROVISION_PRIVATELINK_ENDPOINT(
         '<primary_pls_resource_id>',
         '<sql_fqdn>',
         'sqlServer'
       );

    3. Snowflake Secondary (Central US) → SQL Secondary (Central US):
       SELECT SYSTEM$PROVISION_PRIVATELINK_ENDPOINT(
         '<secondary_pls_resource_id>',
         '<sql_fqdn>',
         'sqlServer'
       );

    4. Snowflake Primary (East US 2) → SQL Secondary (Central US) [cross-region]:
       SELECT SYSTEM$PROVISION_PRIVATELINK_ENDPOINT(
         '<secondary_pls_resource_id>',
         '<sql_fqdn>',
         'sqlServer'
       );

    Then approve each PE connection in the Azure Portal under
    Private Link Service > Private endpoint connections.

    IMPORTANT: Snowflake Business Critical edition required for outbound PE.
    ========================================================================
  EOT
}
