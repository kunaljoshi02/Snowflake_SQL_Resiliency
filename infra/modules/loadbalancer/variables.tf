variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
}

variable "location" {
  description = "Azure region for the load balancer."
  type        = string
}

variable "lb_name" {
  description = "Name of the internal load balancer."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the frontend private IP."
  type        = string
}

variable "frontend_private_ip" {
  description = "Static private IP address for the LB frontend (e.g. 10.1.1.10)."
  type        = string
}

variable "nic_ids" {
  description = "List of NIC IDs to associate with the backend pool."
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
