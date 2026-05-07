variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
}

variable "location" {
  description = "Azure region for the Private Link Service."
  type        = string
}

variable "pls_name" {
  description = "Name of the Private Link Service."
  type        = string
}

variable "lb_frontend_ip_config_id" {
  description = "Resource ID of the Load Balancer frontend IP configuration to front."
  type        = string
}

variable "nat_subnet_id" {
  description = "Resource ID of the subnet used for Private Link Service NAT."
  type        = string
}

variable "auto_approval_subscription_ids" {
  description = "List of subscription IDs that are auto-approved for Private Endpoint connections."
  type        = list(string)
  default     = []
}

variable "visibility_subscription_ids" {
  description = "List of subscription IDs for which the Private Link Service is visible."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to the Private Link Service."
  type        = map(string)
  default     = {}
}
