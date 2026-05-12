resource "azurerm_subnet" "container_apps" {
  name                 = "snet-container-apps"
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.vnet_name
  address_prefixes     = [var.container_app_subnet_prefix]

  delegation {
    name = "container-apps-delegation"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_container_app_environment" "this" {
  name                           = var.container_app_env_name
  location                       = var.location
  resource_group_name            = var.resource_group_name
  infrastructure_subnet_id       = azurerm_subnet.container_apps.id
  internal_load_balancer_enabled = true
  tags                           = var.tags
}

resource "azurerm_container_app" "this" {
  name                         = var.container_app_name
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  tags                         = var.tags

  template {
    container {
      name   = "sql-tester"
      image  = var.container_image
      cpu    = 0.5
      memory = "1Gi"
    }

    min_replicas = 1
    max_replicas = 1
  }

  ingress {
    target_port      = 8080
    external_enabled = true
    transport        = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}
