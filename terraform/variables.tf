variable "client_id" {
  description = "The Client ID for the Service Principal"
  type        = string
}

variable "tenant_id" {
  description = "The Tenant ID for the Service Principal"
  type        = string
}

variable "subscription_id" {
  description = "The Subscription ID for the Service Principal"
  type        = string
}

variable "environment" {
  description = "The environment (e.g., dev, prod)"
  type        = string
}

variable "hub_name" {
  description = "The name of the hub being deployed"
  type        = string
  default     = "core"
}

variable "location" {
  description = "The Azure region to deploy resources"
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