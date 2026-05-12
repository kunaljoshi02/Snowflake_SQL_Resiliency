variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "vnet_id" {
  description = "Resource ID of the existing VNet"
  type        = string
}

variable "vnet_name" {
  description = "Name of the existing VNet"
  type        = string
}

variable "appgw_subnet_prefix" {
  description = "CIDR prefix for the Application Gateway subnet"
  type        = string
  default     = "10.1.3.0/24"
}

variable "pe_subnet_prefix" {
  description = "CIDR prefix for the Private Endpoints subnet"
  type        = string
  default     = "10.1.4.0/24"
}

variable "appgw_name" {
  description = "Name of the Application Gateway"
  type        = string
}

variable "primary_pls_id" {
  description = "Resource ID of the primary region Private Link Service"
  type        = string
}

variable "secondary_pls_id" {
  description = "Resource ID of the secondary region Private Link Service"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
