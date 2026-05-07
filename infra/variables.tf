# =============================================================================
# General
# =============================================================================

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the single resource group for all resources"
  type        = string
  default     = "rg-snowflake-sql-resiliency"
}

variable "environment" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
  default     = "prod"
}

# =============================================================================
# Regions
# =============================================================================

variable "primary_location" {
  description = "Primary Azure region"
  type        = string
  default     = "eastus2"
}

variable "primary_location_short" {
  description = "Short name for primary region (used in resource names)"
  type        = string
  default     = "eastus2"
}

variable "secondary_location" {
  description = "Secondary Azure region for DR"
  type        = string
  default     = "centralus"
}

variable "secondary_location_short" {
  description = "Short name for secondary region (used in resource names)"
  type        = string
  default     = "centralus"
}

variable "cloud_witness_location" {
  description = "Region for Cloud Witness storage account (third region for WSFC quorum)"
  type        = string
  default     = "eastus"
}

# =============================================================================
# Compute
# =============================================================================

variable "sql_vm_size" {
  description = "VM size for SQL Server VMs (primary region)"
  type        = string
  default     = "Standard_E4ds_v5"
}

variable "sql_vm_size_secondary" {
  description = "VM size for SQL Server VMs (secondary region). Falls back to sql_vm_size if not set."
  type        = string
  default     = ""
}

variable "admin_username" {
  description = "Admin username for SQL Server VMs"
  type        = string
  default     = "sqladmin"
}

variable "admin_password" {
  description = "Admin password for SQL Server VMs"
  type        = string
  sensitive   = true
}

variable "sql_data_disk_size_gb" {
  description = "Size of SQL Server data disk in GB"
  type        = number
  default     = 256
}

variable "sql_log_disk_size_gb" {
  description = "Size of SQL Server log disk in GB"
  type        = number
  default     = 128
}

# =============================================================================
# Storage
# =============================================================================

variable "cloud_witness_storage_name" {
  description = "Globally unique name for Cloud Witness storage account"
  type        = string
  default     = "stcloudwitness001"
}

# =============================================================================
# Private Link Service
# =============================================================================

variable "pls_auto_approval_subscription_ids" {
  description = "List of subscription IDs to auto-approve PE connections (leave empty for manual approval)"
  type        = list(string)
  default     = []
}

variable "pls_visibility_subscription_ids" {
  description = "List of subscription IDs that can see the PLS (leave empty for no restriction)"
  type        = list(string)
  default     = []
}

# =============================================================================
# Failover Automation
# =============================================================================

variable "failover_storage_name" {
  description = "Globally unique storage account name for failover Function App"
  type        = string
  default     = "stfailoversql001"
}

variable "snowflake_account" {
  description = "Snowflake account identifier (e.g., xy12345.east-us-2.azure)"
  type        = string
  default     = ""
}

variable "snowflake_user" {
  description = "Snowflake automation user for SQL API calls"
  type        = string
  default     = "FAILOVER_SVC"
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
  description = "Fully qualified Snowflake network rule name"
  type        = string
  default     = ""
}

variable "snowflake_eai" {
  description = "Snowflake external access integration name"
  type        = string
  default     = ""
}

variable "primary_pls_host" {
  description = "Primary region PLS FQDN:port for Snowflake"
  type        = string
  default     = ""
}

variable "secondary_pls_host" {
  description = "Secondary region PLS FQDN:port for Snowflake"
  type        = string
  default     = ""
}

variable "failover_cooldown_seconds" {
  description = "Cooldown period between failover events (seconds)"
  type        = number
  default     = 300
}
