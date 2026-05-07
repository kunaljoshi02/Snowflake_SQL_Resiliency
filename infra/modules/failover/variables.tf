variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region for failover infrastructure"
  type        = string
}

variable "key_vault_name" {
  description = "Name for the Key Vault storing Snowflake credentials"
  type        = string
}

variable "func_storage_name" {
  description = "Globally unique storage account name for Function App"
  type        = string
}

variable "app_service_plan_name" {
  description = "Name for the App Service Plan (Consumption)"
  type        = string
}

variable "app_insights_name" {
  description = "Name for Application Insights"
  type        = string
}

variable "function_app_name" {
  description = "Name for the Function App"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for App Insights"
  type        = string
}

# Snowflake configuration
variable "snowflake_account" {
  description = "Snowflake account identifier (e.g., xy12345.east-us-2.azure)"
  type        = string
}

variable "snowflake_user" {
  description = "Snowflake automation user for SQL API"
  type        = string
}

variable "snowflake_role" {
  description = "Snowflake role for failover operations"
  type        = string
  default     = "ACCOUNTADMIN"
}

variable "snowflake_warehouse" {
  description = "Snowflake warehouse for executing failover SQL"
  type        = string
  default     = "COMPUTE_WH"
}

variable "snowflake_network_rule" {
  description = "Fully qualified Snowflake network rule name (e.g., mydb.rules.sql_private_rule)"
  type        = string
}

variable "snowflake_eai" {
  description = "Snowflake external access integration name"
  type        = string
  default     = ""
}

variable "primary_pls_host" {
  description = "Primary PLS host:port that Snowflake connects to"
  type        = string
}

variable "secondary_pls_host" {
  description = "Secondary PLS host:port that Snowflake connects to"
  type        = string
}

variable "cooldown_seconds" {
  description = "Cooldown period between failover events (seconds)"
  type        = number
  default     = 300
}

# Load Balancer IDs for metric alerts
variable "primary_lb_id" {
  description = "Resource ID of the primary region ILB"
  type        = string
}

variable "secondary_lb_id" {
  description = "Resource ID of the secondary region ILB"
  type        = string
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default     = {}
}
