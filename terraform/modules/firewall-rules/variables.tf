variable "config_file_path" {
  description = "Path to the YAML configuration file containing firewall rules"
  type        = string
}

variable "firewall_policy_id" {
  description = "ID of the Azure Firewall Policy"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
} 