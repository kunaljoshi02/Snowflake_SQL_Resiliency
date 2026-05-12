# -----------------------------------------------------------------------------
# Subnets
# -----------------------------------------------------------------------------

resource "azurerm_subnet" "appgw" {
  name                 = "snet-appgw"
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.vnet_name
  address_prefixes     = [var.appgw_subnet_prefix]
}

resource "azurerm_subnet" "pe" {
  name                 = "snet-privateendpoints"
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.vnet_name
  address_prefixes     = [var.pe_subnet_prefix]
}

# -----------------------------------------------------------------------------
# Private Endpoints to cross-region Private Link Services
# -----------------------------------------------------------------------------

resource "azurerm_private_endpoint" "primary_sql" {
  name                = "pe-pls-primary-sql"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.pe.id
  tags                = var.tags

  private_service_connection {
    name                           = "pe-to-pls-primary"
    private_connection_resource_id = var.primary_pls_id
    is_manual_connection           = true
    request_message                = "PE for App Gateway to Primary SQL PLS"
  }
}

resource "azurerm_private_endpoint" "secondary_sql" {
  name                = "pe-pls-secondary-sql"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.pe.id
  tags                = var.tags

  private_service_connection {
    name                           = "pe-to-pls-secondary"
    private_connection_resource_id = var.secondary_pls_id
    is_manual_connection           = true
    request_message                = "PE for App Gateway to Secondary SQL PLS"
  }
}

# -----------------------------------------------------------------------------
# Public IP (required for Application Gateway v2, used for management plane)
# -----------------------------------------------------------------------------

resource "azurerm_public_ip" "appgw" {
  name                = "${var.appgw_name}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# -----------------------------------------------------------------------------
# Application Gateway v2
# -----------------------------------------------------------------------------
# NOTE: L4 TCP proxy mode must be configured post-deployment via Azure CLI
# as the azurerm provider does not yet natively support TCP/TLS listeners.
# Run: az network application-gateway update ... to switch to TCP mode

resource "azurerm_application_gateway" "this" {
  name                = var.appgw_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  sku {
    name = "Standard_v2"
    tier = "Standard_v2"
  }

  autoscale_configuration {
    min_capacity = 1
    max_capacity = 2
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.appgw.id
  }

  # Private frontend – used by SQL clients inside the VNet
  frontend_ip_configuration {
    name                          = "appgw-private-frontend"
    subnet_id                     = azurerm_subnet.appgw.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(var.appgw_subnet_prefix, 10)
  }

  # Public frontend – required by App Gateway v2 SKU
  frontend_ip_configuration {
    name                 = "appgw-public-frontend"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  frontend_port {
    name = "sql-port"
    port = 1433
  }

  backend_address_pool {
    name = "sql-backends"
    ip_addresses = [
      azurerm_private_endpoint.primary_sql.private_service_connection[0].private_ip_address,
      azurerm_private_endpoint.secondary_sql.private_service_connection[0].private_ip_address,
    ]
  }

  # Placeholder HTTP settings — post-deployment, switch to TCP via Azure CLI
  backend_http_settings {
    name                  = "sql-backend-settings"
    port                  = 1433
    protocol              = "Http"
    request_timeout       = 30
    cookie_based_affinity = "Disabled"
  }

  http_listener {
    name                           = "sql-listener"
    frontend_ip_configuration_name = "appgw-private-frontend"
    frontend_port_name             = "sql-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "sql-routing-rule"
    rule_type                  = "Basic"
    priority                   = 100
    http_listener_name         = "sql-listener"
    backend_address_pool_name  = "sql-backends"
    backend_http_settings_name = "sql-backend-settings"
  }
}
