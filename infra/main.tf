terraform {
  required_version = ">= 1.3.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id      = var.subscription_id
  storage_use_azuread  = true
}

locals {
  common_tags = {
    Environment = var.environment
    Project     = "sql-plink-multiregion"
    ManagedBy   = "Terraform"
  }
  secondary_vm_size = var.sql_vm_size_secondary != "" ? var.sql_vm_size_secondary : var.sql_vm_size
}

# =============================================================================
# Single Resource Group
# =============================================================================

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.primary_location
  tags     = local.common_tags
}

# =============================================================================
# Monitoring (shared — primary region)
# =============================================================================

module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  workspace_name      = "log-sql-plink-${var.primary_location_short}-001"
  retention_days      = 30
  tags                = local.common_tags
}

# =============================================================================
# Cloud Witness Storage Account (third region for quorum)
# =============================================================================

module "cloud_witness" {
  source = "./modules/storage"

  resource_group_name  = azurerm_resource_group.main.name
  location             = var.cloud_witness_location
  storage_account_name = var.cloud_witness_storage_name
  tags                 = local.common_tags
}

# =============================================================================
# PRIMARY REGION — Networking
# =============================================================================

module "networking_primary" {
  source = "./modules/networking"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  vnet_name           = "vnet-sql-${var.primary_location_short}-001"
  vnet_address_space  = ["10.1.0.0/16"]
  sql_subnet_name     = "snet-sql-${var.primary_location_short}-001"
  sql_subnet_prefix   = "10.1.1.0/24"
  pls_subnet_name     = "snet-pls-${var.primary_location_short}-001"
  pls_subnet_prefix   = "10.1.2.0/24"
  pls_source_cidr     = "10.1.2.0/24"
  tags                = local.common_tags
}

# =============================================================================
# SECONDARY REGION — Networking
# =============================================================================

module "networking_secondary" {
  source = "./modules/networking"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.secondary_location
  vnet_name           = "vnet-sql-${var.secondary_location_short}-001"
  vnet_address_space  = ["10.2.0.0/16"]
  sql_subnet_name     = "snet-sql-${var.secondary_location_short}-001"
  sql_subnet_prefix   = "10.2.1.0/24"
  pls_subnet_name     = "snet-pls-${var.secondary_location_short}-001"
  pls_subnet_prefix   = "10.2.2.0/24"
  pls_source_cidr     = "10.2.2.0/24"
  tags                = local.common_tags
}

# =============================================================================
# VNet Peering (bidirectional for WSFC / AG replication)
# =============================================================================

resource "azurerm_virtual_network_peering" "primary_to_secondary" {
  name                      = "peer-${var.primary_location_short}-to-${var.secondary_location_short}"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = module.networking_primary.vnet_name
  remote_virtual_network_id = module.networking_secondary.vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "secondary_to_primary" {
  name                      = "peer-${var.secondary_location_short}-to-${var.primary_location_short}"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = module.networking_secondary.vnet_name
  remote_virtual_network_id = module.networking_primary.vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# =============================================================================
# PRIMARY REGION — SQL Server VMs
# =============================================================================

module "sql_vm_primary_1" {
  source = "./modules/compute"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  vm_name             = "vm-sql-${var.primary_location_short}-001"
  vm_size             = var.sql_vm_size
  zone                = "1"
  subnet_id           = module.networking_primary.sql_subnet_id
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  data_disk_size_gb   = var.sql_data_disk_size_gb
  log_disk_size_gb    = var.sql_log_disk_size_gb
  install_adventureworks = false
  tags                = local.common_tags
}

module "sql_vm_primary_2" {
  source = "./modules/compute"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  vm_name             = "vm-sql-${var.primary_location_short}-002"
  vm_size             = var.sql_vm_size
  zone                = "2"
  subnet_id           = module.networking_primary.sql_subnet_id
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  data_disk_size_gb   = var.sql_data_disk_size_gb
  log_disk_size_gb    = var.sql_log_disk_size_gb
  install_adventureworks = false
  tags                = local.common_tags
}

# =============================================================================
# SECONDARY REGION — SQL Server VMs
# =============================================================================

module "sql_vm_secondary_1" {
  source = "./modules/compute"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.secondary_location
  vm_name             = "vm-sql-${var.secondary_location_short}-001"
  vm_size             = local.secondary_vm_size
  zone                = "2"
  subnet_id           = module.networking_secondary.sql_subnet_id
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  data_disk_size_gb   = var.sql_data_disk_size_gb
  log_disk_size_gb    = var.sql_log_disk_size_gb
  install_adventureworks = false
  tags                = local.common_tags
}

module "sql_vm_secondary_2" {
  source = "./modules/compute"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.secondary_location
  vm_name             = "vm-sql-${var.secondary_location_short}-002"
  vm_size             = local.secondary_vm_size
  zone                = "3"
  subnet_id           = module.networking_secondary.sql_subnet_id
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  data_disk_size_gb   = var.sql_data_disk_size_gb
  log_disk_size_gb    = var.sql_log_disk_size_gb
  install_adventureworks = false
  tags                = local.common_tags
}

# =============================================================================
# PRIMARY REGION — Internal Load Balancer (AG Listener)
# =============================================================================

module "lb_primary" {
  source = "./modules/loadbalancer"

  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  lb_name              = "lbi-sql-${var.primary_location_short}-001"
  subnet_id            = module.networking_primary.sql_subnet_id
  frontend_private_ip  = "10.1.1.10"
  nic_ids              = [module.sql_vm_primary_1.nic_id, module.sql_vm_primary_2.nic_id]
  tags                 = local.common_tags
}

# =============================================================================
# SECONDARY REGION — Internal Load Balancer (AG Listener)
# =============================================================================

module "lb_secondary" {
  source = "./modules/loadbalancer"

  resource_group_name  = azurerm_resource_group.main.name
  location             = var.secondary_location
  lb_name              = "lbi-sql-${var.secondary_location_short}-001"
  subnet_id            = module.networking_secondary.sql_subnet_id
  frontend_private_ip  = "10.2.1.10"
  nic_ids              = [module.sql_vm_secondary_1.nic_id, module.sql_vm_secondary_2.nic_id]
  tags                 = local.common_tags
}

# =============================================================================
# PRIMARY REGION — Private Link Service
# =============================================================================

module "pls_primary" {
  source = "./modules/privatelink"

  resource_group_name              = azurerm_resource_group.main.name
  location                         = azurerm_resource_group.main.location
  pls_name                         = "pls-sql-${var.primary_location_short}-001"
  lb_frontend_ip_config_id         = module.lb_primary.lb_frontend_ip_config_id
  nat_subnet_id                    = module.networking_primary.pls_subnet_id
  auto_approval_subscription_ids   = var.pls_auto_approval_subscription_ids
  visibility_subscription_ids      = var.pls_visibility_subscription_ids
  tags                             = local.common_tags
}

# =============================================================================
# SECONDARY REGION — Private Link Service
# =============================================================================

module "pls_secondary" {
  source = "./modules/privatelink"

  resource_group_name              = azurerm_resource_group.main.name
  location                         = var.secondary_location
  pls_name                         = "pls-sql-${var.secondary_location_short}-001"
  lb_frontend_ip_config_id         = module.lb_secondary.lb_frontend_ip_config_id
  nat_subnet_id                    = module.networking_secondary.pls_subnet_id
  auto_approval_subscription_ids   = var.pls_auto_approval_subscription_ids
  visibility_subscription_ids      = var.pls_visibility_subscription_ids
  tags                             = local.common_tags
}

