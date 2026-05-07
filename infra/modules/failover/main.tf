# =============================================================================
# Failover Automation Infrastructure
# Azure Function + Monitor Alerts + Action Group + Key Vault
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# Key Vault for Snowflake credentials
# ─────────────────────────────────────────────────────────────────────────────
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "failover" {
  name                       = var.key_vault_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  rbac_authorization_enabled = true
  tags                       = var.tags
}

# ─────────────────────────────────────────────────────────────────────────────
# Storage Account for Function App + state table
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_storage_account" "func" {
  name                            = var.func_storage_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  tags                            = var.tags
}

# ─────────────────────────────────────────────────────────────────────────────
# App Service Plan (Consumption)
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_service_plan" "failover" {
  name                = var.app_service_plan_name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = var.tags
}

# ─────────────────────────────────────────────────────────────────────────────
# Application Insights
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_application_insights" "failover" {
  name                = var.app_insights_name
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = var.log_analytics_workspace_id
  application_type    = "web"
  tags                = var.tags
}

# ─────────────────────────────────────────────────────────────────────────────
# Function App
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_linux_function_app" "failover" {
  name                       = var.function_app_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  service_plan_id            = azurerm_service_plan.failover.id
  storage_account_name       = azurerm_storage_account.func.name
  storage_uses_managed_identity = true
  tags                       = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.11"
    }
    application_insights_connection_string = azurerm_application_insights.failover.connection_string
  }

  app_settings = {
    "SNOWFLAKE_ACCOUNT"         = var.snowflake_account
    "SNOWFLAKE_USER"            = var.snowflake_user
    "SNOWFLAKE_ROLE"            = var.snowflake_role
    "SNOWFLAKE_WAREHOUSE"       = var.snowflake_warehouse
    "KEY_VAULT_URL"             = azurerm_key_vault.failover.vault_uri
    "PRIMARY_PLS_HOST"          = var.primary_pls_host
    "SECONDARY_PLS_HOST"        = var.secondary_pls_host
    "SNOWFLAKE_NETWORK_RULE"    = var.snowflake_network_rule
    "SNOWFLAKE_EAI"             = var.snowflake_eai
    "COOLDOWN_SECONDS"          = tostring(var.cooldown_seconds)
  }
}

# Grant Function App access to Key Vault secrets
resource "azurerm_role_assignment" "func_kv_reader" {
  scope                = azurerm_key_vault.failover.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.failover.identity[0].principal_id
}

# Grant Function App access to Storage (for state table + hosting)
resource "azurerm_role_assignment" "func_storage_blob" {
  scope                = azurerm_storage_account.func.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_linux_function_app.failover.identity[0].principal_id
}

resource "azurerm_role_assignment" "func_storage_table" {
  scope                = azurerm_storage_account.func.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_linux_function_app.failover.identity[0].principal_id
}

# ─────────────────────────────────────────────────────────────────────────────
# Action Group (calls the Function App webhook)
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_monitor_action_group" "failover" {
  name                = "ag-sql-failover"
  resource_group_name = var.resource_group_name
  short_name          = "sqlfailover"
  tags                = var.tags

  azure_function_receiver {
    name                     = "failover-function"
    function_app_resource_id = azurerm_linux_function_app.failover.id
    function_name            = "FailoverHandler"
    http_trigger_url         = "https://${azurerm_linux_function_app.failover.default_hostname}/api/failover"
    use_common_alert_schema  = true
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Metric Alerts — ILB Health Probe (DipAvailability)
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_monitor_metric_alert" "primary_lb_health" {
  name                = "alert-ilb-health-primary-eastus2"
  resource_group_name = var.resource_group_name
  scopes              = [var.primary_lb_id]
  description         = "Primary ILB health probe dropped below threshold"
  severity            = 0
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Network/loadBalancers"
    metric_name      = "DipAvailability"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 50
  }

  action {
    action_group_id = azurerm_monitor_action_group.failover.id
  }
}

resource "azurerm_monitor_metric_alert" "secondary_lb_health" {
  name                = "alert-ilb-health-secondary-westus3"
  resource_group_name = var.resource_group_name
  scopes              = [var.secondary_lb_id]
  description         = "Secondary ILB health probe dropped below threshold"
  severity            = 0
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Network/loadBalancers"
    metric_name      = "DipAvailability"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 50
  }

  action {
    action_group_id = azurerm_monitor_action_group.failover.id
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Additional Alert — VipAvailability (data path health)
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_monitor_metric_alert" "primary_lb_vip" {
  name                = "alert-ilb-datapath-primary-eastus2"
  resource_group_name = var.resource_group_name
  scopes              = [var.primary_lb_id]
  description         = "Primary ILB data path availability dropped"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Network/loadBalancers"
    metric_name      = "VipAvailability"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 50
  }

  action {
    action_group_id = azurerm_monitor_action_group.failover.id
  }
}

resource "azurerm_monitor_metric_alert" "secondary_lb_vip" {
  name                = "alert-ilb-datapath-secondary-westus3"
  resource_group_name = var.resource_group_name
  scopes              = [var.secondary_lb_id]
  description         = "Secondary ILB data path availability dropped"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Network/loadBalancers"
    metric_name      = "VipAvailability"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 50
  }

  action {
    action_group_id = azurerm_monitor_action_group.failover.id
  }
}
