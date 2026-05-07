output "lb_id" {
  description = "ID of the internal load balancer."
  value       = azurerm_lb.this.id
}

output "lb_frontend_ip_config_id" {
  description = "ID of the frontend IP configuration (needed by Private Link Service)."
  value       = azurerm_lb.this.frontend_ip_configuration[0].id
}

output "backend_pool_id" {
  description = "ID of the backend address pool."
  value       = azurerm_lb_backend_address_pool.this.id
}
