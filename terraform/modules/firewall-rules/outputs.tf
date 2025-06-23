output "rule_collection_group_id" {
  description = "ID of the firewall policy rule collection group"
  value       = azurerm_firewall_policy_rule_collection_group.main.id
}

output "network_rule_collections" {
  description = "Map of network rule collections created"
  value       = azurerm_firewall_policy_rule_collection.network_rules
}

output "application_rule_collections" {
  description = "Map of application rule collections created"
  value       = azurerm_firewall_policy_rule_collection.application_rules
}

output "nat_rule_collections" {
  description = "Map of NAT rule collections created"
  value       = azurerm_firewall_policy_rule_collection.nat_rules
}

output "total_rules_created" {
  description = "Total number of firewall rules created"
  value = (
    try(length(azurerm_firewall_policy_rule_collection.network_rules), 0) +
    try(length(azurerm_firewall_policy_rule_collection.application_rules), 0) +
    try(length(azurerm_firewall_policy_rule_collection.nat_rules), 0)
  )
} 