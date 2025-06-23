# Firewall Rules Module
# This module reads a YAML configuration file and creates Azure Firewall rules

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

locals {
  # Read the YAML configuration file
  config = yamldecode(file(var.config_file_path))

  # Extract configuration sections
  firewall_policy              = local.config.firewall_policy
  network_rule_collections     = local.config.network_rule_collections
  application_rule_collections = local.config.application_rule_collections
  nat_rule_collections         = local.config.nat_rule_collections
  tags                         = merge(var.tags, local.config.tags)
}

# Create Firewall Policy Rule Collection Group
resource "azurerm_firewall_policy_rule_collection_group" "main" {
  name               = "default-rule-collection-group"
  firewall_policy_id = var.firewall_policy_id
  priority           = 500
}

# Create Network Rule Collections
resource "azurerm_firewall_policy_rule_collection" "network_rules" {
  for_each = { for idx, collection in local.network_rule_collections : collection.name => collection }

  name                     = each.value.name
  firewall_policy_id       = var.firewall_policy_id
  rule_collection_group_id = azurerm_firewall_policy_rule_collection_group.main.id
  priority                 = each.value.priority
  rule_collection_type     = "FirewallPolicyFilterRuleCollection"

  dynamic "rule" {
    for_each = each.value.rules
    content {
      name = rule.value.name

      dynamic "protocols" {
        for_each = rule.value.protocols
        content {
          protocol_type = protocols.value.type
          port          = lookup(protocols.value, "port", null)
        }
      }

      source_addresses      = rule.value.source_addresses
      destination_addresses = rule.value.destination_addresses
      destination_ports     = rule.value.destination_ports
      destination_fqdns     = lookup(rule.value, "destination_fqdns", null)
      action                = rule.value.action
    }
  }
}

# Create Application Rule Collections
resource "azurerm_firewall_policy_rule_collection" "application_rules" {
  for_each = { for idx, collection in local.application_rule_collections : collection.name => collection }

  name                     = each.value.name
  firewall_policy_id       = var.firewall_policy_id
  rule_collection_group_id = azurerm_firewall_policy_rule_collection_group.main.id
  priority                 = each.value.priority
  rule_collection_type     = "FirewallPolicyFilterRuleCollection"

  dynamic "rule" {
    for_each = each.value.rules
    content {
      name = rule.value.name

      dynamic "protocols" {
        for_each = rule.value.protocols
        content {
          port = protocols.value.port
          type = protocols.value.type
        }
      }

      source_addresses  = rule.value.source_addresses
      destination_fqdns = rule.value.destination_fqdns
      action            = rule.value.action
    }
  }
}

# Create NAT Rule Collections
resource "azurerm_firewall_policy_rule_collection" "nat_rules" {
  for_each = { for idx, collection in local.nat_rule_collections : collection.name => collection }

  name                     = each.value.name
  firewall_policy_id       = var.firewall_policy_id
  rule_collection_group_id = azurerm_firewall_policy_rule_collection_group.main.id
  priority                 = each.value.priority
  rule_collection_type     = "FirewallPolicyNatRuleCollection"

  dynamic "rule" {
    for_each = each.value.rules
    content {
      name = rule.value.name

      dynamic "protocols" {
        for_each = rule.value.protocols
        content {
          protocol_type = protocols.value.type
          port          = lookup(protocols.value, "port", null)
        }
      }

      source_addresses      = rule.value.source_addresses
      destination_addresses = rule.value.destination_addresses
      destination_ports     = rule.value.destination_ports
      translated_address    = rule.value.translated_address
      translated_port       = rule.value.translated_port
      action                = rule.value.action
    }
  }
} 