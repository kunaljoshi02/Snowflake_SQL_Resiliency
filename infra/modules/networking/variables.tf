variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
}

variable "sql_subnet_name" {
  description = "Name of the SQL VM subnet"
  type        = string
}

variable "sql_subnet_prefix" {
  description = "Address prefix for the SQL VM subnet"
  type        = string
}

variable "pls_subnet_name" {
  description = "Name of the Private Link Service NAT subnet"
  type        = string
}

variable "pls_subnet_prefix" {
  description = "Address prefix for the PLS NAT subnet"
  type        = string
}

variable "pls_source_cidr" {
  description = "Source CIDR for the PLS NAT subnet, used in SQL NSG rules"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
