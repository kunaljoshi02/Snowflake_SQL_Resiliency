variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "container_app_name" {
  description = "Name of the Container App"
  type        = string
}

variable "container_app_env_name" {
  description = "Name of the Container App Environment"
  type        = string
}

variable "vnet_id" {
  description = "VNet ID for the Container App subnet"
  type        = string
}

variable "vnet_name" {
  description = "VNet name for the Container App subnet"
  type        = string
}

variable "container_app_subnet_prefix" {
  description = "Address prefix for the Container Apps subnet (minimum /23)"
  type        = string
  default     = "10.1.8.0/23"
}

variable "container_image" {
  description = "Container image to deploy"
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
