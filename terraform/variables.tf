variable "hub_name" {
  description = "Name of the hub for state file naming"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "config_format" {
  description = "Configuration file format (json or yaml)"
  type        = string
  default     = "yaml"
  validation {
    condition     = contains(["json", "yaml"], var.config_format)
    error_message = "Config format must be either 'json' or 'yaml'."
  }
} 