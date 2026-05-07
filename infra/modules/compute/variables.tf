variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
}

variable "vm_name" {
  description = "Name of the SQL Server virtual machine."
  type        = string
}

variable "vm_size" {
  description = "Azure VM size."
  type        = string
  default     = "Standard_E4ds_v5"
}

variable "zone" {
  description = "Availability zone for the VM (e.g. \"1\", \"2\", \"3\")."
  type        = string
}

variable "subnet_id" {
  description = "Resource ID of the subnet for the VM NIC."
  type        = string
}

variable "admin_username" {
  description = "Local administrator username."
  type        = string
  default     = "sqladmin"
}

variable "admin_password" {
  description = "Local administrator password."
  type        = string
  sensitive   = true
}

variable "data_disk_size_gb" {
  description = "Size in GB of the SQL data disk."
  type        = number
  default     = 256
}

variable "log_disk_size_gb" {
  description = "Size in GB of the SQL log disk."
  type        = number
  default     = 128
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "install_adventureworks" {
  description = "Whether to install the AdventureWorks sample database on this VM."
  type        = bool
  default     = true
}
