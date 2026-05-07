resource "azurerm_private_link_service" "this" {
  name                = var.pls_name
  resource_group_name = var.resource_group_name
  location            = var.location

  load_balancer_frontend_ip_configuration_ids = [var.lb_frontend_ip_config_id]

  nat_ip_configuration {
    name                       = "pls-nat-config-primary"
    primary                    = true
    private_ip_address_version = "IPv4"
    subnet_id                  = var.nat_subnet_id
  }

  auto_approval_subscription_ids = var.auto_approval_subscription_ids
  visibility_subscription_ids    = var.visibility_subscription_ids

  proxy_protocol_enabled = false

  tags = var.tags
}
