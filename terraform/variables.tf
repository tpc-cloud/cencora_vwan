variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
  default     = "eastus"
}

variable "tags" {
  description = "Tags to be applied to all resources"
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

variable "CLIENT_ID" {
  description = "The Client ID for the Service Principal"
  type        = string
  sensitive   = true
}

variable "TENANT_ID" {
  description = "The Tenant ID for the Azure subscription"
  type        = string
  sensitive   = true
}

variable "SUBSCRIPTION_ID" {
  description = "The Subscription ID for the Azure subscription"
  type        = string
  sensitive   = true
} 